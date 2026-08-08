import OpenAI from "openai"

// ============ CLIENT ============

const apiKey = process.env.OPENAI_API_KEY || ""
const baseURL = process.env.OPENAI_BASE_URL || undefined

if (!apiKey) {
  console.warn("OPENAI_API_KEY is not set. AI features will not work.")
}

export const openai = new OpenAI({
  apiKey: apiKey || "sk-missing-key-for-build",
  ...(baseURL ? { baseURL } : {}),
})

export const MODELS = {
  chat: process.env.OPENAI_MODEL || "gpt-5.5",
  fast: process.env.OPENAI_FAST_MODEL || "gpt-5.4-mini",
  embedding: process.env.OPENAI_EMBEDDING_MODEL || "text-embedding-3-small",
  realtime: process.env.OPENAI_REALTIME_MODEL || "gpt-realtime-2.1",
  transcribe: process.env.OPENAI_TRANSCRIBE_MODEL || "gpt-4o-transcribe",
  tts: process.env.OPENAI_TTS_MODEL || "gpt-4o-mini-tts",
}

// File Search (vector stores) is only available on the real OpenAI API. When a
// custom base URL points at a compatible-but-not-OpenAI provider we fall back to
// the local embedding index in lib/rag.ts.
export const fileSearchEnabled =
  !baseURL || baseURL.includes("api.openai.com")

export function isConfigured() {
  return Boolean(apiKey)
}

// ============ LOW LEVEL HELPERS ============

interface CompleteOptions {
  system?: string
  model?: string
  temperature?: number
  maxTokens?: number
  vectorStoreId?: string | null
}

/**
 * Single-shot completion through the Responses API. When a vector store is
 * available the built-in file_search tool is attached so the model can pull
 * from the student's uploaded notes directly.
 */
export async function complete(
  prompt: string,
  options: CompleteOptions = {}
): Promise<string> {
  const useFileSearch =
    fileSearchEnabled && Boolean(options.vectorStoreId)

  const response = await openai.responses.create({
    model: options.model || MODELS.chat,
    ...(options.system ? { instructions: options.system } : {}),
    input: prompt,
    ...(options.temperature !== undefined
      ? { temperature: options.temperature }
      : {}),
    ...(options.maxTokens ? { max_output_tokens: options.maxTokens } : {}),
    ...(useFileSearch
      ? {
          tools: [
            {
              type: "file_search" as const,
              vector_store_ids: [options.vectorStoreId as string],
              max_num_results: 8,
            },
          ],
        }
      : {}),
  })

  return response.output_text || ""
}

/** Multi-turn chat completion, used by the tutor conversation. */
export async function chat(
  messages: Array<{ role: "system" | "user" | "assistant"; content: string }>,
  options: { model?: string; temperature?: number } = {}
): Promise<string> {
  const completion = await openai.chat.completions.create({
    model: options.model || MODELS.chat,
    messages,
    ...(options.temperature !== undefined
      ? { temperature: options.temperature }
      : {}),
  })

  return completion.choices[0]?.message?.content || ""
}

/** Strict JSON generation. Retries once with a repair prompt on parse failure. */
export async function completeJSON<T = any>(
  prompt: string,
  options: CompleteOptions & { expect?: "array" | "object" } = {}
): Promise<T> {
  const expect = options.expect || "object"
  const instruction = `\n\nRespond with valid JSON only. No markdown, no code fences, no commentary. The top level value must be a JSON ${expect}.`

  const raw = await complete(prompt + instruction, options)
  const parsed = tryParseJSON<T>(raw, expect)
  if (parsed !== null) return parsed

  // One repair attempt with the fast model
  const repaired = await complete(
    `The following text was supposed to be a JSON ${expect} but could not be parsed. Return only the corrected JSON, nothing else.\n\n${raw}`,
    { model: MODELS.fast }
  )
  const reparsed = tryParseJSON<T>(repaired, expect)
  if (reparsed !== null) return reparsed

  throw new Error(`Failed to parse JSON ${expect} from model response`)
}

function tryParseJSON<T>(raw: string, expect: "array" | "object"): T | null {
  if (!raw) return null

  const cleaned = raw
    .replace(/^```(?:json)?\s*/i, "")
    .replace(/```\s*$/, "")
    .trim()

  try {
    return JSON.parse(cleaned) as T
  } catch {
    // Fall through to bracket extraction
  }

  const open = expect === "array" ? "[" : "{"
  const close = expect === "array" ? "]" : "}"
  const start = cleaned.indexOf(open)
  const end = cleaned.lastIndexOf(close)

  if (start !== -1 && end > start) {
    try {
      return JSON.parse(cleaned.slice(start, end + 1)) as T
    } catch {
      return null
    }
  }

  return null
}

// ============ VECTOR STORES (OpenAI File Search) ============

/**
 * Creates an OpenAI vector store for a subject. Returns null when file search
 * is unavailable, in which case the local embedding index is used instead.
 */
export async function createFileSearchStore(
  displayName: string
): Promise<string | null> {
  if (!fileSearchEnabled || !isConfigured()) {
    console.warn(
      "OpenAI file search unavailable, falling back to the local embedding index."
    )
    return null
  }

  try {
    const store = await openai.vectorStores.create({
      name: displayName.slice(0, 250),
    })
    return store.id
  } catch (error) {
    console.error("Error creating vector store:", error)
    return null
  }
}

/** Uploads a file to OpenAI and attaches it to the subject's vector store. */
export async function uploadToFileSearchStore(
  file: File | Blob,
  fileName: string,
  vectorStoreId: string
): Promise<{ fileId: string; status: string } | null> {
  if (!fileSearchEnabled || !isConfigured()) return null

  try {
    const uploadable = new File([file], fileName, {
      type: (file as File).type || "application/octet-stream",
    })

    const uploaded = await openai.files.create({
      file: uploadable,
      purpose: "assistants",
    })

    const vectorStoreFile = await openai.vectorStores.files.createAndPoll(
      vectorStoreId,
      { file_id: uploaded.id }
    )

    return { fileId: uploaded.id, status: vectorStoreFile.status }
  } catch (error) {
    console.error("Error uploading to vector store:", error)
    return null
  }
}

/** Removes a subject's vector store and the files it holds. Best effort. */
export async function deleteFileSearchStore(vectorStoreId: string) {
  if (!fileSearchEnabled || !isConfigured()) return

  try {
    const files = await openai.vectorStores.files.list(vectorStoreId)
    for (const file of files.data) {
      await openai.files.delete(file.id).catch(() => undefined)
    }
    await openai.vectorStores.delete(vectorStoreId)
  } catch (error) {
    console.error("Error deleting vector store:", error)
  }
}

export async function deleteFromFileSearchStore(
  vectorStoreId: string,
  fileId: string
) {
  if (!fileSearchEnabled || !isConfigured()) return

  try {
    await openai.vectorStores.files.delete(fileId, {
      vector_store_id: vectorStoreId,
    })
    await openai.files.delete(fileId)
  } catch (error) {
    console.error("Error deleting file from vector store:", error)
  }
}

// ============ EMBEDDINGS ============

export async function embed(texts: string[]): Promise<number[][]> {
  if (texts.length === 0) return []

  const response = await openai.embeddings.create({
    model: MODELS.embedding,
    input: texts,
  })

  return response.data
    .sort((a, b) => a.index - b.index)
    .map((item) => item.embedding as number[])
}

export async function embedOne(text: string): Promise<number[]> {
  const [vector] = await embed([text])
  return vector
}

// ============ PROMPT BUILDING ============

export interface UserProfile {
  aiPersona?: string | null
  learningStyle?: string | null
  pace?: string | null
  interests?: string | string[] | null
  name?: string | null
}

export function parseInterests(
  interests: string | string[] | null | undefined
): string[] {
  if (!interests) return []
  if (Array.isArray(interests)) return interests

  try {
    const parsed = JSON.parse(interests)
    return Array.isArray(parsed) ? parsed : [interests]
  } catch {
    return interests
      .split(",")
      .map((value) => value.trim())
      .filter(Boolean)
  }
}

export function buildTutorSystemPrompt(profile?: UserProfile): string {
  if (!profile) return "You are a helpful, encouraging AI tutor."

  const interests = parseInterests(profile.interests)

  const lines = [
    "You are an AI tutor for a student.",
    profile.name ? `The student's name is ${profile.name}.` : "",
    profile.aiPersona ? `Adopt this personality: ${profile.aiPersona}.` : "",
    profile.learningStyle
      ? `They learn best through: ${profile.learningStyle}. Shape your explanations accordingly.`
      : "",
    profile.pace ? `Their preferred learning pace is: ${profile.pace}.` : "",
    interests.length
      ? `Their interests are: ${interests.join(", ")}. Draw analogies and examples from these whenever possible.`
      : "",
    "Be accurate, concrete and encouraging. Prefer worked examples over abstract definitions.",
  ]

  return lines.filter(Boolean).join("\n")
}

// ============ RAG ============

/**
 * Answers a question grounded in the student's notes. `context` should come
 * from lib/rag.ts retrieval; `vectorStoreId` additionally lets the model run
 * its own OpenAI file search over the same subject.
 */
export async function queryWithRAG(
  question: string,
  context: string,
  userProfile?: UserProfile,
  vectorStoreId?: string | null
): Promise<string> {
  const prompt = `Context from the student's uploaded notes:
${context || "(no notes have been uploaded yet)"}

Student's question: ${question}

Answer clearly using the context above. If the context does not cover the question, say so explicitly and then give the best general guidance you can.`

  return complete(prompt, {
    system: buildTutorSystemPrompt(userProfile),
    vectorStoreId,
  })
}

export async function queryWithFileSearch(
  question: string,
  vectorStoreId: string | null,
  userProfile?: UserProfile,
  context = ""
): Promise<{ answer: string; citations: string[] | null }> {
  const answer = await queryWithRAG(
    question,
    context,
    userProfile,
    vectorStoreId
  )

  return {
    answer: answer || "I couldn't generate an answer.",
    citations: null,
  }
}

// ============ SLIDES ============

export async function generateSlides(
  topic: string,
  context: string,
  userProfile?: UserProfile,
  vectorStoreId?: string | null
) {
  const interests = parseInterests(userProfile?.interests)

  const prompt = `You are an expert educator creating an engaging slide deck${
    userProfile?.learningStyle
      ? ` for a ${userProfile.learningStyle} learner`
      : ""
  }${interests.length ? ` interested in ${interests.join(", ")}` : ""}.

Topic: ${topic}

Reference material from the student's notes:
${context || "(no notes available, rely on your own knowledge of the topic)"}

Create 8-12 slides. Each slide object must have:
- "title": concise, engaging title
- "mainPoints": array of 3-5 short bullet points
- "visualDescription": what image or diagram should accompany the slide
- "realWorldExample": a concrete example${
    interests.length ? ` relating to ${interests.join(", ")}` : ""
  }
- "practiceQuestion": a thought-provoking question

Return a JSON array of slide objects.`

  return completeJSON<any[]>(prompt, { expect: "array", vectorStoreId })
}

export async function generateSlidesWithFileSearch(
  topic: string,
  vectorStoreId: string | null,
  userProfile?: UserProfile,
  context = ""
) {
  return generateSlides(topic, context, userProfile, vectorStoreId)
}

// ============ QUIZ ============

export async function generateQuiz(
  topic: string,
  difficulty: string,
  context: string,
  vectorStoreId?: string | null
) {
  const prompt = `Generate a ${difficulty} level quiz about "${topic}" with 10 questions.

Reference material from the student's notes:
${context || "(no notes available, rely on your own knowledge of the topic)"}

Question mix:
- 6 multiple choice questions (4 options each)
- 2 true/false questions
- 2 short answer questions

Each question object must have:
{
  "type": "mcq" | "true-false" | "short-answer",
  "question": "question text",
  "options": ["A", "B", "C", "D"],
  "correctAnswer": "the correct answer",
  "explanation": "why this is correct",
  "points": 10
}

Omit "options" for non-MCQ questions. Return a JSON array of question objects.`

  return completeJSON<any[]>(prompt, { expect: "array", vectorStoreId })
}

export async function generateQuizWithFileSearch(
  topic: string,
  difficulty: string,
  vectorStoreId: string | null,
  context = ""
) {
  return generateQuiz(topic, difficulty, context, vectorStoreId)
}

// ============ FLASHCARDS ============

export async function generateFlashcards(
  topic: string,
  context: string,
  vectorStoreId?: string | null
) {
  const prompt = `Create 15-20 flashcards for the topic "${topic}".

Reference material from the student's notes:
${context || "(no notes available, rely on your own knowledge of the topic)"}

Each flashcard object must have:
{
  "front": "question, term or concept",
  "back": "answer, definition or explanation",
  "category": "category name",
  "difficulty": "easy" | "medium" | "hard"
}

Return a JSON array of flashcard objects.`

  return completeJSON<any[]>(prompt, { expect: "array", vectorStoreId })
}

export async function generateFlashcardsWithFileSearch(
  topic: string,
  vectorStoreId: string | null,
  context = ""
) {
  return generateFlashcards(topic, context, vectorStoreId)
}

// ============ GAMES ============

const GAME_TYPE_PROMPTS: Record<string, string> = {
  "interactive-quiz": `Create an engaging quiz game with:
- Colorful, animated UI with progress bars
- Timer for each question
- Visual feedback for correct/wrong answers with animations
- Score multipliers for speed
- Celebration confetti on correct answers
- Final score screen with performance stats`,

  matching: `Create a drag-and-drop matching game with:
- Beautiful card designs that flip and animate
- Smooth drag-and-drop functionality
- Visual connections when matched correctly
- Timer and score system
- Celebration animations on completion
- Shuffle and restart options`,

  "memory-cards": `Create a memory card matching game with:
- Smooth flip card animations
- Grid layout (4x4 or 4x5)
- Match pairs of related concepts
- Move counter and timer
- Star rating based on performance
- Smooth animations and particle effects`,

  "word-scramble": `Create a word scramble game with:
- Scrambled key terms
- Drag letters or click to form words
- Hint system using definitions
- Multiple difficulty levels
- Timer and scoring with combos
- Visual feedback and celebrations`,

  "fill-blank": `Create a fill-in-the-blanks game with:
- Sentences with missing words
- Word bank to choose from or type answers
- Drag-and-drop or click to fill
- Immediate visual feedback
- Score tracking with streaks
- Progressive difficulty levels`,
}

export async function generateGame(
  topic: string,
  gameType: string,
  context: string,
  vectorStoreId?: string | null
): Promise<string> {
  const gameInstructions =
    GAME_TYPE_PROMPTS[gameType] || GAME_TYPE_PROMPTS["interactive-quiz"]

  const prompt = `Create a fun, interactive and visually stunning HTML5 game about "${topic}".

GAME TYPE: ${gameType}
${gameInstructions}

Reference material from the student's notes (the game content must be drawn from this):
${context || "(no notes available, rely on your own knowledge of the topic)"}

REQUIREMENTS:
1. Visuals: modern colorful design with gradients, smooth CSS animations, responsive layout, system font stack, emoji and icons, card shadows and depth.
2. Mechanics: score system with animated numbers, timer with visual countdown where relevant, progress bar, particle or confetti effects on success, smooth state transitions.
3. UX: clear instructions at start, touch-friendly controls, immediate green/red feedback, restart button, results screen with final score.
4. Technical: a single self-contained HTML file with inline CSS and vanilla ES6+ JavaScript, no external dependencies or network requests, mobile-responsive with media queries.

Return only the complete HTML, starting with <!DOCTYPE html>. No markdown fences, no explanation.`

  const html = await complete(prompt, {
    vectorStoreId,
    maxTokens: 16000,
  })

  return html
    .replace(/^```(?:html)?\s*/i, "")
    .replace(/```\s*$/, "")
    .trim()
}

export async function generateGameWithFileSearch(
  topic: string,
  gameType: string,
  vectorStoreId: string | null,
  context = ""
) {
  return generateGame(topic, gameType, context, vectorStoreId)
}

// ============ STUDY PLAN ============

export async function generateStudyPlan(
  subjects: Array<{ id: string; name: string; priority: string }>,
  goals: string,
  availableHours: number,
  userProfile?: UserProfile
) {
  const interests = parseInterests(userProfile?.interests)

  const personalization = userProfile
    ? `
Student profile:
- Learning style: ${userProfile.learningStyle || "not specified"}
- Pace: ${userProfile.pace || "not specified"}
- Interests: ${interests.join(", ") || "not specified"}

Optimize the plan for this learning style and pace.`
    : ""

  const subjectsList = subjects
    .map((s) => `- ${s.name} (id: ${s.id}, priority: ${s.priority})`)
    .join("\n")

  const prompt = `Create a personalized weekly study plan.

Subjects:
${subjectsList}

Learning goals: ${goals}
Available study hours per week: ${availableHours}
${personalization}

Return a JSON object shaped exactly like:
{
  "weeklySchedule": [
    {
      "day": "Monday",
      "sessions": [
        {
          "subjectId": "the id given above",
          "subjectName": "Subject Name",
          "topic": "Specific topic to study",
          "duration": 60,
          "timeSlot": "Morning",
          "activities": ["Review notes", "Practice problems"]
        }
      ]
    }
  ],
  "milestones": [
    {
      "title": "Milestone name",
      "description": "What to accomplish",
      "dueDate": "2026-12-31",
      "subjectId": "the id given above"
    }
  ],
  "tips": ["Study tip 1", "Study tip 2"]
}

Distribute ${availableHours} hours across the week, prioritizing high-priority subjects. Include breaks and variety to prevent burnout. Use only the subject ids given above.`

  return completeJSON<any>(prompt, { expect: "object" })
}

// ============ AUDIO ============

export async function textToSpeech(
  text: string,
  options: { voice?: string; model?: string; instructions?: string } = {}
): Promise<{ audio: Buffer | null; error: Error | null }> {
  try {
    const response = await openai.audio.speech.create({
      model: options.model || MODELS.tts,
      voice: (options.voice || "alloy") as any,
      input: text,
      response_format: "mp3",
      ...(options.instructions ? { instructions: options.instructions } : {}),
    })

    const arrayBuffer = await response.arrayBuffer()
    return { audio: Buffer.from(arrayBuffer), error: null }
  } catch (error) {
    console.error("Error in text-to-speech:", error)
    return { audio: null, error: error as Error }
  }
}

// Maps the MIME types a browser MediaRecorder can emit to the extensions the
// transcription endpoint expects.
const AUDIO_EXTENSIONS: Record<string, string> = {
  "audio/webm": "webm",
  "audio/ogg": "ogg",
  "audio/mp4": "mp4",
  "audio/mpeg": "mp3",
  "audio/mp3": "mp3",
  "audio/wav": "wav",
  "audio/x-wav": "wav",
  "audio/flac": "flac",
  "audio/m4a": "m4a",
  "audio/x-m4a": "m4a",
}

export async function speechToText(
  audioBuffer: Buffer,
  options: { model?: string; language?: string; mimeType?: string } = {}
): Promise<{ text: string; error: Error | null }> {
  try {
    // Strip any codec suffix, e.g. "audio/webm;codecs=opus"
    const mimeType = (options.mimeType || "audio/webm").split(";")[0].trim()
    const extension = AUDIO_EXTENSIONS[mimeType] || "webm"

    const file = new File([new Uint8Array(audioBuffer)], `audio.${extension}`, {
      type: mimeType,
    })

    const transcription = await openai.audio.transcriptions.create({
      file,
      model: options.model || MODELS.transcribe,
      ...(options.language ? { language: options.language } : {}),
    })

    return { text: transcription.text || "", error: null }
  } catch (error) {
    console.error("Error in speech-to-text:", error)
    return { text: "", error: error as Error }
  }
}

// OpenAI TTS / Realtime voices
export const TTS_VOICES = [
  { id: "alloy", name: "Alloy (Neutral, Balanced)" },
  { id: "ash", name: "Ash (Male, Warm)" },
  { id: "ballad", name: "Ballad (Male, Expressive)" },
  { id: "coral", name: "Coral (Female, Bright)" },
  { id: "echo", name: "Echo (Male, Calm)" },
  { id: "sage", name: "Sage (Female, Thoughtful)" },
  { id: "shimmer", name: "Shimmer (Female, Energetic)" },
  { id: "verse", name: "Verse (Male, Conversational)" },
  { id: "marin", name: "Marin (Female, Natural)" },
  { id: "cedar", name: "Cedar (Male, Natural)" },
]

// Voices supported by the Realtime API
export const REALTIME_VOICES = [
  "alloy",
  "ash",
  "ballad",
  "cedar",
  "coral",
  "echo",
  "marin",
  "sage",
  "shimmer",
  "verse",
]
