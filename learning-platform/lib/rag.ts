import { prisma } from "@/lib/prisma"
import {
  embed,
  embedOne,
  isConfigured,
  searchVectorStore,
} from "@/lib/openai"

const CHUNK_SIZE = 1200
const CHUNK_OVERLAP = 200
const EMBED_BATCH = 64

// ============ TEXT EXTRACTION ============

export interface ExtractionResult {
  text: string
  /** Why extraction produced nothing usable, if it did. */
  error: string | null
}

/**
 * Extracts plain text from an uploaded file buffer.
 *
 * Returns the reason on failure rather than an empty string. Swallowing the
 * error here is what let a scanned or unparseable PDF look like a successful
 * upload while leaving RAG with nothing to retrieve.
 */
export async function extractText(
  buffer: Buffer,
  fileType: string,
  fileName: string
): Promise<ExtractionResult> {
  const type = (fileType || "").toLowerCase()
  const name = (fileName || "").toLowerCase()

  try {
    let text = ""

    if (type.includes("pdf") || name.endsWith(".pdf")) {
      const { PDFParse } = await import("pdf-parse")
      const parser = new PDFParse({ data: new Uint8Array(buffer) })
      try {
        const result = await parser.getText()
        text = normalize(result.text || "")
      } finally {
        await parser.destroy()
      }

      if (!text) {
        return {
          text: "",
          error:
            "No text layer found in this PDF. If it is a scan or an image export, it needs OCR before it can be searched.",
        }
      }

      return { text, error: null }
    }

    if (
      type.includes("wordprocessingml") ||
      name.endsWith(".docx") ||
      name.endsWith(".doc")
    ) {
      const mammoth = await import("mammoth")
      const result = await mammoth.extractRawText({ buffer })
      text = normalize(result.value || "")
      return {
        text,
        error: text ? null : "The document contained no readable text.",
      }
    }

    // Plain text, markdown, csv, json and friends
    text = normalize(buffer.toString("utf-8"))
    return {
      text,
      error: text ? null : "The file contained no readable text.",
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error)
    console.error(`Failed to extract text from ${fileName}:`, error)
    return { text: "", error: `Could not read this file: ${message}` }
  }
}

function normalize(text: string): string {
  return text
    .replace(/\r\n/g, "\n")
    .replace(/[ \t]+/g, " ")
    .replace(/\n{3,}/g, "\n\n")
    .trim()
}

// ============ CHUNKING ============

export function chunkText(
  text: string,
  size = CHUNK_SIZE,
  overlap = CHUNK_OVERLAP
): string[] {
  if (!text) return []

  const paragraphs = text.split(/\n\s*\n/)
  const chunks: string[] = []
  let current = ""

  for (const paragraph of paragraphs) {
    if (paragraph.length > size) {
      // Flush and hard-split oversized paragraphs
      if (current.trim()) {
        chunks.push(current.trim())
        current = ""
      }
      for (let i = 0; i < paragraph.length; i += size - overlap) {
        chunks.push(paragraph.slice(i, i + size).trim())
      }
      continue
    }

    if (current.length + paragraph.length + 2 > size) {
      chunks.push(current.trim())
      current = current.slice(-overlap) + "\n\n" + paragraph
    } else {
      current = current ? `${current}\n\n${paragraph}` : paragraph
    }
  }

  if (current.trim()) chunks.push(current.trim())

  return chunks.filter((chunk) => chunk.length > 40)
}

// ============ INDEXING ============

/** Chunks a note, embeds each chunk and stores the vectors for retrieval. */
export async function indexNote(
  noteId: string,
  subjectId: string,
  content: string
): Promise<number> {
  if (!isConfigured() || !content) return 0

  const chunks = chunkText(content)
  if (chunks.length === 0) return 0

  await prisma.noteChunk.deleteMany({ where: { noteId } })

  let stored = 0

  for (let i = 0; i < chunks.length; i += EMBED_BATCH) {
    const batch = chunks.slice(i, i + EMBED_BATCH)
    const vectors = await embed(batch)

    await prisma.noteChunk.createMany({
      data: batch.map((chunk, index) => ({
        noteId,
        subjectId,
        order: i + index,
        content: chunk,
        embedding: JSON.stringify(vectors[index]),
      })),
    })

    stored += batch.length
  }

  await prisma.note.update({
    where: { id: noteId },
    data: { indexed: true },
  })

  return stored
}

// ============ RETRIEVAL ============

function cosineSimilarity(a: number[], b: number[]): number {
  let dot = 0
  let normA = 0
  let normB = 0

  for (let i = 0; i < a.length; i++) {
    dot += a[i] * b[i]
    normA += a[i] * a[i]
    normB += b[i] * b[i]
  }

  const denominator = Math.sqrt(normA) * Math.sqrt(normB)
  return denominator === 0 ? 0 : dot / denominator
}

export interface RetrievedChunk {
  content: string
  score: number
  noteId: string
  noteName: string
}

/**
 * Semantic search over a user's indexed notes. Scoped to a single subject when
 * `subjectId` is given, otherwise across every subject the user owns.
 */
export async function retrieve(
  query: string,
  options: { userId: string; subjectId?: string | null; topK?: number }
): Promise<RetrievedChunk[]> {
  const topK = options.topK ?? 8

  if (!isConfigured() || !query) return []

  const subjectFilter = options.subjectId
    ? { id: options.subjectId, userId: options.userId }
    : { userId: options.userId }

  const subjects = await prisma.subject.findMany({
    where: subjectFilter,
    select: { id: true, fileSearchStoreId: true },
  })

  const subjectIds = subjects.map((subject) => subject.id)
  if (subjectIds.length === 0) return []

  const chunks = await prisma.noteChunk.findMany({
    where: { subjectId: { in: subjectIds } },
    include: { note: { select: { displayName: true } } },
  })

  // Nothing indexed locally, usually because the file had no extractable text.
  // OpenAI still indexed the uploaded file, so ask it instead of giving up.
  if (chunks.length === 0) {
    return remoteFallback(query, subjects, topK)
  }

  let queryVector: number[]
  try {
    queryVector = await embedOne(query)
  } catch (error) {
    console.error("Failed to embed query, falling back to keyword match:", error)
    return keywordFallback(query, chunks, topK)
  }

  return chunks
    .map((chunk) => ({
      content: chunk.content,
      score: cosineSimilarity(queryVector, JSON.parse(chunk.embedding)),
      noteId: chunk.noteId,
      noteName: chunk.note.displayName,
    }))
    .sort((a, b) => b.score - a.score)
    .slice(0, topK)
}

/** Retrieval through OpenAI's vector stores, used when we have no local index. */
async function remoteFallback(
  query: string,
  subjects: Array<{ id: string; fileSearchStoreId: string | null }>,
  topK: number
): Promise<RetrievedChunk[]> {
  const stores = subjects.filter((subject) => subject.fileSearchStoreId)
  if (stores.length === 0) return []

  const batches = await Promise.all(
    stores.map((subject) =>
      searchVectorStore(subject.fileSearchStoreId as string, query, topK)
    )
  )

  return batches
    .flat()
    .filter((hit) => hit.content)
    .map((hit) => ({
      content: hit.content,
      score: hit.score,
      noteId: "",
      noteName: hit.fileName,
    }))
    .sort((a, b) => b.score - a.score)
    .slice(0, topK)
}

function keywordFallback(
  query: string,
  chunks: Array<{
    content: string
    noteId: string
    note: { displayName: string }
  }>,
  topK: number
): RetrievedChunk[] {
  const terms = query
    .toLowerCase()
    .split(/\W+/)
    .filter((term) => term.length > 3)

  return chunks
    .map((chunk) => {
      const haystack = chunk.content.toLowerCase()
      const score = terms.reduce(
        (total, term) => total + (haystack.includes(term) ? 1 : 0),
        0
      )
      return {
        content: chunk.content,
        score,
        noteId: chunk.noteId,
        noteName: chunk.note.displayName,
      }
    })
    .filter((chunk) => chunk.score > 0)
    .sort((a, b) => b.score - a.score)
    .slice(0, topK)
}

/** Retrieval formatted as a prompt-ready context block plus citations. */
export async function retrieveContext(
  query: string,
  options: { userId: string; subjectId?: string | null; topK?: number }
): Promise<{ context: string; citations: string[] }> {
  const chunks = await retrieve(query, options)

  if (chunks.length === 0) {
    return { context: "", citations: [] }
  }

  const context = chunks
    .map(
      (chunk, index) =>
        `[${index + 1}] From "${chunk.noteName}":\n${chunk.content}`
    )
    .join("\n\n---\n\n")

  const citations = Array.from(new Set(chunks.map((chunk) => chunk.noteName)))

  return { context, citations }
}

/**
 * Broad context for generation tasks (slides, quizzes, games) where a single
 * query does not capture everything. Falls back to the raw note text when the
 * subject has not been embedded yet.
 */
export async function buildSubjectContext(
  subjectId: string,
  userId: string,
  topic: string,
  options: { topK?: number; maxChars?: number } = {}
): Promise<{ context: string; citations: string[] }> {
  const maxChars = options.maxChars ?? 30000

  const retrieved = await retrieveContext(topic, {
    userId,
    subjectId,
    topK: options.topK ?? 16,
  })

  if (retrieved.context) {
    return {
      context: retrieved.context.slice(0, maxChars),
      citations: retrieved.citations,
    }
  }

  // Nothing retrievable - fall back to whatever raw text we stored on upload
  const notes = await prisma.note.findMany({
    where: { subjectId, subject: { userId } },
    orderBy: { uploadedAt: "desc" },
    take: 10,
    select: { displayName: true, content: true },
  })

  const parts: string[] = []
  let used = 0

  for (const note of notes) {
    if (!note.content) continue
    const remaining = maxChars - used
    if (remaining <= 0) break

    const slice = note.content.slice(0, remaining)
    parts.push(`From "${note.displayName}":\n${slice}`)
    used += slice.length
  }

  return {
    context: parts.join("\n\n---\n\n"),
    citations: notes.filter((note) => note.content).map((n) => n.displayName),
  }
}
