import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/game_controller.dart';
import '../models/game_state.dart';

class GameTopBar extends StatelessWidget {
  const GameTopBar({super.key});

  String _phaseLabel(GamePhase phase) {
    switch (phase) {
      case GamePhase.market:
        return 'Market';
      case GamePhase.loadBag:
        return 'Load Bag';
      case GamePhase.declaration:
        return 'Declaration';
      case GamePhase.inspection:
        return 'Inspection';
      case GamePhase.endOfRound:
        return 'End of Round';
      case GamePhase.gameOver:
        return 'Game Over';
      default:
        return 'Lobby';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<GameController>();
    final theme = Theme.of(context);
    final phase = ctrl.phase;

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _PhaseIndicator(phase: phase, label: _phaseLabel(phase)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Round ${ctrl.round}',
                  style: theme.textTheme.labelSmall,
                ),
                Row(
                  children: [
                    Icon(Icons.shield, size: 14, color: Colors.amber.shade700),
                    const SizedBox(width: 4),
                    Text(
                      ctrl.sheriff ?? '...',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (ctrl.isSheriff)
                      Text(
                        ' (you)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.monetization_on, size: 16, color: Colors.amber.shade800),
                const SizedBox(width: 4),
                Text(
                  '${ctrl.myGold}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => Scaffold.of(context).openEndDrawer(),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.storefront, size: 20, color: theme.colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhaseIndicator extends StatelessWidget {
  final GamePhase phase;
  final String label;

  const _PhaseIndicator({required this.phase, required this.label});

  int get _phaseIndex {
    switch (phase) {
      case GamePhase.market: return 0;
      case GamePhase.loadBag: return 1;
      case GamePhase.declaration: return 2;
      case GamePhase.inspection: return 3;
      case GamePhase.endOfRound: return 4;
      default: return -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final idx = _phaseIndex;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (idx >= 0) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (i) {
              return Container(
                width: 8,
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: i <= idx
                      ? theme.colorScheme.primary
                      : theme.colorScheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}
