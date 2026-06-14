import 'card.dart';

class Player {
  final String id;
  final String name;
  int gold;
  List<GameCard> hand;
  List<GameCard> merchantStand;
  List<GameCard> bag;

  Player({
    required this.id,
    required this.name,
    this.gold = 50,
    List<GameCard>? hand,
    List<GameCard>? merchantStand,
    List<GameCard>? bag,
  })  : hand = hand ?? [],
        merchantStand = merchantStand ?? [],
        bag = bag ?? [];

  int get standValue =>
      merchantStand.fold(0, (sum, card) => sum + card.value);

  int countGoodOnStand(String goodName) =>
      merchantStand.where((c) => c.name == goodName).length;

  int get legalGoodsCount =>
      merchantStand.where((c) => c.isLegal).length;

  int get contrabandCount =>
      merchantStand.where((c) => c.isContraband).length;

  factory Player.fromJson(Map<String, dynamic> json) => Player(
        id: json['id'] as String,
        name: json['name'] as String,
        gold: json['gold'] as int? ?? 50,
        hand: (json['hand'] as List<dynamic>?)
                ?.map((c) => GameCard.fromJson(c as Map<String, dynamic>))
                .toList() ??
            [],
        merchantStand: (json['merchantStand'] as List<dynamic>?)
                ?.map((c) => GameCard.fromJson(c as Map<String, dynamic>))
                .toList() ??
            [],
        bag: (json['bag'] as List<dynamic>?)
                ?.map((c) => GameCard.fromJson(c as Map<String, dynamic>))
                .toList() ??
            [],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'gold': gold,
        'hand': hand.map((c) => c.toJson()).toList(),
        'merchantStand': merchantStand.map((c) => c.toJson()).toList(),
        'bag': bag.map((c) => c.toJson()).toList(),
      };
}
