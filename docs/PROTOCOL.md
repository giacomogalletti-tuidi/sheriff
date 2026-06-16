# WebSocket Protocol Reference

All client↔server communication is **JSON text frames over a single WebSocket**.
Endpoint: `ws://<host>:8080/ws` (or `wss://` behind TLS).

Every message is a JSON object with a `type` field. Unknown types are ignored.
This document is the contract between `sheriff_game` (client) and
`sheriff_server` (server). If you change a message shape, change **both sides**
and update this file.

- Client send logic: `sheriff_game/lib/services/game_controller.dart`
- Client receive logic: `sheriff_game/lib/services/game_controller.dart` (`_handleMessage`)
- Server dispatch: `sheriff_server/bin/server.dart` (`_handleWebSocket`, `_handleInGame`)

---

## Connection lifecycle

- The client opens the socket and computes the URL from the page origin
  (`localhost` → port 8080; otherwise the page's scheme/host/port). See
  `lobby_screen.dart` `_getWebSocketUrl()`.
- **Keepalive:** the client sends `{"type":"ping"}` every **10s**; the server
  replies `{"type":"pong"}`. Both are filtered out before reaching app logic.
- **Auto-reconnect:** if the socket drops, the client emits a synthetic
  `connection_closed` to its own UI, retries with **exponential backoff** (2s base,
  max 60s, up to 30 attempts), and on success emits a synthetic
  `connection_restored` and re-sends a `reconnect` message.
- **Identity:** each player receives a random **`token`** on create/join. Reconnecting
  requires matching `name`, `roomId`, and `token` (names are display-only).

---

## Client → Server messages

| `type`          | Fields                                                                 | When / effect |
|-----------------|-----------------------------------------------------------------------|---------------|
| `ping`          | —                                                                     | Keepalive; server replies `pong`. |
| `create`        | `name: string`                                                        | Create a new room; sender becomes player 1. Server replies with `token`. |
| `join`          | `name: string`, `roomId: string`, `token?: string`                    | Join a lobby (unique name, 1–20 chars). Mid-game reconnect requires matching `token`. |
| `reconnect`     | `name: string`, `roomId: string`, `token: string`                     | Re-attach an existing player to a new socket. |
| `ready`         | —                                                                     | Mark self ready in lobby. |
| `unready`       | —                                                                     | Cancel ready (also cancels countdown). |
| `market_action` | `discards: string[]`, `drawSources: string[]` (`"discard1"`/`"discard2"`/`"deck"`), `discardTarget: string` (`"discard1"`/`"discard2"`) | Submit market exchange. |
| `load_bag`      | `cards: string[]` (1–5)                                               | Seal the bag. |
| `declare`       | `declaredType: string` (legal good), `declaredCount: int`            | Declare bag (count must equal real bag size). |
| `inspect`       | `target: string` (merchant name)                                     | Sheriff inspects a merchant's bag. |
| `pass`          | `target: string`                                                     | Sheriff passes a merchant's bag. |
| `bribe_offer`   | `goldAmount: int`, `goodsFromStand: string[]`                        | Merchant offers a bribe to the Sheriff. |
| `bribe_response`| `target: string`, `accepted: bool`                                  | Sheriff accepts/refuses a merchant's bribe. |
| `chat`          | `text: string`                                                      | Free-text negotiation (inspection phase only). |

Server-side guards (selected):
- Phase checks: every in-game handler ignores messages sent in the wrong phase.
- Role checks: merchants can't `inspect`/`pass`/`bribe_response`; the Sheriff
  can't `market_action`/`load_bag`/`declare`/`bribe_offer`.
- Idempotency: a player can't act twice in the same phase (tracked by
  `marketDone`, `bagLoaded`, `declared`, `inspectionDecisions`).

---

## Server → Client messages

| `type`               | Key fields | Meaning |
|----------------------|-----------|---------|
| `pong`               | —         | Keepalive reply (filtered by client). |
| `room_created`       | `roomId`, `token` | Room created; you are in the lobby. |
| `room_joined`        | `roomId`, `token` | You joined a lobby. |
| `error`              | `message` | Generic error (room not found, full, in progress…). |
| `lobby_state`        | `players: string[]`, `ready: string[]`, `phase` | Lobby roster snapshot. |
| `countdown`          | `value: int` | Pre-game countdown tick (5→1). |
| `game_state`         | *(see below)* | **Per-player** state snapshot for the current phase. |
| `bag_loaded`         | `bag: string[]`, `hand: string[]` | Confirmation to the merchant who sealed (only place `myBag` is set). |
| `player_loaded_bag`  | `player`, `bagLoaded: string[]` | Broadcast progress of bag loading. |
| `player_declared`    | `player`, `declaredType`, `declaredCount`, `declared: string[]` | A merchant declared. |
| `chat_message`       | `from`, `text`, `timestamp` | A negotiation message. |
| `bribe_offered`      | `fromPlayer`, `goldAmount`, `goodsFromStand` | A bribe was offered (visible to all). |
| `bribe_resolved`     | `target`, `accepted` | A bribe was accepted/refused. |
| `inspection_result`  | `player`, `inspected`, `wasHonest`, `declaredType`, `declaredCount`, `actualCards`, `penaltyPaid`, `paidBy`, `cardsToStand`, `confiscated?` | Outcome of one merchant's resolution. |
| `round_summary`      | `round`, `gold`, `merchantStands` | End-of-round snapshot. |
| `game_over`          | `scores: ScoreBreakdown[]` | Final standings (sorted desc). |
| `player_disconnected`| `player`, `message` | A player dropped; grace period started. |
| `player_reconnected` | `player`  | A player came back. |
| `stand_update`       | `myStand: string[]` | Your merchant stand changed (after customs resolution). |

Client-only synthetic messages (never sent by the server, injected by
`websocket_service.dart`): `connection_closed`, `connection_restored`.

### `game_state` payload (per-player, phase-dependent)

Built by `Room.buildGameStateFor(player)`. Always includes:

```jsonc
{
  "type": "game_state",
  "phase": "market",            // current GamePhase name
  "round": 1,
  "sheriff": "Alice",
  "players": ["Alice","Bob","Cara"],
  "gold": { "Alice": 50, "Bob": 50, "Cara": 50 },
  "myGold": 50,
  "myName": "Bob",
  "isSheriff": false,
  "merchantStands": { /* per player: only LEGAL goods are revealed */ },
  "merchantStandCounts": { /* per player: total stand size incl. contraband */ },
  "discardPile1Top": "apple",   // or null
  "discardPile2Top": "cheese",  // or null
  "deckCount": 188,
  "myStand": ["apple", "cheese", "pepper"],   // full own stand (incl. contraband); always present
  "phaseDeadlineMs": 1710000000000            // epoch ms when current phase auto-advances; omitted if no timer
}
```

Phase timeouts (server auto-advances if players are slow): market **60s**, load bag **45s**,
declaration **30s**, inspection **90s**. The client shows a live countdown from
`phaseDeadlineMs` in the top bar.

- **market / loadBag:** `hand`, `marketDone`
- **loadBag:** `bagLoaded`
- **declaration / inspection:** `declarations`, `declared`; merchants also get `hand` and **`myBag`** (own sealed bag, for reconnect)
- **inspection:** `inspectionDecisions`, `chatMessages`, `pendingBribes`; the Sheriff also gets `hand`

> **Hidden information is preserved:** only **legal** goods on a stand are sent to
> other players (`merchantStands`), while the true total is sent as a count
> (`merchantStandCounts`). Other players' bags are never revealed until resolution.
> Each merchant receives their own **`myBag`** in `game_state` during
> declaration/inspection (including after reconnect).
