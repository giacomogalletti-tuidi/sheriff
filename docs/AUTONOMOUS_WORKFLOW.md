# Autonomous Workflow — how an AI runs, debugs & verifies this project alone

This is the operating manual for working on **Sheriff** without a human in the
loop. The goal: an AI can **make a change, run it, observe it, and verify it**
on its own. Read [AGENTS.md](../AGENTS.md) first for architecture; this file is
about the *operating loop*.

> Every command below was **executed and verified on 2026-06-15**
> (Dart 3.8.0, Flutter present, Windows). Results are noted inline.

## The core loop

```
understand → change → STATIC CHECK → UNIT TEST → END-TO-END SIM → (read logs) → iterate
```

The hard part of this project is that it's a **real-time multiplayer game**: you
can't "play it" to test. The solution is the **headless simulation harness**
(`sheriff_server/tool/smoke_test.dart`), which drives a full 3-player game over
real WebSockets and asserts it reaches `game_over`. That is your "did I break the
game?" check.

## Verification commands (run after every change)

Run these from the repo root. **All currently pass / are clean.**

### 1. Static analysis — fast, run first
```bash
cd sheriff_server && dart analyze        # ✅ "No issues found!"
cd sheriff_game   && flutter analyze     # ✅ "No issues found!" (~50s)
```

### 2. Unit tests
```bash
cd sheriff_server && dart test           # ✅ 15 tests pass (server game logic)
cd sheriff_game   && flutter test        # ✅ 11 tests pass (client models)
```

### 3. End-to-end game simulation (the key check)
```bash
cd sheriff_server && dart run tool/smoke_test.dart   # ✅ exit 0, plays a full game
```
This auto-starts the server (or reuses a running one), connects 3 bots, plays
every phase for the whole game, prints a transcript + final scores, and exits
non-zero if the game stalls or errors. A full game takes ~30–60s (the server
delays 3s between rounds).

### 4. Web build (deploy path — slower, run before shipping)
```bash
cd sheriff_game && flutter build web     # ✅ "Built build/web" (~14s); served by the server
```

### One-shot "verify everything"

PowerShell (Windows — `;` then check `$LASTEXITCODE`):
```powershell
cd sheriff_server; dart analyze; dart test; dart run tool/smoke_test.dart
cd ..\sheriff_game; flutter analyze; flutter test
```
Bash:
```bash
(cd sheriff_server && dart analyze && dart test && dart run tool/smoke_test.dart) && \
(cd sheriff_game && flutter analyze && flutter test)
```

## Running the app autonomously

### Server (long-running) — run it in the background
Don't block on the server in the foreground. Either:
- let the smoke test spawn+stop it for you (preferred for tests), or
- start it as a background process and stop it when done:

```bash
cd sheriff_server && dart run bin/server.dart     # run in background; stop when finished
```

The server logs every phase transition, e.g.
`[ROOM QPMGL] enterPhase: GamePhase.inspection (from GamePhase.declaration, disconnected={})`
and connect/disconnect events — these traces are your primary debugging signal.

### Full app in a browser (manual visual check, if a human is available)
```bash
cd sheriff_game && flutter build web
cd ../sheriff_server && dart run bin/server.dart   # serves the web app + ws on :8080
# open http://localhost:8080
```

## Debugging playbook (no human)

1. **Reproduce in the harness.** Most multiplayer bugs are reachable by editing
   `tool/smoke_test.dart`:
   - change bot count (add a 4th/5th bot → tests 4–5 player rules and the
     2-vs-3 sheriff-rounds logic),
   - make a bot **lie/be honest** deliberately (change the `declare` type),
   - make a merchant **offer a bribe** (`bribe_offer`) and the sheriff respond,
   - **drop and reconnect** a bot mid-game (close its socket, reconnect with the
     same name+roomId) → this reproduces the P0 "reconnect loses bag" bug.
2. **Read the server transcript.** The `[server] [ROOM …] enterPhase …` lines
   tell you exactly which phase stalled. If the harness times out, the last
   transition is where it got stuck.
3. **Add a targeted unit test.** For pure logic (scoring ties, payGold, market
   validation) add a case to `sheriff_server/test/game_logic_test.dart` — it
   imports `bin/server.dart` directly and constructs a `Room`, so you can call
   handlers and assert on state without any networking. This is the fastest
   feedback loop for rules bugs.
4. **Inspect a single message exchange.** Write a tiny throwaway client (copy
   the `Bot` connect/send pattern from the harness) to send one message and
   print the server's reply — useful for protocol questions.
5. **Confirm the fix** by re-running the full verification loop above.

## Definition of Done (self-check before claiming a task complete)

- [ ] `dart analyze` and `flutter analyze` are clean.
- [ ] `dart test` and `flutter test` pass.
- [ ] `dart run tool/smoke_test.dart` still reaches `game_over` (exit 0).
- [ ] If you fixed a bug, there is a **new/updated test** that fails before and
      passes after.
- [ ] If you changed a message shape, the **server**, the **client**
      (`game_controller.dart`), and **[docs/PROTOCOL.md](PROTOCOL.md)** all match.
- [ ] If you changed card data, all **three** sources are in sync (see
      [IMPROVEMENTS.md](IMPROVEMENTS.md)).
- [ ] The relevant `docs/` file is updated in the same change.

## Guardrails for autonomous work

- **No git yet.** There is no undo. Prefer additive changes; before deleting or
  rewriting a file, confirm it's the right one. (`git init` is the #1 infra task
  in [IMPROVEMENTS.md](IMPROVEMENTS.md) — doing it first makes everything safer.)
- **Don't break the protocol contract** unilaterally — both sides + the doc.
- **Keep the client thin** — new rules/validation go on the server.
- **Long-running processes** (the server) must be started in the background and
  stopped when done, or spawned+killed by a script (the harness does this). Never
  block the loop on a foreground server.
- **Ports:** the server hardcodes `:8080`. The harness reuses a running server if
  one is up; otherwise it starts its own. Don't start two foreground servers.

## Harness: current coverage & extension points

**Covered today:** create/join/ready/countdown, market (discard+draw), loadBag,
declaration (honest + lying), inspection (inspect + pass), multi-round rotation,
scoring, clean shutdown — for a **3-player** game.

**Not yet covered** (good "first autonomous tasks" to add):
- bribes (`bribe_offer` / `bribe_response`) and chat,
- disconnect/reconnect flows (would surface the P0 bag bug),
- 4- and 5-player games,
- phase-timeout paths (let a bot go silent so the server auto-advances),
- assertions on gold conservation / penalties (currently it only asserts the
  game finishes and everyone is scored).

Extend `tool/smoke_test.dart` to cover these as you work on the matching areas.
