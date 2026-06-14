# Improvements, Bugs & Next Steps

A prioritized, actionable backlog derived from a full read of the codebase
(June 2026). Each item lists **where** it lives and **why** it matters. Line
numbers are approximate — search by symbol name to be safe.

Legend: 🔴 bug / correctness · 🟠 robustness / security · 🟡 maintainability ·
🟢 feature / polish · 🧪 tests · 🚀 infra / deployment.

---

## P0 — Correctness bugs (fix first)

### 🔴 Reconnecting mid-game loses your bag
`buildGameStateFor` (server) never includes the recipient's own `bag`. `myBag`
is only set by the one-shot `bag_loaded` message. A merchant who reconnects
during **declaration** is stuck: `myBag` is empty → `bagCount == 0` → the
"Declare" button is disabled (`declaration_screen.dart`), so they can only wait
for the 30s auto-declare. They also can't see their bag during inspection.
- **Fix:** add the player's own `bag` to `buildGameStateFor` in the
  declaration/inspection branches; have the client read `myBag` from `game_state`.
- Files: `sheriff_server/bin/server.dart` (`buildGameStateFor`),
  `sheriff_game/lib/services/game_controller.dart` (`_updateGameState`).

### 🔴 Market action isn't validated server-side → hand can exceed 6 / cheating
`handleMarketAction` trusts the client: it draws one card per `drawSources`
entry with no check that `drawSources.length <= discards.length`, and there is
**no cap at 6** before the top-up loop. A crafted client can inflate its hand or
draw extra contraband. The UI enforces the rule, the server does not.
- **Fix:** validate `drawSources.length == discards.length` (or ≤), validate that
  each discarded card is actually in hand, and clamp the final hand to 6.
- File: `sheriff_server/bin/server.dart` (`handleMarketAction`).

### 🔴 Duplicate / colliding player names
Neither `create` nor `join` (in lobby) checks that a name is unique. Two players
named "Bob" break everything: state is keyed by name (`gold`, `hands`, `bags`,
`merchantStands`, …) and `socketFor` uses `playerNames.indexOf(name)` which
returns the **first** match.
- **Fix:** reject duplicate names on join/create, or assign a stable per-player
  id (see P1 identity item).
- File: `sheriff_server/bin/server.dart` (`_handleCreate`, `_handleJoin`).

---

## P1 — Robustness & security

### 🟠 Name-based identity allows seat hijacking
A player is just a name. Anyone who knows the room code and a player's name can
`join`/`reconnect` as them (during a game, `join` with an existing name is
treated as a reconnect). There is no token or auth.
- **Fix:** issue a random reconnect token (e.g. `uuid`, already a dependency) on
  create/join; require it on reconnect. Keep names for display only.
- Files: `server.dart` (`_handleJoin`, `_handleReconnect`, `handleReconnect`),
  `game_controller.dart` (persist + resend token).

### 🟠 Finished rooms leak forever
`rooms` only deletes a room when it becomes empty **in lobby**. After
`gameOver`, the `Room` (sockets, timers, state) stays in memory indefinitely.
- **Fix:** delete the room (and cancel timers) on game over and when the last
  socket for a finished room closes; add a periodic sweep / room TTL.
- File: `server.dart` (`broadcastFinalScores`, `_handleDisconnect`).

### 🟠 Deck regeneration duplicates cards
When the draw pile and reshuffle are both exhausted, `drawCard` calls
`generateDeck()`, creating a fresh 204-card deck while copies already sit in
hands/bags/stands — breaking card conservation.
- **Fix:** reshuffle only real discards; if still empty, draw from a controlled
  pool or end the round gracefully instead of fabricating cards.
- File: `server.dart` (`drawCard`, `reshuffleDeckIfNeeded`, `generateDeck`).

### 🟠 Unbounded reconnect retries
`_attemptReconnect` retries every 2s forever with no backoff or cap, and
duplicates the `listen` setup from `connect`.
- **Fix:** exponential backoff with a max, and extract the shared listen handler.
- File: `sheriff_game/lib/services/websocket_service.dart`.

### 🟠 No input limits on names / chat
Names and chat text are unbounded and unsanitized (no XSS risk in Flutter's
`Text`, but spam/oversized payloads are possible). No chat rate limiting.
- **Fix:** length caps + trim on the server; basic rate limit on `chat`.
- File: `server.dart` (`_handleCreate`/`_handleJoin`, `handleChat`).

### 🟠 Hardcoded WS fallback for native builds
On non-web targets the WebSocket URL falls back to `ws://localhost:8080/ws`.
There's no configuration for pointing a mobile/desktop build at a real server.
- **Fix:** make the server URL configurable (build-time `--dart-define` or a
  settings field in the lobby).
- File: `sheriff_game/lib/screens/lobby_screen.dart` (`_getWebSocketUrl`).

---

## P2 — Maintainability

### 🟡 Card data duplicated in 3 places (single source of truth)
Card values/penalties/types live in `server.dart` (`cardValues`,
`deckComposition`, `kingBonus`, `queenBonus`), `sheriff_game/lib/models/card.dart`
(`CardCatalog`), and partially in `widgets/good_card.dart` (contraband set,
colors, icons). They can drift silently.
- **Fix:** one source of truth — e.g. a small **shared Dart package** imported by
  both projects, or a generated `card_data.dart` from a single JSON.
- Files: the three above.

### 🟡 Unused dependencies / dead tooling
`pubspec.yaml` declares `json_annotation`, `json_serializable`, `build_runner`,
and `uuid`, but JSON is hand-written (no `.g.dart`, no `part` directives) and
`uuid` appears unused on the client.
- **Fix:** either adopt codegen for the models or drop the unused deps. (Keep
  `uuid` if you implement reconnect tokens.)
- File: `sheriff_game/pubspec.yaml`.

### 🟡 Default Flutter README, no project-level docs
`sheriff_game/README.md` is the untouched template. (This `docs/` set + root
`AGENTS.md`/`README.md` now address project-level docs.)

### 🟡 `inspectionResults` cleared on every `game_state`
`_updateGameState` calls `inspectionResults.clear()`. It's safe today only
because the server doesn't broadcast `game_state` mid-inspection — a fragile
implicit coupling.
- **Fix:** track inspection results keyed by player and derive the list, instead
  of clearing on state updates.
- File: `sheriff_game/lib/services/game_controller.dart`.

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
