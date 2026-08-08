import { NextResponse } from "next/server"
import { getServerSession } from "next-auth"
import { authOptions } from "@/lib/auth/config"
import { prisma } from "@/lib/prisma"
import { complete, buildTutorSystemPrompt } from "@/lib/openai"
import { retrieveContext } from "@/lib/rag"

export async function POST(req: Request) {
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

    const { message, subjectId, conversationHistory } = await req.json()

    if (!message) {
      return NextResponse.json({ error: "Message is required" }, { status: 400 })
    }

    const normalizedSubjectId =
      subjectId && subjectId !== "all" ? subjectId : null

    // Semantic retrieval over the student's indexed notes
    const { context, citations } = await retrieveContext(message, {
      userId: user.id,
      subjectId: normalizedSubjectId,
      topK: 8,
    })

    // Hand the model the subject's vector store too. Local retrieval misses
    // files we could not extract text from, and OpenAI indexed those anyway.
    let vectorStoreId: string | null = null
    if (normalizedSubjectId) {
      const subject = await prisma.subject.findFirst({
        where: { id: normalizedSubjectId, userId: user.id },
        select: { fileSearchStoreId: true },
      })
      vectorStoreId = subject?.fileSearchStoreId ?? null
    }

    const userProfile = {
      aiPersona: user.aiPersona,
      learningStyle: user.learningStyle,
      pace: user.pace,
      interests: user.interests,
      name: user.name,
    }

    const systemPrompt = `${buildTutorSystemPrompt(userProfile)}

Ground your answers in the student's uploaded notes and reference the source document by name. Search the attached files when the excerpts below do not already answer the question. Only say the notes do not cover something after you have actually looked.`

    const history = (Array.isArray(conversationHistory) ? conversationHistory : [])
      .slice(-10)
      .filter((item: any) => item?.role === "user" || item?.role === "assistant")
      .map(
        (item: any) =>
          `${item.role === "user" ? "Student" : "Tutor"}: ${String(item.content ?? "")}`
      )
      .join("\n")

    const prompt = [
      history ? `Conversation so far:\n${history}` : "",
      context ? `Relevant excerpts from the student's notes:\n\n${context}` : "",
      `Student's question: ${message}`,
    ]
      .filter(Boolean)
      .join("\n\n---\n\n")

    const response = await complete(prompt, {
      system: systemPrompt,
      vectorStoreId,
    })

    return NextResponse.json({
      response,
      citations: citations.slice(0, 5),
    })
  } catch (error) {
    console.error("Error in AI chat:", error)
    return NextResponse.json(
      { error: "Failed to generate response" },
      { status: 500 }
    )
  }
}
