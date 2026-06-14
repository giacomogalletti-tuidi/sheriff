import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/websocket_service.dart';
import '../services/game_controller.dart';

class LobbyScreen extends StatefulWidget {
  final WebSocketService wsService;
  final GameController controller;

  const LobbyScreen({
    super.key,
    required this.wsService,
    required this.controller,
  });

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final _nameController = TextEditingController();
  final _roomController = TextEditingController();
  final _serverUrlController = TextEditingController();
  bool _connected = false;

  static const _defaultWsUrl = String.fromEnvironment(
    'SHERIFF_WS_URL',
    defaultValue: '',
  );

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onStateChange);
  }

  void _onStateChange() {
    if (!mounted) return;

    final ctrl = widget.controller;

    if (ctrl.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ctrl.errorMessage!), backgroundColor: Colors.red),
      );
      ctrl.errorMessage = null;
    }

    setState(() {});
  }

  String _getWebSocketUrl() {
    final custom = _serverUrlController.text.trim();
    if (custom.isNotEmpty) {
      return custom.endsWith('/ws') ? custom : '$custom/ws';
    }
    if (_defaultWsUrl.isNotEmpty) {
      return _defaultWsUrl.endsWith('/ws') ? _defaultWsUrl : '$_defaultWsUrl/ws';
    }
    try {
      final uri = Uri.base;
      final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
      final host = uri.host;
      final port = (host == 'localhost' || host == '127.0.0.1') ? 8080 : uri.port;
      return '$scheme://$host:$port/ws';
    } catch (_) {
      return 'ws://localhost:8080/ws';
    }
  }

  void _connect() {
    widget.wsService.connect(_getWebSocketUrl());
    setState(() => _connected = true);
  }

  void _createRoom() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    if (!_connected) _connect();
    widget.controller.createRoom(name);
  }

  void _joinRoom() {
    final name = _nameController.text.trim();
    final roomId = _roomController.text.trim().toUpperCase();
    if (name.isEmpty || roomId.isEmpty) return;
    if (!_connected) _connect();
    widget.controller.joinRoom(name, roomId);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onStateChange);
    _nameController.dispose();
    _roomController.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final inRoom = ctrl.roomId.isNotEmpty;
    final isReady = ctrl.readyPlayers.contains(ctrl.playerName);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sheriff of Nottingham'),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!inRoom) ...[
                  const SizedBox(height: 24),
                  Icon(Icons.shield, size: 80, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Welcome, Merchant!',
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Your name',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _serverUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Server URL (optional)',
                      hintText: 'ws://host:8080/ws',
                      prefixIcon: Icon(Icons.dns),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add_box),
                    onPressed: _createRoom,
                    label: const Text('Create New Room'),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _roomController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Room Code',
                            prefixIcon: Icon(Icons.meeting_room),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.login),
                        onPressed: _joinRoom,
                        label: const Text('Join'),
                      ),
                    ],
                  ),
                ] else ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text('Room Code', style: theme.textTheme.labelMedium),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                ctrl.roomId,
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 4,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 20),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: ctrl.roomId));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Room code copied!')),
                                  );
                                },
                              ),
                            ],
                          ),
                          Text(
                            '${ctrl.players.length} player${ctrl.players.length != 1 ? 's' : ''} connected',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Card(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(8),
                        itemCount: ctrl.players.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final player = ctrl.players[index];
                          final ready = ctrl.readyPlayers.contains(player);
                          final isMe = player == ctrl.playerName;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: ready
                                  ? Colors.green.shade100
                                  : Colors.grey.shade200,
                              child: Text(
                                player[0].toUpperCase(),
                                style: TextStyle(
                                  color: ready ? Colors.green.shade800 : Colors.grey.shade600,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              player + (isMe ? ' (you)' : ''),
                              style: TextStyle(
                                fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            trailing: ready
                                ? const Icon(Icons.check_circle, color: Colors.green)
                                : const Icon(Icons.hourglass_empty, color: Colors.grey),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (ctrl.countdown != null)
                    Center(
                      child: Text(
                        'Game starts in ${ctrl.countdown}...',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  if (ctrl.players.length < 3)
                    Center(
                      child: Text(
                        'Need at least 3 players to start',
                        style: TextStyle(color: Colors.orange.shade700),
                      ),
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: ctrl.players.length >= 3 && ctrl.countdown == null
                          ? () => ctrl.toggleReady()
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isReady ? Colors.orange : Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(isReady ? 'Cancel Ready' : 'Ready!'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
