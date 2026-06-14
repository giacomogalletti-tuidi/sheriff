import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/game_controller.dart';
import '../widgets/good_card.dart';

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  final Set<int> _selectedToDiscard = {};
  final List<String> _drawSources = [];
  String _discardTarget = 'discard1';
  bool _submitted = false;

  int get _numDiscards => _selectedToDiscard.length;
  int get _numDraws => _drawSources.length;
  int get _remainingDraws => _numDiscards - _numDraws;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<GameController>();
    final theme = Theme.of(context);

    if (_submitted || ctrl.marketDone.contains(ctrl.playerName)) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            Text('Market action submitted!', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Waiting for other merchants...',
              style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Text(
              '${ctrl.marketDone.length}/${ctrl.merchants.length} ready',
              style: theme.textTheme.bodyMedium,
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
          Text('Market Phase', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Select cards to discard (0-5), then choose where to draw replacements.',
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
              final selected = _selectedToDiscard.contains(i);
              return GoodCard(
                name: card,
                selected: selected,
                onTap: _numDraws > 0
                    ? null
                    : () {
                        setState(() {
                          if (selected) {
                            _selectedToDiscard.remove(i);
                          } else if (_selectedToDiscard.length < 5) {
                            _selectedToDiscard.add(i);
                          }
                        });
                      },
              );
            }),
          ),

          if (_selectedToDiscard.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Discard to:',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'discard1', label: Text('Pile 1')),
                ButtonSegment(value: 'discard2', label: Text('Pile 2')),
              ],
              selected: {_discardTarget},
              onSelectionChanged: (val) {
                setState(() => _discardTarget = val.first);
              },
            ),
          ],

          if (_numDiscards > 0 && _remainingDraws > 0) ...[
            const SizedBox(height: 20),
            Text(
              'Draw $_remainingDraws card${_remainingDraws > 1 ? 's' : ''} from:',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _DrawButton(
                  label: 'Pile 1',
                  subtitle: ctrl.discardPile1Top ?? 'empty',
                  enabled: ctrl.discardPile1Top != null,
                  onTap: () => setState(() => _drawSources.add('discard1')),
                ),
                const SizedBox(width: 8),
                _DrawButton(
                  label: 'Pile 2',
                  subtitle: ctrl.discardPile2Top ?? 'empty',
                  enabled: ctrl.discardPile2Top != null,
                  onTap: () => setState(() => _drawSources.add('discard2')),
                ),
                const SizedBox(width: 8),
                _DrawButton(
                  label: 'Draw Pile',
                  subtitle: '${ctrl.deckCount} left',
                  enabled: true,
                  onTap: () => setState(() => _drawSources.add('deck')),
                ),
              ],
            ),
            if (_drawSources.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: _drawSources.asMap().entries.map((e) {
                  return Chip(
                    label: Text(e.value),
                    onDeleted: () {
                      setState(() => _drawSources.removeAt(e.key));
                    },
                  );
                }).toList(),
              ),
            ],
          ],

          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: (_numDiscards == 0 || _remainingDraws == 0)
                        ? () => _submit(ctrl)
                        : null,
                    child: Text(_numDiscards == 0 ? 'Skip Market (Keep Hand)' : 'Confirm Market Action'),
                  ),
                ),
                if (_numDiscards > 0 && _remainingDraws > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Choose $_remainingDraws more draw source${_remainingDraws > 1 ? 's' : ''}',
                      style: TextStyle(color: Colors.orange.shade700),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _submit(GameController ctrl) {
    final discards = _selectedToDiscard.map((i) => ctrl.hand[i]).toList();
    ctrl.submitMarketAction(
      discards: discards,
      drawSources: _drawSources,
      discardTarget: _discardTarget,
    );
    setState(() => _submitted = true);
  }
}

class _DrawButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;

  const _DrawButton({
    required this.label,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton(
        onPressed: enabled ? onTap : null,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(subtitle, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
