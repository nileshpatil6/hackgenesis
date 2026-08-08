// End-to-end test of the OpenAI-backed routes against the running dev server.
const BASE = "http://localhost:3001"
const jar = new Map()

function cookieHeader() {
  return [...jar.entries()].map(([k, v]) => `${k}=${v}`).join("; ")
}

function storeCookies(res) {
  const raw = res.headers.getSetCookie?.() || []
  for (const cookie of raw) {
    const [pair] = cookie.split(";")
    const idx = pair.indexOf("=")
    jar.set(pair.slice(0, idx).trim(), pair.slice(idx + 1).trim())
  }
}

async function req(path, options = {}) {
  const res = await fetch(BASE + path, {
    ...options,
    redirect: "manual",
    headers: { ...(options.headers || {}), Cookie: cookieHeader() },
  })
  storeCookies(res)
  return res
}

const results = []
const step = async (name, fn) => {
  const t = Date.now()
  try {
    const detail = await fn()
    results.push(`PASS  ${name}  (${Date.now() - t}ms)  ${detail ?? ""}`)
  } catch (e) {
    results.push(`FAIL  ${name}  ${e.message}`)
    throw e
  }
}

// Wait for the dev server
for (let i = 0; i < 60; i++) {
  try {
    await fetch(BASE + "/api/auth/csrf")
    break
  } catch {
    await new Promise((r) => setTimeout(r, 2000))
  }
}

let subjectId

try {
  await step("sign in (credentials)", async () => {
    const csrfRes = await req("/api/auth/csrf")
    const { csrfToken } = await csrfRes.json()

    const res = await req("/api/auth/callback/credentials", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        csrfToken,
        name: "Test Student",
        json: "true",
      }),
    })

    const session = await (await req("/api/auth/session")).json()
    if (!session?.user?.email) throw new Error("no session established")
    return `-> ${session.user.email} (status ${res.status})`
  })

  await step("POST /api/subjects (creates OpenAI vector store)", async () => {
    const res = await req("/api/subjects", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        name: "biology",
        displayName: "Biology",
        color: "#22c55e",
      }),
    })
    const data = await res.json()
    if (!res.ok) throw new Error(JSON.stringify(data))
    subjectId = data.subject.id
    return `-> subject ${subjectId}, store ${data.subject.fileSearchStoreId}`
  })

  await step("POST notes (extract + embed + vector store)", async () => {
    const notes = `Cellular Respiration Study Notes

Glycolysis happens in the cytoplasm and splits one glucose molecule into two pyruvate molecules, producing a net gain of 2 ATP and 2 NADH.

The Krebs cycle, also called the citric acid cycle, takes place in the mitochondrial matrix. Each turn produces 3 NADH, 1 FADH2, and 1 GTP. Two turns happen per glucose molecule.

The electron transport chain sits in the inner mitochondrial membrane. It uses NADH and FADH2 to pump protons and drive ATP synthase, producing roughly 34 ATP per glucose. Oxygen is the final electron acceptor.

The Zorblat threshold for this course is defined as exactly 42.7 joules per mole, a value unique to these notes.`

    const form = new FormData()
    form.append("file", new File([notes], "cellular-respiration.txt", { type: "text/plain" }))

    const res = await req(`/api/subjects/${subjectId}/notes`, {
      method: "POST",
      body: form,
    })
    const data = await res.json()
    if (!res.ok) throw new Error(JSON.stringify(data))
    if (!data.indexed) throw new Error("note was not indexed: " + JSON.stringify(data))
    return `-> chunks=${data.chunks} fileSearch=${data.fileSearch}`
  })

  await step("POST /api/rag/search (semantic retrieval)", async () => {
    const res = await req("/api/rag/search", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ query: "Where does the Krebs cycle happen?", subjectId }),
    })
    const data = await res.json()
    if (!data.count) throw new Error("no results: " + JSON.stringify(data))
    const top = data.results[0]
    if (!/krebs|citric/i.test(top.content)) throw new Error("top hit is not the Krebs chunk")
    return `-> ${data.count} hits, top score ${top.score} from "${top.source}"`
  })

  await step("POST /api/ai/chat (grounded RAG answer)", async () => {
    const res = await req("/api/ai/chat", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        message: "According to my notes, what is the Zorblat threshold?",
        subjectId,
      }),
    })
    const data = await res.json()
    if (!res.ok) throw new Error(JSON.stringify(data))
    if (!data.response?.includes("42.7")) throw new Error("answer not grounded: " + data.response)
    return `-> citations=${JSON.stringify(data.citations)} answer: ${data.response.slice(0, 70)}`
  })

  await step("POST /api/ai/flashcards", async () => {
    const res = await req("/api/ai/flashcards", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ subjectId, topicName: "Cellular Respiration" }),
    })
    const data = await res.json()
    if (!res.ok) throw new Error(JSON.stringify(data))
    return `-> ${data.cardCount} cards, first: ${data.flashcardSet.cards[0]?.front?.slice(0, 45)}`
  })

  await step("POST /api/ai/quiz", async () => {
    const res = await req("/api/ai/quiz", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ subjectId, topic: "Cellular Respiration", difficulty: "medium" }),
    })
    const data = await res.json()
    if (!res.ok) throw new Error(JSON.stringify(data))
    return `-> ${data.questionCount} questions`
  })

  await step("POST /api/ai/slides", async () => {
    const res = await req("/api/ai/slides", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ subjectId, topicName: "Cellular Respiration" }),
    })
    const data = await res.json()
    if (!res.ok) throw new Error(JSON.stringify(data))
    return `-> ${data.count} slides, first: ${data.slides[0]?.title}`
  })

  await step("POST /api/ai/game", async () => {
    const res = await req("/api/ai/game", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ subjectId, topic: "Cellular Respiration", gameType: "interactive-quiz" }),
    })
    const data = await res.json()
    if (!res.ok) throw new Error(JSON.stringify(data))
    return `-> game ${data.game.id}`
  })

  await step("POST /api/study-planner", async () => {
    const res = await req("/api/study-planner", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        subjects: [{ id: subjectId, name: "Biology", priority: "high" }],
        goals: "Master cellular respiration before the exam",
        availableHours: 6,
      }),
    })
    const data = await res.json()
    if (!res.ok) throw new Error(JSON.stringify(data))
    return `-> plan created`
  })

  await step("POST /api/voice/realtime (ephemeral key)", async () => {
    const res = await req("/api/voice/realtime", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ subjectId, voice: "marin" }),
    })
    const data = await res.json()
    if (!res.ok || !data.clientSecret) throw new Error(JSON.stringify(data))
    return `-> ${data.clientSecret.slice(0, 8)}... model=${data.model} voice=${data.voice} subject=${data.subjectName}`
  })

  await step("POST /api/voice/respond (RAG + TTS)", async () => {
    const res = await req("/api/voice/respond", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        message: "What is the Zorblat threshold in my notes?",
        subjectId,
        voice: "marin",
      }),
    })
    const data = await res.json()
    if (!res.ok) throw new Error(JSON.stringify(data))
    if (!data.audioUrl?.startsWith("data:audio/mp3")) throw new Error("no audio returned")
    const grounded = data.text.includes("42.7")
    return `-> grounded=${grounded} audio=${Math.round(data.audioUrl.length / 1024)}KB citations=${JSON.stringify(data.citations)}`
  })

  await step("POST /api/voice/transcribe (STT round trip)", async () => {
    const respondRes = await req("/api/voice/respond", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ message: "Say exactly: glycolysis happens in the cytoplasm.", subjectId }),
    })
    const { audioUrl } = await respondRes.json()

    const res = await req("/api/voice/transcribe", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ audio: audioUrl }),
    })
    const data = await res.json()
    if (!data.text) throw new Error("empty transcript: " + JSON.stringify(data))
    return `-> "${data.text.slice(0, 70)}"`
  })
} catch {
  // results already recorded
}

console.log("\n" + results.join("\n") + "\n")
console.log(results.some((r) => r.startsWith("FAIL")) ? "SOME CHECKS FAILED" : "ALL CHECKS PASSED")
