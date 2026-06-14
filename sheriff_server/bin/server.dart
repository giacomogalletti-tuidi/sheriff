import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:sheriff_shared/card_data.dart';
import 'package:uuid/uuid.dart';

export 'package:sheriff_shared/card_data.dart';

// ---------------------------------------------------------------------------
// Input limits
// ---------------------------------------------------------------------------

const maxNameLength = 20;
const maxChatLength = 500;
const _chatRateLimitCount = 5;
const _chatRateLimitWindow = Duration(seconds: 10);
const _roomFinishedTtl = Duration(hours: 1);

const _uuid = Uuid();

String? normalizePlayerName(String? raw, {Iterable<String>? existingNames}) {
  if (raw == null) return null;
  final name = raw.trim();
  if (name.isEmpty || name.length > maxNameLength) return null;
  if (existingNames != null) {
    final lower = name.toLowerCase();
    for (final existing in existingNames) {
      if (existing.toLowerCase() == lower) return null;
    }
  }
  return name;
}

String issuePlayerToken() => _uuid.v4();

// ---------------------------------------------------------------------------
// Game phase
// ---------------------------------------------------------------------------

enum GamePhase { lobby, market, loadBag, declaration, inspection, endOfRound, gameOver }

// ---------------------------------------------------------------------------
// Room (all game state)
// ---------------------------------------------------------------------------

class Room {
  final String id;
  final List<WebSocket> clients = [];
  final List<String> playerNames = [];
  final Set<String> readyPlayers = {};

  GamePhase phase = GamePhase.lobby;
  int currentSheriffIndex = -1;
  Map<String, int> sheriffCount = {};
  int roundNumber = 0;

  Map<String, List<String>> hands = {};
  Map<String, List<String>> bags = {};
  Map<String, Map<String, dynamic>> declarations = {};
  Map<String, List<String>> merchantStands = {};
  Map<String, int> gold = {};
  Map<String, String> playerTokens = {};

  Set<String> marketDone = {};
  Set<String> bagLoaded = {};
  Set<String> declared = {};
  Map<String, String> inspectionDecisions = {};

  List<String> deck = [];
  List<String> discardPile1 = [];
  List<String> discardPile2 = [];

  List<Map<String, dynamic>> chatMessages = [];
  Map<String, Map<String, dynamic>> pendingBribes = {};

  Timer? countdownTimer;
  Timer? disconnectTimer;
  Timer? phaseTimer;
  Timer? _roomCleanupTimer;
  int countdown = 5;
  DateTime? finishedAt;

  final Map<String, List<DateTime>> _chatTimestamps = {};

  Room(this.id);

  void dispose() {
    countdownTimer?.cancel();
    phaseTimer?.cancel();
    disconnectTimer?.cancel();
    _roomCleanupTimer?.cancel();
    for (final t in _disconnectTimers.values) {
      t.cancel();
    }
    _disconnectTimers.clear();
  }

  // ---- Deck management ----

  void generateDeck() {
    deck.clear();
    deckComposition.forEach((name, count) {
      deck.addAll(List.filled(count, name));
    });
    deck.shuffle(Random());
  }

  void reshuffleDeckIfNeeded() {
    if (deck.length >= 10) return;
    final kept1 = discardPile1.length > 5 ? discardPile1.sublist(discardPile1.length - 5) : List<String>.from(discardPile1);
    final kept2 = discardPile2.length > 5 ? discardPile2.sublist(discardPile2.length - 5) : List<String>.from(discardPile2);

    final toShuffle = <String>[];
    if (discardPile1.length > 5) {
      toShuffle.addAll(discardPile1.sublist(0, discardPile1.length - 5));
    }
    if (discardPile2.length > 5) {
      toShuffle.addAll(discardPile2.sublist(0, discardPile2.length - 5));
    }

    toShuffle.shuffle(Random());
    deck.addAll(toShuffle);
    discardPile1 = kept1;
    discardPile2 = kept2;
  }

  String? drawCard() {
    reshuffleDeckIfNeeded();
    if (deck.isEmpty) return null;
    return deck.removeLast();
  }

  // ---- Player management ----

  String? get currentSheriff =>
      playerNames.isNotEmpty && currentSheriffIndex >= 0
          ? playerNames[currentSheriffIndex]
          : null;

  List<String> get merchants =>
      playerNames.where((p) => p != currentSheriff).toList();

  int get requiredSheriffRounds => playerNames.length == 3 ? 3 : 2;

  WebSocket? socketFor(String playerName) {
    final idx = playerNames.indexOf(playerName);
    return idx >= 0 && idx < clients.length ? clients[idx] : null;
  }

  void sendTo(String playerName, Map<String, dynamic> message) {
    final socket = socketFor(playerName);
    if (socket == null || disconnectedPlayers.contains(playerName)) return;
    try {
      socket.add(jsonEncode(message));
    } catch (e) {
      print('[ROOM $id] Error sending to $playerName: $e');
    }
  }

  void broadcast(Map<String, dynamic> message) {
    final msg = jsonEncode(message);
    final type = message['type'];
    for (var i = 0; i < clients.length; i++) {
      final name = i < playerNames.length ? playerNames[i] : '?';
      if (i < playerNames.length && disconnectedPlayers.contains(playerNames[i])) {
        continue;
      }
      try {
        clients[i].add(msg);
      } catch (e) {
        print('[ROOM $id] Error broadcasting $type to $name: $e');
      }
    }
  }

  final Set<String> disconnectedPlayers = {};
  final Map<String, Timer> _disconnectTimers = {};

  // ---- Lobby ----

  void addReady(String player) {
    readyPlayers.add(player);
    broadcastLobbyState();
    if (readyPlayers.length == playerNames.length && playerNames.length >= 3) {
      startCountdown();
    }
  }

  void removeReady(String player) {
    readyPlayers.remove(player);
    countdownTimer?.cancel();
    countdownTimer = null;
    broadcastLobbyState();
  }

  void broadcastLobbyState() {
    broadcast({
      'type': 'lobby_state',
      'players': playerNames,
      'ready': readyPlayers.toList(),
      'phase': phase.name,
    });
  }

  void startCountdown() {
    countdown = 5;
    broadcast({'type': 'countdown', 'value': countdown});

    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      countdown--;
      if (countdown > 0) {
        broadcast({'type': 'countdown', 'value': countdown});
      } else {
        timer.cancel();
        countdownTimer = null;
        readyPlayers.clear();
        startGame();
      }
    });
  }

  void startGame() {
    generateDeck();
    for (final p in playerNames) {
      gold[p] = 50;
      merchantStands[p] = [];
      sheriffCount[p] = 0;
      hands[p] = [];
    }

    discardPile1 = [];
    discardPile2 = [];
    for (var i = 0; i < 5; i++) {
      final c = drawCard();
      if (c != null) discardPile1.add(c);
    }
    for (var i = 0; i < 5; i++) {
      final c = drawCard();
      if (c != null) discardPile2.add(c);
    }

    dealInitialHands();
    startNewRound();
  }

  void dealInitialHands() {
    for (final p in playerNames) {
      final hand = <String>[];
      for (var i = 0; i < 6; i++) {
        final c = drawCard();
        if (c != null) hand.add(c);
      }
      hands[p] = hand;
    }
  }

  // ---- Round flow ----

  void startNewRound() {
    roundNumber++;
    currentSheriffIndex = (currentSheriffIndex + 1) % playerNames.length;
    sheriffCount[currentSheriff!] = (sheriffCount[currentSheriff!] ?? 0) + 1;

    bags.clear();
    declarations.clear();
    marketDone.clear();
    bagLoaded.clear();
    declared.clear();
    inspectionDecisions.clear();
    chatMessages.clear();
    pendingBribes.clear();

    enterPhase(GamePhase.market);
  }

  void enterPhase(GamePhase newPhase) {
    print('[ROOM $id] enterPhase: $newPhase (from $phase, disconnected=$disconnectedPlayers)');
    phase = newPhase;
    phaseTimer?.cancel();
    phaseTimer = null;

    broadcastGameState();

    switch (newPhase) {
      case GamePhase.market:
        sendHandsToMerchants();
        _startPhaseTimeout(const Duration(seconds: 60));
        break;
      case GamePhase.loadBag:
        _startPhaseTimeout(const Duration(seconds: 45));
        break;
      case GamePhase.declaration:
        _startPhaseTimeout(const Duration(seconds: 30));
        break;
      case GamePhase.inspection:
        _startPhaseTimeout(const Duration(seconds: 90));
        break;
      case GamePhase.endOfRound:
        processEndOfRound();
        break;
      case GamePhase.gameOver:
        finishedAt = DateTime.now();
        broadcastFinalScores();
        _roomCleanupTimer?.cancel();
        _roomCleanupTimer = Timer(_roomFinishedTtl, () {
          rooms.remove(id);
        });
        break;
      default:
        break;
    }
  }

  void broadcastGameState() {
    for (final p in playerNames) {
      sendTo(p, buildGameStateFor(p));
    }
  }

  Map<String, dynamic> buildGameStateFor(String player) {
    final isSheriff = player == currentSheriff;
    final state = <String, dynamic>{
      'type': 'game_state',
      'phase': phase.name,
      'round': roundNumber,
      'sheriff': currentSheriff,
      'players': playerNames,
      'gold': gold,
      'myGold': gold[player] ?? 0,
      'myName': player,
      'isSheriff': isSheriff,
      'merchantStands': {
        for (final p in playerNames)
          p: (merchantStands[p] ?? []).where((c) => isLegal(c)).toList(),
      },
      'merchantStandCounts': {
        for (final p in playerNames)
          p: (merchantStands[p] ?? []).length,
      },
      'discardPile1Top': discardPile1.isNotEmpty ? discardPile1.last : null,
      'discardPile2Top': discardPile2.isNotEmpty ? discardPile2.last : null,
      'deckCount': deck.length,
    };

    if (phase == GamePhase.market || phase == GamePhase.loadBag) {
      state['hand'] = hands[player] ?? [];
      state['marketDone'] = marketDone.toList();
    }

    if (phase == GamePhase.loadBag) {
      state['bagLoaded'] = bagLoaded.toList();
    }

    if (phase == GamePhase.declaration || phase == GamePhase.inspection) {
      state['declarations'] = declarations;
      state['declared'] = declared.toList();
      if (!isSheriff) {
        state['hand'] = hands[player] ?? [];
        final bag = bags[player];
        if (bag != null && bag.isNotEmpty) {
          state['myBag'] = bag;
        }
      }
    }

    if (phase == GamePhase.inspection) {
      state['inspectionDecisions'] = inspectionDecisions;
      state['chatMessages'] = chatMessages;
      state['pendingBribes'] = pendingBribes;
      if (isSheriff) {
        state['hand'] = hands[player] ?? [];
      }
    }

    return state;
  }

  // ---- Market Phase ----

  void handleMarketAction(String player, Map<String, dynamic> msg) {
    if (phase != GamePhase.market) return;
    if (player == currentSheriff) return;
    if (marketDone.contains(player)) return;

    final discards = List<String>.from(msg['discards'] ?? []);
    final drawSources = List<String>.from(msg['drawSources'] ?? []);

    if (drawSources.length != discards.length) return;

    final hand = List<String>.from(hands[player] ?? []);
    final handCopy = List<String>.from(hand);

    for (final card in discards) {
      if (!handCopy.remove(card)) return;
    }

    for (final source in drawSources) {
      String? drawn;
      if (source == 'discard1' && discardPile1.isNotEmpty) {
        drawn = discardPile1.removeLast();
      } else if (source == 'discard2' && discardPile2.isNotEmpty) {
        drawn = discardPile2.removeLast();
      } else if (source == 'deck') {
        drawn = drawCard();
      } else {
        return;
      }
      if (drawn != null) hand.add(drawn);
    }

    while (hand.length < 6) {
      final drawn = drawCard();
      if (drawn == null) break;
      hand.add(drawn);
    }

    if (hand.length > 6) {
      hand.removeRange(6, hand.length);
    }

    final targetPile = (msg['discardTarget'] ?? 'discard1') == 'discard2'
        ? discardPile2
        : discardPile1;
    targetPile.addAll(discards);

    hands[player] = hand;
    marketDone.add(player);

    broadcastGameState();

    if (marketDone.length >= merchants.length) {
      enterPhase(GamePhase.loadBag);
    }
  }

  void sendHandsToMerchants() {
    for (final p in merchants) {
      final hand = hands[p] ?? [];
      while (hand.length < 6) {
        final drawn = drawCard();
        if (drawn == null) break;
        hand.add(drawn);
      }
      hands[p] = hand;
    }
  }

  // ---- Load Bag Phase ----

  void handleLoadBag(String player, Map<String, dynamic> msg) {
    if (phase != GamePhase.loadBag) return;
    if (player == currentSheriff) return;
    if (bagLoaded.contains(player)) return;

    final selectedCards = List<String>.from(msg['cards'] ?? []);
    if (selectedCards.isEmpty || selectedCards.length > 5) return;

    final hand = hands[player] ?? [];
    final bag = <String>[];
    final handCopy = List<String>.from(hand);

    for (final card in selectedCards) {
      if (handCopy.remove(card)) {
        bag.add(card);
      }
    }

    if (bag.isEmpty) return;

    bags[player] = bag;
    hands[player] = handCopy;
    bagLoaded.add(player);

    sendTo(player, {
      'type': 'bag_loaded',
      'bag': bag,
      'hand': handCopy,
    });

    broadcast({
      'type': 'player_loaded_bag',
      'player': player,
      'bagLoaded': bagLoaded.toList(),
    });

    if (bagLoaded.length >= merchants.length) {
      enterPhase(GamePhase.declaration);
    }
  }

  // ---- Declaration Phase ----

  void handleDeclaration(String player, Map<String, dynamic> msg) {
    if (phase != GamePhase.declaration) return;
    if (player == currentSheriff) return;
    if (declared.contains(player)) return;

    final declaredType = msg['declaredType'] as String?;
    final declaredCount = msg['declaredCount'] as int?;

    if (declaredType == null || declaredCount == null) return;
    if (!legalTypes.contains(declaredType)) return;

    final bag = bags[player] ?? [];
    if (declaredCount != bag.length) return;

    declarations[player] = {
      'declaredType': declaredType,
      'declaredCount': declaredCount,
    };
    declared.add(player);

    broadcast({
      'type': 'player_declared',
      'player': player,
      'declaredType': declaredType,
      'declaredCount': declaredCount,
      'declared': declared.toList(),
    });

    if (declared.length >= merchants.length) {
      enterPhase(GamePhase.inspection);
    }
  }

  // ---- Inspection Phase ----

  void handleChat(String player, Map<String, dynamic> msg) {
    if (phase != GamePhase.inspection) return;
    final text = (msg['text'] as String? ?? '').trim();
    if (text.isEmpty || text.length > maxChatLength) return;
    if (!_checkChatRateLimit(player)) return;

    final chatMsg = {
      'from': player,
      'text': text,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    chatMessages.add(chatMsg);
    broadcast({'type': 'chat_message', ...chatMsg});
  }

  bool _checkChatRateLimit(String player) {
    final now = DateTime.now();
    final timestamps = _chatTimestamps.putIfAbsent(player, () => []);
    timestamps.removeWhere((t) => now.difference(t) > _chatRateLimitWindow);
    if (timestamps.length >= _chatRateLimitCount) return false;
    timestamps.add(now);
    return true;
  }

  void handleBribeOffer(String player, Map<String, dynamic> msg) {
    if (phase != GamePhase.inspection) return;
    if (player == currentSheriff) return;

    final goldAmount = msg['goldAmount'] as int? ?? 0;
    final goodsFromStand = List<String>.from(msg['goodsFromStand'] ?? []);

    if (goldAmount <= 0 && goodsFromStand.isEmpty) return;

    pendingBribes[player] = {
      'fromPlayer': player,
      'goldAmount': goldAmount,
      'goodsFromStand': goodsFromStand,
    };

    broadcast({
      'type': 'bribe_offered',
      'fromPlayer': player,
      'goldAmount': goldAmount,
      'goodsFromStand': goodsFromStand,
    });
  }

  void handleBribeResponse(String player, Map<String, dynamic> msg) {
    if (phase != GamePhase.inspection) return;
    if (player != currentSheriff) return;

    final target = msg['target'] as String?;
    final accepted = msg['accepted'] as bool? ?? false;

    if (target == null || !pendingBribes.containsKey(target)) return;

    if (accepted) {
      final bribe = pendingBribes[target]!;
      final goldAmount = bribe['goldAmount'] as int;
      final goodsFromStand = List<String>.from(bribe['goodsFromStand'] ?? []);

      final merchantGold = gold[target] ?? 0;
      final actualGold = goldAmount.clamp(0, merchantGold);
      gold[target] = merchantGold - actualGold;
      gold[currentSheriff!] = (gold[currentSheriff!] ?? 0) + actualGold;

      final stand = merchantStands[target] ?? [];
      for (final g in goodsFromStand) {
        if (stand.remove(g)) {
          merchantStands[currentSheriff!] = [...(merchantStands[currentSheriff!] ?? []), g];
        }
      }

      inspectionDecisions[target] = 'pass';
      resolveMerchant(target, false);
    }

    pendingBribes.remove(target);

    broadcast({
      'type': 'bribe_resolved',
      'target': target,
      'accepted': accepted,
    });

    checkInspectionComplete();
  }

  void handleInspect(String player, Map<String, dynamic> msg) {
    if (phase != GamePhase.inspection) return;
    if (player != currentSheriff) return;

    final target = msg['target'] as String?;
    if (target == null || inspectionDecisions.containsKey(target)) return;
    if (!merchants.contains(target)) return;

    inspectionDecisions[target] = 'inspect';
    resolveMerchant(target, true);
    checkInspectionComplete();
  }

  void handlePass(String player, Map<String, dynamic> msg) {
    if (phase != GamePhase.inspection) return;
    if (player != currentSheriff) return;

    final target = msg['target'] as String?;
    if (target == null || inspectionDecisions.containsKey(target)) return;
    if (!merchants.contains(target)) return;

    inspectionDecisions[target] = 'pass';
    resolveMerchant(target, false);
    checkInspectionComplete();
  }

  void resolveMerchant(String merchant, bool inspected) {
    final bag = bags[merchant] ?? [];
    final decl = declarations[merchant];
    if (decl == null) return;

    final declaredType = decl['declaredType'] as String;
    final stand = merchantStands[merchant] ?? [];

    if (!inspected) {
      for (final card in bag) {
        stand.add(card);
      }
      merchantStands[merchant] = stand;

      broadcast({
        'type': 'inspection_result',
        'player': merchant,
        'inspected': false,
        'declaredType': declaredType,
        'declaredCount': bag.length,
        'actualCards': [],
        'wasHonest': true,
        'penaltyPaid': 0,
        'paidBy': '',
        'cardsToStand': bag.where((c) => isLegal(c)).toList(),
      });
      return;
    }

    final honest = bag.every((c) => c == declaredType);

    if (honest) {
      int totalPenalty = 0;
      for (final card in bag) {
        totalPenalty += cardPenalty(card);
      }

      payGold(currentSheriff!, merchant, totalPenalty);

      for (final card in bag) {
        stand.add(card);
      }
      merchantStands[merchant] = stand;

      broadcast({
        'type': 'inspection_result',
        'player': merchant,
        'inspected': true,
        'declaredType': declaredType,
        'declaredCount': bag.length,
        'actualCards': bag,
        'wasHonest': true,
        'penaltyPaid': totalPenalty,
        'paidBy': currentSheriff,
        'cardsToStand': bag,
      });
    } else {
      final confiscated = <String>[];
      final kept = <String>[];
      int totalPenalty = 0;

      for (final card in bag) {
        if (card == declaredType) {
          kept.add(card);
        } else {
          confiscated.add(card);
          totalPenalty += cardPenalty(card);
        }
      }

      payGold(merchant, currentSheriff!, totalPenalty);

      for (final card in kept) {
        stand.add(card);
      }
      merchantStands[merchant] = stand;

      for (final card in confiscated) {
        discardPile1.add(card);
      }

      broadcast({
        'type': 'inspection_result',
        'player': merchant,
        'inspected': true,
        'declaredType': declaredType,
        'declaredCount': bag.length,
        'actualCards': bag,
        'wasHonest': false,
        'penaltyPaid': totalPenalty,
        'paidBy': merchant,
        'cardsToStand': kept,
        'confiscated': confiscated,
      });
    }
  }

  void payGold(String from, String to, int amount) {
    final fromGold = gold[from] ?? 0;

    if (fromGold >= amount) {
      gold[from] = fromGold - amount;
      gold[to] = (gold[to] ?? 0) + amount;
      return;
    }

    gold[from] = 0;
    int remaining = amount - fromGold;
    gold[to] = (gold[to] ?? 0) + fromGold;

    final stand = merchantStands[from] ?? [];

    final legalOnStand = stand.where((c) => isLegal(c)).toList();
    for (final card in legalOnStand) {
      if (remaining <= 0) break;
      stand.remove(card);
      discardPile1.add(card);
      remaining -= cardValue(card);
    }

    if (remaining > 0) {
      final contrabandOnStand = stand.where((c) => !isLegal(c)).toList();
      for (final card in contrabandOnStand) {
        if (remaining <= 0) break;
        stand.remove(card);
        discardPile1.add(card);
        remaining -= cardValue(card);
      }
    }

    merchantStands[from] = stand;
  }

  void checkInspectionComplete() {
    if (inspectionDecisions.length >= merchants.length) {
      phaseTimer?.cancel();
      phaseTimer = null;
      enterPhase(GamePhase.endOfRound);
    }
  }

  // ---- End of Round ----

  void processEndOfRound() {
    broadcast({
      'type': 'round_summary',
      'round': roundNumber,
      'gold': gold,
      'merchantStands': {
        for (final p in playerNames)
          p: merchantStands[p] ?? [],
      },
    });

    bool allDone = true;
    for (final p in playerNames) {
      if ((sheriffCount[p] ?? 0) < requiredSheriffRounds) {
        allDone = false;
        break;
      }
    }

    if (allDone) {
      Future.delayed(const Duration(seconds: 3), () {
        enterPhase(GamePhase.gameOver);
      });
    } else {
      Future.delayed(const Duration(seconds: 3), () {
        startNewRound();
      });
    }
  }

  // ---- Scoring ----

  void broadcastFinalScores() {
    final scores = <Map<String, dynamic>>[];

    for (final p in playerNames) {
      final stand = merchantStands[p] ?? [];
      int goodsValue = 0;
      for (final card in stand) {
        goodsValue += cardValue(card);
      }

      scores.add({
        'playerName': p,
        'goodsValue': goodsValue,
        'gold': gold[p] ?? 0,
        'standCards': stand,
        'kingBonuses': <String, int>{},
        'queenBonuses': <String, int>{},
        'totalScore': 0,
      });
    }

    for (final goodType in legalTypes) {
      final counts = <String, int>{};
      for (final p in playerNames) {
        counts[p] = (merchantStands[p] ?? []).where((c) => c == goodType).length;
      }

      final sorted = counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      if (sorted.isEmpty || sorted.first.value == 0) continue;

      final topCount = sorted.first.value;
      final kings = sorted.where((e) => e.value == topCount).toList();

      if (kings.length > 1) {
        final combined = (kingBonus[goodType]! + queenBonus[goodType]!) ~/ kings.length;
        for (final king in kings) {
          final ps = scores.firstWhere((s) => s['playerName'] == king.key);
          (ps['kingBonuses'] as Map<String, int>)[goodType] = combined;
        }
      } else {
        final kingPlayer = kings.first.key;
        final ps = scores.firstWhere((s) => s['playerName'] == kingPlayer);
        (ps['kingBonuses'] as Map<String, int>)[goodType] = kingBonus[goodType]!;

        final remaining = sorted.where((e) => e.value > 0 && e.key != kingPlayer).toList();
        if (remaining.isNotEmpty) {
          final secondCount = remaining.first.value;
          final queens = remaining.where((e) => e.value == secondCount).toList();
          final qBonus = queenBonus[goodType]! ~/ queens.length;
          for (final queen in queens) {
            final qs = scores.firstWhere((s) => s['playerName'] == queen.key);
            (qs['queenBonuses'] as Map<String, int>)[goodType] = qBonus;
          }
        }
      }
    }

    for (final s in scores) {
      int total = (s['goodsValue'] as int) + (s['gold'] as int);
      (s['kingBonuses'] as Map<String, int>).forEach((_, v) => total += v);
      (s['queenBonuses'] as Map<String, int>).forEach((_, v) => total += v);
      s['totalScore'] = total;
    }

    scores.sort((a, b) => (b['totalScore'] as int).compareTo(a['totalScore'] as int));

    broadcast({
      'type': 'game_over',
      'scores': scores,
    });
  }

  // ---- Phase timeouts (auto-advance when players are slow/disconnected) ----

  void _startPhaseTimeout(Duration duration) {
    phaseTimer?.cancel();
    phaseTimer = Timer(duration, _onPhaseTimeout);
  }

  void _onPhaseTimeout() {
    print('[ROOM $id] Phase timeout! phase=$phase, disconnected=$disconnectedPlayers');
    switch (phase) {
      case GamePhase.market:
        for (final m in merchants) {
          if (!marketDone.contains(m)) {
            marketDone.add(m);
          }
        }
        enterPhase(GamePhase.loadBag);
        break;

      case GamePhase.loadBag:
        for (final m in merchants) {
          if (!bagLoaded.contains(m)) {
            final hand = hands[m] ?? [];
            if (hand.isNotEmpty) {
              bags[m] = [hand.first];
              hands[m] = hand.sublist(1);
            } else {
              bags[m] = ['apple'];
            }
            bagLoaded.add(m);
          }
        }
        enterPhase(GamePhase.declaration);
        break;

      case GamePhase.declaration:
        for (final m in merchants) {
          if (!declared.contains(m)) {
            final bag = bags[m] ?? [];
            declarations[m] = {
              'declaredType': 'apple',
              'declaredCount': bag.length,
            };
            declared.add(m);
          }
        }
        enterPhase(GamePhase.inspection);
        break;

      case GamePhase.inspection:
        for (final m in merchants) {
          if (!inspectionDecisions.containsKey(m)) {
            inspectionDecisions[m] = 'pass';
            resolveMerchant(m, false);
          }
        }
        checkInspectionComplete();
        break;

      default:
        break;
    }
  }

  // ---- Disconnect handling ----

  void handleDisconnect(String leaver) {
    print('[ROOM $id] handleDisconnect: $leaver (phase=$phase, disconnected=$disconnectedPlayers)');
    if (phase == GamePhase.lobby) {
      broadcastLobbyState();
      return;
    }

    if (disconnectedPlayers.contains(leaver)) {
      print('[ROOM $id] $leaver already marked as disconnected, ignoring duplicate');
      return;
    }

    disconnectedPlayers.add(leaver);

    broadcast({
      'type': 'player_disconnected',
      'player': leaver,
      'message': '$leaver disconnected. Waiting for reconnection...',
    });

    _disconnectTimers[leaver]?.cancel();
    _disconnectTimers[leaver] = Timer(const Duration(seconds: 60), () {
      _disconnectTimers.remove(leaver);
      final activePlayers = playerNames.where((p) => !disconnectedPlayers.contains(p)).length;
      print('[ROOM $id] Disconnect timer expired for $leaver. Active players: $activePlayers');
      if (activePlayers < 2) {
        broadcastFinalScores();
      }
    });
  }

  void handleReconnect(String player, WebSocket socket) {
    print('[ROOM $id] handleReconnect: $player (was disconnected: ${disconnectedPlayers.contains(player)})');
    disconnectedPlayers.remove(player);
    _disconnectTimers[player]?.cancel();
    _disconnectTimers.remove(player);
    final idx = playerNames.indexOf(player);
    if (idx >= 0 && idx < clients.length) {
      clients[idx] = socket;
    }
    broadcast({'type': 'player_reconnected', 'player': player});
    sendTo(player, buildGameStateFor(player));
  }
}

// ---------------------------------------------------------------------------
// Global state
// ---------------------------------------------------------------------------

final Map<String, Room> rooms = {};
final Map<WebSocket, String> clientRoomMap = {};
final Map<WebSocket, String> clientNameMap = {};
final Random _random = Random();

String _generateRoomId() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  return List.generate(5, (_) => chars[_random.nextInt(chars.length)]).join();
}

Room? _getRoom(WebSocket socket) {
  final roomId = clientRoomMap[socket];
  return roomId != null ? rooms[roomId] : null;
}

String? _getPlayer(WebSocket socket) => clientNameMap[socket];

// ---------------------------------------------------------------------------
// Main server
// ---------------------------------------------------------------------------

void main() async {
  final webDir = _findWebBuildDir();
  final server = await HttpServer.bind('0.0.0.0', 8080);
  print('Server running on http://0.0.0.0:8080');
  print('WebSocket endpoint: ws://0.0.0.0:8080/ws');
  if (webDir != null) {
    print('Serving web app from: $webDir');
  }

  Timer.periodic(const Duration(minutes: 5), (_) {
    final now = DateTime.now();
    rooms.removeWhere((_, room) {
      if (room.finishedAt != null &&
          now.difference(room.finishedAt!) >= _roomFinishedTtl) {
        room.dispose();
        return true;
      }
      return false;
    });
  });

  await for (HttpRequest req in server) {
    if (req.uri.path == '/ws' && WebSocketTransformer.isUpgradeRequest(req)) {
      final socket = await WebSocketTransformer.upgrade(req);
      _handleWebSocket(socket);
    } else if (webDir != null) {
      _serveStaticFile(req, webDir);
    } else {
      req.response
        ..statusCode = HttpStatus.notFound
        ..write('Web build not found. Run: cd sheriff_game && flutter build web')
        ..close();
    }
  }
}

void _handleWebSocket(WebSocket socket) {
  print('[SERVER] New WebSocket connection');
  socket.listen((data) {
    try {
      final message = jsonDecode(data) as Map<String, dynamic>;
      final type = message['type'] as String?;
      if (type == null) return;

      switch (type) {
        case 'ping':
          try { socket.add(jsonEncode({'type': 'pong'})); } catch (_) {}
          break;
        case 'create':
          _handleCreate(socket, message);
          break;
        case 'join':
          _handleJoin(socket, message);
          break;
        case 'reconnect':
          _handleReconnect(socket, message);
          break;
        case 'ready':
        case 'unready':
          _handleReadyToggle(socket, type);
          break;
        case 'market_action':
        case 'load_bag':
        case 'declare':
        case 'inspect':
        case 'pass':
        case 'bribe_offer':
        case 'bribe_response':
        case 'chat':
          _handleInGame(socket, message);
          break;
        default:
          break;
      }
    } catch (e) {
      print('Error processing message: $e');
    }
  }, onDone: () {
    _handleDisconnect(socket);
  }, onError: (_) {
    _handleDisconnect(socket);
  });
}

String? _findWebBuildDir() {
  final candidates = [
    '../sheriff_game/build/web',
    '../../sheriff_game/build/web',
    'sheriff_game/build/web',
  ];
  for (final path in candidates) {
    final dir = Directory(path);
    if (dir.existsSync() && File('${dir.path}/index.html').existsSync()) {
      return dir.path;
    }
  }
  return null;
}

const _mimeTypes = {
  '.html': 'text/html',
  '.js': 'application/javascript',
  '.css': 'text/css',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.ico': 'image/x-icon',
  '.svg': 'image/svg+xml',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.wasm': 'application/wasm',
};

void _serveStaticFile(HttpRequest req, String webDir) {
  var path = req.uri.path;
  if (path == '/') path = '/index.html';

  final filePath = '$webDir$path';
  final file = File(filePath);

  if (file.existsSync()) {
    final ext = path.contains('.') ? '.${path.split('.').last}' : '';
    final mime = _mimeTypes[ext] ?? 'application/octet-stream';

    req.response
      ..statusCode = HttpStatus.ok
      ..headers.set('Content-Type', mime)
      ..headers.set('Cache-Control', 'no-cache');
    file.openRead().pipe(req.response);
  } else {
    final indexFile = File('$webDir/index.html');
    if (indexFile.existsSync()) {
      req.response
        ..statusCode = HttpStatus.ok
        ..headers.set('Content-Type', 'text/html')
        ..headers.set('Cache-Control', 'no-cache');
      indexFile.openRead().pipe(req.response);
    } else {
      req.response
        ..statusCode = HttpStatus.notFound
        ..write('Not found')
        ..close();
    }
  }
}

void _handleCreate(WebSocket socket, Map<String, dynamic> msg) {
  final name = normalizePlayerName(msg['name'] as String?);
  if (name == null) {
    socket.add(jsonEncode({'type': 'error', 'message': 'Invalid player name (1–$maxNameLength chars)'}));
    return;
  }

  final roomId = _generateRoomId();
  final room = Room(roomId);
  rooms[roomId] = room;

  final token = issuePlayerToken();
  room.clients.add(socket);
  room.playerNames.add(name);
  room.playerTokens[name] = token;
  clientRoomMap[socket] = roomId;
  clientNameMap[socket] = name;

  socket.add(jsonEncode({'type': 'room_created', 'roomId': roomId, 'token': token}));
  room.broadcastLobbyState();
}

void _handleJoin(WebSocket socket, Map<String, dynamic> msg) {
  final roomId = msg['roomId'] as String?;
  if (roomId == null) return;

  final room = rooms[roomId];
  if (room == null) {
    socket.add(jsonEncode({'type': 'error', 'message': 'Room not found'}));
    return;
  }

  final rawName = msg['name'] as String?;
  final token = msg['token'] as String?;

  if (room.phase != GamePhase.lobby && room.playerNames.contains(rawName?.trim())) {
    final name = rawName!.trim();
    if (token == null || room.playerTokens[name] != token) {
      socket.add(jsonEncode({'type': 'error', 'message': 'Invalid reconnect token'}));
      return;
    }
    clientRoomMap[socket] = roomId;
    clientNameMap[socket] = name;
    room.handleReconnect(name, socket);
    return;
  }

  final name = normalizePlayerName(rawName, existingNames: room.playerNames);
  if (name == null) {
    socket.add(jsonEncode({
      'type': 'error',
      'message': 'Invalid or duplicate player name (1–$maxNameLength chars, must be unique)',
    }));
    return;
  }

  if (room.phase != GamePhase.lobby) {
    socket.add(jsonEncode({'type': 'error', 'message': 'Game already in progress'}));
    return;
  }

  if (room.playerNames.length >= 5) {
    socket.add(jsonEncode({'type': 'error', 'message': 'Room is full (max 5 players)'}));
    return;
  }

  final newToken = issuePlayerToken();
  room.clients.add(socket);
  room.playerNames.add(name);
  room.playerTokens[name] = newToken;
  clientRoomMap[socket] = roomId;
  clientNameMap[socket] = name;

  socket.add(jsonEncode({'type': 'room_joined', 'roomId': roomId, 'token': newToken}));
  room.broadcastLobbyState();
}

void _handleReadyToggle(WebSocket socket, String type) {
  final room = _getRoom(socket);
  final player = _getPlayer(socket);
  if (room == null || player == null) return;

  if (type == 'ready') {
    room.addReady(player);
  } else {
    room.removeReady(player);
  }
}

void _handleReconnect(WebSocket socket, Map<String, dynamic> msg) {
  final name = msg['name'] as String?;
  final roomId = msg['roomId'] as String?;
  final token = msg['token'] as String?;
  if (name == null || roomId == null || token == null) return;

  final room = rooms[roomId];
  if (room == null) return;

  final trimmed = name.trim();
  if (room.playerNames.contains(trimmed) && room.playerTokens[trimmed] == token) {
    clientRoomMap[socket] = roomId;
    clientNameMap[socket] = trimmed;
    room.handleReconnect(trimmed, socket);
  } else {
    socket.add(jsonEncode({'type': 'error', 'message': 'Invalid reconnect token'}));
  }
}

void _handleInGame(WebSocket socket, Map<String, dynamic> msg) {
  final room = _getRoom(socket);
  final player = _getPlayer(socket);
  if (room == null || player == null) return;

  final type = msg['type'] as String;

  switch (type) {
    case 'market_action':
      room.handleMarketAction(player, msg);
      break;
    case 'load_bag':
      room.handleLoadBag(player, msg);
      break;
    case 'declare':
      room.handleDeclaration(player, msg);
      break;
    case 'inspect':
      room.handleInspect(player, msg);
      break;
    case 'pass':
      room.handlePass(player, msg);
      break;
    case 'bribe_offer':
      room.handleBribeOffer(player, msg);
      break;
    case 'bribe_response':
      room.handleBribeResponse(player, msg);
      break;
    case 'chat':
      room.handleChat(player, msg);
      break;
  }
}

void _handleDisconnect(WebSocket socket) {
  final roomId = clientRoomMap.remove(socket);
  final player = clientNameMap.remove(socket);

  print('[SERVER] WebSocket closed. player=$player, room=$roomId');

  if (roomId == null || player == null) return;
  final room = rooms[roomId];
  if (room == null) return;

  if (room.phase == GamePhase.lobby) {
    room.clients.remove(socket);
    room.playerNames.remove(player);
    room.playerTokens.remove(player);
    room.readyPlayers.remove(player);
    room.broadcastLobbyState();

    if (room.playerNames.isEmpty) {
      room.dispose();
      rooms.remove(roomId);
    }
  } else if (room.phase == GamePhase.gameOver) {
    final idx = room.clients.indexOf(socket);
    if (idx >= 0) room.clients.removeAt(idx);
    if (room.clients.isEmpty) {
      room.dispose();
      rooms.remove(roomId);
    }
  } else {
    room.handleDisconnect(player);
  }
}
