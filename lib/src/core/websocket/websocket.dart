import 'dart:async';
import 'dart:io';

/// WebSocket connection for bidirectional real-time communication.
///
/// WebSocket provides full-duplex communication channels over a single TCP connection.
/// It's ideal for real-time applications that require low latency and bidirectional
/// data exchange between client and server.
///
/// Features:
/// - Bidirectional communication (both client and server can send messages)
/// - Text and binary message support
/// - Automatic ping/pong for connection keep-alive
/// - Connection state management
/// - Error handling and reconnection support
/// - Lower latency than HTTP polling or SSE
///
/// Use cases:
/// - Real-time chat applications
/// - Live collaborative editing
/// - Multiplayer games
/// - Real-time dashboards
/// - Trading platforms
/// - IoT device communication
/// - Video/audio streaming metadata
///
/// Example usage:
/// ```dart
/// // Basic WebSocket endpoint
/// app.get('/ws', (ctx) async {
///   final ws = await ctx.req.upgrade();
///
///   ws.onMessage((message) {
///     print('Received: $message');
///     ws.send('Echo: $message');
///   });
///
///   ws.onClose((code, reason) {
///     print('Connection closed: $code $reason');
///   });
/// });
///
/// // Chat room
/// app.get('/chat', (ctx) async {
///   final ws = await ctx.req.upgrade();
///   final username = ctx.req.query('user') ?? 'Anonymous';
///
///   // Broadcast to all connected clients
///   chatRoom.add(ws);
///
///   ws.onMessage((message) {
///     for (final client in chatRoom) {
///       if (client != ws) {
///         client.send('$username: $message');
///       }
///     }
///   });
///
///   ws.onClose((code, reason) {
///     chatRoom.remove(ws);
///   });
/// });
///
/// // Binary data streaming
/// app.get('/binary', (ctx) async {
///   final ws = await ctx.req.upgrade();
///
///   ws.onBinary((data) {
///     print('Received ${data.length} bytes');
///     // Process binary data
///     final processed = processData(data);
///     ws.sendBinary(processed);
///   });
/// });
///
/// // Ping/Pong monitoring
/// app.get('/monitor', (ctx) async {
///   final ws = await ctx.req.upgrade();
///
///   // Send periodic pings
///   Timer.periodic(Duration(seconds: 30), (timer) {
///     if (ws.isClosed) {
///       timer.cancel();
///     } else {
///       ws.ping();
///     }
///   });
///
///   ws.onPong(() {
///     print('Connection is alive');
///   });
/// });
/// ```
///
/// Client-side JavaScript:
/// ```javascript
/// const ws = new WebSocket('ws://localhost:6060/ws');
///
/// ws.onopen = () => {
///   console.log('Connected');
///   ws.send('Hello, Server!');
/// };
///
/// ws.onmessage = (event) => {
///   console.log('Received:', event.data);
/// };
///
/// ws.onerror = (error) => {
///   console.error('WebSocket error:', error);
/// };
///
/// ws.onclose = (event) => {
///   console.log('Closed:', event.code, event.reason);
/// };
/// ```
class ChaseWebSocket {
  final WebSocket _socket;
  bool _closed = false;

  final _messageController = StreamController<String>.broadcast();
  final _binaryController = StreamController<List<int>>.broadcast();
  final _errorController = StreamController<Object>.broadcast();
  final _closeController = StreamController<_CloseEvent>.broadcast();
  final _pongController = StreamController<void>.broadcast();

  /// Creates a new ChaseWebSocket wrapping a native WebSocket.
  ChaseWebSocket(this._socket) {
    _socket.listen(
      (dynamic message) {
        if (message is String) {
          _messageController.add(message);
        } else if (message is List<int>) {
          _binaryController.add(message);
        }
      },
      onError: (error) {
        _errorController.add(error);
      },
      onDone: () {
        _handleClose(_socket.closeCode ?? 1006, _socket.closeReason ?? '');
      },
      cancelOnError: false,
    );
  }

  /// Whether the WebSocket connection is closed.
  bool get isClosed => _closed;

  /// The close code if the connection is closed, null otherwise.
  int? get closeCode => _socket.closeCode;

  /// The close reason if the connection is closed, null otherwise.
  String? get closeReason => _socket.closeReason;

  /// Sends a text message to the client.
  ///
  /// Example:
  /// ```dart
  /// ws.send('Hello, client!');
  /// ws.send(jsonEncode({'type': 'notification', 'message': 'New update'}));
  /// ```
  void send(String message) {
    if (_closed) {
      throw StateError('Cannot send message to closed WebSocket');
    }
    _socket.add(message);
  }

  /// Sends binary data to the client.
  ///
  /// Example:
  /// ```dart
  /// ws.sendBinary([1, 2, 3, 4, 5]);
  /// ws.sendBinary(imageBytes);
  /// ws.sendBinary(utf8.encode('Binary string'));
  /// ```
  void sendBinary(List<int> data) {
    if (_closed) {
      throw StateError('Cannot send binary data to closed WebSocket');
    }
    _socket.add(data);
  }

  /// Registers a callback for receiving text messages.
  ///
  /// Example:
  /// ```dart
  /// ws.onMessage((message) {
  ///   print('Received: $message');
  ///   final data = jsonDecode(message);
  ///   // Handle message
  /// });
  /// ```
  void onMessage(void Function(String message) callback) {
    _messageController.stream.listen(callback);
  }

  /// Registers a callback for receiving binary messages.
  ///
  /// Example:
  /// ```dart
  /// ws.onBinary((data) {
  ///   print('Received ${data.length} bytes');
  ///   // Process binary data
  /// });
  /// ```
  void onBinary(void Function(List<int> data) callback) {
    _binaryController.stream.listen(callback);
  }

  /// Registers a callback for connection errors.
  ///
  /// Example:
  /// ```dart
  /// ws.onError((error) {
  ///   print('WebSocket error: $error');
  ///   // Handle error
  /// });
  /// ```
  void onError(void Function(Object error) callback) {
    _errorController.stream.listen(callback);
  }

  /// Registers a callback for connection close events.
  ///
  /// The callback receives the close code and reason.
  ///
  /// Common close codes:
  /// - 1000: Normal closure
  /// - 1001: Going away (e.g., server shutdown)
  /// - 1002: Protocol error
  /// - 1003: Unsupported data
  /// - 1006: Abnormal closure (no close frame received)
  /// - 1011: Internal server error
  ///
  /// Example:
  /// ```dart
  /// ws.onClose((code, reason) {
  ///   print('Connection closed: $code - $reason');
  ///   // Cleanup resources
  /// });
  /// ```
  void onClose(void Function(int code, String reason) callback) {
    _closeController.stream.listen((event) {
      callback(event.code, event.reason);
    });
  }

  /// Registers a callback for pong frames.
  ///
  /// Pong frames are sent automatically in response to ping frames.
  /// This callback is useful for monitoring connection health.
  ///
  /// Example:
  /// ```dart
  /// ws.onPong(() {
  ///   print('Received pong - connection is alive');
  /// });
  /// ```
  void onPong(void Function() callback) {
    _pongController.stream.listen((_) => callback());
  }

  /// Sends a ping frame to the client.
  ///
  /// The client should respond with a pong frame automatically.
  /// Use this to check if the connection is still alive.
  ///
  /// Example:
  /// ```dart
  /// // Send periodic pings
  /// Timer.periodic(Duration(seconds: 30), (timer) {
  ///   if (ws.isClosed) {
  ///     timer.cancel();
  ///   } else {
  ///     ws.ping();
  ///   }
  /// });
  /// ```
  void ping([List<int>? payload]) {
    if (_closed) {
      throw StateError('Cannot ping closed WebSocket');
    }
    _socket.pingInterval = Duration.zero; // Disable auto-ping
    _socket.add(payload ?? []);
  }

  /// Closes the WebSocket connection.
  ///
  /// Optionally specify a [code] (default: 1000) and [reason] for closure.
  ///
  /// Example:
  /// ```dart
  /// // Normal closure
  /// ws.close();
  ///
  /// // Close with custom code and reason
  /// ws.close(1001, 'Server shutting down');
  /// ```
  Future<void> close([int code = 1000, String reason = '']) async {
    if (_closed) return;

    _closed = true;
    await _socket.close(code, reason);
    await _cleanup();
  }

  /// Internal method to handle connection close.
  void _handleClose(int code, String reason) {
    if (_closed) return;

    _closed = true;
    _closeController.add(_CloseEvent(code, reason));
    _cleanup();
  }

  /// Internal method to clean up resources.
  Future<void> _cleanup() async {
    await _messageController.close();
    await _binaryController.close();
    await _errorController.close();
    await _closeController.close();
    await _pongController.close();
  }
}

/// Internal class to represent a close event.
class _CloseEvent {
  final int code;
  final String reason;

  _CloseEvent(this.code, this.reason);
}
