# Architecture

## Overview

Two independent Dart projects in one folder (no root workspace, no git yet):

```
sheriff/
├── sheriff_game/      # Flutter client (mobile / desktop / web)
└── sheriff_server/    # Pure-Dart authoritative WebSocket server
```

The model is **authoritative server, thin client**:

- The **server** owns all game state and rules. It validates every action,
  advances phases, and pushes per-player state snapshots.
- The **client** renders whatever the server sends and forwards user intents.
  It holds no authoritative rules (it has a *copy* of card data for display).

```
┌────────────────────┐        JSON over WebSocket        ┌────────────────────┐
│   sheriff_game      │  ───────  ws://host:8080/ws  ───▶ │   sheriff_server    │
│   (Flutter)         │ ◀───────  game_state, ...   ───── │   (dart:io)         │
│                     │                                   │                     │
│ WebSocketService    │                                   │ HttpServer + WS     │
│   ↓ stream          │                                   │   ↓                 │
│ GameController      │                                   │ Room (per game)     │
│   (ChangeNotifier)  │                                   │   - phase machine   │
│   ↓ notify          │                                   │   - deck / hands    │
│ Screens / Widgets   │                                   │   - timers          │
└────────────────────┘                                   └────────────────────┘
```

In production the **server also serves the built Flutter web app** as static
files, so a single process can host everything (see Deployment).

---

## Server (`sheriff_server`)

Single file: **`bin/server.dart`** (~1250 lines, no runtime dependencies).

### Key types

- **`GamePhase`** enum: `lobby, market, loadBag, declaration, inspection,
  endOfRound, gameOver`.
- **`Room`** — all state for one game: players, sockets, deck, discard piles,
  hands, bags, declarations, stands, gold, chat, pending bribes, and the phase
  machine. One `Room` per game; created on `create`.
- Global maps: `rooms` (id → Room), `clientRoomMap` / `clientNameMap`
  (socket → room id / player name).

### Phase machine

`Room.enterPhase(phase)` is the hub:
1. sets `phase`, cancels any phase timer,
2. broadcasts a per-player `game_state`,
3. runs phase entry logic and starts a **phase timeout** (auto-advance).

Player actions (`handleMarketAction`, `handleLoadBag`, `handleDeclaration`,
`handleInspect`, `handlePass`, `handleBribe*`) mutate state and, when all
merchants are done, call `enterPhase(next)`. See [GAME_RULES.md](GAME_RULES.md)
for the per-phase logic and [PROTOCOL.md](PROTOCOL.md) for message shapes.

### Player ↔ socket mapping

`Room.clients` and `Room.playerNames` are **parallel lists** kept aligned by
index; `socketFor(name)` does `clients[playerNames.indexOf(name)]`. Players are
keyed everywhere by **name** (no stable id). This is simple but fragile — see
the identity items in [IMPROVEMENTS.md](IMPROVEMENTS.md).

### Disconnect / reconnect

- Drop in **lobby** → player removed from roster; empty room is deleted.
- Drop **in game** → player added to `disconnectedPlayers`, a 60s timer starts,
  others are notified. Reconnect (same name+room) re-binds the socket and
  re-sends that player's `game_state`. If fewer than 2 players remain active
  when the timer fires, the game ends.

### Timers (all `dart:async` `Timer`)

- Pre-game **countdown**: 5s.
- **Phase timeouts**: market 60s / loadBag 45s / declaration 30s / inspection 90s.
- **Disconnect grace**: 60s per player.

---

## Client (`sheriff_game`)

Standard Flutter app. State management is **`provider`** with a single
`ChangeNotifier`.

### Layers

```
lib/
├── main.dart                     # App root, theme, lobby↔game switch
├── models/                       # Plain data: card.dart, game_state.dart, player.dart
├── services/
│   ├── websocket_service.dart    # Raw socket, keepalive, auto-reconnect, JSON stream
│   └── game_controller.dart      # ChangeNotifier: receives messages → state → notify
├── screens/                      # One widget per phase + lobby + end game
│   ├── lobby_screen.dart
│   ├── game_screen.dart          # Phase router (picks the screen for the current phase)
│   ├── market_screen.dart
│   ├── load_bag_screen.dart
│   ├── declaration_screen.dart
│   ├── inspection_screen.dart
│   └── end_game_screen.dart
└── widgets/                      # Reusable UI: good_card, merchant_stand, game_top_bar, player_list
```

### Data flow

1. `WebSocketService` connects, filters `pong`, and exposes a broadcast
   `Stream<Map<String,dynamic>>` of decoded messages. It also injects synthetic
   `connection_closed` / `connection_restored` events and auto-reconnects.
2. `GameController` (a `ChangeNotifier`) subscribes to that stream. `_handleMessage`
   updates its many public fields (phase, hand, gold, declarations, …) and calls
   `notifyListeners()`.
3. `main.dart` provides the controller via `ChangeNotifierProvider.value`.
   `AppRoot` listens and switches between `LobbyScreen` and `GameScreen`.
4. `GameScreen` is a `Consumer<GameController>` that routes to the right phase
   screen. Screens read state with `context.watch<GameController>()` and call
   controller methods (`submitMarketAction`, `submitLoadBag`, …) which send
   messages back through `WebSocketService`.

### Notable client conventions

- Cards are referenced as **string names** (`"apple"`) end-to-end. The rich
  `GameCard`/`CardCatalog` types in `models/card.dart` are mostly used for
  display/lookups; the wire format is plain strings.
- Each phase screen tracks a local `_submitted`/selection state and shows a
  "waiting for others" view once the player has acted (also driven by server
  `*Done`/`*Loaded`/`declared` sets).
- Returning to lobby (`AppRoot.returnToLobby`) **disposes and recreates** the
  `WebSocketService` + `GameController` for a clean slate.

---

## Deployment model

The server serves the Flutter **web** build statically (see `_findWebBuildDir`
and `_serveStaticFile` in `server.dart`). Single-host flow:

```
cd sheriff_game && flutter build web      # produces build/web
cd ../sheriff_server && dart run bin/server.dart
# open http://<host>:8080  → app + ws on the same origin/port
```

The client derives its WebSocket URL from the page origin, so when served this
way it "just works" (same host/port, `/ws` path). For native builds (Android /
iOS / desktop) the URL falls back to `ws://localhost:8080/ws` unless the origin
provides one — see `_getWebSocketUrl()` and the hardcoded-URL item in
[IMPROVEMENTS.md](IMPROVEMENTS.md).

There is **no TLS, no persistence, and no horizontal scaling** today: all state
is in-process memory. A server restart drops every game. For online playtesting
see **[DEPLOYMENT.md](DEPLOYMENT.md)** (Docker + Render/Fly.io). Further hardening
is in [IMPROVEMENTS.md](IMPROVEMENTS.md).
