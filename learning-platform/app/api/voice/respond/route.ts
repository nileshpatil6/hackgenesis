import { NextResponse } from "next/server"
import { getServerSession } from "next-auth"
import { authOptions } from "@/lib/auth/config"
import { prisma } from "@/lib/prisma"
import { queryWithRAG, textToSpeech } from "@/lib/openai"
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

    const { message, subjectId, voice } = await req.json()

    if (!message) {
      return NextResponse.json({ error: "No message provided" }, { status: 400 })
    }

    const normalizedSubjectId =
      subjectId && subjectId !== "all" ? subjectId : null

    // Retrieve the relevant note passages for this question
    const { context, citations } = await retrieveContext(message, {
      userId: user.id,
      subjectId: normalizedSubjectId,
      topK: 6,
    })

    let vectorStoreId: string | null = null
    if (normalizedSubjectId) {
      const subject = await prisma.subject.findFirst({
        where: { id: normalizedSubjectId, userId: user.id },
        select: { fileSearchStoreId: true },
      })
      vectorStoreId = subject?.fileSearchStoreId ?? null
    }

    const userProfile = {
      learningStyle: user.learningStyle,
      pace: user.pace,
      interests: user.interests,
      aiPersona: user.aiPersona,
      name: user.name,
    }

    const responseText = await queryWithRAG(
      `${message}\n\n(Answer conversationally, as this will be read aloud. Keep it under about 120 words and avoid markdown formatting.)`,
      context,
      userProfile,
      vectorStoreId
    )

    const { audio, error } = await textToSpeech(responseText, {
      voice: voice || "marin",
      instructions:
        "Speak warmly and clearly, like a patient tutor explaining something to a student.",
    })

    if (error || !audio) {
      // Text still works even when TTS fails
      return NextResponse.json({
        text: responseText,
        audioUrl: null,
        citations,
        success: true,
      })
    }

    return NextResponse.json({
      text: responseText,
      audioUrl: `data:audio/mp3;base64,${audio.toString("base64")}`,
      citations,
      success: true,
    })
  } catch (error) {
    console.error("Error generating voice response:", error)
    return NextResponse.json(
      { error: "Failed to generate voice response" },
      { status: 500 }
    )
  }
}
