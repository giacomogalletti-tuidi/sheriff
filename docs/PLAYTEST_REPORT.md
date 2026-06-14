# Playtest Report

A running log of multiplayer playtest sessions (mostly via the headless simulator
`sheriff_server/tool/smoke_test.dart`). Append a new entry per run — newest at the
top. This is the artifact the "full multiplayer playtest" task writes to (see
[FABLE5_PROMPT.md](FABLE5_PROMPT.md)). For the prioritized bug backlog see
[IMPROVEMENTS.md](IMPROVEMENTS.md).

Entry template:

```
## YYYY-MM-DD HH:MM — <short title>
- Players: <n> (<names / how driven>)
- Commands: <exact commands run>
- Expected: <what should happen>
- Actual: <what happened>
- Scenarios covered: <...>
- Not covered: <...>
- Bugs found: <list, link to IMPROVEMENTS items>
- Fixes in this run: <list, or "none">
- Result: PASS / FAIL (+ reason)
```

---

## 2026-06-15 — Baseline (happy-path e2e green)

- **Players:** 3 (Alice, Bob, Cara — bots driven by `tool/smoke_test.dart`).
- **Commands:**
  - `cd sheriff_server && dart pub get && dart test && dart analyze`
  - `cd sheriff_game && flutter pub get && flutter test && flutter analyze`
  - `cd sheriff_server && dart run tool/smoke_test.dart`
  - `cd sheriff_game && flutter build web`
- **Expected:** all checks pass; the simulator plays a full game to `game_over`
  with every player scored.
- **Actual:** ✅ all green.
  - `dart analyze` (server) → No issues. `flutter analyze` (client) → No issues.
  - `dart test` → 15/15. `flutter test` → 11/11.
  - `dart run tool/smoke_test.dart` → reached `game_over`, exit 0. Final scores:
    Cara 190 (goods 80, gold 68), Bob 113 (goods 38, gold 48), Alice 62 (goods 8,
    gold 34).
  - `flutter build web` → `Built build/web` (~14s).
- **Scenarios covered:** room create/join/ready/countdown, market (discard+draw),
  load bag, declaration (honest + lying, declaring "apple" over contraband bags),
  inspection (inspect first merchant + pass the rest), sheriff rotation across all
  9 rounds (3-player game), end-game scoring incl. King/Queen bonuses.
- **Not covered (next runs):** bribes (`bribe_offer`/`bribe_response`) and chat;
  disconnect/reconnect; 4- and 5-player games; phase-timeout auto-advance paths;
  invariant assertions (gold conservation, exact penalties).
- **Bugs found this run:** none on the happy path. Known issues on *untested*
  paths remain open in [IMPROVEMENTS.md](IMPROVEMENTS.md): reconnect-loses-bag
  (P0), market action not server-validated → hand can exceed 6 (P0), duplicate
  player names collide (P0). These need the simulator extended to be reproduced.
- **Fixes in this run:** none (baseline only).
- **Result:** ✅ PASS — the implemented happy path is stable end-to-end; future
  work is extending coverage to the paths above and fixing the known P0s.
