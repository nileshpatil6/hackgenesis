"use client"

import { useCallback, useEffect, useRef, useState } from "react"

export type RealtimeStatus =
  | "idle"
  | "connecting"
  | "connected"
  | "error"

export interface RealtimeTranscript {
  id: string
  role: "user" | "assistant"
  content: string
  done: boolean
}

interface UseRealtimeOptions {
  subjectId?: string
  voice?: string
  onError?: (message: string) => void
}

/**
 * Drives an OpenAI Realtime voice session over WebRTC. The browser gets a
 * short-lived client secret from /api/voice/realtime and then talks straight to
 * OpenAI, so audio never round-trips through this server.
 */
export function useRealtime(options: UseRealtimeOptions = {}) {
  const { subjectId, voice, onError } = options

  const [status, setStatus] = useState<RealtimeStatus>("idle")
  const [transcripts, setTranscripts] = useState<RealtimeTranscript[]>([])
  const [isMuted, setIsMuted] = useState(false)
  const [isAssistantSpeaking, setIsAssistantSpeaking] = useState(false)
  const [searching, setSearching] = useState(false)

  const peerRef = useRef<RTCPeerConnection | null>(null)
  const channelRef = useRef<RTCDataChannel | null>(null)
  const streamRef = useRef<MediaStream | null>(null)
  const audioRef = useRef<HTMLAudioElement | null>(null)
  const subjectRef = useRef(subjectId)

  subjectRef.current = subjectId

  const send = useCallback((event: Record<string, unknown>) => {
    const channel = channelRef.current
    if (channel?.readyState === "open") {
      channel.send(JSON.stringify(event))
    }
  }, [])

  const upsertTranscript = useCallback(
    (id: string, role: "user" | "assistant", content: string, done: boolean) => {
      setTranscripts((prev) => {
        const index = prev.findIndex((item) => item.id === id)
        if (index === -1) {
          return [...prev, { id, role, content, done }]
        }
        const next = [...prev]
        next[index] = { ...next[index], content, done }
        return next
      })
    },
    []
  )

  /** Runs the search_notes tool against our RAG endpoint. */
  const handleToolCall = useCallback(
    async (callId: string, name: string, argsJson: string) => {
      if (name !== "search_notes") return

      let output: string
      setSearching(true)

      try {
        const args = JSON.parse(argsJson || "{}")
        const response = await fetch("/api/rag/search", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            query: args.query || "",
            subjectId: subjectRef.current,
            topK: 5,
          }),
        })

        const data = await response.json()

        output = data.results?.length
          ? JSON.stringify(data.results)
          : JSON.stringify({
              message: "No matching passages found in the student's notes.",
            })
      } catch (error) {
        console.error("search_notes failed:", error)
        output = JSON.stringify({ error: "Note search failed." })
      } finally {
        setSearching(false)
      }

      send({
        type: "conversation.item.create",
        item: {
          type: "function_call_output",
          call_id: callId,
          output,
        },
      })
      send({ type: "response.create" })
    },
    [send]
  )

  const handleEvent = useCallback(
    (event: any) => {
      switch (event.type) {
        case "conversation.item.input_audio_transcription.delta":
          setTranscripts((prev) => {
            const index = prev.findIndex((item) => item.id === event.item_id)
            if (index === -1) {
              return [
                ...prev,
                {
                  id: event.item_id,
                  role: "user",
                  content: event.delta || "",
                  done: false,
                },
              ]
            }
            const next = [...prev]
            next[index] = {
              ...next[index],
              content: next[index].content + (event.delta || ""),
            }
            return next
          })
          break

        case "conversation.item.input_audio_transcription.completed":
          upsertTranscript(event.item_id, "user", event.transcript || "", true)
          break

        case "response.output_audio_transcript.delta":
        case "response.audio_transcript.delta":
          setTranscripts((prev) => {
            const index = prev.findIndex((item) => item.id === event.item_id)
            if (index === -1) {
              return [
                ...prev,
                {
                  id: event.item_id,
                  role: "assistant",
                  content: event.delta || "",
                  done: false,
                },
              ]
            }
            const next = [...prev]
            next[index] = {
              ...next[index],
              content: next[index].content + (event.delta || ""),
            }
            return next
          })
          setIsAssistantSpeaking(true)
          break

        case "response.output_audio_transcript.done":
        case "response.audio_transcript.done":
          upsertTranscript(
            event.item_id,
            "assistant",
            event.transcript || "",
            true
          )
          break

        case "response.done": {
          setIsAssistantSpeaking(false)
          const outputs = event.response?.output || []
          for (const item of outputs) {
            if (item.type === "function_call") {
              handleToolCall(item.call_id, item.name, item.arguments)
            }
          }
          break
        }

        case "input_audio_buffer.speech_started":
          setIsAssistantSpeaking(false)
          break

        case "error":
          console.error("Realtime error:", event.error)
          onError?.(event.error?.message || "Realtime session error")
          break

        default:
          break
      }
    },
    [handleToolCall, onError, upsertTranscript]
  )

  const disconnect = useCallback(() => {
    channelRef.current?.close()
    channelRef.current = null

    peerRef.current?.close()
    peerRef.current = null

    streamRef.current?.getTracks().forEach((track) => track.stop())
    streamRef.current = null

    if (audioRef.current) {
      audioRef.current.srcObject = null
    }

    setStatus("idle")
    setIsAssistantSpeaking(false)
    setIsMuted(false)
  }, [])

  const connect = useCallback(async () => {
    if (status === "connecting" || status === "connected") return

    setStatus("connecting")

    try {
      // 1. Mint an ephemeral client secret server-side
      const tokenResponse = await fetch("/api/voice/realtime", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ subjectId, voice }),
      })

      const tokenData = await tokenResponse.json()

      if (!tokenResponse.ok || !tokenData.clientSecret) {
        throw new Error(
          tokenData.details || tokenData.error || "Failed to start session"
        )
      }

      // 2. Set up the peer connection
      const peer = new RTCPeerConnection()
      peerRef.current = peer

      peer.ontrack = (event) => {
        if (audioRef.current) {
          audioRef.current.srcObject = event.streams[0]
          audioRef.current.play().catch(() => {
            /* autoplay may need a user gesture, the button click covers it */
          })
        }
      }

      peer.onconnectionstatechange = () => {
        if (
          peer.connectionState === "failed" ||
          peer.connectionState === "closed"
        ) {
          setStatus("idle")
        }
      }

      // 3. Microphone in
      const stream = await navigator.mediaDevices.getUserMedia({
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
        },
      })
      streamRef.current = stream
      stream.getTracks().forEach((track) => peer.addTrack(track, stream))

      // 4. Event channel
      const channel = peer.createDataChannel("oai-events")
      channelRef.current = channel

      channel.onmessage = (message) => {
        try {
          handleEvent(JSON.parse(message.data))
        } catch (error) {
          console.error("Failed to parse realtime event:", error)
        }
      }

      channel.onopen = () => setStatus("connected")

      // 5. SDP exchange
      const offer = await peer.createOffer()
      await peer.setLocalDescription(offer)

      const sdpResponse = await fetch("https://api.openai.com/v1/realtime/calls", {
        method: "POST",
        body: offer.sdp,
        headers: {
          Authorization: `Bearer ${tokenData.clientSecret}`,
          "Content-Type": "application/sdp",
        },
      })

      if (!sdpResponse.ok) {
        throw new Error(`Realtime handshake failed: ${await sdpResponse.text()}`)
      }

      await peer.setRemoteDescription({
        type: "answer",
        sdp: await sdpResponse.text(),
      })
    } catch (error: any) {
      console.error("Failed to connect realtime session:", error)
      onError?.(error?.message || "Failed to connect")
      setStatus("error")
      disconnect()
    }
  }, [disconnect, handleEvent, onError, status, subjectId, voice])

  const toggleMute = useCallback(() => {
    const stream = streamRef.current
    if (!stream) return

    const nextMuted = !isMuted
    stream.getAudioTracks().forEach((track) => {
      track.enabled = !nextMuted
    })
    setIsMuted(nextMuted)
  }, [isMuted])

  /** Injects a typed message into the live conversation. */
  const sendText = useCallback(
    (text: string) => {
      if (!text.trim()) return

      send({
        type: "conversation.item.create",
        item: {
          type: "message",
          role: "user",
          content: [{ type: "input_text", text }],
        },
      })
      send({ type: "response.create" })
    },
    [send]
  )

  const clearTranscripts = useCallback(() => setTranscripts([]), [])

  useEffect(() => disconnect, [disconnect])

  return {
    status,
    transcripts,
    isMuted,
    isAssistantSpeaking,
    searching,
    audioRef,
    connect,
    disconnect,
    toggleMute,
    sendText,
    clearTranscripts,
  }
}
