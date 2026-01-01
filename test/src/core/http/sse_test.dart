import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chase/src/core/http/sse.dart';
import 'package:test/test.dart';

// Mock HttpResponse for testing
class MockHttpResponse implements HttpResponse {
  final List<List<int>> writtenData = [];
  final Completer<void> _doneCompleter = Completer<void>();
  bool _closed = false;

  @override
  Future<void> get done => _doneCompleter.future;

  @override
  void add(List<int> data) {
    writtenData.add(List.from(data));
  }

  @override
  Future<void> flush() async {}

  List<String> get writtenText =>
      writtenData.map((data) => utf8.decode(data)).toList();

  String get allText => writtenText.join();

  List<String> get messages {
    // Split by double newline to get individual SSE messages
    // Keep the trailing newline for each message
    final parts = allText.split('\n\n');
    return parts.where((s) => s.isNotEmpty).map((s) => '$s\n').toList();
  }

  // Unused HttpResponse methods
  @override
  bool bufferOutput = true;

  @override
  int contentLength = -1;

  @override
  Duration? deadline;

  @override
  Encoding encoding = utf8;

  @override
  bool persistentConnection = true;

  @override
  String reasonPhrase = 'OK';

  @override
  int statusCode = 200;

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  List<Cookie> get cookies => [];

  @override
  HttpHeaders get headers => throw UnimplementedError();

  @override
  Future addStream(Stream<List<int>> stream) => throw UnimplementedError();

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      throw UnimplementedError();

  @override
  Future close() async {
    if (_closed) return;
    _closed = true;
    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete();
    }
  }

  @override
  Future redirect(Uri location, {int status = HttpStatus.movedTemporarily}) =>
      throw UnimplementedError();

  @override
  void write(Object? object) => throw UnimplementedError();

  @override
  void writeAll(Iterable objects, [String separator = '']) =>
      throw UnimplementedError();

  @override
  void writeCharCode(int charCode) => throw UnimplementedError();

  @override
  void writeln([Object? object = '']) => throw UnimplementedError();

  @override
  Future<Socket> detachSocket({bool writeHeaders = true}) =>
      throw UnimplementedError();
}

void main() {
  group('Sse', () {
    late MockHttpResponse mockResponse;
    late Sse sse;

    setUp(() {
      mockResponse = MockHttpResponse();
      sse = Sse(mockResponse);
    });

    group('send', () {
      test('sends simple text data', () async {
        await sse.send('Hello, SSE!');

        expect(mockResponse.messages, hasLength(1));
        expect(mockResponse.messages[0], equals('data: Hello, SSE!\n'));
      });

      test('sends multiple messages', () async {
        await sse.send('Message 1');
        await sse.send('Message 2');
        await sse.send('Message 3');

        expect(mockResponse.messages, hasLength(3));
        expect(mockResponse.messages[0], equals('data: Message 1\n'));
        expect(mockResponse.messages[1], equals('data: Message 2\n'));
        expect(mockResponse.messages[2], equals('data: Message 3\n'));
      });

      test('sends JSON data from Map', () async {
        await sse.send({'user': 'Alice', 'message': 'Hello'});

        final message = mockResponse.messages[0];
        expect(message, startsWith('data: {'));
        expect(message, contains('"user":"Alice"'));
        expect(message, contains('"message":"Hello"'));
      });

      test('sends JSON data from List', () async {
        await sse.send([1, 2, 3, 4, 5]);

        final message = mockResponse.messages[0];
        expect(message, equals('data: [1,2,3,4,5]\n'));
      });

      test('sends data with custom event type', () async {
        await sse.send('Alert!', event: 'notification');

        final message = mockResponse.messages[0];
        expect(message, contains('event: notification\n'));
        expect(message, contains('data: Alert!\n'));
      });

      test('sends data with ID', () async {
        await sse.send('Message', id: '42');

        final message = mockResponse.messages[0];
        expect(message, contains('id: 42\n'));
        expect(message, contains('data: Message\n'));
      });

      test('sends data with retry interval', () async {
        await sse.send('Connection info', retry: 5000);

        final message = mockResponse.messages[0];
        expect(message, contains('retry: 5000\n'));
        expect(message, contains('data: Connection info\n'));
      });

      test('sends data with all optional parameters', () async {
        await sse.send('Full message', event: 'update', id: '123', retry: 3000);

        final message = mockResponse.messages[0];
        expect(message, contains('event: update\n'));
        expect(message, contains('id: 123\n'));
        expect(message, contains('retry: 3000\n'));
        expect(message, contains('data: Full message\n'));

        // Verify field order (event, id, retry, data)
        final lines = message.split('\n');
        expect(lines[0], equals('event: update'));
        expect(lines[1], equals('id: 123'));
        expect(lines[2], equals('retry: 3000'));
        expect(lines[3], equals('data: Full message'));
      });

      test('handles multi-line data', () async {
        await sse.send('Line 1\nLine 2\nLine 3');

        final message = mockResponse.messages[0];
        expect(message, contains('data: Line 1\n'));
        expect(message, contains('data: Line 2\n'));
        expect(message, contains('data: Line 3\n'));
      });

      test('handles empty string', () async {
        await sse.send('');

        final message = mockResponse.messages[0];
        expect(message, equals('data: \n'));
      });

      test('handles numeric data', () async {
        await sse.send(42);

        final message = mockResponse.messages[0];
        expect(message, equals('data: 42\n'));
      });

      test('handles boolean data', () async {
        await sse.send(true);

        final message = mockResponse.messages[0];
        expect(message, equals('data: true\n'));
      });

      test('ends each message with double newline', () async {
        await sse.send('Test');

        final text = mockResponse.allText;
        expect(text, endsWith('\n\n'));
      });
    });

    group('comment', () {
      test('sends comment with colon prefix', () async {
        await sse.comment('keep-alive');

        final text = mockResponse.allText;
        expect(text, equals(': keep-alive\n\n'));
      });

      test('sends multiple comments', () async {
        await sse.comment('comment 1');
        await sse.comment('comment 2');

        final text = mockResponse.allText;
        expect(text, equals(': comment 1\n\n: comment 2\n\n'));
      });

      test('handles empty comment', () async {
        await sse.comment('');

        final text = mockResponse.allText;
        expect(text, equals(': \n\n'));
      });

      test('can mix with data messages', () async {
        await sse.send('Message 1');
        await sse.comment('keep-alive');
        await sse.send('Message 2');

        final text = mockResponse.allText;
        expect(text, contains('data: Message 1\n\n'));
        expect(text, contains(': keep-alive\n\n'));
        expect(text, contains('data: Message 2\n\n'));
      });
    });

    group('SSE format compliance', () {
      test('follows W3C SSE specification format', () async {
        await sse.send('test data', event: 'message', id: '1', retry: 1000);

        final message = mockResponse.messages[0];
        final lines = message.split('\n').where((l) => l.isNotEmpty).toList();

        // Verify each line follows "field: value" format
        for (final line in lines) {
          expect(line, matches(r'^[a-z]+: .+$'));
        }
      });

      test('comment lines start with colon', () async {
        await sse.comment('test comment');

        final text = mockResponse.allText;
        expect(text, startsWith(':'));
      });

      test('messages are separated by blank lines', () async {
        await sse.send('Message 1');
        await sse.send('Message 2');

        final text = mockResponse.allText;
        expect(text, contains('\n\ndata: Message 2'));
      });
    });

    group('inheritance from Streaming', () {
      test('inherits close functionality', () async {
        await sse.send('Test');
        await sse.close();

        expect(sse.isClosed, isTrue);
        await expectLater(sse.done, completes);
      });

      test('inherits abort functionality', () async {
        unawaited(sse.done.catchError((_) {}));

        await sse.send('Test');
        await sse.abort();

        expect(sse.isClosed, isTrue);
      });

      test('inherits isClosed property', () {
        expect(sse.isClosed, isFalse);
      });

      test('throws when sending to closed stream', () async {
        await sse.close();

        expect(() => sse.send('Test'), throwsStateError);
      });
    });

    group('real-world scenarios', () {
      test('progress updates', () async {
        for (var i = 0; i <= 100; i += 25) {
          await sse.send(
            {'progress': i, 'status': 'Processing'},
            event: 'progress',
            id: '$i',
          );
        }

        expect(mockResponse.messages, hasLength(5));

        // Verify first message
        expect(mockResponse.messages[0], contains('event: progress'));
        expect(mockResponse.messages[0], contains('id: 0'));
        expect(mockResponse.messages[0], contains('"progress":0'));

        // Verify last message
        expect(mockResponse.messages[4], contains('id: 100'));
        expect(mockResponse.messages[4], contains('"progress":100'));
      });

      test('notification stream', () async {
        await sse.send(
          {'title': 'New message', 'body': 'You have 1 new message'},
          event: 'notification',
          id: '1',
        );

        await sse.send(
          {'title': 'Friend request', 'body': 'Alice wants to connect'},
          event: 'notification',
          id: '2',
        );

        expect(mockResponse.messages, hasLength(2));

        for (final message in mockResponse.messages) {
          expect(message, contains('event: notification'));
          expect(message, contains('id:'));
          expect(message, contains('"title"'));
          expect(message, contains('"body"'));
        }
      });

      test('keep-alive with periodic comments', () async {
        await sse.send('Initial data');
        await sse.comment('keep-alive');
        await Future.delayed(Duration(milliseconds: 10));
        await sse.comment('keep-alive');
        await sse.send('More data');

        final text = mockResponse.allText;
        expect(text, contains('data: Initial data\n\n'));
        expect(text, contains(': keep-alive\n\n'));
        expect(text, contains('data: More data\n\n'));
      });

      test('server time updates', () async {
        for (var i = 0; i < 3; i++) {
          await sse.send({
            'timestamp': DateTime.now().toIso8601String(),
            'value': i,
          }, event: 'time');
        }

        expect(mockResponse.messages, hasLength(3));

        for (final message in mockResponse.messages) {
          expect(message, contains('event: time'));
          expect(message, contains('"timestamp"'));
        }
      });
    });

    group('edge cases', () {
      test('handles very long data', () async {
        final longData = 'A' * 10000;
        await sse.send(longData);

        final message = mockResponse.messages[0];
        expect(message, contains('data: $longData'));
      });

      test('handles special characters in data', () async {
        await sse.send('Special: \n\r\t "quotes" \'apostrophes\'');

        expect(mockResponse.messages, isNotEmpty);
      });

      test('handles unicode in data', () async {
        await sse.send('Hello 世界 🌍');

        final message = mockResponse.messages[0];
        expect(message, contains('data: Hello 世界 🌍'));
      });

      test('handles nested JSON', () async {
        await sse.send({
          'user': {
            'name': 'Alice',
            'profile': {'age': 30, 'city': 'Tokyo'},
          },
          'messages': ['Hello', 'World'],
        });

        final message = mockResponse.messages[0];
        expect(message, contains('"name":"Alice"'));
        expect(message, contains('"age":30'));
        expect(message, contains('"messages":'));
      });
    });
  });
}
