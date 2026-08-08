import { NextResponse } from "next/server"
import { getServerSession } from "next-auth"
import { authOptions } from "@/lib/auth/config"
import { prisma } from "@/lib/prisma"
import {
  createFileSearchStore,
  uploadToFileSearchStore,
  fileSearchEnabled,
} from "@/lib/openai"
import { extractText, indexNote } from "@/lib/rag"

const SUPPORTED = [
  "application/pdf",
  "text/plain",
  "text/markdown",
  "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
]

// POST - Upload a note
export async function POST(
  req: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const session = await getServerSession(authOptions)

    if (!session?.user?.email) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
    }

    const user = await prisma.user.findUnique({
      where: { email: session.user.email },
    })

    if (!user) {
      return NextResponse.json({ error: "User not found" }, { status: 404 })
    }

    const { id } = await params

    let subject = await prisma.subject.findFirst({
      where: { id, userId: user.id },
    })

    if (!subject) {
      return NextResponse.json({ error: "Subject not found" }, { status: 404 })
    }

    const formData = await req.formData()
    const file = formData.get("file") as File

    if (!file) {
      return NextResponse.json({ error: "No file provided" }, { status: 400 })
    }

    const name = file.name.toLowerCase()
    const isSupported =
      SUPPORTED.some((type) => file.type.includes(type.split("/")[1])) ||
      /\.(pdf|txt|md|docx)$/.test(name)

    if (!isSupported) {
      return NextResponse.json(
        { error: "Supported formats: PDF, DOCX, TXT, MD" },
        { status: 400 }
      )
    }

    const buffer = Buffer.from(await file.arrayBuffer())

    // 1. Extract text so RAG always has real content to work with
    const { text: content, error: extractionError } = await extractText(
      buffer,
      file.type,
      file.name
    )

    if (extractionError) {
      console.warn(`Text extraction failed for ${file.name}: ${extractionError}`)
    }

    // 2. Attach to the subject's OpenAI vector store (created lazily)
    let vectorStoreId = subject.fileSearchStoreId

    if (!vectorStoreId && fileSearchEnabled) {
      vectorStoreId = await createFileSearchStore(
        `${subject.displayName}-${subject.id}`
      )

      if (vectorStoreId) {
        subject = await prisma.subject.update({
          where: { id: subject.id },
          data: { fileSearchStoreId: vectorStoreId },
        })
      }
    }

    let openaiFileId: string | null = null

    if (vectorStoreId) {
      const uploaded = await uploadToFileSearchStore(
        file,
        file.name,
        vectorStoreId
      )
      openaiFileId = uploaded?.fileId ?? null
    }

    const sanitizedFileName = file.name.replace(/[^a-zA-Z0-9.-]/g, "_")

    const note = await prisma.note.create({
      data: {
        subjectId: subject.id,
        displayName: file.name,
        fileName: sanitizedFileName,
        fileUrl: `/uploads/${subject.id}/${sanitizedFileName}`,
        fileType: file.type || "application/octet-stream",
        fileSize: file.size,
        fileSearchDocId: openaiFileId,
        content: content || null,
        metadata: {
          uploadedBy: user.email,
          originalName: file.name,
          openaiFileId,
          fileSearchEnabled: Boolean(openaiFileId),
          characters: content.length,
          extractionError,
        },
      },
    })

    // 3. Build the local embedding index for semantic retrieval
    let chunkCount = 0
    let indexError: string | null = null
    try {
      chunkCount = await indexNote(note.id, subject.id, content)
    } catch (error) {
      indexError = error instanceof Error ? error.message : String(error)
      console.error("Failed to index note embeddings:", error)
    }

    // Say plainly which retrieval paths this file is actually reachable through,
    // so a file the AI cannot read never looks like a clean upload.
    const searchable = chunkCount > 0 || Boolean(openaiFileId)
    const warning = chunkCount > 0 ? null : extractionError || indexError

    return NextResponse.json({
      note,
      indexed: chunkCount > 0,
      chunks: chunkCount,
      fileSearch: Boolean(openaiFileId),
      searchable,
      warning,
      message: !searchable
        ? "File uploaded, but the AI cannot read it yet"
        : chunkCount > 0
          ? "File uploaded and indexed for AI features"
          : "File uploaded. Local indexing failed, so answers will come from OpenAI file search only",
    })
  } catch (error) {
    console.error("Error uploading note:", error)
    return NextResponse.json(
      { error: "Failed to upload note" },
      { status: 500 }
    )
  }
}

// GET - List all notes for a subject
export async function GET(
  req: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params
  try {
    const session = await getServerSession(authOptions)

    if (!session?.user?.email) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
    }

    const user = await prisma.user.findUnique({
      where: { email: session.user.email },
    })

    if (!user) {
      return NextResponse.json({ error: "User not found" }, { status: 404 })
    }

    const notes = await prisma.note.findMany({
      where: {
        subject: { id, userId: user.id },
      },
      orderBy: { uploadedAt: "desc" },
      select: {
        id: true,
        displayName: true,
        fileName: true,
        fileUrl: true,
        fileType: true,
        fileSize: true,
        indexed: true,
        uploadedAt: true,
        metadata: true,
      },
    })

    return NextResponse.json({ notes })
  } catch (error) {
    console.error("Error fetching notes:", error)
    return NextResponse.json(
      { error: "Failed to fetch notes" },
      { status: 500 }
    )
  }
}
