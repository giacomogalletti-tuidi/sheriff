import 'package:flutter_test/flutter_test.dart';
import 'package:sheriff_game/models/card.dart';
import 'package:sheriff_game/models/game_state.dart';

void main() {
  group('GameCard', () {
    test('fromJson and toJson roundtrip', () {
      const card = CardCatalog.apple;
      final json = card.toJson();
      final restored = GameCard.fromJson(json);

      expect(restored.name, card.name);
      expect(restored.type, card.type);
      expect(restored.value, card.value);
      expect(restored.penalty, card.penalty);
    });

    test('isLegal/isContraband correctly identifies types', () {
      expect(CardCatalog.apple.isLegal, isTrue);
      expect(CardCatalog.apple.isContraband, isFalse);
      expect(CardCatalog.pepper.isLegal, isFalse);
      expect(CardCatalog.pepper.isContraband, isTrue);
    });

    test('CardCatalog.byName returns correct card', () {
      expect(CardCatalog.byName('crossbow'), CardCatalog.crossbow);
      expect(CardCatalog.byName('cheese'), CardCatalog.cheese);
    });
  });

  group('CardCatalog', () {
    test('legalGoods contains 4 types', () {
      expect(CardCatalog.legalGoods.length, 4);
      expect(CardCatalog.legalGoods.every((c) => c.isLegal), isTrue);
    });

    test('contrabandGoods contains 4 types', () {
      expect(CardCatalog.contrabandGoods.length, 4);
      expect(CardCatalog.contrabandGoods.every((c) => c.isContraband), isTrue);
    });

    test('deck composition sums to 204 cards', () {
      int total = 0;
      CardCatalog.deckComposition.forEach((_, count) => total += count);
      expect(total, 204);
    });

    test('king and queen bonuses defined for all legal types', () {
      for (final good in CardCatalog.legalGoods) {
        expect(CardCatalog.kingBonus.containsKey(good.name), isTrue);
        expect(CardCatalog.queenBonus.containsKey(good.name), isTrue);
      }
    });
  });

  group('GamePhase', () {
    test('gamePhaseFromString parses all phases', () {
      expect(gamePhaseFromString('lobby'), GamePhase.lobby);
      expect(gamePhaseFromString('market'), GamePhase.market);
      expect(gamePhaseFromString('loadBag'), GamePhase.loadBag);
      expect(gamePhaseFromString('declaration'), GamePhase.declaration);
      expect(gamePhaseFromString('inspection'), GamePhase.inspection);
      expect(gamePhaseFromString('endOfRound'), GamePhase.endOfRound);
      expect(gamePhaseFromString('gameOver'), GamePhase.gameOver);
    });

    test('unknown phase defaults to lobby', () {
      expect(gamePhaseFromString('unknown'), GamePhase.lobby);
      expect(gamePhaseFromString(''), GamePhase.lobby);
    });
  });

  group('Declaration', () {
    test('fromJson/toJson roundtrip', () {
      const decl = Declaration(
        playerName: 'Alice',
        declaredType: 'apple',
        declaredCount: 3,
      );

      final json = decl.toJson();
      final restored = Declaration.fromJson(json);

      expect(restored.playerName, 'Alice');
      expect(restored.declaredType, 'apple');
      expect(restored.declaredCount, 3);
    });
  });

  group('ScoreBreakdown', () {
    test('fromJson/toJson roundtrip', () {
      const score = ScoreBreakdown(
        playerName: 'Bob',
        goodsValue: 45,
        gold: 30,
        kingBonuses: {'apple': 20},
        queenBonuses: {'cheese': 10},
        totalScore: 105,
      );

      final json = score.toJson();
      final restored = ScoreBreakdown.fromJson(json);

      expect(restored.playerName, 'Bob');
      expect(restored.goodsValue, 45);
      expect(restored.gold, 30);
      expect(restored.kingBonuses['apple'], 20);
      expect(restored.queenBonuses['cheese'], 10);
      expect(restored.totalScore, 105);
    });
  });
}
