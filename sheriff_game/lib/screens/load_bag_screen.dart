import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/game_controller.dart';
import '../widgets/good_card.dart';

class LoadBagScreen extends StatefulWidget {
  const LoadBagScreen({super.key});

  @override
  State<LoadBagScreen> createState() => _LoadBagScreenState();
}

class _LoadBagScreenState extends State<LoadBagScreen> {
  final Set<int> _selected = {};
  bool _submitted = false;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<GameController>();
    final theme = Theme.of(context);

    if (_submitted || ctrl.bagLoaded.contains(ctrl.playerName)) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shopping_bag, size: 64, color: Colors.brown),
            const SizedBox(height: 16),
            Text('Bag sealed!', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            if (ctrl.myBag.isNotEmpty) ...[
              Text('Your bag contains:', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: ctrl.myBag.map((c) => GoodCard(name: c, width: 70, height: 96)).toList(),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              '${ctrl.bagLoaded.length}/${ctrl.merchants.length} bags loaded',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Load Your Merchant Bag', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Select 1-5 cards to place in your bag. Once sealed, you cannot change it.',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 20),

          Text('Your Hand', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(ctrl.hand.length, (i) {
              final card = ctrl.hand[i];
              final selected = _selected.contains(i);
              return GoodCard(
                name: card,
                selected: selected,
                onTap: () {
                  setState(() {
                    if (selected) {
                      _selected.remove(i);
                    } else if (_selected.length < 5) {
                      _selected.add(i);
                    }
                  });
                },
              );
            }),
          ),

          const SizedBox(height: 16),
          if (_selected.isNotEmpty) ...[
            Text(
              'Bag Preview (${_selected.length} card${_selected.length > 1 ? 's' : ''})',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.brown.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.brown.shade200),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selected.map((i) {
                  return GoodCard(name: ctrl.hand[i], width: 70, height: 96);
                }).toList(),
              ),
            ),
          ],

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.lock),
              onPressed: _selected.isNotEmpty && _selected.length <= 5
                  ? () => _sealBag(ctrl)
                  : null,
              label: Text('Seal Bag (${_selected.length} cards)'),
            ),
          ),
        ],
      ),
    );
  }

  void _sealBag(GameController ctrl) {
    final cards = _selected.map((i) => ctrl.hand[i]).toList();
    ctrl.submitLoadBag(cards);
    setState(() => _submitted = true);
  }
}
