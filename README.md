# Yukti / EduAI

An AI-assisted learning ecosystem built as a monorepo of six independent
applications: a marketing site, a community hub, a web study platform, an AI
experiment sandbox in both web and native form, and a mobile study companion.

Every directory is a self-contained project with its own dependency manifest,
build tooling and README. There is no shared build or workspace at the root.
Install and run whichever application you are working on.

---

## Table of contents

- [Repository layout](#repository-layout)
- [Prerequisites](#prerequisites)
- [Quick start](#quick-start)
- [Applications](#applications)
  - [website-frontend](#website-frontend)
  - [main](#main)
  - [learning-platform](#learning-platform)
  - [canvas](#canvas)
  - [canvas_flutter](#canvas_flutter)
  - [canvas/edtech-app](#canvasedtech-app)
- [AI model usage](#ai-model-usage)
- [Configuration and secrets](#configuration-and-secrets)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)

---

## Repository layout

| Directory | Purpose | Stack | Runs on |
| --- | --- | --- | --- |
| `website-frontend/` | Public marketing site for the ecosystem | React 18, Vite, Three.js, Framer Motion | Web |
| `main/` | Community hub: hackathons, challenges, leaderboards | Next.js, Firebase Auth, Supabase | Web |
| `learning-platform/` | Study platform: subjects, quizzes, flashcards, AI tutor | Next.js, Prisma, NextAuth, OpenAI | Web |
| `canvas/` | AI experiment sandbox on an infinite canvas | React 18, Vite, React Flow, OpenAI | Web |
| `canvas_flutter/` | The sandbox rebuilt as a game with progression | Flutter 3.35, Dart 3.9 | Windows, Web, Android |
| `canvas/edtech-app/` | Mobile study companion with offline support | Flutter, Hive, Firebase, Supabase | Android |

`canvas/edtech-app/` is nested inside `canvas/` for historical reasons. It is a
separate application and shares no code with the sandbox surrounding it.

---

## Prerequisites

| Requirement | Version | Needed for |
| --- | --- | --- |
| Node.js | 18 or newer | `website-frontend`, `main`, `learning-platform`, `canvas` |
| Flutter SDK | 3.35 or newer | `canvas_flutter`, `canvas/edtech-app` |
| Dart SDK | 3.9 or newer | Bundled with Flutter |
| Android SDK | API 21 or newer | `canvas/edtech-app` on device |

API credentials are required per application. See
[Configuration and secrets](#configuration-and-secrets).

---

## Quick start

The fastest path to something running, with no credentials required:

```bash
cd website-frontend
npm install
npm run dev
```

To run the AI sandbox, which needs one OpenAI key:

```bash
cd canvas
npm install
echo "VITE_OPENAI_API_KEY=sk-your-key" > .env
npm run dev
```

---

## Applications

### website-frontend

The public marketing site. Includes an animated hero, a scroll-driven feature
section, Three.js background effects and links out to the other applications in
the ecosystem.

```bash
cd website-frontend
npm install
npm run dev          # Vite dev server
npm run build        # production bundle
npm run preview      # serve the production bundle locally
```

No credentials are required. The call-to-action buttons currently point at a
locally running instance of `canvas`.

---

### main

The community hub. Provides Google sign-in, hackathon listings, coding
challenges and a leaderboard feature named "voom".

```bash
cd main
npm install
npm run dev          # http://localhost:3000
npm run build
npm run lint
```

**Pages**

| Route | Purpose |
| --- | --- |
| `/` | Landing page |
| `/login`, `/signup` | Firebase authentication |
| `/dashboard` | Signed-in home |
| `/hackathons`, `/hackathons/[id]` | Hackathon listings and detail |
| `/challenges`, `/challenges/solve` | Coding challenges |
| `/voom`, `/voom/[id]` | Leaderboard feature |

**API routes**

| Endpoint | Purpose |
| --- | --- |
| `POST /api/generate-questions` | AI question generation |
| `POST /api/voom/submit` | Submit a leaderboard entry |
| `GET /api/voom/leaderboard` | Read the leaderboard |

**Environment.** Create `main/.env.local`:

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
OPENAI_BASE_URL=        # optional, defaults to an AWS Bedrock proxy
OPENAI_MODEL_NAME=      # optional, defaults to deepseek.v3.2
```

---

### learning-platform

The most feature-complete web application. Covers subjects and notes,
AI-generated quizzes and flashcards with spaced repetition, generated slide
decks, learning games, a study planner, achievements and a voice tutor.

```bash
cd learning-platform
cp .env.example .env           # then set OPENAI_API_KEY and NEXTAUTH_SECRET
npm install                    # runs prisma generate via postinstall
npx prisma db push             # creates or updates prisma/dev.db
npm run dev                    # http://localhost:3001
```

Sign in with any name. The credentials provider creates a demo account on
first use, so there is no password and no OAuth application to register.

Note that `npx prisma migrate dev` does not apply here: the project has no
migrations directory and tracks the schema with `db push`.

**Pages**

All authenticated pages live under `/dashboard`:

| Route | Purpose |
| --- | --- |
| `/dashboard` | Overview and statistics |
| `/dashboard/subjects` | Subject list, detail, topic slides |
| `/dashboard/quizzes` | Quiz list, attempt, results |
| `/dashboard/flashcards` | Deck list and spaced-repetition review |
| `/dashboard/games` | Generated learning games |
| `/dashboard/study-planner` | Sessions and milestones |
| `/dashboard/achievements` | Gamification and streaks |
| `/dashboard/ai-teacher` | Conversational tutor |
| `/dashboard/voice` | Speech-driven tutoring |
| `/dashboard/settings` | Profile and preferences |
| `/onboarding` | First-run setup |

**Architecture notes**

- Persistence is Prisma over SQLite. The datasource URL is hardcoded to
  `file:./dev.db` in `prisma/schema.prisma`, so the `DATABASE_URL` entry in
  `.env.example` is inert and changing it moves nothing.
- `prisma/dev.db` is committed, so a fresh clone starts with a working
  database. Delete it and rerun `npx prisma db push` for an empty one.
- Authentication is NextAuth with a credentials provider that creates a demo
  user from whatever name is typed.
- Spaced repetition lives in `lib/algorithms/spaced-repetition.ts`.
- `lib/openai.ts` is the only place a model is called. Uploaded notes are
  extracted, chunked and embedded into `NoteChunk` by `lib/rag.ts`, and
  retrieval is exposed at `/api/rag/search`.
- The voice tutor opens a WebRTC session against the OpenAI Realtime API. The
  browser receives a short-lived client secret from `/api/voice/realtime` and
  never sees the account key.

**Environment.** Copy `learning-platform/.env.example` to `.env`. Only two
entries are required:

```bash
OPENAI_API_KEY=           # drives every AI feature, including voice
NEXTAUTH_SECRET=          # any long random string
NEXTAUTH_URL=http://localhost:3001
```

Everything else in the template is optional. `OPENAI_BASE_URL` points at an
OpenAI-compatible proxy, in which case vector-store file search is skipped and
retrieval falls back to the local embedding index. The `OPENAI_*_MODEL`
entries override the per-task model defaults.

---

### canvas

The AI experiment lab. Drag components from a library of 308 parts onto an
infinite canvas, wire them together, then run the experiment. An OpenAI model
simulates the outcome, explains what happened and generates an illustration of
the apparatus.

```bash
cd canvas
npm install
npm run dev
npm run build
```

**Features**

- 308 components across 15 scientific domains, grouped into collapsible
  families in the palette.
- React Flow canvas with drag-and-drop placement, labelled connections, undo
  and redo, and a freehand drawing layer.
- A lab-assistant chat that is prompted to give hints only, never solutions.
- Four bundled starter experiments covering electronics, chemistry, physics and
  control flow.
- Light and dark themes.

**Environment.** Create `canvas/.env`:

```bash
VITE_OPENAI_API_KEY=sk-your-key
```

> **Security note.** Vite inlines `VITE_*` variables into the client bundle, so
> this key is visible to anyone who loads the page. That is acceptable for
> local development. Move the calls behind a backend proxy before deploying
> publicly.

---

### canvas_flutter

The canvas sandbox rebuilt as a game. Same 308-component library and same AI
backend, wrapped in a progression system.

```bash
cd canvas_flutter
flutter pub get
flutter run -d windows     # or: -d chrome, or an attached device
flutter test               # 29 tests
flutter build web
```

**Features**

- XP and levelling with a smooth curve, rank titles and daily play streaks.
- 24 achievements across bronze, silver, gold and legendary tiers.
- 12 rotating daily quests, picked deterministically per day.
- A local quiz of 47 questions shown while an experiment runs, selected to
  match the scientific domains the player actually built with. It is entirely
  offline and deliberately adds no load to the API being waited on.
- Confetti and toast celebrations on level-up and unlock.

**Credentials.** No key is compiled into the build. The application prompts for
your own OpenAI key on first run and stores it on-device through
`shared_preferences`. There is no account system and no backend.

**Layout**

```
lib/
  models/      Core types: ComponentData, ExperimentNode, AnalysisResult
  data/        308 components, 15 categories, 4 starter experiments
  services/    OpenAI client and on-device settings
  canvas/      Node-graph engine: controller, node cards, edge painter, view
  game/        XP, levels, quests, achievements, waiting quiz
  widgets/     Palette, assistant chat, result sheet, dialogs, HUD
  screens/     The single home screen that composes everything
```

---

### canvas/edtech-app

The mobile study companion. Provides subjects and notes, AI chat grounded in
your own uploaded documents via retrieval, quiz and flashcard generation, a
study calendar and YouTube playlists. Data is stored locally in Hive and
synchronised to Supabase when the network is reachable.

```bash
cd canvas/edtech-app
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # required
flutter run
flutter test               # 24 tests
flutter build apk --debug
```

> **Code generation is mandatory.** The Hive models declare `part '*.g.dart'`
> files that are gitignored, so a fresh clone will not compile until they are
> generated. Re-run the `build_runner` command above after changing any
> `@HiveType` model.

**Screens**

| Area | Screens |
| --- | --- |
| Entry | Splash, login, onboarding |
| Home | Dashboard, subjects, progress, profile tabs |
| Subjects | Detail, chat, quiz generation and attempt, flashcard generation and review |
| Planning | Calendar, add event, playlists, add playlist |
| Settings | OpenAI API key |

**Services**

| Service | Responsibility |
| --- | --- |
| `auth_service.dart` | Firebase authentication and Google sign-in |
| `database_service.dart` | Hive boxes and adapter registration |
| `supabase_service.dart` | Remote sync |
| `openai_rag_service.dart` | Document-grounded chat |
| `openai_config_service.dart` | On-device key storage |
| `deepgram_service.dart` | Speech to text |
| `youtube_service.dart` | Study playlist search |
| `notification_service.dart` | Local reminders |

**Firebase.** `android/app/google-services.json` is gitignored and is not in
the repository. Download it from the Firebase console for the `learnxai`
project and place it in `android/app/` before building for Android. Google
sign-in additionally requires your debug SHA-1 fingerprint to be registered
there.

**Credentials.** The OpenAI key is entered inside the application under
Settings and is never compiled into the build.

---

## AI model usage

`canvas` and `canvas_flutter` select a model tier per task rather than using a
single model for everything. All calls go through the OpenAI Responses API.

| Task | Model | Reasoning effort | Rationale |
| --- | --- | --- | --- |
| Assistant hints | `gpt-5.6-luna` | `low` | Short conversational replies that must feel immediate |
| Visualisation code | `gpt-5.6-terra` | `medium` | Balanced tier for code generation |
| Experiment analysis | `gpt-5.6-sol` | `high` | Frontier reasoning over the experiment graph |
| Result illustration | `gpt-image-2` | quality `low` | Decorative panel; low quality returns in seconds |

Two implementation details worth knowing:

- **Structured output.** Experiment analysis uses a strict JSON schema, so a
  verdict cannot come back malformed and require defensive parsing.
- **Parallel requests.** The analysis and the illustration are dispatched
  simultaneously. The image prompt is constructed from the experiment graph in
  application code rather than written by the analysis model, which removes the
  dependency between the two calls. Total latency is therefore the slower of
  the two rather than their sum. The trade-off is that the illustration depicts
  the apparatus the user assembled rather than the analysed outcome, because
  the outcome is not yet known when rendering begins.

`learning-platform` calls OpenAI directly and selects the model per task: the
heavier model for tutoring and study plans, the fast one for the short
structured output behind flashcards, quizzes and games. Each name is an
environment variable with a default, so a model can be swapped without a code
change. `main` calls an OpenAI-compatible endpoint overridable through
`OPENAI_BASE_URL` and `OPENAI_MODEL_NAME`.

---

## Configuration and secrets

No credentials are committed to this repository. Each application either reads
them from an environment file you create or requests them at runtime.

| Application | Mechanism | File |
| --- | --- | --- |
| `main` | Build-time environment | `.env.local` |
| `learning-platform` | Build-time environment | `.env` |
| `canvas` | Build-time environment, inlined into the bundle | `.env` |
| `canvas_flutter` | Runtime prompt, stored on-device | none |
| `canvas/edtech-app` | Runtime prompt, plus `google-services.json` | none |

The following are gitignored by design and must be recreated after cloning:

- `*.g.dart` in `canvas/edtech-app`, produced by `build_runner`
- `android/app/google-services.json` in `canvas/edtech-app`
- All `.env*` files
- `node_modules/`, `build/`, `.dart_tool/`, `.next/`

---

## Testing

```bash
cd canvas_flutter && flutter test          # 29 tests
cd canvas/edtech-app && flutter test       # 24 tests
```

`canvas_flutter` covers component library integrity, canvas controller graph
operations including edge rejection and undo, the XP curve, quiz data validity
and result sheet behaviour.

`canvas/edtech-app` covers navigation bar layout across five screen widths,
every tab selection and an enlarged system font scale. These are regression
tests for a real overflow defect.

The web applications currently have no automated test suite. `main` declares a
`test` script but no test files are present.

---

## Troubleshooting

**`Error when reading 'lib/models/*.g.dart'`** in `canvas/edtech-app`

Generated Hive adapters are missing. Run:

```bash
dart run build_runner build --delete-conflicting-outputs
```

**`File google-services.json is missing`** in `canvas/edtech-app`

Download the file from the Firebase console into `android/app/`. The Gradle
Google Services plugin cannot run without it.

**`Failed host lookup: <project>.supabase.co`**

The device has no network route, or the Supabase project no longer exists. The
mobile application continues to function offline through Hive, but it logs one
warning per attempted call.

**`unable to find directory entry in pubspec.yaml`**

A directory declared under `flutter: assets:` does not exist. Create it. An
empty directory containing a `.gitkeep` file is sufficient.

**`The target device is full`** during a Flutter build

The build cache and Gradle caches grow large. `%TEMP%` and `~/.gradle` are the
usual candidates for reclaiming space.
