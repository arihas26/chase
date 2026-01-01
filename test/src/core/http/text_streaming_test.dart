import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chase/src/core/http/text_streaming.dart';
import 'package:test/test.dart';

// Mock HttpResponse for testing
class MockHttpResponse implements HttpResponse {
  final List<List<int>> writtenData = [];
  final Completer<void> _doneCompleter = Completer<void>();
  bool _flushed = false;
  bool _closed = false;

  @override
  Future<void> get done => _doneCompleter.future;

  @override
  void add(List<int> data) {
    writtenData.add(List.from(data));
  }

  @override
  Future<void> flush() async {
    _flushed = true;
  }

  bool get wasFlushed => _flushed;

  List<String> get writtenText =>
      writtenData.map((data) => utf8.decode(data)).toList();

  String get allText => writtenText.join();

  // Simulate client disconnect
  void simulateDisconnect() {
    if (!_doneCompleter.isCompleted) {
      _doneCompleter.completeError(SocketException('Connection closed'));
    }
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
  group('TextStreaming', () {
    late MockHttpResponse mockResponse;
    late TextStreaming streaming;

    setUp(() {
      mockResponse = MockHttpResponse();
      streaming = TextStreaming(mockResponse);
    });

    group('write', () {
      test('writes text as UTF-8', () async {
        await streaming.write('Hello, World!');

        expect(mockResponse.writtenText, hasLength(1));
        expect(mockResponse.writtenText[0], equals('Hello, World!'));
      });

      test('writes multiple text chunks', () async {
        await streaming.write('Hello, ');
        await streaming.write('World!');

        expect(mockResponse.writtenText, hasLength(2));
        expect(mockResponse.writtenText[0], equals('Hello, '));
        expect(mockResponse.writtenText[1], equals('World!'));
        expect(mockResponse.allText, equals('Hello, World!'));
      });

      test('handles empty strings', () async {
        await streaming.write('');

        expect(mockResponse.writtenText, hasLength(1));
        expect(mockResponse.writtenText[0], isEmpty);
      });

      test('handles unicode characters', () async {
        await streaming.write('Hello, 世界! 🌍');

        expect(mockResponse.writtenText, hasLength(1));
        expect(mockResponse.writtenText[0], equals('Hello, 世界! 🌍'));
      });

      test('handles multi-byte unicode', () async {
        await streaming.write('😀😃😄😁');

        expect(mockResponse.writtenText, hasLength(1));
        expect(mockResponse.writtenText[0], equals('😀😃😄😁'));
      });

      test('handles special characters', () async {
        await streaming.write('Tab:\t Newline:\n Return:\r Quote:"');

        expect(mockResponse.writtenText, hasLength(1));
        expect(
          mockResponse.writtenText[0],
          equals('Tab:\t Newline:\n Return:\r Quote:"'),
        );
      });

      test('encodes as UTF-8 bytes', () async {
        await streaming.write('Hello');

        // Verify the actual bytes are UTF-8 encoded
        final expectedBytes = utf8.encode('Hello');
        expect(mockResponse.writtenData[0], equals(expectedBytes));
      });

      test('throws when writing to closed stream', () async {
        await streaming.close();

        expect(() => streaming.write('test'), throwsStateError);
      });
    });

    group('writeln', () {
      test('writes text with newline', () async {
        await streaming.writeln('Hello');

        expect(mockResponse.writtenText, hasLength(1));
        expect(mockResponse.writtenText[0], equals('Hello\n'));
      });

      test('writes multiple lines', () async {
        await streaming.writeln('Line 1');
        await streaming.writeln('Line 2');
        await streaming.writeln('Line 3');

        expect(mockResponse.writtenText, hasLength(3));
        expect(mockResponse.allText, equals('Line 1\nLine 2\nLine 3\n'));
      });

      test('handles empty lines', () async {
        await streaming.writeln('');

        expect(mockResponse.writtenText, hasLength(1));
        expect(mockResponse.writtenText[0], equals('\n'));
      });

      test('adds newline to text already containing newlines', () async {
        await streaming.writeln('Line 1\nLine 2');

        expect(mockResponse.writtenText, hasLength(1));
        expect(mockResponse.writtenText[0], equals('Line 1\nLine 2\n'));
      });

      test('throws when writing to closed stream', () async {
        await streaming.close();

        expect(() => streaming.writeln('test'), throwsStateError);
      });
    });

    group('mixed operations', () {
      test('can mix write and writeln', () async {
        await streaming.write('Hello, ');
        await streaming.writeln('World!');
        await streaming.write('How ');
        await streaming.writeln('are you?');

        expect(mockResponse.allText, equals('Hello, World!\nHow are you?\n'));
      });

      test('can use writeBytes with write', () async {
        await streaming.writeBytes([72, 101, 108, 108, 111]); // "Hello"
        await streaming.write(' World');

        expect(mockResponse.allText, equals('Hello World'));
      });
    });

    group('streaming scenarios', () {
      test('streams log output', () async {
        await streaming.writeln('[INFO] Starting process');
        await streaming.writeln('[DEBUG] Loading configuration');
        await streaming.writeln('[INFO] Process complete');

        expect(mockResponse.writtenText, hasLength(3));
        expect(
          mockResponse.allText,
          equals(
            '[INFO] Starting process\n[DEBUG] Loading configuration\n[INFO] Process complete\n',
          ),
        );
      });

      test('streams NDJSON', () async {
        final event1 = jsonEncode({'event': 'start', 'timestamp': 1234567890});
        final event2 = jsonEncode({'event': 'update', 'data': 'test'});
        final event3 = jsonEncode({'event': 'end'});

        await streaming.writeln(event1);
        await streaming.writeln(event2);
        await streaming.writeln(event3);

        expect(mockResponse.writtenText, hasLength(3));

        // Verify each line is valid JSON
        final lines = mockResponse.allText.trim().split('\n');
        expect(lines, hasLength(3));

        final decoded1 = jsonDecode(lines[0]);
        expect(decoded1['event'], equals('start'));

        final decoded2 = jsonDecode(lines[1]);
        expect(decoded2['event'], equals('update'));

        final decoded3 = jsonDecode(lines[2]);
        expect(decoded3['event'], equals('end'));
      });

      test('streams progressive HTML', () async {
        await streaming.write('<!DOCTYPE html><html><body>');
        await streaming.write('<h1>Streaming Content</h1>');
        await streaming.write('<p>This is progressive rendering.</p>');
        await streaming.write('</body></html>');

        expect(
          mockResponse.allText,
          equals(
            '<!DOCTYPE html><html><body><h1>Streaming Content</h1><p>This is progressive rendering.</p></body></html>',
          ),
        );
      });

      test('streams large text content', () async {
        final largeText = 'A' * 100000;
        await streaming.write(largeText);

        expect(mockResponse.writtenText[0], hasLength(100000));
        expect(mockResponse.allText, equals(largeText));
      });
    });

    group('inheritance from Streaming', () {
      test('inherits pipe functionality', () async {
        final controller = StreamController<List<int>>();

        unawaited(streaming.pipe(controller.stream));

        controller.add(utf8.encode('Hello '));
        controller.add(utf8.encode('World'));
        await controller.close();

        await streaming.done;

        expect(mockResponse.allText, equals('Hello World'));
      });

      test('inherits close functionality', () async {
        await streaming.write('Test');
        await streaming.close();

        expect(streaming.isClosed, isTrue);
        await expectLater(streaming.done, completes);
      });

      test('inherits abort functionality', () async {
        await streaming.write('Test');
        await streaming.abort();

        expect(streaming.isClosed, isTrue);
        await expectLater(streaming.done, throwsA(isA<StateError>()));
      });

      test('inherits onAbort functionality', () async {
        var abortCalled = false;

        streaming.onAbort(() {
          abortCalled = true;
        });

        mockResponse.simulateDisconnect();
        await Future.delayed(Duration(milliseconds: 10));

        expect(abortCalled, isTrue);
      });
    });

    group('edge cases', () {
      test('handles very long lines', () async {
        final longLine = 'A' * 10000;
        await streaming.writeln(longLine);

        expect(mockResponse.writtenText[0], equals('$longLine\n'));
      });

      test('handles rapid writes', () async {
        for (var i = 0; i < 100; i++) {
          await streaming.write('$i ');
        }

        expect(mockResponse.writtenText, hasLength(100));
      });

      test('handles null character', () async {
        await streaming.write('Before\x00After');

        expect(mockResponse.writtenText[0], equals('Before\x00After'));
      });

      test('handles all whitespace types', () async {
        await streaming.write(' \t\n\r\f\v');

        expect(mockResponse.writtenText[0], equals(' \t\n\r\f\v'));
      });
    });
  });
}
