import 'package:flutter/material.dart';
import 'good_card.dart';

class MerchantStand extends StatelessWidget {
  final String playerName;
  final List<String> visibleGoods;
  final int totalCount;
  final int gold;
  final bool isSheriff;
  final bool isCurrentPlayer;

  const MerchantStand({
    super.key,
    required this.playerName,
    required this.visibleGoods,
    required this.totalCount,
    required this.gold,
    this.isSheriff = false,
    this.isCurrentPlayer = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final goodCounts = <String, int>{};
    for (final g in visibleGoods) {
      goodCounts[g] = (goodCounts[g] ?? 0) + 1;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isCurrentPlayer
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSheriff ? Colors.amber : Colors.grey.shade300,
          width: isSheriff ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (isSheriff) ...[
                Icon(Icons.shield, size: 16, color: Colors.amber.shade700),
                const SizedBox(width: 4),
              ],
              Text(
                playerName + (isCurrentPlayer ? ' (you)' : ''),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isSheriff ? Colors.amber.shade800 : null,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$gold gold',
                  style: TextStyle(fontSize: 11, color: Colors.amber.shade900, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (goodCounts.isEmpty)
            Text('No goods yet', style: TextStyle(fontSize: 11, color: Colors.grey.shade500))
          else
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: goodCounts.entries.map((e) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: GoodCard.isContraband(e.key) ? Colors.red.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: GoodCard.isContraband(e.key) ? Colors.red.shade200 : Colors.green.shade200,
                    ),
                  ),
                  child: Text(
                    '${e.value}x ${e.key}',
                    style: TextStyle(
                      fontSize: 11,
                      color: GoodCard.isContraband(e.key) ? Colors.red.shade700 : Colors.green.shade700,
                    ),
                  ),
                );
              }).toList(),
            ),
          if (totalCount > visibleGoods.length) ...[
            const SizedBox(height: 4),
            Text(
              '+${totalCount - visibleGoods.length} hidden goods',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }
}
