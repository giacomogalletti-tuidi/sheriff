# Sheriff of Nottingham — online

A real-time multiplayer adaptation of the **Sheriff of Nottingham** board game
(bluffing / smuggling card game, 3–5 players), built with **Flutter** (client)
and a **pure-Dart WebSocket server**.

```
sheriff/
├── sheriff_game/     # Flutter client (Android, iOS, web, desktop)
└── sheriff_server/   # Authoritative WebSocket game server (also serves the web build)
```

## Quick start

> Needs the [Flutter SDK](https://docs.flutter.dev/get-started/install)
> (bundles Dart).

**1. Start the server**
```bash
cd sheriff_server
dart pub get
dart run bin/server.dart        # listens on 0.0.0.0:8080, WebSocket at /ws
```

**2. Run the client (web)**
```bash
cd sheriff_game
flutter pub get
flutter run -d chrome
```

To play on one host, build the web app first and let the server serve it:
```bash
cd sheriff_game && flutter build web
cd ../sheriff_server && dart run bin/server.dart
# then open http://localhost:8080
```

Create a room, share the 5-letter code, and have 3–5 players join. Everyone hits
**Ready** to start.

## How to play

You're a merchant smuggling goods past the Sheriff. Each round one player is the
Sheriff; the rest load bags, declare (truth optional!), and try to sneak
contraband through — by bluffing, negotiating, and bribing. Full rules as
implemented: **[docs/GAME_RULES.md](docs/GAME_RULES.md)**.

## Documentation

| Doc | For |
|-----|-----|
| **[AGENTS.md](AGENTS.md)** | AI assistants — start here. |
| [docs/AUTONOMOUS_WORKFLOW.md](docs/AUTONOMOUS_WORKFLOW.md) | Running, debugging & verifying autonomously. |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | How the client/server fit together. |
| [docs/PROTOCOL.md](docs/PROTOCOL.md) | WebSocket message contract. |
| [docs/GAME_RULES.md](docs/GAME_RULES.md) | Rules, constants, scoring. |
| [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) | Docker + free online hosting (Render). |
| [docs/IMPROVEMENTS.md](docs/IMPROVEMENTS.md) | Known bugs, roadmap, next steps. |

## Tests

```bash
cd sheriff_server && dart test                    # server game logic
cd sheriff_game   && flutter test                 # client models
cd sheriff_server && dart run tool/smoke_test.dart # headless full-game e2e simulation
```

## Status & roadmap

Playable end-to-end. Known issues and the prioritized backlog (reconnect bug,
server-side validation, identity/auth, single source of truth for card data,
deployment) are tracked in **[docs/IMPROVEMENTS.md](docs/IMPROVEMENTS.md)**.

> ⚠️ This project is **not yet under version control**. Run `git init` before
> making changes — see the infra section of IMPROVEMENTS.
