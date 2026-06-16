import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/card.dart';
import '../services/game_controller.dart';
import 'good_card.dart';
import 'all_players_stands_list.dart';

/// Compact summary of goods the player has passed through customs (their stand).
class MyGoodsPanel extends StatelessWidget {
  const MyGoodsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<GameController>();
    final theme = Theme.of(context);

    final counts = <String, int>{};
    for (final good in ctrl.myStand) {
      counts[good] = (counts[good] ?? 0) + 1;
    }

    final sortedTypes = CardCatalog.legalGoods.map((c) => c.name).toList()
      ..addAll(CardCatalog.contrabandGoods.map((c) => c.name));
    final entries = sortedTypes
        .where((t) => (counts[t] ?? 0) > 0)
        .map((t) => MapEntry(t, counts[t]!))
        .toList();

    final total = ctrl.myStand.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.storefront, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                'Goods passed customs',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '$total total',
                style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => showAllPlayersStands(context),
                icon: const Icon(Icons.people_outline, size: 18),
                label: const Text('All players'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (entries.isEmpty)
            Text(
              'No goods on your stand yet',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: entries.map((e) {
                  final contraband = GoodCard.isContraband(e.key);
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: contraband ? Colors.red.shade50 : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: contraband ? Colors.red.shade200 : Colors.green.shade200,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${e.value}×',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: contraband ? Colors.red.shade800 : Colors.green.shade800,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            e.key,
                            style: TextStyle(
                              fontSize: 12,
                              color: contraband ? Colors.red.shade700 : Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
