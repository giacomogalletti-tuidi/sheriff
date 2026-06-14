# Improvements, Bugs & Next Steps

A prioritized, actionable backlog derived from a full read of the codebase
(June 2026). Each item lists **where** it lives and **why** it matters. Line
numbers are approximate — search by symbol name to be safe.

Legend: 🔴 bug / correctness · 🟠 robustness / security · 🟡 maintainability ·
🟢 feature / polish · 🧪 tests · 🚀 infra / deployment.

---

## P0 — Correctness bugs (fix first)

_All P0 items below were fixed 2026-06-15._

### ~~🔴 Reconnecting mid-game loses your bag~~ ✅ Fixed
`buildGameStateFor` now includes `myBag` during declaration/inspection; the client
reads it from `game_state`.

### ~~🔴 Market action isn't validated server-side~~ ✅ Fixed
`handleMarketAction` validates discard ownership, `drawSources.length == discards.length`,
and clamps the hand to 6.

### ~~🔴 Duplicate / colliding player names~~ ✅ Fixed
Create/join reject duplicate names (case-insensitive) and invalid lengths.

---

## P1 — Robustness & security

### ~~🟠 Name-based identity allows seat hijacking~~ ✅ Fixed
Server issues a random reconnect `token` on create/join; reconnect requires it.

### ~~🟠 Finished rooms leak forever~~ ✅ Fixed
Rooms are deleted when the last client disconnects after `gameOver`, plus a 1h TTL
sweep and `Room.dispose()` cancels timers.

### ~~🟠 Deck regeneration duplicates cards~~ ✅ Fixed
`drawCard` no longer calls `generateDeck()` when empty; returns `null` instead.

### ~~🟠 Unbounded reconnect retries~~ ✅ Fixed
Exponential backoff (2s→60s cap, 30 attempts max); shared listen handler extracted.

### ~~🟠 No input limits on names / chat~~ ✅ Fixed
Names trimmed and capped at 20 chars; chat capped at 500 chars with rate limiting
(5 msgs / 10s per player).

### ~~🟠 Hardcoded WS fallback for native builds~~ ✅ Fixed
Optional server URL field in lobby + `--dart-define=SHERIFF_WS_URL=...`.

---

## P2 — Maintainability

### ~~🟡 Card data duplicated in 3 places~~ ✅ Fixed
Single source of truth in `sheriff_shared/lib/card_data.dart` (imported by server
and client). UI colors/icons remain in `good_card.dart`.

### ~~🟡 Unused dependencies / dead tooling~~ ✅ Fixed
Removed unused `uuid`, `json_annotation`, `json_serializable`, and `build_runner`
from the client. Server uses `uuid` for reconnect tokens.

### 🟡 Default Flutter README, no project-level docs
`sheriff_game/README.md` is the untouched template. (This `docs/` set + root
`AGENTS.md`/`README.md` now address project-level docs.)

### ~~🟡 `inspectionResults` cleared on every `game_state`~~ ✅ Fixed
Results keyed by player; cleared only when leaving the inspection phase.

---

## P3 — Tests 🧪

Current coverage: server card/deck/scoring/payGold/inspection-resolution unit
tests (`sheriff_server/test/game_logic_test.dart`), client model roundtrip tests
(`sheriff_game/test/widget_test.dart` — note: it tests models, not widgets), and
a **headless end-to-end game simulator** (`sheriff_server/tool/smoke_test.dart`)
that plays a full 3-player game over real WebSockets and asserts it reaches
`game_over`. See [AUTONOMOUS_WORKFLOW.md](AUTONOMOUS_WORKFLOW.md). Gaps:

- Promote the e2e simulator into CI and add **assertions on invariants** (gold
  conservation, penalties) beyond "the game finished".
- Extend the simulator to cover bribes/chat, disconnect/reconnect, 4–5 players,
  and phase-timeout paths (see the harness's own "extension points" list).
- Scoring **tie** cases (King tie split, Queen tie split, all-zero good).
- `payGold` liquidation order (legal before contraband) and exact shortfall.
- Disconnect/reconnect flows and phase-timeout auto-actions.
- Market validation (once the P0 fix lands) and declaration count enforcement.
- At least one real **widget test** per phase screen.

---

## P4 — Features & polish 🟢

- **Bribe with goods UI** — server already supports `goodsFromStand`; add the
  merchant-side UI to select stand goods to offer (`inspection_screen.dart`).
- **Rematch** — keep players in the room after `gameOver` and allow a new game
  without re-entering the code.
- **Host controls** — kick player, configurable rules (rounds, starting gold,
  timeouts), start without full readiness.
- **Bots / AI players** — fill empty seats; useful for testing too.
- **Spectator mode** — watch an in-progress game.
- **i18n (English/Italian)** — UI strings are English-only; the owner is
  Italian. Use `flutter_localizations` + ARB files.
- **Visual polish** — real card art instead of Material icons, animations for
  inspection reveals, sound.
- **Better disconnect UX** — show who's gone and a live countdown to forfeit.

---

## P5 — Infrastructure & deployment 🚀

- **`git init`** — the project is **not** under version control. Do this first;
  it makes every change above reversible and reviewable.
- **Root `.gitignore`** — exclude `build/`, `.dart_tool/`, `.vs/`, IDE files
  (a starter is included at the repo root).
- **Dockerfile** — multi-stage: `flutter build web` → copy into a Dart runtime
  serving `bin/server.dart`. The server already serves the web build, so this is
  a clean single-container deploy.
- **CI** (GitHub Actions) — `dart test` (server), `flutter test` (client),
  `flutter build web`, `dart analyze`/`flutter analyze`.
- **TLS / WSS** — terminate TLS at a reverse proxy (Caddy/nginx) and confirm
  `wss://` upgrades on `/ws`.
- **Observability** — replace `print` with structured logging; add a `/health`
  endpoint and basic metrics (active rooms/players).
- **Persistence / scale-out** — only needed if you want games to survive
  restarts or run multiple instances (move room state to Redis or similar).

---

## Suggested order of attack

1. `git init` + root `.gitignore` (P5) — safety net before touching code.
2. P0 bugs (bag-on-reconnect, market validation, duplicate names).
3. P1 identity tokens + room cleanup (unlocks safe multiplayer).
4. P2 single source of truth for card data (prevents future drift).
5. P3 tests around everything you just changed.
6. P4/P5 features and deployment as the product matures.
