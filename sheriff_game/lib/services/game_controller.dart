import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/game_state.dart';
import 'websocket_service.dart';

class GameController extends ChangeNotifier {
  final WebSocketService ws;
  StreamSubscription? _sub;

  String playerName = '';
  String roomId = '';
  String reconnectToken = '';

  // Lobby state
  List<String> players = [];
  List<String> readyPlayers = [];
  int? countdown;
  String? errorMessage;

  // Game state
  GamePhase phase = GamePhase.lobby;
  int round = 0;
  String? sheriff;
  bool isSheriff = false;
  int myGold = 50;
  Map<String, int> gold = {};
  List<String> hand = [];
  Map<String, List<String>> merchantStands = {};
  Map<String, int> merchantStandCounts = {};
  List<String> myStand = [];

  // Market
  String? discardPile1Top;
  String? discardPile2Top;
  int deckCount = 0;
  List<String> marketDone = [];

  // Load Bag
  List<String> bagLoaded = [];
  List<String> myBag = [];

  // Declaration
  Map<String, Map<String, dynamic>> declarations = {};
  List<String> declared = [];

  // Inspection
  Map<String, String> inspectionDecisions = {};
  List<Map<String, dynamic>> chatMessages = [];
  Map<String, Map<String, dynamic>> pendingBribes = {};
  Map<String, Map<String, dynamic>> inspectionResultsByPlayer = {};
  List<Map<String, dynamic>> get inspectionResults =>
      inspectionResultsByPlayer.values.toList();

  // End game
  List<Map<String, dynamic>> finalScores = [];

  // Phase timer (server-authoritative deadline)
  int? phaseDeadlineMs;

  // Disconnection
  String? disconnectMessage;

  GameController(this.ws) {
    _sub = ws.messages.listen(_handleMessage);
  }

  void _handleMessage(Map<String, dynamic> msg) {
    final type = msg['type'] as String?;
    if (type == null) return;

    switch (type) {
      case 'room_created':
        roomId = msg['roomId'] as String;
        reconnectToken = msg['token'] as String? ?? reconnectToken;
        errorMessage = null;
        break;

      case 'room_joined':
        roomId = msg['roomId'] as String;
        reconnectToken = msg['token'] as String? ?? reconnectToken;
        errorMessage = null;
        break;

      case 'error':
        errorMessage = msg['message'] as String?;
        break;

      case 'lobby_state':
        players = List<String>.from(msg['players'] ?? []);
        readyPlayers = List<String>.from(msg['ready'] ?? []);
        phase = gamePhaseFromString(msg['phase'] ?? 'lobby');
        break;

      case 'countdown':
        countdown = msg['value'] as int?;
        break;

      case 'game_state':
        _updateGameState(msg);
        break;

      case 'bag_loaded':
        myBag = List<String>.from(msg['bag'] ?? []);
        hand = List<String>.from(msg['hand'] ?? []);
        break;

      case 'player_loaded_bag':
        bagLoaded = List<String>.from(msg['bagLoaded'] ?? []);
        break;

      case 'player_declared':
        final p = msg['player'] as String;
        declarations[p] = {
          'declaredType': msg['declaredType'],
          'declaredCount': msg['declaredCount'],
        };
        declared = List<String>.from(msg['declared'] ?? []);
        break;

      case 'chat_message':
        chatMessages.add(msg);
        break;

      case 'bribe_offered':
        pendingBribes[msg['fromPlayer'] as String] = msg;
        break;

      case 'bribe_resolved':
        pendingBribes.remove(msg['target']);
        break;

      case 'inspection_result':
        final player = msg['player'] as String;
        inspectionResultsByPlayer[player] = msg;
        if (msg['inspected'] == false) {
          inspectionDecisions[player] = 'pass';
        } else {
          inspectionDecisions[player] = 'inspect';
        }
        break;

      case 'stand_update':
        myStand = List<String>.from(msg['myStand'] ?? []);
        break;

      case 'round_summary':
        gold = Map<String, int>.from(msg['gold'] ?? {});
        myGold = gold[playerName] ?? 0;
        final stands = msg['merchantStands'] as Map<String, dynamic>? ?? {};
        merchantStands = stands.map(
          (k, v) => MapEntry(k, List<String>.from(v as List)),
        );
        myStand = List<String>.from(merchantStands[playerName] ?? []);
        break;

      case 'game_over':
        phase = GamePhase.gameOver;
        finalScores = List<Map<String, dynamic>>.from(
          (msg['scores'] as List).map((s) => Map<String, dynamic>.from(s)),
        );
        break;

      case 'player_disconnected':
        disconnectMessage = msg['message'] as String?;
        break;

      case 'player_reconnected':
        disconnectMessage = null;
        break;

      case 'connection_closed':
        disconnectMessage = 'Connection lost. Reconnecting...';
        break;

      case 'connection_restored':
        disconnectMessage = null;
        if (roomId.isNotEmpty && playerName.isNotEmpty) {
          ws.send({
            'type': 'reconnect',
            'name': playerName,
            'roomId': roomId,
            'token': reconnectToken,
          });
        }
        break;
    }

    notifyListeners();
  }

  void _updateGameState(Map<String, dynamic> msg) {
    final newPhase = gamePhaseFromString(msg['phase'] ?? 'lobby');
    if (phase == GamePhase.inspection && newPhase != GamePhase.inspection) {
      inspectionResultsByPlayer.clear();
    }
    phase = newPhase;
    round = msg['round'] as int? ?? 0;
    sheriff = msg['sheriff'] as String?;
    isSheriff = msg['isSheriff'] as bool? ?? false;
    if (msg.containsKey('myName')) {
      final name = msg['myName'] as String?;
      if (name != null && name.isNotEmpty) playerName = name;
    }
    myGold = msg['myGold'] as int? ?? 0;
    gold = Map<String, int>.from(msg['gold'] ?? {});
    players = List<String>.from(msg['players'] ?? []);

    hand = List<String>.from(msg['hand'] ?? hand);

    final stands = msg['merchantStands'] as Map<String, dynamic>? ?? {};
    merchantStands = stands.map(
      (k, v) => MapEntry(k, List<String>.from(v as List)),
    );
    merchantStandCounts = Map<String, int>.from(msg['merchantStandCounts'] ?? {});

    if (msg.containsKey('myStand')) {
      myStand = List<String>.from(msg['myStand'] ?? []);
    }

    discardPile1Top = msg['discardPile1Top'] as String?;
    discardPile2Top = msg['discardPile2Top'] as String?;
    deckCount = msg['deckCount'] as int? ?? 0;

    marketDone = List<String>.from(msg['marketDone'] ?? []);
    bagLoaded = List<String>.from(msg['bagLoaded'] ?? []);

    if (msg.containsKey('myBag')) {
      myBag = List<String>.from(msg['myBag'] ?? []);
    }

    if (msg.containsKey('declarations')) {
      final decls = msg['declarations'] as Map<String, dynamic>? ?? {};
      declarations = decls.map(
        (k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)),
      );
    }
    declared = List<String>.from(msg['declared'] ?? []);

    if (msg.containsKey('inspectionDecisions')) {
      inspectionDecisions = Map<String, String>.from(msg['inspectionDecisions'] ?? {});
    }
    if (msg.containsKey('chatMessages')) {
      chatMessages = List<Map<String, dynamic>>.from(
        (msg['chatMessages'] as List? ?? []).map((m) => Map<String, dynamic>.from(m)),
      );
    }
    if (msg.containsKey('pendingBribes')) {
      final bribes = msg['pendingBribes'] as Map<String, dynamic>? ?? {};
      pendingBribes = bribes.map(
        (k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)),
      );
    }

    if (msg.containsKey('phaseDeadlineMs')) {
      phaseDeadlineMs = msg['phaseDeadlineMs'] as int?;
    } else {
      phaseDeadlineMs = null;
    }

    disconnectMessage = null;
    countdown = null;
  }

  // --- Actions ---

  void createRoom(String name) {
    playerName = name;
    ws.send({'type': 'create', 'name': name});
  }

  void joinRoom(String name, String room) {
    playerName = name;
    ws.send({
      'type': 'join',
      'roomId': room,
      'name': name,
      if (reconnectToken.isNotEmpty) 'token': reconnectToken,
    });
  }

  void toggleReady() {
    final isReady = readyPlayers.contains(playerName);
    ws.send({'type': isReady ? 'unready' : 'ready'});
  }

  void submitMarketAction({
    required List<String> discards,
    required List<String> drawSources,
    String discardTarget = 'discard1',
  }) {
    ws.send({
      'type': 'market_action',
      'discards': discards,
      'drawSources': drawSources,
      'discardTarget': discardTarget,
    });
  }

  void submitLoadBag(List<String> cards) {
    ws.send({'type': 'load_bag', 'cards': cards});
  }

  void submitDeclaration(String declaredType, int declaredCount) {
    ws.send({
      'type': 'declare',
      'declaredType': declaredType,
      'declaredCount': declaredCount,
    });
  }

  void inspectMerchant(String target) {
    ws.send({'type': 'inspect', 'target': target});
  }

  void passMerchant(String target) {
    ws.send({'type': 'pass', 'target': target});
  }

  void offerBribe({required int goldAmount, List<String>? goodsFromStand}) {
    ws.send({
      'type': 'bribe_offer',
      'goldAmount': goldAmount,
      'goodsFromStand': goodsFromStand ?? [],
    });
  }

  void respondToBribe(String target, bool accepted) {
    ws.send({
      'type': 'bribe_response',
      'target': target,
      'accepted': accepted,
    });
  }

  void sendChat(String text) {
    ws.send({'type': 'chat', 'text': text});
  }

  List<String> get merchants => players.where((p) => p != sheriff).toList();

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
