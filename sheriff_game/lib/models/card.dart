import 'package:sheriff_shared/card_data.dart' as shared;

export 'package:sheriff_shared/card_data.dart';

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
  static GameCard _fromShared(String name) {
    final stats = shared.cardValues[name]!;
    return GameCard(
      name: name,
      type: stats['type'] == 'legal' ? CardType.legal : CardType.contraband,
      value: stats['value'] as int,
      penalty: stats['penalty'] as int,
    );
  }

  static final apple = _fromShared('apple');
  static final cheese = _fromShared('cheese');
  static final bread = _fromShared('bread');
  static final chicken = _fromShared('chicken');
  static final pepper = _fromShared('pepper');
  static final silk = _fromShared('silk');
  static final crossbow = _fromShared('crossbow');
  static final mead = _fromShared('mead');

  static final legalGoods = [apple, cheese, bread, chicken];
  static final contrabandGoods = [pepper, silk, crossbow, mead];
  static final allGoods = [...legalGoods, ...contrabandGoods];

  static Map<String, int> get deckComposition => shared.deckComposition;
  static Map<String, int> get kingBonus => shared.kingBonus;
  static Map<String, int> get queenBonus => shared.queenBonus;

  static GameCard byName(String name) {
    return allGoods.firstWhere((c) => c.name == name);
  }
}
