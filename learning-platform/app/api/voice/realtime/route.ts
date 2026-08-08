import { NextResponse } from "next/server"
import { getServerSession } from "next-auth"
import { authOptions } from "@/lib/auth/config"
import { prisma } from "@/lib/prisma"
import {
  openai,
  MODELS,
  REALTIME_VOICES,
  buildTutorSystemPrompt,
  isConfigured,
} from "@/lib/openai"
import { buildSubjectContext } from "@/lib/rag"

/**
 * Mints a short-lived client secret for an OpenAI Realtime session. The browser
 * uses it to open a WebRTC connection directly to OpenAI without ever seeing
 * the account API key.
 */
export async function POST(req: Request) {
  try {
    const session = await getServerSession(authOptions)

    if (!session?.user?.email) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
    }

    if (!isConfigured()) {
      return NextResponse.json(
        { error: "OPENAI_API_KEY is not configured on the server" },
        { status: 500 }
      )
    }

    const user = await prisma.user.findUnique({
      where: { email: session.user.email },
    })

    if (!user) {
      return NextResponse.json({ error: "User not found" }, { status: 404 })
    }

    const body = await req.json().catch(() => ({}))
    const { subjectId, voice } = body as {
      subjectId?: string
      voice?: string
    }

    const normalizedSubjectId =
      subjectId && subjectId !== "all" ? subjectId : null

    const selectedVoice = REALTIME_VOICES.includes(voice || "")
      ? (voice as string)
      : "marin"

    // Seed the session with an overview of the selected subject. Deeper lookups
    // happen mid-conversation through the search_notes tool.
    let subjectName = ""
    let seedContext = ""

    if (normalizedSubjectId) {
      const subject = await prisma.subject.findFirst({
        where: { id: normalizedSubjectId, userId: user.id },
        select: { displayName: true },
      })

      if (subject) {
        subjectName = subject.displayName
        const { context } = await buildSubjectContext(
          normalizedSubjectId,
          user.id,
          `overview of the key topics in ${subject.displayName}`,
          { topK: 6, maxChars: 6000 }
        )
        seedContext = context
      }
    }

    const instructions = `${buildTutorSystemPrompt({
      aiPersona: user.aiPersona,
      learningStyle: user.learningStyle,
      pace: user.pace,
      interests: user.interests,
      name: user.name,
    })}

You are speaking out loud in a live voice conversation, so:
- Keep replies short and conversational, roughly two to four sentences.
- Never read out markdown, bullet characters, code fences or URLs.
- Spell out equations and symbols in words.
- Pause to check understanding, and ask the student questions back.

${
  subjectName
    ? `The student is currently studying "${subjectName}".`
    : "The student has not picked a specific subject, so cover whatever they ask about."
}

Whenever the student asks about anything that could be covered by their uploaded notes, call the search_notes tool first and base your answer on what it returns. Say when the notes do not cover something.

${
  seedContext
    ? `Here is an overview of their notes for context:\n${seedContext}`
    : ""
}`.trim()

    const clientSecret = await openai.realtime.clientSecrets.create({
      expires_after: { anchor: "created_at", seconds: 600 },
      session: {
        type: "realtime",
        model: MODELS.realtime,
        instructions,
        audio: {
          input: {
            transcription: { model: MODELS.transcribe },
            turn_detection: {
              type: "semantic_vad",
              create_response: true,
              interrupt_response: true,
            },
          },
          output: { voice: selectedVoice },
        },
        tools: [
          {
            type: "function",
            name: "search_notes",
            description:
              "Search the student's uploaded notes for passages relevant to a question or topic. Call this before answering anything about their study material.",
            parameters: {
              type: "object",
              properties: {
                query: {
                  type: "string",
                  description:
                    "The topic or question to look up, phrased as a full sentence.",
                },
              },
              required: ["query"],
              additionalProperties: false,
            },
          },
        ],
      },
    })

    return NextResponse.json({
      clientSecret: clientSecret.value,
      expiresAt: clientSecret.expires_at,
      model: MODELS.realtime,
      voice: selectedVoice,
      subjectName,
    })
  } catch (error: any) {
    console.error("Error creating realtime session:", error)
    return NextResponse.json(
      {
        error: "Failed to create realtime session",
        details: error?.message ?? String(error),
      },
      { status: 500 }
    )
  }
}
