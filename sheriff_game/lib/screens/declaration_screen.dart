import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/game_controller.dart';
import '../widgets/good_card.dart';

class DeclarationScreen extends StatefulWidget {
  const DeclarationScreen({super.key});

  @override
  State<DeclarationScreen> createState() => _DeclarationScreenState();
}

class _DeclarationScreenState extends State<DeclarationScreen> {
  String _declaredType = 'apple';
  bool _submitted = false;

  static const _legalTypes = ['apple', 'cheese', 'bread', 'chicken'];

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<GameController>();
    final theme = Theme.of(context);
    final bagCount = ctrl.myBag.length;

    if (_submitted || ctrl.declared.contains(ctrl.playerName)) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.record_voice_over, size: 64, color: Colors.blue),
            const SizedBox(height: 16),
            Text('Declaration submitted!', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              '"I have $bagCount $_declaredType${bagCount > 1 ? 's' : ''}!"',
              style: theme.textTheme.bodyLarge?.copyWith(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 16),
            Text(
              '${ctrl.declared.length}/${ctrl.merchants.length} declared',
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
          Text('Declaration Phase', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Tell the Sheriff what\'s in your bag. You must declare the exact number of cards, but you may lie about the type!',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 20),

          Text('Your Bag', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.brown.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.brown.shade200),
            ),
            child: ctrl.myBag.isEmpty
                ? const Text('Empty bag')
                : Wrap(
                    spacing: 8,
                    children: ctrl.myBag.map((c) => GoodCard(name: c, width: 70, height: 96)).toList(),
                  ),
          ),

          const SizedBox(height: 24),
          Text('Your Declaration', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '"I have $bagCount...',
                    style: theme.textTheme.bodyLarge?.copyWith(fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _legalTypes.map((type) {
                      final selected = _declaredType == type;
                      return ChoiceChip(
                        label: Text(
                          type[0].toUpperCase() + type.substring(1),
                          style: TextStyle(
                            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        selected: selected,
                        onSelected: (_) => setState(() => _declaredType = type),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '...$_declaredType${bagCount > 1 ? 's' : ''}!"',
                    style: theme.textTheme.bodyLarge?.copyWith(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),
          _buildHonestyHint(ctrl),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.campaign),
              onPressed: bagCount > 0 ? () => _submit(ctrl) : null,
              label: Text('Declare: $bagCount $_declaredType${bagCount > 1 ? 's' : ''}'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHonestyHint(GameController ctrl) {
    final bag = ctrl.myBag;
    final allSameType = bag.every((c) => c == _declaredType);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: allSameType ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: allSameType ? Colors.green.shade200 : Colors.orange.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            allSameType ? Icons.check_circle : Icons.warning,
            color: allSameType ? Colors.green : Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              allSameType
                  ? 'Honest declaration -- if inspected, the Sheriff pays you!'
                  : 'Bluffing! If inspected, you pay penalties for undeclared goods.',
              style: TextStyle(
                fontSize: 13,
                color: allSameType ? Colors.green.shade700 : Colors.orange.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _submit(GameController ctrl) {
    ctrl.submitDeclaration(_declaredType, ctrl.myBag.length);
    setState(() => _submitted = true);
  }
}
