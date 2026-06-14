enum CardType { legal, contraband }

class GameCard {
  final String name;
  final CardType type;
  final int value;
  final int penalty;

  const GameCard({
    required this.name,
    required this.type,
    required this.value,
    required this.penalty,
  });

  bool get isLegal => type == CardType.legal;
  bool get isContraband => type == CardType.contraband;

  factory GameCard.fromJson(Map<String, dynamic> json) => GameCard(
        name: json['name'] as String,
        type: json['type'] == 'legal' ? CardType.legal : CardType.contraband,
        value: json['value'] as int,
        penalty: json['penalty'] as int,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type.name,
        'value': value,
        'penalty': penalty,
      };

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is GameCard && name == other.name;

  @override
  int get hashCode => name.hashCode;
}

class CardCatalog {
  static const apple = GameCard(
    name: 'apple', type: CardType.legal, value: 2, penalty: 2,
  );
  static const cheese = GameCard(
    name: 'cheese', type: CardType.legal, value: 3, penalty: 2,
  );
  static const bread = GameCard(
    name: 'bread', type: CardType.legal, value: 3, penalty: 2,
  );
  static const chicken = GameCard(
    name: 'chicken', type: CardType.legal, value: 4, penalty: 2,
  );
  static const pepper = GameCard(
    name: 'pepper', type: CardType.contraband, value: 6, penalty: 4,
  );
  static const silk = GameCard(
    name: 'silk', type: CardType.contraband, value: 5, penalty: 4,
  );
  static const crossbow = GameCard(
    name: 'crossbow', type: CardType.contraband, value: 9, penalty: 4,
  );
  static const mead = GameCard(
    name: 'mead', type: CardType.contraband, value: 7, penalty: 4,
  );

  static const legalGoods = [apple, cheese, bread, chicken];
  static const contrabandGoods = [pepper, silk, crossbow, mead];
  static const allGoods = [...legalGoods, ...contrabandGoods];

  static const deckComposition = {
    'apple': 48,
    'cheese': 36,
    'bread': 36,
    'chicken': 24,
    'pepper': 22,
    'silk': 21,
    'crossbow': 12,
    'mead': 5,
  };

  static const kingBonus = {
    'apple': 20,
    'cheese': 15,
    'bread': 15,
    'chicken': 10,
  };

  static const queenBonus = {
    'apple': 10,
    'cheese': 10,
    'bread': 10,
    'chicken': 5,
  };

  static GameCard byName(String name) {
    return allGoods.firstWhere((c) => c.name == name);
  }
}
