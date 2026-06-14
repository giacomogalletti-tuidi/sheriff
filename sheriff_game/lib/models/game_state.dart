enum GamePhase {
  lobby,
  market,
  loadBag,
  declaration,
  inspection,
  endOfRound,
  gameOver,
}

GamePhase gamePhaseFromString(String s) {
  switch (s) {
    case 'lobby':
      return GamePhase.lobby;
    case 'market':
      return GamePhase.market;
    case 'loadBag':
      return GamePhase.loadBag;
    case 'declaration':
      return GamePhase.declaration;
    case 'inspection':
      return GamePhase.inspection;
    case 'endOfRound':
      return GamePhase.endOfRound;
    case 'gameOver':
      return GamePhase.gameOver;
    default:
      return GamePhase.lobby;
  }
}

class Declaration {
  final String playerName;
  final String declaredType;
  final int declaredCount;

  const Declaration({
    required this.playerName,
    required this.declaredType,
    required this.declaredCount,
  });

  factory Declaration.fromJson(Map<String, dynamic> json) => Declaration(
        playerName: json['playerName'] as String,
        declaredType: json['declaredType'] as String,
        declaredCount: json['declaredCount'] as int,
      );

  Map<String, dynamic> toJson() => {
        'playerName': playerName,
        'declaredType': declaredType,
        'declaredCount': declaredCount,
      };
}

class BribeOffer {
  final String fromPlayer;
  final int goldAmount;
  final List<String> goodsFromStand;

  const BribeOffer({
    required this.fromPlayer,
    this.goldAmount = 0,
    this.goodsFromStand = const [],
  });

  factory BribeOffer.fromJson(Map<String, dynamic> json) => BribeOffer(
        fromPlayer: json['fromPlayer'] as String,
        goldAmount: json['goldAmount'] as int? ?? 0,
        goodsFromStand: List<String>.from(json['goodsFromStand'] ?? []),
      );

  Map<String, dynamic> toJson() => {
        'fromPlayer': fromPlayer,
        'goldAmount': goldAmount,
        'goodsFromStand': goodsFromStand,
      };
}

class InspectionResult {
  final String playerName;
  final String declaredType;
  final int declaredCount;
  final List<String> actualCards;
  final bool wasHonest;
  final int penaltyPaid;
  final String paidBy;

  const InspectionResult({
    required this.playerName,
    required this.declaredType,
    required this.declaredCount,
    required this.actualCards,
    required this.wasHonest,
    required this.penaltyPaid,
    required this.paidBy,
  });

  factory InspectionResult.fromJson(Map<String, dynamic> json) =>
      InspectionResult(
        playerName: json['playerName'] as String,
        declaredType: json['declaredType'] as String,
        declaredCount: json['declaredCount'] as int,
        actualCards: List<String>.from(json['actualCards']),
        wasHonest: json['wasHonest'] as bool,
        penaltyPaid: json['penaltyPaid'] as int,
        paidBy: json['paidBy'] as String,
      );

  Map<String, dynamic> toJson() => {
        'playerName': playerName,
        'declaredType': declaredType,
        'declaredCount': declaredCount,
        'actualCards': actualCards,
        'wasHonest': wasHonest,
        'penaltyPaid': penaltyPaid,
        'paidBy': paidBy,
      };
}

class ScoreBreakdown {
  final String playerName;
  final int goodsValue;
  final int gold;
  final Map<String, int> kingBonuses;
  final Map<String, int> queenBonuses;
  final int totalScore;

  const ScoreBreakdown({
    required this.playerName,
    required this.goodsValue,
    required this.gold,
    required this.kingBonuses,
    required this.queenBonuses,
    required this.totalScore,
  });

  factory ScoreBreakdown.fromJson(Map<String, dynamic> json) => ScoreBreakdown(
        playerName: json['playerName'] as String,
        goodsValue: json['goodsValue'] as int,
        gold: json['gold'] as int,
        kingBonuses: Map<String, int>.from(json['kingBonuses'] ?? {}),
        queenBonuses: Map<String, int>.from(json['queenBonuses'] ?? {}),
        totalScore: json['totalScore'] as int,
      );

  Map<String, dynamic> toJson() => {
        'playerName': playerName,
        'goodsValue': goodsValue,
        'gold': gold,
        'kingBonuses': kingBonuses,
        'queenBonuses': queenBonuses,
        'totalScore': totalScore,
      };
}
