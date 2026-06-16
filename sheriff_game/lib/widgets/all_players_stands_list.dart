import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/game_controller.dart';
import 'merchant_stand.dart';

/// List of every player's goods passed through customs (stand).
class AllPlayersStandsList extends StatelessWidget {
  final ScrollController? controller;

  const AllPlayersStandsList({super.key, this.controller});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<GameController>();

    if (ctrl.players.isEmpty) {
      return const Center(child: Text('No players'));
    }

    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.all(12),
      itemCount: ctrl.players.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final player = ctrl.players[i];
        final isMe = player == ctrl.playerName;
        return MerchantStand(
          playerName: player,
          visibleGoods: isMe ? ctrl.myStand : (ctrl.merchantStands[player] ?? []),
          totalCount: isMe ? ctrl.myStand.length : (ctrl.merchantStandCounts[player] ?? 0),
          gold: ctrl.gold[player] ?? 0,
          isSheriff: player == ctrl.sheriff,
          isCurrentPlayer: isMe,
        );
      },
    );
  }
}

void showAllPlayersStands(BuildContext context) {
  final theme = Theme.of(context);
  final sheetHeight = MediaQuery.sizeOf(context).height * 0.6;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (ctx) => SizedBox(
      height: sheetHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Goods passed customs',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'All players — legal goods are visible; contraband may be hidden on other stands',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          const Expanded(child: AllPlayersStandsList()),
        ],
      ),
    ),
  );
}
