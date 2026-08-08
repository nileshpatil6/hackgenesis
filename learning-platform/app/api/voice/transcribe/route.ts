import { NextResponse } from "next/server"
import { getServerSession } from "next-auth"
import { authOptions } from "@/lib/auth/config"
import { speechToText } from "@/lib/openai"

export async function POST(req: Request) {
  try {
    const session = await getServerSession(authOptions)

    if (!session?.user?.email) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
    }

    const { audio, language, mimeType } = await req.json()

    if (!audio) {
      return NextResponse.json({ error: "No audio provided" }, { status: 400 })
    }

    // Accepts either a raw base64 string or a data URL. When it is a data URL
    // the media type in the prefix wins, since that is what was recorded.
    const isDataUrl = audio.startsWith("data:")
    const base64Data = isDataUrl ? audio.slice(audio.indexOf(",") + 1) : audio
    const detectedMime = isDataUrl
      ? audio.slice(5, audio.indexOf(";") > 0 ? audio.indexOf(";") : audio.indexOf(","))
      : undefined

    const audioBuffer = Buffer.from(base64Data, "base64")

    const { text, error } = await speechToText(audioBuffer, {
      language,
      mimeType: mimeType || detectedMime,
    })

    if (error) {
      throw error
    }

    return NextResponse.json({ text, success: true })
  } catch (error) {
    console.error("Error transcribing audio:", error)
    return NextResponse.json(
      { error: "Failed to transcribe audio" },
      { status: 500 }
    )
  }
}
