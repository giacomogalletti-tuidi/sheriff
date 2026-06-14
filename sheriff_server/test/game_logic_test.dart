import 'package:test/test.dart';
import '../bin/server.dart';

void main() {
  group('Card catalog', () {
    test('legal goods have correct values and penalties', () {
      expect(cardValue('apple'), 2);
      expect(cardPenalty('apple'), 2);
      expect(cardValue('cheese'), 3);
      expect(cardPenalty('cheese'), 2);
      expect(cardValue('bread'), 3);
      expect(cardPenalty('bread'), 2);
      expect(cardValue('chicken'), 4);
      expect(cardPenalty('chicken'), 2);
    });

    test('contraband goods have correct values and penalties', () {
      expect(cardValue('pepper'), 6);
      expect(cardPenalty('pepper'), 4);
      expect(cardValue('silk'), 5);
      expect(cardPenalty('silk'), 4);
      expect(cardValue('crossbow'), 9);
      expect(cardPenalty('crossbow'), 4);
      expect(cardValue('mead'), 7);
      expect(cardPenalty('mead'), 4);
    });

    test('isLegal correctly identifies goods', () {
      expect(isLegal('apple'), isTrue);
      expect(isLegal('cheese'), isTrue);
      expect(isLegal('bread'), isTrue);
      expect(isLegal('chicken'), isTrue);
      expect(isLegal('pepper'), isFalse);
      expect(isLegal('silk'), isFalse);
      expect(isLegal('crossbow'), isFalse);
      expect(isLegal('mead'), isFalse);
    });
  });

  group('Deck', () {
    test('generates 204 cards', () {
      final room = Room('test');
      room.generateDeck();

      int total = 0;
      deckComposition.forEach((_, count) => total += count);
      expect(total, 204);
      expect(room.deck.length, 204);
    });

    test('contains correct card distribution', () {
      final room = Room('test');
      room.generateDeck();

      final counts = <String, int>{};
      for (final card in room.deck) {
        counts[card] = (counts[card] ?? 0) + 1;
      }

      expect(counts['apple'], 48);
      expect(counts['cheese'], 36);
      expect(counts['bread'], 36);
      expect(counts['chicken'], 24);
      expect(counts['pepper'], 22);
      expect(counts['silk'], 21);
      expect(counts['crossbow'], 12);
      expect(counts['mead'], 5);
    });

    test('drawCard removes from deck', () {
      final room = Room('test');
      room.generateDeck();
      final initialSize = room.deck.length;

      room.drawCard();
      expect(room.deck.length, initialSize - 1);
    });

    test('reshuffleDeckIfNeeded replenishes deck from discard piles', () {
      final room = Room('test');
      room.deck = ['apple', 'bread'];
      room.discardPile1 = List.generate(20, (_) => 'cheese');
      room.discardPile2 = List.generate(20, (_) => 'chicken');

      room.reshuffleDeckIfNeeded();

      expect(room.deck.length, greaterThan(2));
      expect(room.discardPile1.length, 5);
      expect(room.discardPile2.length, 5);
    });
  });

  group('Room game flow', () {
    test('requiredSheriffRounds is 3 for 3 players, 2 for 4-5', () {
      final room = Room('test');
      room.playerNames.addAll(['A', 'B', 'C']);
      expect(room.requiredSheriffRounds, 3);

      room.playerNames.add('D');
      expect(room.requiredSheriffRounds, 2);

      room.playerNames.add('E');
      expect(room.requiredSheriffRounds, 2);
    });

    test('merchants excludes sheriff', () {
      final room = Room('test');
      room.playerNames.addAll(['Alice', 'Bob', 'Charlie']);
      room.currentSheriffIndex = 0;

      expect(room.currentSheriff, 'Alice');
      expect(room.merchants, ['Bob', 'Charlie']);
    });
  });

  group('Scoring', () {
    test('king and queen bonus values are correct', () {
      expect(kingBonus['apple'], 20);
      expect(kingBonus['cheese'], 15);
      expect(kingBonus['bread'], 15);
      expect(kingBonus['chicken'], 10);

      expect(queenBonus['apple'], 10);
      expect(queenBonus['cheese'], 10);
      expect(queenBonus['bread'], 10);
      expect(queenBonus['chicken'], 5);
    });
  });

  group('Gold payment', () {
    test('payGold transfers gold between players', () {
      final room = Room('test');
      room.playerNames.addAll(['A', 'B']);
      room.gold = {'A': 50, 'B': 50};
      room.merchantStands = {'A': [], 'B': []};

      room.payGold('A', 'B', 10);

      expect(room.gold['A'], 40);
      expect(room.gold['B'], 60);
    });

    test('payGold handles insufficient gold by using stand goods', () {
      final room = Room('test');
      room.playerNames.addAll(['A', 'B']);
      room.gold = {'A': 3, 'B': 50};
      room.merchantStands = {'A': ['apple', 'cheese'], 'B': []};
      room.discardPile1 = [];

      room.payGold('A', 'B', 10);

      expect(room.gold['A'], 0);
      expect(room.gold['B'], 53);
      expect(room.merchantStands['A']!.length, lessThan(2));
    });
  });

  group('Inspection resolution', () {
    test('honest merchant bag passes correctly', () {
      final room = Room('test');
      room.playerNames.addAll(['Sheriff', 'Merchant']);
      room.currentSheriffIndex = 0;
      room.gold = {'Sheriff': 50, 'Merchant': 50};
      room.merchantStands = {'Sheriff': [], 'Merchant': []};
      room.bags = {'Merchant': ['apple', 'apple', 'apple']};
      room.declarations = {
        'Merchant': {'declaredType': 'apple', 'declaredCount': 3}
      };
      room.discardPile1 = [];

      room.resolveMerchant('Merchant', true);

      expect(room.merchantStands['Merchant'], contains('apple'));
      expect(room.merchantStands['Merchant']!.length, 3);
      // Sheriff pays penalty: 3 * 2 = 6
      expect(room.gold['Sheriff'], 44);
      expect(room.gold['Merchant'], 56);
    });

    test('dishonest merchant pays penalty', () {
      final room = Room('test');
      room.playerNames.addAll(['Sheriff', 'Merchant']);
      room.currentSheriffIndex = 0;
      room.gold = {'Sheriff': 50, 'Merchant': 50};
      room.merchantStands = {'Sheriff': [], 'Merchant': []};
      room.bags = {'Merchant': ['apple', 'pepper', 'silk']};
      room.declarations = {
        'Merchant': {'declaredType': 'apple', 'declaredCount': 3}
      };
      room.discardPile1 = [];

      room.resolveMerchant('Merchant', true);

      // Only the declared apple goes to stand
      expect(room.merchantStands['Merchant'], ['apple']);
      // Penalty: pepper(4) + silk(4) = 8, merchant pays sheriff
      expect(room.gold['Merchant'], 42);
      expect(room.gold['Sheriff'], 58);
      // Confiscated cards go to discard
      expect(room.discardPile1, containsAll(['pepper', 'silk']));
    });

    test('passed bag adds all goods to stand', () {
      final room = Room('test');
      room.playerNames.addAll(['Sheriff', 'Merchant']);
      room.currentSheriffIndex = 0;
      room.gold = {'Sheriff': 50, 'Merchant': 50};
      room.merchantStands = {'Sheriff': [], 'Merchant': []};
      room.bags = {'Merchant': ['apple', 'pepper']};
      room.declarations = {
        'Merchant': {'declaredType': 'apple', 'declaredCount': 2}
      };

      room.resolveMerchant('Merchant', false);

      // All cards go to stand (including contraband!)
      expect(room.merchantStands['Merchant'], ['apple', 'pepper']);
      // No gold changes when passed
      expect(room.gold['Sheriff'], 50);
      expect(room.gold['Merchant'], 50);
    });
  });
}
