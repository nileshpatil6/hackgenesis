"use client"

import { useState, useRef, useEffect } from "react"
import { Card } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import {
  Mic,
  MicOff,
  Volume2,
  VolumeX,
  Brain,
  MessageCircle,
  Loader2,
  Circle,
  PhoneOff,
  Radio,
  Search,
} from "lucide-react"
import { useRealtime } from "@/lib/use-realtime"

const VOICES = [
  { id: "marin", name: "Marin (Female, Natural)" },
  { id: "cedar", name: "Cedar (Male, Natural)" },
  { id: "alloy", name: "Alloy (Neutral, Balanced)" },
  { id: "coral", name: "Coral (Female, Bright)" },
  { id: "sage", name: "Sage (Female, Thoughtful)" },
  { id: "ash", name: "Ash (Male, Warm)" },
  { id: "echo", name: "Echo (Male, Calm)" },
  { id: "verse", name: "Verse (Male, Conversational)" },
]

interface Message {
  role: "user" | "assistant"
  content: string
  timestamp: Date
  audioUrl?: string
  citations?: string[]
}

export default function VoiceModePage() {
  const [mode, setMode] = useState<"live" | "turn">("live")
  const [selectedSubject, setSelectedSubject] = useState<string>("all")
  const [selectedVoice, setSelectedVoice] = useState("marin")
  const [subjects, setSubjects] = useState<any[]>([])
  const [error, setError] = useState<string | null>(null)

  // Push-to-talk state
  const [isRecording, setIsRecording] = useState(false)
  const [isProcessing, setIsProcessing] = useState(false)
  const [isPlaying, setIsPlaying] = useState(false)
  const [messages, setMessages] = useState<Message[]>([])

  const mediaRecorderRef = useRef<MediaRecorder | null>(null)
  const audioChunksRef = useRef<Blob[]>([])
  const playbackRef = useRef<HTMLAudioElement | null>(null)
  const scrollRef = useRef<HTMLDivElement>(null)

  const realtime = useRealtime({
    subjectId: selectedSubject,
    voice: selectedVoice,
    onError: setError,
  })

  useEffect(() => {
    fetchSubjects()
  }, [])

  useEffect(() => {
    scrollRef.current?.scrollIntoView({ behavior: "smooth" })
  }, [messages, realtime.transcripts])

  const fetchSubjects = async () => {
    try {
      const response = await fetch("/api/subjects")
      const data = await response.json()
      setSubjects(data.subjects || [])
    } catch (err) {
      console.error("Error fetching subjects:", err)
    }
  }

  // ---------- Live realtime mode ----------

  const isLive = realtime.status === "connected"
  const isConnecting = realtime.status === "connecting"

  const toggleLiveSession = async () => {
    setError(null)
    if (isLive || isConnecting) {
      realtime.disconnect()
    } else {
      await realtime.connect()
    }
  }

  // ---------- Push-to-talk mode ----------

  const startRecording = async () => {
    setError(null)
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      const mediaRecorder = new MediaRecorder(stream)

      mediaRecorderRef.current = mediaRecorder
      audioChunksRef.current = []

      mediaRecorder.ondataavailable = (event) => {
        if (event.data.size > 0) audioChunksRef.current.push(event.data)
      }

      mediaRecorder.onstop = async () => {
        const audioBlob = new Blob(audioChunksRef.current, {
          type: "audio/webm",
        })
        stream.getTracks().forEach((track) => track.stop())
        await processAudio(audioBlob)
      }

      mediaRecorder.start()
      setIsRecording(true)
    } catch (err) {
      console.error("Error starting recording:", err)
      setError("Failed to access the microphone. Please check permissions.")
    }
  }

  const stopRecording = () => {
    if (mediaRecorderRef.current && isRecording) {
      mediaRecorderRef.current.stop()
      setIsRecording(false)
    }
  }

  const processAudio = async (audioBlob: Blob) => {
    setIsProcessing(true)

    try {
      const base64Audio = await blobToBase64(audioBlob)

      const response = await fetch("/api/voice/transcribe", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          audio: base64Audio,
          mimeType: audioBlob.type || "audio/webm",
        }),
      })

      const data = await response.json()

      if (!data.text) {
        setError("Nothing was transcribed. Try speaking a little longer.")
        return
      }

      setMessages((prev) => [
        ...prev,
        { role: "user", content: data.text, timestamp: new Date() },
      ])

      await getAIResponse(data.text)
    } catch (err) {
      console.error("Error processing audio:", err)
      setError("Failed to process audio. Please try again.")
    } finally {
      setIsProcessing(false)
    }
  }

  const getAIResponse = async (userText: string) => {
    try {
      const response = await fetch("/api/voice/respond", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          message: userText,
          subjectId: selectedSubject,
          voice: selectedVoice,
        }),
      })

      const data = await response.json()

      if (!data.text) {
        setError(data.error || "Failed to get a response.")
        return
      }

      setMessages((prev) => [
        ...prev,
        {
          role: "assistant",
          content: data.text,
          timestamp: new Date(),
          audioUrl: data.audioUrl,
          citations: data.citations,
        },
      ])

      if (data.audioUrl) playAudio(data.audioUrl)
    } catch (err) {
      console.error("Error getting AI response:", err)
      setError("Failed to get a response.")
    }
  }

  const playAudio = (audioUrl: string) => {
    playbackRef.current?.pause()

    const audio = new Audio(audioUrl)
    playbackRef.current = audio

    audio.onplay = () => setIsPlaying(true)
    audio.onended = () => setIsPlaying(false)
    audio.onerror = () => setIsPlaying(false)

    audio.play().catch(() => setIsPlaying(false))
  }

  const stopAudio = () => {
    if (playbackRef.current) {
      playbackRef.current.pause()
      playbackRef.current.currentTime = 0
      setIsPlaying(false)
    }
  }

  const formatTime = (date: Date) =>
    date.toLocaleTimeString("en-US", { hour: "2-digit", minute: "2-digit" })

  const conversation: Message[] =
    mode === "live"
      ? realtime.transcripts.map((item) => ({
          role: item.role,
          content: item.content,
          timestamp: new Date(),
        }))
      : messages

  const settingsLocked = isLive || isConnecting

  return (
    <div className="h-full flex flex-col p-8">
      {/* Hidden sink for the realtime audio stream */}
      <audio ref={realtime.audioRef} autoPlay className="hidden" />

      <div className="mb-6">
        <h1 className="text-3xl font-bold mb-2 flex items-center gap-3">
          <Mic className="h-8 w-8 text-purple-600" />
          Voice Mode
        </h1>
        <p className="text-gray-600">
          Talk to your AI teacher. It searches your uploaded notes while you
          speak.
        </p>
      </div>

      {/* Mode switch */}
      <div className="flex gap-2 mb-4">
        <Button
          variant={mode === "live" ? "default" : "outline"}
          onClick={() => setMode("live")}
          disabled={isRecording || isProcessing}
        >
          <Radio className="h-4 w-4 mr-2" />
          Live conversation
        </Button>
        <Button
          variant={mode === "turn" ? "default" : "outline"}
          onClick={() => {
            if (settingsLocked) realtime.disconnect()
            setMode("turn")
          }}
        >
          <Mic className="h-4 w-4 mr-2" />
          Push to talk
        </Button>
      </div>

      <Card className="p-6 mb-6">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="text-sm font-medium mb-2 block">
              Subject (for note lookups)
            </label>
            <Select
              value={selectedSubject}
              onValueChange={setSelectedSubject}
              disabled={settingsLocked}
            >
              <SelectTrigger>
                <SelectValue placeholder="All subjects" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All subjects</SelectItem>
                {subjects.map((subject) => (
                  <SelectItem key={subject.id} value={subject.id}>
                    {subject.displayName || subject.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <div>
            <label className="text-sm font-medium mb-2 block">AI Voice</label>
            <Select
              value={selectedVoice}
              onValueChange={setSelectedVoice}
              disabled={settingsLocked}
            >
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {VOICES.map((voice) => (
                  <SelectItem key={voice.id} value={voice.id}>
                    {voice.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
        </div>

        {settingsLocked && (
          <p className="text-xs text-gray-500 mt-3">
            End the session to change the subject or voice.
          </p>
        )}
      </Card>

      {error && (
        <Card className="p-4 mb-4 bg-red-50 border-red-200">
          <p className="text-sm text-red-800">{error}</p>
        </Card>
      )}

      {/* Conversation */}
      <div className="flex-1 overflow-y-auto mb-6 space-y-4">
        {conversation.length === 0 ? (
          <Card className="p-12 text-center">
            <Mic className="h-16 w-16 mx-auto mb-4 text-gray-400" />
            <h3 className="text-xl font-semibold mb-2">
              {mode === "live"
                ? "Start a live conversation"
                : "Ready to start voice conversation"}
            </h3>
            <p className="text-gray-600">
              {mode === "live"
                ? "Press Start session and just talk. The AI will listen, interrupt-safe, and answer out loud."
                : "Press the microphone button below to start speaking"}
            </p>
          </Card>
        ) : (
          conversation.map((message, index) => (
            <Card
              key={index}
              className={`p-4 ${
                message.role === "user"
                  ? "bg-blue-50 border-blue-200 ml-12"
                  : "bg-purple-50 border-purple-200 mr-12"
              }`}
            >
              <div className="flex items-start gap-3">
                <div
                  className={`p-2 rounded-full ${
                    message.role === "user" ? "bg-blue-600" : "bg-purple-600"
                  }`}
                >
                  {message.role === "user" ? (
                    <MessageCircle className="h-4 w-4 text-white" />
                  ) : (
                    <Brain className="h-4 w-4 text-white" />
                  )}
                </div>

                <div className="flex-1">
                  <div className="flex items-center gap-2 mb-2">
                    <span className="font-semibold">
                      {message.role === "user" ? "You" : "AI Teacher"}
                    </span>
                    <span className="text-xs text-gray-500">
                      {formatTime(message.timestamp)}
                    </span>
                  </div>

                  <p className="text-gray-800 mb-2 whitespace-pre-wrap">
                    {message.content}
                  </p>

                  {message.citations && message.citations.length > 0 && (
                    <div className="flex flex-wrap gap-1 mb-2">
                      {message.citations.map((citation) => (
                        <Badge
                          key={citation}
                          variant="secondary"
                          className="text-xs"
                        >
                          {citation}
                        </Badge>
                      ))}
                    </div>
                  )}

                  {message.audioUrl && (
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => playAudio(message.audioUrl!)}
                      disabled={isPlaying}
                    >
                      <Volume2 className="h-3 w-3 mr-2" />
                      Play Response
                    </Button>
                  )}
                </div>
              </div>
            </Card>
          ))
        )}
        <div ref={scrollRef} />
      </div>

      {/* Controls */}
      <Card className="p-6">
        {mode === "live" ? (
          <div className="flex flex-col items-center gap-4">
            <div className="flex items-center gap-4">
              <Button
                size="lg"
                onClick={toggleLiveSession}
                disabled={isConnecting}
                className={`w-56 h-16 rounded-full ${
                  isLive
                    ? "bg-red-600 hover:bg-red-700"
                    : "bg-purple-600 hover:bg-purple-700"
                }`}
              >
                {isConnecting ? (
                  <>
                    <Loader2 className="h-5 w-5 mr-2 animate-spin" />
                    Connecting...
                  </>
                ) : isLive ? (
                  <>
                    <PhoneOff className="h-5 w-5 mr-2" />
                    End session
                  </>
                ) : (
                  <>
                    <Radio className="h-5 w-5 mr-2" />
                    Start session
                  </>
                )}
              </Button>

              {isLive && (
                <Button
                  size="lg"
                  variant="outline"
                  onClick={realtime.toggleMute}
                  className="rounded-full w-16 h-16"
                  title={realtime.isMuted ? "Unmute" : "Mute"}
                >
                  {realtime.isMuted ? (
                    <MicOff className="h-6 w-6" />
                  ) : (
                    <Mic className="h-6 w-6" />
                  )}
                </Button>
              )}
            </div>

            <div className="flex flex-wrap items-center justify-center gap-2">
              {isLive && (
                <Badge className="bg-green-600">
                  <Circle className="h-2 w-2 mr-1 fill-current" />
                  Live
                </Badge>
              )}
              {realtime.isMuted && (
                <Badge variant="secondary">
                  <MicOff className="h-3 w-3 mr-1" />
                  Mic muted
                </Badge>
              )}
              {realtime.isAssistantSpeaking && (
                <Badge className="bg-purple-600">
                  <Volume2 className="h-3 w-3 mr-1" />
                  Speaking
                </Badge>
              )}
              {realtime.searching && (
                <Badge variant="secondary">
                  <Search className="h-3 w-3 mr-1" />
                  Searching your notes...
                </Badge>
              )}
            </div>
          </div>
        ) : (
          <div className="flex flex-col items-center gap-4">
            <div className="flex items-center justify-center gap-4">
              <Button
                size="lg"
                onClick={isRecording ? stopRecording : startRecording}
                disabled={isProcessing || isPlaying}
                className={`w-48 h-48 rounded-full ${
                  isRecording
                    ? "bg-red-600 hover:bg-red-700 animate-pulse"
                    : "bg-purple-600 hover:bg-purple-700"
                }`}
              >
                {isRecording ? (
                  <div className="flex flex-col items-center">
                    <Circle className="h-12 w-12 mb-2 fill-current" />
                    <span className="text-sm">Recording...</span>
                  </div>
                ) : isProcessing ? (
                  <div className="flex flex-col items-center">
                    <Loader2 className="h-12 w-12 mb-2 animate-spin" />
                    <span className="text-sm">Processing...</span>
                  </div>
                ) : (
                  <div className="flex flex-col items-center">
                    <Mic className="h-12 w-12 mb-2" />
                    <span className="text-sm">Tap to Speak</span>
                  </div>
                )}
              </Button>

              {isPlaying && (
                <Button
                  size="lg"
                  variant="outline"
                  onClick={stopAudio}
                  className="rounded-full w-16 h-16"
                >
                  <VolumeX className="h-6 w-6" />
                </Button>
              )}
            </div>

            <div className="flex items-center gap-2">
              {isRecording && (
                <Badge variant="destructive" className="animate-pulse">
                  <Circle className="h-2 w-2 mr-1 fill-current" />
                  Recording in progress
                </Badge>
              )}
              {isProcessing && (
                <Badge variant="secondary">
                  <Loader2 className="h-3 w-3 mr-1 animate-spin" />
                  Processing your voice...
                </Badge>
              )}
              {isPlaying && (
                <Badge className="bg-purple-600">
                  <Volume2 className="h-3 w-3 mr-1" />
                  Playing AI response
                </Badge>
              )}
            </div>
          </div>
        )}
      </Card>

      <Card className="mt-4 p-4 bg-blue-50 border-blue-200">
        <h3 className="font-semibold mb-2 text-blue-900">How to use:</h3>
        <ul className="text-sm text-blue-800 space-y-1">
          {mode === "live" ? (
            <>
              <li>• Press Start session and simply begin speaking</li>
              <li>• The AI detects when you stop and replies out loud</li>
              <li>• You can interrupt it at any time, just talk over it</li>
              <li>• It searches your uploaded notes automatically when relevant</li>
              <li>• Pick a subject above to focus the note lookups</li>
            </>
          ) : (
            <>
              <li>• Tap the microphone button to start recording</li>
              <li>• Speak your question or topic</li>
              <li>• Tap again to stop and process</li>
              <li>• The AI will respond with voice and text</li>
              <li>• Select a subject for context-aware responses</li>
            </>
          )}
        </ul>
      </Card>
    </div>
  )
}

function blobToBase64(blob: Blob): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onloadend = () => resolve(reader.result as string)
    reader.onerror = reject
    reader.readAsDataURL(blob)
  })
}
