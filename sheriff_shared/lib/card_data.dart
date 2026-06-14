/// Single source of truth for card stats and deck composition.
/// Imported by sheriff_server and sheriff_game — do not duplicate elsewhere.

const cardValues = {
  'apple': {'value': 2, 'penalty': 2, 'type': 'legal'},
  'cheese': {'value': 3, 'penalty': 2, 'type': 'legal'},
  'bread': {'value': 3, 'penalty': 2, 'type': 'legal'},
  'chicken': {'value': 4, 'penalty': 2, 'type': 'legal'},
  'pepper': {'value': 6, 'penalty': 4, 'type': 'contraband'},
  'silk': {'value': 5, 'penalty': 4, 'type': 'contraband'},
  'crossbow': {'value': 9, 'penalty': 4, 'type': 'contraband'},
  'mead': {'value': 7, 'penalty': 4, 'type': 'contraband'},
};

const deckComposition = {
  'apple': 48,
  'cheese': 36,
  'bread': 36,
  'chicken': 24,
  'pepper': 22,
  'silk': 21,
  'crossbow': 12,
  'mead': 5,
};

const legalTypes = ['apple', 'cheese', 'bread', 'chicken'];

const kingBonus = {'apple': 20, 'cheese': 15, 'bread': 15, 'chicken': 10};
const queenBonus = {'apple': 10, 'cheese': 10, 'bread': 10, 'chicken': 5};

bool isLegal(String name) => cardValues[name]?['type'] == 'legal';
bool isContraband(String name) => !isLegal(name);
int cardValue(String name) => (cardValues[name]?['value'] ?? 0) as int;
int cardPenalty(String name) => (cardValues[name]?['penalty'] ?? 0) as int;
