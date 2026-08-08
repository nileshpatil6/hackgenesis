import { NextResponse } from "next/server"
import { getServerSession } from "next-auth"
import { authOptions } from "@/lib/auth/config"
import { prisma } from "@/lib/prisma"
import { retrieve } from "@/lib/rag"

/**
 * Semantic search over the signed-in user's notes. Used directly by the UI and
 * as the backing implementation of the realtime `search_notes` tool.
 */
export async function POST(req: Request) {
  try {
    const session = await getServerSession(authOptions)

    if (!session?.user?.email) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
    }

    const user = await prisma.user.findUnique({
      where: { email: session.user.email },
      select: { id: true },
    })

    if (!user) {
      return NextResponse.json({ error: "User not found" }, { status: 404 })
    }

    const { query, subjectId, topK } = await req.json()

    if (!query || typeof query !== "string") {
      return NextResponse.json({ error: "Query is required" }, { status: 400 })
    }

    const results = await retrieve(query, {
      userId: user.id,
      subjectId: subjectId && subjectId !== "all" ? subjectId : null,
      topK: Math.min(Number(topK) || 6, 20),
    })

    return NextResponse.json({
      results: results.map((result) => ({
        source: result.noteName,
        score: Number(result.score.toFixed(4)),
        content: result.content,
      })),
      count: results.length,
    })
  } catch (error) {
    console.error("Error searching notes:", error)
    return NextResponse.json(
      { error: "Failed to search notes" },
      { status: 500 }
    )
  }
}
