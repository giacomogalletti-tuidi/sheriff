# CLAUDE.md

The canonical project context lives in **[AGENTS.md](AGENTS.md)** and the
**[docs/](docs/)** folder. Read those first — they are vendor-neutral and kept
up to date.

Quick links:
- [AGENTS.md](AGENTS.md) — project overview, structure, how to run, key facts.
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- [docs/PROTOCOL.md](docs/PROTOCOL.md)
- [docs/GAME_RULES.md](docs/GAME_RULES.md)
- [docs/IMPROVEMENTS.md](docs/IMPROVEMENTS.md) — what to work on.

When you change code, update the matching doc in the same change. Validation and
rules belong on the **server**; keep the client thin. There is **no git** here
yet, so prefer careful, additive changes.
