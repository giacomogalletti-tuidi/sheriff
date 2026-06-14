# AGENTS.md — AI context for the **Sheriff** project

> This is the canonical onboarding file for **any** AI assistant (Claude, Fable,
> Cursor, Copilot, ChatGPT, …) working on this repo. Read it first. Tool-specific
> files (`CLAUDE.md`, `.cursorrules`, `.github/copilot-instructions.md`) just
> point here. Keep this file up to date when the architecture changes.

## What this is

A digital, real-time multiplayer adaptation of the board game **Sheriff of
Nottingham** (bluffing / trading card game, 3–5 players). Two Dart projects:

| Folder           | What                          | Stack |
|------------------|-------------------------------|-------|
| `sheriff_game/`  | Client app (UI)               | Flutter, Dart `^3.6.0`, `provider`, `web_socket_channel` |
| `sheriff_server/`| Authoritative game server     | Pure Dart (`dart:io`), no runtime deps |

**Authoritative server, thin client.** The server owns all state and rules and
pushes per-player JSON snapshots over a single WebSocket; the client renders
them and sends user intents. In production the server also serves the built
Flutter **web** app, so one process can host everything.

## Read next (deep docs)

- **[docs/AUTONOMOUS_WORKFLOW.md](docs/AUTONOMOUS_WORKFLOW.md)** — how to run, debug & verify the project on your own. **Read this to operate autonomously.**
- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** — components, data flow, phase machine, deployment.
- **[docs/PROTOCOL.md](docs/PROTOCOL.md)** — every WebSocket message (client↔server) and the `game_state` shape.
- **[docs/GAME_RULES.md](docs/GAME_RULES.md)** — rules *as implemented*, constants, scoring, house rules.
- **[docs/IMPROVEMENTS.md](docs/IMPROVEMENTS.md)** — prioritized bugs, refactors, features, infra. **Start here for "what to work on".**

## Project map

```
sheriff/
├── AGENTS.md                      # ← you are here (AI context hub)
├── README.md                      # human-facing overview + run instructions
├── docs/                          # AUTONOMOUS_WORKFLOW / ARCHITECTURE / PROTOCOL / GAME_RULES / IMPROVEMENTS / PLAYTEST_REPORT / FABLE5_PROMPT
├── sheriff_shared/                # shared card catalog (single source of truth)
│   └── lib/card_data.dart
├── sheriff_server/
│   └── bin/server.dart            # the whole server: Room state + phase machine + WS + static file serving
│   └── tool/smoke_test.dart       # headless 3-bot end-to-end game simulator (autonomous e2e check)
│   └── test/game_logic_test.dart  # server unit tests
└── sheriff_game/
    └── lib/
        ├── main.dart              # app root, theme, lobby↔game switch
        ├── models/                # card.dart, game_state.dart, player.dart (plain data)
        ├── services/              # websocket_service.dart (socket), game_controller.dart (ChangeNotifier)
        ├── screens/               # one per phase: lobby, game (router), market, load_bag, declaration, inspection, end_game
        └── widgets/               # good_card, merchant_stand, game_top_bar, player_list
    └── test/widget_test.dart      # client model tests
```

## How to run

> Requires the Flutter SDK (includes Dart). Commands assume you're at the repo root.

**Server (dev):**
```bash
cd sheriff_server
dart pub get
dart run bin/server.dart        # http + ws on 0.0.0.0:8080, ws endpoint /ws
```

**Client (dev, web):**
```bash
cd sheriff_game
flutter pub get
flutter run -d chrome           # or any connected device/emulator
```

**Single-host (server serves the web build):**
```bash
cd sheriff_game && flutter build web
cd ../sheriff_server && dart run bin/server.dart
# open http://localhost:8080  → app + websocket on the same origin
```

**Tests:**
```bash
cd sheriff_server && dart test          # server logic
cd sheriff_game   && flutter test       # client models
```

**Analyze/lint:**
```bash
cd sheriff_game && flutter analyze
cd sheriff_server && dart analyze
```

**End-to-end game simulation (no human needed):**
```bash
cd sheriff_server && dart run tool/smoke_test.dart   # starts the server, plays a full 3-bot game, exits 0/1
```
This is how you verify the real-time multiplayer flow autonomously. Full
operating procedure (the change→run→verify→debug loop, definition of done,
guardrails) is in **[docs/AUTONOMOUS_WORKFLOW.md](docs/AUTONOMOUS_WORKFLOW.md)**.
All checks above (`dart/flutter analyze`, `dart/flutter test`, the simulator, and
`flutter build web`) were run and pass as of 2026-06-15.

## Key facts an AI must know before editing

- **Cards are strings on the wire** (`"apple"`, `"crossbow"`), end-to-end. The
  `GameCard`/`CardCatalog` types are for display/lookup, not the protocol.
- **Card stats live in `sheriff_shared/lib/card_data.dart`** (imported by server
  and client). UI colors/icons remain in `widgets/good_card.dart`.
- **Players are keyed by name** with a per-session **reconnect token** issued on
  create/join. Names must be unique within a room.
- **The protocol is a hand-maintained contract.** If you change a message shape,
  update the server, the client (`game_controller.dart`), **and**
  [docs/PROTOCOL.md](docs/PROTOCOL.md).
- **Phases are server-driven** with timeouts that auto-advance. Don't add
  client-side phase transitions; react to `game_state`.
- **No git yet.** There is no version control safety net — make changes
  carefully and prefer additive edits. (`git init` is the #1 infra task.)
- **State is in-memory only.** Restarting the server drops all games.

## Conventions

- Follow existing style: `provider` + `ChangeNotifier` on the client, plain
  functions/methods on the server. Match the surrounding code's idioms.
- Keep the client dumb: validation and rules belong on the **server**.
- Prefer small, reviewable changes. When you fix a bug, add/adjust a test in the
  matching `test/` folder.
- Update the relevant `docs/` file in the same change as the code.
