import { NextResponse } from "next/server"
import { getServerSession } from "next-auth"
import { authOptions } from "@/lib/auth/config"
import { prisma } from "@/lib/prisma"
import { chat, buildTutorSystemPrompt } from "@/lib/openai"
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

    const userProfile = {
      aiPersona: user.aiPersona,
      learningStyle: user.learningStyle,
      pace: user.pace,
      interests: user.interests,
      name: user.name,
    }

    const systemPrompt = `${buildTutorSystemPrompt(userProfile)}

When note excerpts are provided, ground your answer in them and reference the source document by name. If the excerpts do not cover the question, say so before giving general guidance.`

    const messages: Array<{
      role: "system" | "user" | "assistant"
      content: string
    }> = [{ role: "system", content: systemPrompt }]

    if (Array.isArray(conversationHistory)) {
      for (const item of conversationHistory.slice(-10)) {
        if (item?.role === "user" || item?.role === "assistant") {
          messages.push({ role: item.role, content: String(item.content ?? "") })
        }
      }
    }

    messages.push({
      role: "user",
      content: context
        ? `Relevant excerpts from my notes:\n\n${context}\n\n---\n\nMy question: ${message}`
        : message,
    })

    const response = await chat(messages)

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
