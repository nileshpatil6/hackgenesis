# AI Experiment Lab — Flutter

A Flutter port of the `canvas/` React experiment simulator, rebuilt as a game.

Drag components onto an infinite canvas, wire them together, then hit **Run** —
an OpenAI model simulates the experiment, tells you what would happen, and
draws the result. You earn XP, level up, chase daily quests, and unlock
achievements as you build.

## Bring your own API key

There is **no API key in this repository and none baked into the build.** On
first run the app asks for your own OpenAI key and stores it on-device via
`shared_preferences`. You can change or remove it any time from the 🔑 button in
the app bar.

Get a key at [platform.openai.com/api-keys](https://platform.openai.com/api-keys).

There is no login, no account, and no backend — the app talks to OpenAI directly.

## Run it

```bash
flutter pub get

flutter run -d windows   # desktop
flutter run -d chrome    # web
flutter run -d <device>  # android
```

## Models

Each task uses the tier that fits it, via the OpenAI Responses API:

| Task | Model | Reasoning effort |
| --- | --- | --- |
| Assistant hints | `gpt-5.6-luna` | `low` |
| Visualization code | `gpt-5.6-terra` | `medium` |
| Experiment analysis | `gpt-5.6-sol` | `high` |

Experiment analysis uses strict JSON-schema structured output, so the verdict
can never come back malformed.

## Layout

```
lib/
  models/      core types (ComponentData, ExperimentNode/Edge, AnalysisResult)
  data/        308 components across 15 categories + 4 starter experiments
  services/    OpenAI client and on-device settings
  canvas/      node-graph engine: controller, node cards, edge painter, view
  game/        XP, levels, quests, achievements
  widgets/     palette, assistant chat, result sheet, dialogs, HUD
  screens/     the single home screen that wires it together
```

## Credits

Ported from the React + React Flow app in `../canvas`.
