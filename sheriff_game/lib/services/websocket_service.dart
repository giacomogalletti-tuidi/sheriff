import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  StreamController<Map<String, dynamic>>? _controller;
  StreamSubscription? _subscription;
  Timer? _keepAlive;
  bool _disposed = false;
  String? _uri;

  Stream<Map<String, dynamic>> get messages {
    _controller ??= StreamController<Map<String, dynamic>>.broadcast();
    return _controller!.stream;
  }

  bool get isConnected => _channel != null && !_disposed;

  void connect(String uri) {
    _disposed = false;
    _uri = uri;
    _channel = WebSocketChannel.connect(Uri.parse(uri));
    _controller ??= StreamController<Map<String, dynamic>>.broadcast();

    _subscription = _channel!.stream.listen(
      (data) {
        try {
          final decoded = jsonDecode(data as String) as Map<String, dynamic>;
          if (decoded['type'] == 'pong') return;
          if (!_controller!.isClosed) {
            _controller!.add(decoded);
          }
        } catch (_) {}
      },
      onError: (error) {
        if (!_controller!.isClosed) {
          _controller!.addError(error);
        }
      },
      onDone: () {
        _keepAlive?.cancel();
        if (!_disposed && !_controller!.isClosed) {
          _controller!.add({'type': 'connection_closed'});
          _attemptReconnect();
        }
      },
    );

    _startKeepAlive();
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

    Future.delayed(const Duration(seconds: 2), () {
      if (_disposed) return;
      try {
        _subscription?.cancel();
        _channel = WebSocketChannel.connect(Uri.parse(_uri!));
        _subscription = _channel!.stream.listen(
          (data) {
            try {
              final decoded = jsonDecode(data as String) as Map<String, dynamic>;
              if (decoded['type'] == 'pong') return;
              if (!_controller!.isClosed) {
                _controller!.add(decoded);
              }
            } catch (_) {}
          },
          onError: (_) {},
          onDone: () {
            _keepAlive?.cancel();
            if (!_disposed) {
              _attemptReconnect();
            }
          },
        );
        _startKeepAlive();
        if (!_controller!.isClosed) {
          _controller!.add({'type': 'connection_restored'});
        }
      } catch (_) {
        _attemptReconnect();
      }
    });
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
    _subscription?.cancel();
    _channel?.sink.close();
    _controller?.close();
    _channel = null;
    _controller = null;
  }
}
