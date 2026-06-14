import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/websocket_service.dart';
import 'services/game_controller.dart';
import 'screens/lobby_screen.dart';
import 'screens/game_screen.dart';
import 'models/game_state.dart';

void main() {
  runApp(const SheriffGameApp());
}

final navigatorKey = GlobalKey<NavigatorState>();

class SheriffGameApp extends StatelessWidget {
  const SheriffGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF3B6E47),
      brightness: Brightness.light,
    );

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Sheriff of Nottingham',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        fontFamily: 'Georgia',
        scaffoldBackgroundColor: const Color(0xFFFAF8F0),
        textTheme: ThemeData.light().textTheme.copyWith(
              bodyMedium: const TextStyle(fontSize: 16),
              titleLarge: const TextStyle(fontWeight: FontWeight.bold),
            ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
      ),
      home: const AppRoot(),
    );
  }
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => AppRootState();
}

class AppRootState extends State<AppRoot> {
  late WebSocketService _ws;
  late GameController _controller;
  bool _inGame = false;

  @override
  void initState() {
    super.initState();
    _createFreshServices();
  }

  void _createFreshServices() {
    _ws = WebSocketService();
    _controller = GameController(_ws);
    _controller.addListener(_onStateChange);
  }

  void _onStateChange() {
    final shouldBeInGame = _controller.phase != GamePhase.lobby &&
        _controller.phase != GamePhase.gameOver &&
        _controller.roomId.isNotEmpty;

    if (shouldBeInGame && !_inGame) {
      setState(() => _inGame = true);
    }
  }

  void returnToLobby() {
    _controller.removeListener(_onStateChange);
    _controller.dispose();
    _ws.dispose();

    setState(() {
      _inGame = false;
      _createFreshServices();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onStateChange);
    _controller.dispose();
    _ws.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: _inGame
          ? GameScreen(onReturnToLobby: returnToLobby)
          : LobbyScreen(wsService: _ws, controller: _controller),
    );
  }
}
