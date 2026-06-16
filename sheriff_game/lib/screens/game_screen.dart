import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/game_controller.dart';
import '../models/game_state.dart';
import '../widgets/game_top_bar.dart';
import '../widgets/all_players_stands_list.dart';
import '../widgets/my_goods_panel.dart';
import 'market_screen.dart';
import 'load_bag_screen.dart';
import 'declaration_screen.dart';
import 'inspection_screen.dart';
import 'end_game_screen.dart';

class GameScreen extends StatelessWidget {
  final VoidCallback? onReturnToLobby;

  const GameScreen({super.key, this.onReturnToLobby});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameController>(
      builder: (context, ctrl, _) {
        return Scaffold(
          endDrawer: _buildStandsDrawer(context, ctrl),
          body: Column(
            children: [
              const GameTopBar(),
              if (ctrl.phase != GamePhase.gameOver && ctrl.phase != GamePhase.lobby)
                const MyGoodsPanel(),
              if (ctrl.disconnectMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  color: Colors.red.shade100,
                  child: Text(
                    ctrl.disconnectMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red.shade900),
                  ),
                ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildPhaseView(ctrl),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStandsDrawer(BuildContext context, GameController ctrl) {
    final theme = Theme.of(context);
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Goods passed customs',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'All players',
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

  Widget _buildPhaseView(GameController ctrl) {
    switch (ctrl.phase) {
      case GamePhase.market:
        if (ctrl.isSheriff) {
          return const _WaitingView(
            key: ValueKey('sheriff-wait-market'),
            title: 'Market Phase',
            message: 'You are the Sheriff this round.\nWait while merchants select their goods...',
            icon: Icons.shield,
          );
        }
        return const MarketScreen(key: ValueKey('market'));

      case GamePhase.loadBag:
        if (ctrl.isSheriff) {
          return const _WaitingView(
            key: ValueKey('sheriff-wait-bag'),
            title: 'Loading Bags',
            message: 'Merchants are loading their bags...',
            icon: Icons.shopping_bag,
          );
        }
        return const LoadBagScreen(key: ValueKey('loadBag'));

      case GamePhase.declaration:
        if (ctrl.isSheriff) {
          return _DeclarationWaitView(key: const ValueKey('sheriff-wait-decl'), ctrl: ctrl);
        }
        return const DeclarationScreen(key: ValueKey('declaration'));

      case GamePhase.inspection:
        return const InspectionScreen(key: ValueKey('inspection'));

      case GamePhase.endOfRound:
        return const _WaitingView(
          key: ValueKey('endOfRound'),
          title: 'End of Round',
          message: 'Preparing next round...',
          icon: Icons.refresh,
        );

      case GamePhase.gameOver:
        return EndGameScreen(
          key: const ValueKey('gameOver'),
          scores: ctrl.finalScores,
          onReturnToLobby: onReturnToLobby,
        );

      default:
        return const _WaitingView(
          key: ValueKey('loading'),
          title: 'Loading...',
          message: 'Waiting for game to start...',
          icon: Icons.hourglass_empty,
        );
    }
  }
}

class _WaitingView extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const _WaitingView({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          const CircularProgressIndicator(),
        ],
      ),
    );
  }
}

class _DeclarationWaitView extends StatelessWidget {
  final GameController ctrl;

  const _DeclarationWaitView({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Declarations', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Waiting for merchants to declare...',
            style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: ctrl.merchants.length,
              itemBuilder: (context, i) {
                final merchant = ctrl.merchants[i];
                final decl = ctrl.declarations[merchant];
                final hasDeclared = ctrl.declared.contains(merchant);

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: hasDeclared ? Colors.green.shade100 : Colors.grey.shade200,
                      child: Text(merchant[0].toUpperCase()),
                    ),
                    title: Text(merchant),
                    subtitle: hasDeclared && decl != null
                        ? Text('${decl['declaredCount']} ${decl['declaredType']}')
                        : const Text('Thinking...'),
                    trailing: hasDeclared
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
