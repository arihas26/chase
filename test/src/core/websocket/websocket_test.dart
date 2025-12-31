import 'dart:async';
import 'dart:io';

import 'package:chase/src/core/websocket/websocket.dart';
import 'package:test/test.dart';

// Mock WebSocket for testing
class MockWebSocket implements WebSocket {
  final List<dynamic> sentMessages = [];
  final StreamController<dynamic> _messageController = StreamController<dynamic>.broadcast();
  final Completer<void> _doneCompleter = Completer<void>();

  int? _closeCode;
  String? _closeReason;
  bool _closed = false;

  @override
  int? get closeCode => _closeCode;

  @override
  String? get closeReason => _closeReason;

  @override
  void add(dynamic data) {
    if (_closed) {
      throw StateError('WebSocket is closed');
    }
    sentMessages.add(data);
  }

  @override
  Future<void> addStream(Stream stream) async {
    await for (final data in stream) {
      add(data);
    }
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    if (_closed) return;

    _closed = true;
    _closeCode = code ?? 1000;
    _closeReason = reason ?? '';

    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete();
    }
    await _messageController.close();
  }

  @override
  Future get done => _doneCompleter.future;

  // Methods to simulate receiving messages
  void simulateMessage(String message) {
    _messageController.add(message);
  }

  void simulateBinary(List<int> data) {
    _messageController.add(data);
  }

  void simulateError(Object error) {
    _messageController.addError(error);
  }

  void simulateClose([int code = 1000, String reason = '']) {
    _closeCode = code;
    _closeReason = reason;
    _closed = true;
    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete();
    }
    _messageController.close();
  }

  @override
  StreamSubscription listen(
    void Function(dynamic event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _messageController.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  // Implement required WebSocket properties
  @override
  Duration? pingInterval;

  @override
  String? get protocol => null;

  @override
  int get readyState => _closed ? 3 : 1;

  @override
  String get extensions => '';

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      throw UnimplementedError();

  @override
  void addUtf8Text(List<int> bytes) => add(bytes);

  // Use noSuchMethod to handle all Stream methods we don't need
  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

void main() {
  group('ChaseWebSocket', () {
    late MockWebSocket mockSocket;
    late ChaseWebSocket ws;

    setUp(() {
      mockSocket = MockWebSocket();
      ws = ChaseWebSocket(mockSocket);
    });

    tearDown(() async {
      if (!ws.isClosed) {
        await ws.close();
      }
    });

    group('send', () {
      test('sends text message', () {
        ws.send('Hello, WebSocket!');

        expect(mockSocket.sentMessages, hasLength(1));
        expect(mockSocket.sentMessages[0], equals('Hello, WebSocket!'));
      });

      test('sends multiple text messages', () {
        ws.send('Message 1');
        ws.send('Message 2');
        ws.send('Message 3');

        expect(mockSocket.sentMessages, hasLength(3));
        expect(mockSocket.sentMessages[0], equals('Message 1'));
        expect(mockSocket.sentMessages[1], equals('Message 2'));
        expect(mockSocket.sentMessages[2], equals('Message 3'));
      });

      test('throws when sending to closed socket', () async {
        await ws.close();

        expect(() => ws.send('test'), throwsStateError);
      });
    });

    group('sendBinary', () {
      test('sends binary data', () {
        ws.sendBinary([1, 2, 3, 4, 5]);

        expect(mockSocket.sentMessages, hasLength(1));
        expect(mockSocket.sentMessages[0], equals([1, 2, 3, 4, 5]));
      });

      test('sends multiple binary messages', () {
        ws.sendBinary([1, 2, 3]);
        ws.sendBinary([4, 5, 6]);

        expect(mockSocket.sentMessages, hasLength(2));
        expect(mockSocket.sentMessages[0], equals([1, 2, 3]));
        expect(mockSocket.sentMessages[1], equals([4, 5, 6]));
      });

      test('throws when sending to closed socket', () async {
        await ws.close();

        expect(() => ws.sendBinary([1, 2, 3]), throwsStateError);
      });
    });

    group('onMessage', () {
      test('receives text messages', () async {
        final messages = <String>[];

        ws.onMessage((message) {
          messages.add(message);
        });

        mockSocket.simulateMessage('Hello');
        mockSocket.simulateMessage('World');

        await Future.delayed(Duration(milliseconds: 10));

        expect(messages, hasLength(2));
        expect(messages[0], equals('Hello'));
        expect(messages[1], equals('World'));
      });

      test('supports multiple listeners', () async {
        final messages1 = <String>[];
        final messages2 = <String>[];

        ws.onMessage((message) => messages1.add(message));
        ws.onMessage((message) => messages2.add(message));

        mockSocket.simulateMessage('Test');

        await Future.delayed(Duration(milliseconds: 10));

        expect(messages1, equals(['Test']));
        expect(messages2, equals(['Test']));
      });
    });

    group('onBinary', () {
      test('receives binary messages', () async {
        final messages = <List<int>>[];

        ws.onBinary((data) {
          messages.add(data);
        });

        mockSocket.simulateBinary([1, 2, 3]);
        mockSocket.simulateBinary([4, 5, 6]);

        await Future.delayed(Duration(milliseconds: 10));

        expect(messages, hasLength(2));
        expect(messages[0], equals([1, 2, 3]));
        expect(messages[1], equals([4, 5, 6]));
      });

      test('does not receive text messages', () async {
        final messages = <List<int>>[];

        ws.onBinary((data) => messages.add(data));

        mockSocket.simulateMessage('Not binary');

        await Future.delayed(Duration(milliseconds: 10));

        expect(messages, isEmpty);
      });
    });

    group('onError', () {
      test('handles errors', () async {
        final errors = <Object>[];

        ws.onError((error) => errors.add(error));

        final testError = Exception('Test error');
        mockSocket.simulateError(testError);

        await Future.delayed(Duration(milliseconds: 10));

        expect(errors, hasLength(1));
        expect(errors[0], equals(testError));
      });
    });

    group('onClose', () {
      test('handles normal close', () async {
        final closeEvents = <Map<String, dynamic>>[];

        ws.onClose((code, reason) {
          closeEvents.add({'code': code, 'reason': reason});
        });

        mockSocket.simulateClose(1000, 'Normal closure');

        await Future.delayed(Duration(milliseconds: 10));

        expect(closeEvents, hasLength(1));
        expect(closeEvents[0]['code'], equals(1000));
        expect(closeEvents[0]['reason'], equals('Normal closure'));
      });

      test('handles abnormal close', () async {
        final closeEvents = <Map<String, dynamic>>[];

        ws.onClose((code, reason) {
          closeEvents.add({'code': code, 'reason': reason});
        });

        mockSocket.simulateClose(1006, 'Abnormal closure');

        await Future.delayed(Duration(milliseconds: 10));

        expect(closeEvents, hasLength(1));
        expect(closeEvents[0]['code'], equals(1006));
      });
    });

    group('close', () {
      test('closes with default code', () async {
        await ws.close();

        expect(ws.isClosed, isTrue);
        expect(mockSocket.closeCode, equals(1000));
        expect(mockSocket.closeReason, isEmpty);
      });

      test('closes with custom code and reason', () async {
        await ws.close(1001, 'Going away');

        expect(ws.isClosed, isTrue);
        expect(mockSocket.closeCode, equals(1001));
        expect(mockSocket.closeReason, equals('Going away'));
      });

      test('is idempotent', () async {
        await ws.close();
        await ws.close();
        await ws.close();

        expect(ws.isClosed, isTrue);
      });

      test('triggers onClose callback', () async {
        var callbackCalled = false;

        ws.onClose((code, reason) {
          callbackCalled = true;
        });

        await ws.close();

        // Give time for async cleanup
        await Future.delayed(Duration(milliseconds: 10));

        expect(callbackCalled, isFalse); // close() doesn't trigger onClose
      });
    });

    group('isClosed', () {
      test('returns false initially', () {
        expect(ws.isClosed, isFalse);
      });

      test('returns true after close', () async {
        await ws.close();
        expect(ws.isClosed, isTrue);
      });

      test('returns true after remote close', () async {
        mockSocket.simulateClose();
        await Future.delayed(Duration(milliseconds: 10));
        expect(ws.isClosed, isTrue);
      });
    });

    group('closeCode and closeReason', () {
      test('are null when open', () {
        expect(ws.closeCode, isNull);
        expect(ws.closeReason, isNull);
      });

      test('are set after close', () async {
        await ws.close(1001, 'Test reason');

        expect(ws.closeCode, equals(1001));
        expect(ws.closeReason, equals('Test reason'));
      });
    });

    group('mixed operations', () {
      test('can send and receive messages', () async {
        final received = <String>[];

        ws.onMessage((message) => received.add(message));

        ws.send('Outgoing 1');
        mockSocket.simulateMessage('Incoming 1');
        ws.send('Outgoing 2');
        mockSocket.simulateMessage('Incoming 2');

        await Future.delayed(Duration(milliseconds: 10));

        expect(mockSocket.sentMessages, hasLength(2));
        expect(mockSocket.sentMessages[0], equals('Outgoing 1'));
        expect(mockSocket.sentMessages[1], equals('Outgoing 2'));

        expect(received, hasLength(2));
        expect(received[0], equals('Incoming 1'));
        expect(received[1], equals('Incoming 2'));
      });

      test('can mix text and binary messages', () async {
        final textMessages = <String>[];
        final binaryMessages = <List<int>>[];

        ws.onMessage((message) => textMessages.add(message));
        ws.onBinary((data) => binaryMessages.add(data));

        ws.send('Text message');
        ws.sendBinary([1, 2, 3]);
        mockSocket.simulateMessage('Incoming text');
        mockSocket.simulateBinary([4, 5, 6]);

        await Future.delayed(Duration(milliseconds: 10));

        expect(mockSocket.sentMessages, hasLength(2));
        expect(textMessages, equals(['Incoming text']));
        expect(binaryMessages, equals([
          [4, 5, 6]
        ]));
      });
    });

    group('real-world scenarios', () {
      test('chat message exchange', () async {
        final messages = <String>[];

        ws.onMessage((message) {
          messages.add(message);
          // Echo back
          ws.send('Echo: $message');
        });

        mockSocket.simulateMessage('Hello');
        await Future.delayed(Duration(milliseconds: 10));

        expect(messages, equals(['Hello']));
        expect(mockSocket.sentMessages, equals(['Echo: Hello']));
      });

      test('JSON data exchange', () async {
        ws.send('{"type":"connect","user":"Alice"}');
        ws.send('{"type":"message","text":"Hello"}');

        expect(mockSocket.sentMessages, hasLength(2));
        expect(mockSocket.sentMessages[0], contains('"type":"connect"'));
        expect(mockSocket.sentMessages[1], contains('"type":"message"'));
      });

      test('handles rapid messages', () async {
        final messages = <String>[];
        ws.onMessage((message) => messages.add(message));

        for (var i = 0; i < 100; i++) {
          mockSocket.simulateMessage('Message $i');
        }

        await Future.delayed(Duration(milliseconds: 50));

        expect(messages, hasLength(100));
      });
    });

    group('edge cases', () {
      test('handles empty string message', () {
        ws.send('');
        expect(mockSocket.sentMessages, equals(['']));
      });

      test('handles empty binary data', () {
        ws.sendBinary([]);
        expect(mockSocket.sentMessages, equals([
          []
        ]));
      });

      test('handles very long message', () {
        final longMessage = 'A' * 100000;
        ws.send(longMessage);
        expect(mockSocket.sentMessages[0], hasLength(100000));
      });

      test('handles unicode messages', () {
        ws.send('Hello 世界 🌍');
        expect(mockSocket.sentMessages, equals(['Hello 世界 🌍']));
      });

      test('handles special characters', () {
        ws.send('Special: \n\r\t "quotes" \'apostrophes\'');
        expect(mockSocket.sentMessages, hasLength(1));
      });
    });
  });
}
