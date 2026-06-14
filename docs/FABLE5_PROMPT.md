# Fable 5 prompt (portable AI onboarding)

This file gives you a **ready-to-paste prompt** to bootstrap Fable 5 — or any
other AI — to work on this project without re-explaining it every time.

There are two variants:

- **Variant A** — for AI tools that can read the repo (Claude Code, Cursor, an
  IDE agent, Fable with file access). Short: it points at `AGENTS.md`/`docs/`.
- **Variant B** — for chat-only AIs with **no** file access (paste into a web
  chat). It embeds a condensed-but-complete context inline.

After the prompt, append your actual task where it says **`<YOUR TASK>`**.

Keep this prompt in sync when the architecture changes (or just regenerate it
from `AGENTS.md` + `docs/`).

---

## Variant A — AI with repository access

```text
You are a senior Dart/Flutter engineer working on "Sheriff" — a real-time
multiplayer adaptation of the board game Sheriff of Nottingham. The repo has two
Dart projects: sheriff_game/ (Flutter client) and sheriff_server/ (authoritative
pure-Dart WebSocket server).

Before doing anything, read these files and treat them as ground truth:
- AGENTS.md                   (overview, project map, how to run, key facts)
- docs/AUTONOMOUS_WORKFLOW.md  (how to run/debug/verify on your own — your operating loop)
- docs/ARCHITECTURE.md        (components, data flow, phase machine, deployment)
- docs/PROTOCOL.md            (WebSocket message contract, client <-> server)
- docs/GAME_RULES.md          (rules as implemented, constants, scoring)
- docs/IMPROVEMENTS.md        (prioritized bugs / refactors / features)

Working agreement:
- The server is authoritative. Put validation and game rules on the server; keep
  the client thin (it renders game_state and sends intents).
- Cards are plain strings on the wire ("apple", "crossbow").
- Card stats are duplicated in sheriff_server/bin/server.dart,
  sheriff_game/lib/models/card.dart and sheriff_game/lib/widgets/good_card.dart —
  keep all three in sync.
- If you change a message shape, update the server, the client
  (sheriff_game/lib/services/game_controller.dart), AND docs/PROTOCOL.md.
- There is no git in this repo yet, so make careful, additive changes and explain
  anything destructive before doing it.
- When you fix a bug, add or update a test (sheriff_server/test or
  sheriff_game/test) and update the relevant docs/ file in the same change.

How to run / verify (work autonomously — run these yourself; all currently pass):
- Lint:    cd sheriff_server && dart analyze   ;   cd sheriff_game && flutter analyze
- Tests:   cd sheriff_server && dart test      ;   cd sheriff_game && flutter test
- E2E:     cd sheriff_server && dart run tool/smoke_test.dart   (starts the server,
           plays a full 3-bot game over WebSockets, exits 0 on success — this is
           how you verify the real-time multiplayer flow without a human)
- Server:  cd sheriff_server && dart run bin/server.dart   (run in the background; stop when done)
- Client:  cd sheriff_game && flutter run -d chrome   (or: flutter build web, then the server serves it)

Operate the loop autonomously: make a change → analyze → test → run the e2e
simulator → read the server transcript ([ROOM …] enterPhase lines) → iterate.
To debug a multiplayer scenario, edit tool/smoke_test.dart (add bots, lie,
bribe, disconnect/reconnect) to reproduce it. Don't claim done until analyze +
tests + the simulator all pass. See docs/AUTONOMOUS_WORKFLOW.md for the full
procedure, definition of done, and guardrails.

First, briefly confirm your understanding of the architecture and the relevant
files, propose a short plan, then implement it. Ask before large refactors.

YOUR TASK:
<YOUR TASK>
```

---

## Variant B — chat-only AI (no file access)

```text
You are a senior Dart/Flutter engineer. We are working on "Sheriff", a real-time
multiplayer adaptation of the board game Sheriff of Nottingham (a bluffing /
smuggling card game for 3–5 players). I will paste code as needed. Use the
context below as ground truth; ask for a specific file if you need its contents.

== PROJECT SHAPE ==
Two Dart projects in one folder (no root workspace, no git yet):
- sheriff_game/    Flutter client. Dart ^3.6.0. Deps: provider, web_socket_channel,
                   uuid (unused), json_annotation (codegen NOT used — manual JSON).
- sheriff_server/  Pure-Dart server (dart:io), no runtime deps. One file:
                   bin/server.dart (~1250 lines). Also serves the Flutter web build.

Model: AUTHORITATIVE SERVER, THIN CLIENT. The server owns all state and rules and
pushes per-player JSON snapshots over a single WebSocket (ws://host:8080/ws). The
client renders them and sends user intents. Cards are plain strings on the wire
(e.g. "apple", "crossbow").

== CLIENT FILE MAP (sheriff_game/lib) ==
- main.dart                       app root, theme, lobby<->game switch (provider)
- models/card.dart                GameCard + CardCatalog (display/lookup data)
- models/game_state.dart          GamePhase enum + Declaration/BribeOffer/etc.
- models/player.dart              Player data model
- services/websocket_service.dart raw socket: keepalive (10s ping), auto-reconnect
                                  (2s), decoded JSON broadcast stream
- services/game_controller.dart   ChangeNotifier: _handleMessage updates state ->
                                  notifyListeners; exposes action methods (send)
- screens/                        lobby, game (phase router), market, load_bag,
                                  declaration, inspection, end_game
- widgets/                        good_card, merchant_stand, game_top_bar, player_list

== SERVER (sheriff_server/bin/server.dart) ==
- GamePhase enum: lobby, market, loadBag, declaration, inspection, endOfRound, gameOver
- class Room: all state for one game (players, sockets, deck, discard piles, hands,
  bags, declarations, stands, gold, chat, pendingBribes) + the phase machine.
- enterPhase(phase): sets phase, broadcasts per-player game_state, runs entry logic,
  starts a phase timeout that auto-advances.
- Players are keyed by NAME (no stable id/auth). Room.clients and Room.playerNames
  are parallel index-aligned lists; socketFor(name) = clients[playerNames.indexOf(name)].
- Global maps: rooms (id->Room), clientRoomMap, clientNameMap.

== PROTOCOL (JSON, type field) ==
Client->server: ping, create{name}, join{name,roomId}, reconnect{name,roomId},
  ready/unready, market_action{discards[],drawSources[],discardTarget},
  load_bag{cards[]}, declare{declaredType,declaredCount}, inspect{target},
  pass{target}, bribe_offer{goldAmount,goodsFromStand[]},
  bribe_response{target,accepted}, chat{text}.
Server->client: pong, room_created{roomId}, room_joined{roomId}, error{message},
  lobby_state{players[],ready[],phase}, countdown{value}, game_state{...},
  bag_loaded{bag[],hand[]}, player_loaded_bag, player_declared, chat_message,
  bribe_offered, bribe_resolved, inspection_result{...}, round_summary, game_over{scores[]},
  player_disconnected, player_reconnected.
game_state is per-player and phase-dependent; it reveals only LEGAL goods on other
players' stands (plus a total count), never bags. Note: game_state does NOT include
the recipient's own bag (a known reconnect bug).

== RULES AS IMPLEMENTED ==
3–5 players, start 50 gold, hand size 6, bag 1–5 cards, deck 204 cards.
Sheriff rotates each round; game ends when everyone has been Sheriff
(3 times with 3 players, 2 times with 4–5). Phase timeouts: market 60s, loadBag 45s,
declaration 30s, inspection 90s. Disconnect grace 60s.
Cards (value/penalty/type, deck count):
  apple 2/2 legal x48, cheese 3/2 legal x36, bread 3/2 legal x36, chicken 4/2 legal x24,
  pepper 6/4 contraband x22, silk 5/4 contraband x21, crossbow 9/4 contraband x12,
  mead 7/4 contraband x5.
Declaration: count must be truthful; type may be a lie but must be a LEGAL good.
Inspection: pass -> all cards (incl. contraband) go to stand, no gold moves.
  inspected & honest -> sheriff pays merchant total penalty, all to stand.
  inspected & lying -> matching cards to stand, rest confiscated (discarded),
  merchant pays sheriff penalty of confiscated. Bribes = gold and/or stand goods
  (goods path has no client UI yet); accepting passes the bag.
Scoring: total = stand goods value + gold + King bonus (most of a legal good) +
  Queen bonus (2nd most). King/Queen: apple 20/10, cheese 15/10, bread 15/10,
  chicken 10/5. Ties for King split (king+queen)/n and award no Queen; ties for
  Queen split queen/n.

== KNOWN ISSUES (top ones) ==
- Reconnecting mid-game loses your bag (game_state omits own bag).
- market_action isn't validated server-side (hand can exceed 6; cheating vector).
- Duplicate player names collide (state keyed by name; no uniqueness check).
- Name-only identity allows seat hijack (no token/auth).
- Card stats duplicated in 3 files (drift risk).
- Finished rooms leak in memory; in-memory only (restart drops games); no TLS; no git.

== HOW TO VERIFY (if you have shell access; otherwise tell me to run these) ==
- Lint:  (cd sheriff_server && dart analyze) ; (cd sheriff_game && flutter analyze)
- Test:  (cd sheriff_server && dart test)    ; (cd sheriff_game && flutter test)
- E2E:   cd sheriff_server && dart run tool/smoke_test.dart   # headless 3-bot full game,
         starts the server itself, exits 0 on success; the server prints
         "[ROOM ..] enterPhase .." traces you can read to see where a game stalls.
- Debug a multiplayer scenario by editing tool/smoke_test.dart (add bots, make a
  bot lie/bribe/disconnect) to reproduce it. Don't claim done until lint + tests
  + the simulator pass.

== WORKING AGREEMENT ==
- Put validation and rules on the SERVER; keep the client thin.
- If you change a message shape, change server + game_controller.dart + the protocol notes.
- Keep the 3 card-data sources in sync.
- Prefer small, additive changes (no git safety net). Add/adjust a test when you
  fix a bug. Explain anything destructive before doing it.

First, confirm your understanding and propose a short plan. Then implement.

YOUR TASK:
<YOUR TASK>
```

---

## Ready-made task — full multiplayer playtest & stabilization

Paste this in place of `<YOUR TASK>` (assumes Variant A / repo access). It is
tuned to the current repo: it builds on the existing headless simulator
(`sheriff_server/tool/smoke_test.dart`) and the loop in
[AUTONOMOUS_WORKFLOW.md](AUTONOMOUS_WORKFLOW.md), points the bug hunt at the known
issues in [IMPROVEMENTS.md](IMPROVEMENTS.md), and logs runs to
[PLAYTEST_REPORT.md](PLAYTEST_REPORT.md).

```text
Task: Full multiplayer playtest, bug reporting, and iterative stabilization.

Goal: verify that Sheriff can run a COMPLETE multiplayer game correctly,
consistently with the implemented rules, and without crashes, deadlocks, invalid
states, or protocol mismatches.

1. Read first (ground truth):
   - AGENTS.md
   - docs/AUTONOMOUS_WORKFLOW.md   (your run/debug/verify loop + the simulator)
   - docs/ARCHITECTURE.md
   - docs/PROTOCOL.md
   - docs/GAME_RULES.md
   - docs/IMPROVEMENTS.md          (start the bug hunt from the P0/P1 list)
   - docs/PLAYTEST_REPORT.md       (previous runs / baseline to append to)

2. Summarize the architecture and identify the files most relevant to:
   - server rules & validation: sheriff_server/bin/server.dart
   - protocol messages: server.dart + sheriff_game/lib/services/game_controller.dart
     (contract in docs/PROTOCOL.md)
   - client game-state rendering & intents: sheriff_game/lib/services + lib/screens
   - multiplayer coverage: sheriff_server/test/game_logic_test.dart and the
     simulator sheriff_server/tool/smoke_test.dart

3. Establish a GREEN BASELINE, recording results:
   - cd sheriff_server && dart pub get && dart test && dart analyze
   - cd sheriff_game   && flutter pub get && flutter test && flutter analyze
   - cd sheriff_server && dart run tool/smoke_test.dart   (must reach game_over, exit 0)
   If anything is already red, fix or document it before continuing.

4. Run a realistic multiplayer simulation against the authoritative server.
   A headless simulator already exists (sheriff_server/tool/smoke_test.dart: 3 bots,
   full game). EXTEND it rather than starting from scratch — it is far more
   reproducible than a manual UI playthrough. Add coverage incrementally.
   Optional visual check: flutter build web, run the server (it serves the web app
   on :8080), and confirm the UI stays consistent with the server game_state.

5. Cover, as much as the implementation allows:
   - join room; game start; dealing / hand state
   - market selection (discard/draw)
   - bag loading + declaration (honest AND lying)
   - sheriff inspect vs pass; bribes (gold and goods)
   - legal vs contraband resolution; coins / penalties / rewards
   - sheriff rotation; phase transitions; end-game; final scoring
   - 3, 4 AND 5 players (sheriff rounds: 3x for 3 players, 2x for 4-5)

6. Actively hunt for:
   - crashes / uncaught exceptions; protocol mismatches; invalid phase transitions
   - duplicated/missing cards (deck regeneration on exhaustion is a known risk)
   - illegal actions accepted by the server (e.g. market drawSources > discards ->
     hand > 6; duplicate player names -- both known P0/P1)
   - legal actions wrongly rejected
   - inconsistent coins/penalties/rewards/scoring (incl. King/Queen tie splits)
   - client diverging from server state (e.g. bag lost on reconnect -- known P0)
   - freezes / deadlocks / impossible-to-continue states
   - rule inconsistencies vs docs/GAME_RULES.md

7. For any anomaly/bug/incomplete rule:
   - track it in docs/IMPROVEMENTS.md (prioritized), and
   - append a run entry to docs/PLAYTEST_REPORT.md with: date/time, #players,
     commands used, expected vs actual, repro steps, suspected cause, fix status.

8. Fix each confirmed bug with the SMALLEST SAFE change. Server stays
   authoritative (validation/rules on the server); client stays thin. No git in
   the repo yet -> prefer additive changes. Ask before large refactors.

9. For every fix:
   - add/update a test (prefer a Room-level unit test for rules; extend
     tool/smoke_test.dart for flow/protocol coverage)
   - update docs/PROTOCOL.md if a message shape changes
   - update docs/GAME_RULES.md if rule behavior changes or is clarified
   - update docs/IMPROVEMENTS.md (mark fixed / reprioritize)
   - keep card stats in sync across server.dart, models/card.dart, widgets/good_card.dart

10. After each fix rerun: server tests, client tests, server+client analyze, and
    the simulator (tool/smoke_test.dart).

11. Iterate until the simulator completes a whole game with no blocking
    bug/crash/deadlock/invalid state, and tests + analyze pass (or any remaining
    failure is documented with a clear reason).

12. Final report: playtest summary; #players simulated; scenarios covered; bugs
    found; bugs fixed; tests added/updated; docs updated; remaining known
    limitations; exact commands used to verify.

Begin by reading the files and establishing the baseline, then propose a short
plan before changing anything.
```

---

## Tips

- The **ready-made task** above is the recommended default for a stabilization
  pass — paste it into `<YOUR TASK>` in Variant A.
- For a narrower job, replace `<YOUR TASK>` with something concrete, e.g.
  *"Fix the reconnect-loses-bag bug (P0 in docs/IMPROVEMENTS.md): include the
  player's own bag in game_state during declaration/inspection and read it on the
  client. Add a server test and extend tool/smoke_test.dart to reconnect a bot."*
- With file-aware tools, **Variant A** is enough — the docs carry the detail.
- Re-paste **Variant B** whenever you start a fresh chat-only session; it's
  self-contained.
- If you change the architecture or protocol, update `AGENTS.md` and `docs/` and
  regenerate Variant B from them so the embedded context never goes stale.
