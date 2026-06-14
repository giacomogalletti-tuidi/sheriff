# Copilot / AI instructions

The canonical project context is **[AGENTS.md](../AGENTS.md)** and the
**[docs/](../docs/)** folder. Read AGENTS.md first.

- **What:** "Sheriff of Nottingham" online — a Flutter client (`sheriff_game/`)
  and an authoritative pure-Dart WebSocket server (`sheriff_server/bin/server.dart`).
- **Architecture:** authoritative server, thin client; JSON over a single
  WebSocket. See [docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md).
- **Protocol:** hand-maintained contract — if you change a message, update the
  server, `game_controller.dart`, and [docs/PROTOCOL.md](../docs/PROTOCOL.md).
- **Rules & constants:** [docs/GAME_RULES.md](../docs/GAME_RULES.md).
- **What to work on:** [docs/IMPROVEMENTS.md](../docs/IMPROVEMENTS.md).

Conventions: validation/rules on the **server**; cards are strings on the wire;
card stats are duplicated in three files (keep in sync); no git yet — prefer
careful, additive changes; update docs alongside code.
