# Game Rules — as implemented

This is a digital adaptation of the board game **Sheriff of Nottingham**. This
document describes the rules **exactly as the server implements them**, including
house rules and deviations from the official tabletop game. When in doubt, the
server (`sheriff_server/bin/server.dart`) is the source of truth.

> ⚠️ Card stats and bonuses are currently **duplicated** in three places
> (`sheriff_server/bin/server.dart`, `sheriff_game/lib/models/card.dart`,
> `sheriff_game/lib/widgets/good_card.dart`). Keep them in sync. See
> [IMPROVEMENTS.md](IMPROVEMENTS.md).

## Players

- **3 to 5 players.** Minimum 3 to start, maximum 5 to join a room.
- Each player starts with **50 gold**.
- Players are identified by their **display name** (a string). There is no
  account system or stable ID. See [PROTOCOL.md](PROTOCOL.md) and
  [IMPROVEMENTS.md](IMPROVEMENTS.md) for the implications.

## The deck (204 cards)

| Good      | Type        | Value | Penalty | Count |
|-----------|-------------|------:|--------:|------:|
| apple     | legal       |     2 |       2 |    48 |
| cheese    | legal       |     3 |       2 |    36 |
| bread     | legal       |     3 |       2 |    36 |
| chicken   | legal       |     4 |       2 |    24 |
| pepper    | contraband  |     6 |       4 |    22 |
| silk      | contraband  |     5 |       4 |    21 |
| crossbow  | contraband  |     9 |       4 |    12 |
| mead      | contraband  |     7 |       4 |     5 |

- **Legal goods** are the only types you may legally *declare*.
- **Contraband** is worth more but can never be declared honestly — smuggling it
  past the Sheriff is the whole point.
- **Value** counts toward your final score (goods on your stand).
- **Penalty** is what gets paid when a bag is inspected (see Inspection).

There are two face-up **discard piles** (`discardPile1`, `discardPile2`), each
seeded with 5 cards at game start.

## Game structure

A game is a sequence of **rounds**. Each round one player is the **Sheriff** and
the others are **merchants**. The Sheriff role rotates each round.

The game ends when **every player has been Sheriff the required number of times**:

| Player count | Times each player is Sheriff | Total rounds |
|--------------|------------------------------|--------------|
| 3            | 3                            | 9            |
| 4            | 2                            | 8            |
| 5            | 2                            | 10           |

### Round phases

```
lobby → market → loadBag → declaration → inspection → endOfRound
                    ↑__________________________________________|
                         (next round, Sheriff rotates)
                                      ↓
                                  gameOver
```

Each in-round phase has a **server-side timeout** that auto-advances the game if
players are slow or disconnected (see table below). The Sheriff does not act in
market / loadBag / declaration (they wait).

| Phase        | Who acts   | Timeout | Auto-action on timeout                                  |
|--------------|------------|--------:|--------------------------------------------------------|
| market       | merchants  |     60s | Mark remaining merchants done (keep current hand)      |
| loadBag      | merchants  |     45s | Force a 1-card bag from the first hand card            |
| declaration  | merchants  |     30s | Auto-declare `apple` × (bag size)                      |
| inspection   | sheriff    |     90s | Auto-`pass` every merchant not yet resolved            |

## Phase details

### 1. Market

Each merchant simultaneously refreshes their hand of **6 cards**:

1. Optionally discard **0–5** cards from hand.
2. For each discarded card, draw a replacement from a chosen source: discard
   pile 1, discard pile 2, or the face-down draw pile.
3. Discarded cards are placed on top of a chosen discard pile (pile 1 or 2).
4. Hand is topped back up to 6 from the draw pile if needed.

> The official "draw 2, discard down" flow is simplified here to a
> "discard N, draw N" exchange. The client UI enforces *draws ≤ discards*; the
> **server does not validate this** (see [IMPROVEMENTS.md](IMPROVEMENTS.md)).

### 2. Load bag

Each merchant secretly seals **1–5 cards** from their hand into their bag. Once
sealed it cannot be changed. Remaining cards stay in hand for next round.

### 3. Declaration

Each merchant publicly declares their bag to the Sheriff:

- **Count must be truthful** — you must declare the real number of cards in the
  bag (server enforces `declaredCount == bag.length`).
- **Type may be a lie** — you may only declare a **legal** type
  (apple/cheese/bread/chicken), even if the bag is full of contraband.

### 4. Inspection

The Sheriff reviews each merchant one at a time and chooses to **inspect** or
**pass** the bag. Merchants may **chat** (free-text negotiation) and offer
**bribes** to influence the decision.

Resolution per merchant:

- **Passed (not inspected):** all cards in the bag — *including contraband* —
  go onto the merchant's stand. No gold changes hands.
- **Inspected & honest** (every card matches the declared type): the **Sheriff
  pays the merchant** the total penalty of the bag's cards; all cards go to the
  merchant's stand.
- **Inspected & lying** (any card differs from the declared type): cards
  matching the declaration go to the stand; all others are **confiscated**
  (discarded), and the **merchant pays the Sheriff** the total penalty of the
  confiscated cards.

#### Bribes

- A merchant may offer the Sheriff **gold** and/or **goods from their stand**.
  (The goods-from-stand path exists in the server but has **no client UI** yet.)
- The Sheriff accepts or refuses. Accepting transfers the bribe and **passes**
  that merchant's bag (no inspection).
- Gold offered is clamped to what the merchant actually has at accept time.

#### Paying when short on gold (house rule)

If a player owes more gold than they have, their gold goes to 0 and the
shortfall is covered by **liquidating goods from their stand** (legal first,
then contraband) at face value, discarding those cards. This is a house rule;
the official game caps payment at available gold.

### 5. End of round

A round summary is broadcast. After a short delay the game either starts the
next round (Sheriff rotates) or proceeds to game over.

## Scoring (game over)

Each player's final score is:

```
totalScore = goodsValue + gold + kingBonuses + queenBonuses
```

- **goodsValue** — sum of the *value* of every card on the player's stand
  (legal *and* contraband).
- **gold** — remaining gold.
- **King bonus** — awarded to the player with the **most** of a given legal good:

  | Good    | King | Queen |
  |---------|-----:|------:|
  | apple   |   20 |    10 |
  | cheese  |   15 |    10 |
  | bread   |   15 |    10 |
  | chicken |   10 |     5 |

- **Queen bonus** — awarded to the player with the **second most** of that good.
- **Ties for King:** the tied players split `(king + queen) / n` (integer
  division) and **no Queen** is awarded for that good.
- **Ties for Queen:** the tied players split `queen / n` (integer division).
- A good with zero copies anywhere awards nothing.

Highest total wins. Final standings are sorted descending by total score.
