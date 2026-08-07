# Yukti / EduAI — AI Learning Ecosystem

A monorepo of six independent apps that make up one AI-assisted learning
product: a marketing site, a community hub, a study platform, an AI experiment
sandbox (in two flavours), and a mobile companion app.

Each folder is a **self-contained project with its own dependencies**. There is
no shared build at the root — you install and run whichever app you're working
on.

---

## What's in here

| Folder | What it is | Stack |
| --- | --- | --- |
| [`website-frontend/`](#website-frontend) | Marketing site for the ecosystem | React + Vite, Three.js, Framer Motion |
| [`main/`](#main) | Community hub: hackathons, challenges, leaderboards | Next.js, Firebase Auth, Supabase |
| [`learning-platform/`](#learning-platform) | Full study platform: subjects, quizzes, flashcards, AI teacher | Next.js, Prisma, NextAuth, Deepgram |
| [`canvas/`](#canvas) | AI experiment sandbox — build a circuit, AI simulates it | React + Vite, React Flow, OpenAI |
| [`canvas_flutter/`](#canvas_flutter) | The same sandbox rebuilt as a game | Flutter |
| [`canvas/edtech-app/`](#canvasedtech-app) | Mobile study companion | Flutter, Hive, Firebase, Supabase |

> `canvas/edtech-app/` is nested inside `canvas/` for historical reasons — it is
> a separate app, unrelated to the canvas sandbox around it.

---

## Prerequisites

- **Node.js 18+** — for the four web apps
- **Flutter 3.35+ / Dart 3.9+** — for the two Flutter apps
- API keys, depending on which app you run (see each section)

---

## Projects

### `website-frontend/`

The public marketing site. Animated hero, feature scroller, 3D background
effects, and links out to the other apps.

```bash
cd website-frontend
npm install
npm run dev        # vite dev server
```

No API keys needed. The CTA buttons point at a locally running canvas app.

---

### `main/`

The community hub — hackathons, coding challenges, a "voom" leaderboard, and
Google sign-in.

```bash
cd main
npm install
npm run dev
```

Routes: `/` · `/login` · `/signup` · `/dashboard` · `/hackathons` ·
`/challenges` · `/voom`
API: `/api/generate-questions` · `/api/voom/submit` · `/api/voom/leaderboard`

**Environment** — create `.env.local`:

```bash
NEXT_PUBLIC_FIREBASE_API_KEY=
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=
NEXT_PUBLIC_FIREBASE_PROJECT_ID=
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=
NEXT_PUBLIC_FIREBASE_APP_ID=
NEXT_PUBLIC_FIREBASE_MEASUREMENT_ID=
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
OPENAI_API_KEY=
OPENAI_BASE_URL=          # optional, defaults to an AWS Bedrock proxy
OPENAI_MODEL_NAME=        # optional, defaults to deepseek.v3.2
```

---

### `learning-platform/`

The most feature-complete web app: subjects and notes, AI-generated quizzes and
flashcards with spaced repetition, slide decks, learning games, a study
planner, achievements, and a voice tutor.

```bash
cd learning-platform
npm install          # runs prisma generate via postinstall
npm run dev
```

Routes live under `/dashboard`: `subjects` · `quizzes` · `flashcards` ·
`games` · `study-planner` · `achievements` · `ai-teacher` · `voice` ·
`settings`

**Environment** — create `.env`:

```bash
NEXTAUTH_URL=http://localhost:3000
NEXTAUTH_SECRET=
OPENAI_API_KEY=           # used for all AI generation
OPENAI_BASE_URL=          # optional, defaults to an AWS Bedrock proxy
OPENAI_MODEL_NAME=        # optional, defaults to deepseek.v3.2
DEEPGRAM_API_KEY=         # speech, for the voice tutor
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
```

The Prisma datasource is hardcoded to SQLite at `prisma/dev.db`, so there is no
`DATABASE_URL` to set. Create the database on first run:

```bash
npx prisma migrate dev
```

> Note: `lib/gemini.ts` is a legacy filename — despite the `@google/*` packages
> still listed in `package.json`, generation actually goes through the
> OpenAI-compatible endpoint configured above.

---

### `canvas/`

The AI experiment lab. Drag components from a library of 300+ parts onto an
infinite canvas, wire them together, and hit **Run** — an OpenAI model
simulates the experiment, explains what happened, and generates an
illustration of it.

```bash
cd canvas
npm install
npm run dev
```

**Environment** — create `.env`:

```bash
VITE_OPENAI_API_KEY=sk-...
```

> ⚠️ This key ships in the browser bundle. Fine locally; put it behind a
> backend proxy before deploying anywhere public.

Models are picked per task rather than one-size-fits-all:

| Task | Model | Effort |
| --- | --- | --- |
| Assistant hints | `gpt-5.6-luna` | low |
| Visualisation code | `gpt-5.6-terra` | medium |
| Experiment analysis | `gpt-5.6-sol` | high |
| Result illustration | `gpt-image-2` | quality `low` |

Analysis uses strict JSON-schema structured output, so a verdict can never come
back malformed. The analysis and the illustration are requested **in parallel**
— the image prompt is built from the graph in code, so it doesn't wait on the
verdict.

---

### `canvas_flutter/`

The canvas sandbox rebuilt as a game: XP, levels, daily quests, 24
achievements, and streaks. Same 308-component library, same AI backend.

```bash
cd canvas_flutter
flutter pub get
flutter run -d windows   # or chrome, or a device
flutter test             # 29 tests
```

**No API key in the build.** The app asks for your own OpenAI key on first run
and stores it on-device via `shared_preferences`. There is no login and no
backend.

While an experiment runs, the result sheet shows a **local quiz** drawn from a
hardcoded bank of 47 questions, matched to the science domains you actually
built with — it fills the wait without adding any load to the API being waited
on.

---

### `canvas/edtech-app/`

The mobile study companion — subjects, notes, AI chat over your own documents
(RAG), quiz and flashcard generation, a calendar, and YouTube study playlists.
Works offline through Hive, syncing to Supabase when reachable.

```bash
cd canvas/edtech-app
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # required
flutter run
flutter test             # 24 tests
```

> **`build_runner` is not optional.** The Hive models use `part '*.g.dart'`
> files that are gitignored, so a fresh clone will not compile until you
> generate them. Re-run it whenever you change a `@HiveType` model.

**Firebase** — `android/app/google-services.json` is gitignored and not in the
repo. Download it from the Firebase console (project `learnxai`) before
building for Android. Google Sign-In additionally needs your debug SHA-1
registered there.

The OpenAI key is entered in-app under Settings, not baked into the build.

---

## Repo conventions

- **Generated and secret files are gitignored**: `*.g.dart`,
  `google-services.json`, `.env*`. A fresh clone needs `build_runner` and your
  own keys.
- **No API keys are committed.** Every app either reads them from an env file
  you create or asks for them at runtime.
- Each app has its own README with more detail.

## Troubleshooting

**`Error when reading 'lib/models/*.g.dart'`** (edtech-app)
Run `dart run build_runner build --delete-conflicting-outputs`.

**`File google-services.json is missing`** (edtech-app)
Download it from the Firebase console into `android/app/`.

**`Failed host lookup: *.supabase.co`**
No network, or the Supabase project no longer exists. The edtech app keeps
working offline via Hive; it just logs a warning per call.

**`unable to find directory entry in pubspec.yaml`**
A declared asset folder doesn't exist. Create it (an empty folder with a
`.gitkeep` is enough).
