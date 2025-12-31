import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chase/src/core/context/context.dart';
import 'package:chase/src/core/http/sse.dart';
import 'package:chase/src/core/http/streaming.dart';
import 'package:chase/src/core/http/text_streaming.dart';
import 'package:test/test.dart';

// Mock HttpResponse for testing
class MockHttpResponse implements HttpResponse {
  final Completer<void> _doneCompleter = Completer<void>();

  @override
  Future<void> get done => _doneCompleter.future;

  @override
  void add(List<int> data) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) async {}

  @override
  Future<void> close() async {
    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete();
    }
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future flush() async {}

  // Unused HttpResponse properties/methods
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
  HttpHeaders get headers => MockHttpHeaders();

  @override
  Future redirect(Uri location, {int status = HttpStatus.movedTemporarily}) =>
      throw UnimplementedError();

  @override
  void write(Object? object) {}

  @override
  void writeAll(Iterable objects, [String separator = '']) {}

  @override
  void writeCharCode(int charCode) {}

  @override
  void writeln([Object? object = '']) {}

  @override
  Future<Socket> detachSocket({bool writeHeaders = true}) => throw UnimplementedError();
}

class MockHttpHeaders implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// Mock HttpRequest for testing
class MockHttpRequest implements HttpRequest {
  final MockHttpResponse _response = MockHttpResponse();

  @override
  HttpResponse get response => _response;

  @override
  String get method => 'GET';

  @override
  Uri get uri => Uri.parse('http://localhost/');

  @override
  HttpHeaders get headers => MockHttpHeaders();

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  X509Certificate? get certificate => null;

  @override
  HttpSession get session => throw UnimplementedError();

  @override
  String get protocolVersion => '1.1';

  @override
  int get contentLength => 0;

  @override
  bool get persistentConnection => true;

  @override
  List<Cookie> get cookies => [];

  @override
  Uri get requestedUri => Uri.parse('http://localhost/');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('ContextProtocols', () {
    late Context ctx;

    setUp(() {
      final mockRequest = MockHttpRequest();
      ctx = Context(mockRequest, mockRequest.response);
    });

    test('stream() returns Streaming instance', () {
      final streaming = ctx.res.stream();

      expect(streaming, isA<Streaming>());
      expect(streaming.isClosed, isFalse);
    });

    test('textStream() returns TextStreaming instance', () {
      final textStream = ctx.res.textStream();

      expect(textStream, isA<TextStreaming>());
      expect(textStream.isClosed, isFalse);
    });

    test('sse() returns Sse instance', () {
      final sse = ctx.res.sse();

      expect(sse, isA<Sse>());
      expect(sse.isClosed, isFalse);
    });

    test('all protocol methods use the same response', () {
      final streaming = ctx.res.stream();
      final textStream = ctx.res.textStream();
      final sse = ctx.res.sse();

      // All should wrap the same HttpResponse
      expect(streaming, isA<Streaming>());
      expect(textStream, isA<TextStreaming>());
      expect(sse, isA<Sse>());
    });

    // Note: upgrade() is tested in test/integration/websocket_upgrade_test.dart
    // since it requires a real WebSocket connection
  });
}
