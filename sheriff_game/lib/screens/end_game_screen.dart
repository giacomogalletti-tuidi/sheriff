import 'package:flutter/material.dart';

class EndGameScreen extends StatelessWidget {
  final List<Map<String, dynamic>> scores;
  final VoidCallback? onReturnToLobby;

  const EndGameScreen({super.key, required this.scores, this.onReturnToLobby});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (scores.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Game ended'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onReturnToLobby,
              child: const Text('Back to Lobby'),
            ),
          ],
        ),
      );
    }

    final winner = scores.first['playerName'] as String;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Icon(Icons.emoji_events, size: 80, color: Colors.amber.shade600),
          const SizedBox(height: 12),
          Text('Game Over!', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            '$winner wins!',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 32),

          ...scores.asMap().entries.map((entry) {
            final i = entry.key;
            final s = entry.value;
            final name = s['playerName'] as String;
            final total = s['totalScore'] as int;
            final goodsValue = s['goodsValue'] as int;
            final gold = s['gold'] as int;
            final kings = Map<String, int>.from(s['kingBonuses'] ?? {});
            final queens = Map<String, int>.from(s['queenBonuses'] ?? {});
            final isWinner = i == 0;

            return Card(
              elevation: isWinner ? 4 : 1,
              color: isWinner ? Colors.amber.shade50 : null,
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: isWinner ? Colors.amber : Colors.grey.shade300,
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: isWinner ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            name,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                        Text(
                          '$total pts',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isWinner ? Colors.amber.shade800 : null,
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    _ScoreRow(label: 'Goods value', value: goodsValue),
                    _ScoreRow(label: 'Gold', value: gold),
                    ...kings.entries.map((e) =>
                        _ScoreRow(label: 'King of ${_capitalize(e.key)}', value: e.value, color: Colors.amber)),
                    ...queens.entries.map((e) =>
                        _ScoreRow(label: 'Queen of ${_capitalize(e.key)}', value: e.value, color: Colors.purple)),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.home),
              onPressed: onReturnToLobby,
              label: const Text('Back to Lobby'),
            ),
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) => s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : s;
}

class _ScoreRow extends StatelessWidget {
  final String label;
  final int value;
  final Color? color;

  const _ScoreRow({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: color ?? Colors.grey.shade700)),
          Text(
            '+$value',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color ?? Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
