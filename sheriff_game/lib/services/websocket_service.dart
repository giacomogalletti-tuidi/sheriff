import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  StreamController<Map<String, dynamic>>? _controller;
  StreamSubscription? _subscription;
  Timer? _keepAlive;
  Timer? _reconnectTimer;
  bool _disposed = false;
  String? _uri;
  int _reconnectAttempts = 0;

  static const _maxReconnectAttempts = 30;
  static const _baseDelay = Duration(seconds: 2);
  static const _maxDelay = Duration(seconds: 60);

  Stream<Map<String, dynamic>> get messages {
    _controller ??= StreamController<Map<String, dynamic>>.broadcast();
    return _controller!.stream;
  }

  bool get isConnected => _channel != null && !_disposed;

  void connect(String uri) {
    _disposed = false;
    _uri = uri;
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    _channel = WebSocketChannel.connect(Uri.parse(uri));
    _controller ??= StreamController<Map<String, dynamic>>.broadcast();
    _attachListen();
    _startKeepAlive();
  }

  void _attachListen() {
    _subscription?.cancel();
    _subscription = _channel!.stream.listen(
      _onData,
      onError: (_) {
        if (!_disposed && _controller != null && !_controller!.isClosed) {
          _scheduleReconnect();
        }
      },
      onDone: _onDone,
    );
  }

  void _onData(dynamic data) {
    try {
      final decoded = jsonDecode(data as String) as Map<String, dynamic>;
      if (decoded['type'] == 'pong') return;
      if (_controller != null && !_controller!.isClosed) {
        _controller!.add(decoded);
      }
    } catch (_) {}
  }

  void _onDone() {
    _keepAlive?.cancel();
    if (!_disposed && _controller != null && !_controller!.isClosed) {
      _controller!.add({'type': 'connection_closed'});
      _scheduleReconnect();
    }
  }

  Duration _reconnectDelay() {
    final exp = min(_reconnectAttempts, 5);
    final delay = _baseDelay * (1 << exp);
    return delay > _maxDelay ? _maxDelay : delay;
  }

  void _scheduleReconnect() {
    if (_disposed || _uri == null) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      if (_controller != null && !_controller!.isClosed) {
        _controller!.add({
          'type': 'connection_closed',
          'message': 'Could not reconnect after $_maxReconnectAttempts attempts',
        });
      }
      return;
    }

    _reconnectTimer?.cancel();
    final delay = _reconnectDelay();
    _reconnectAttempts++;
    _reconnectTimer = Timer(delay, _attemptReconnect);
  }

  void _startKeepAlive() {
    _keepAlive?.cancel();
    _keepAlive = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_channel != null && !_disposed) {
        try {
          _channel!.sink.add(jsonEncode({'type': 'ping'}));
        } catch (_) {}
      }
    });
  }

  void _attemptReconnect() {
    if (_disposed || _uri == null) return;

    try {
      _subscription?.cancel();
      _channel = WebSocketChannel.connect(Uri.parse(_uri!));
      _attachListen();
      _startKeepAlive();
      _reconnectAttempts = 0;
      if (_controller != null && !_controller!.isClosed) {
        _controller!.add({'type': 'connection_restored'});
      }
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void send(Map<String, dynamic> message) {
    if (_channel != null && !_disposed) {
      try {
        _channel!.sink.add(jsonEncode(message));
      } catch (_) {}
    }
  }

  void dispose() {
    _disposed = true;
    _keepAlive?.cancel();
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _controller?.close();
    _channel = null;
    _controller = null;
  }
}
