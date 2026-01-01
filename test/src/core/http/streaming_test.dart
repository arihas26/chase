import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chase/src/core/http/streaming.dart';
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

  // Simulate client disconnect
  void simulateDisconnect() {
    if (!_doneCompleter.isCompleted) {
      _doneCompleter.completeError(SocketException('Connection closed'));
    }
  }

  // Complete the response normally
  void complete() {
    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete();
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
  group('Streaming', () {
    late MockHttpResponse mockResponse;
    late Streaming streaming;

    setUp(() {
      mockResponse = MockHttpResponse();
      streaming = Streaming(mockResponse);
    });

    group('writeBytes', () {
      test('writes binary data and flushes', () async {
        final data = [1, 2, 3, 4, 5];
        await streaming.writeBytes(data);

        expect(mockResponse.writtenData, hasLength(1));
        expect(mockResponse.writtenData[0], equals(data));
        expect(mockResponse.wasFlushed, isTrue);
      });

      test('writes multiple chunks', () async {
        await streaming.writeBytes([1, 2, 3]);
        await streaming.writeBytes([4, 5, 6]);
        await streaming.writeBytes([7, 8, 9]);

        expect(mockResponse.writtenData, hasLength(3));
        expect(mockResponse.writtenData[0], equals([1, 2, 3]));
        expect(mockResponse.writtenData[1], equals([4, 5, 6]));
        expect(mockResponse.writtenData[2], equals([7, 8, 9]));
      });

      test('throws when writing to closed stream', () async {
        await streaming.close();

        expect(() => streaming.writeBytes([1, 2, 3]), throwsStateError);
      });
    });

    group('pipe', () {
      test('pipes stream data to response', () async {
        final controller = StreamController<List<int>>();

        unawaited(streaming.pipe(controller.stream));

        controller.add([1, 2, 3]);
        await Future.delayed(Duration(milliseconds: 10));

        controller.add([4, 5, 6]);
        await Future.delayed(Duration(milliseconds: 10));

        await controller.close();
        await streaming.done;

        expect(mockResponse.writtenData, hasLength(2));
        expect(mockResponse.writtenData[0], equals([1, 2, 3]));
        expect(mockResponse.writtenData[1], equals([4, 5, 6]));
      });

      test('completes done future when piped stream ends', () async {
        final controller = StreamController<List<int>>();

        unawaited(streaming.pipe(controller.stream));

        controller.add([1, 2, 3]);
        await controller.close();

        await expectLater(streaming.done, completes);
      });

      test('handles piped stream errors', () async {
        final controller = StreamController<List<int>>();

        // Attach error handler to prevent unhandled error
        unawaited(streaming.done.catchError((_) {}));

        unawaited(streaming.pipe(controller.stream));

        controller.addError(Exception('Test error'));
        await Future.delayed(Duration(milliseconds: 10));

        expect(streaming.isClosed, isTrue);
      });

      test('throws when piping to closed stream', () async {
        await streaming.close();

        final controller = StreamController<List<int>>();

        expect(() => streaming.pipe(controller.stream), throwsStateError);
      });
    });

    group('close', () {
      test('closes stream normally', () async {
        await streaming.close();

        expect(streaming.isClosed, isTrue);
        await expectLater(streaming.done, completes);
      });

      test('prevents writes after close', () async {
        await streaming.close();

        expect(() => streaming.writeBytes([1, 2, 3]), throwsStateError);
      });

      test('idempotent - can be called multiple times', () async {
        await streaming.close();
        await streaming.close();
        await streaming.close();

        expect(streaming.isClosed, isTrue);
      });
    });

    group('abort', () {
      test('aborts stream and sets isClosed', () async {
        // Attach error handler to prevent unhandled error
        unawaited(streaming.done.catchError((_) {}));

        await streaming.abort();

        expect(streaming.isClosed, isTrue);
      });

      test('done future completes with error', () async {
        final doneFuture = streaming.done;

        await streaming.abort();

        await expectLater(doneFuture, throwsA(isA<StateError>()));
      });

      test('cancels active pipe subscription', () async {
        final controller = StreamController<List<int>>();
        var cancelled = false;

        controller.onCancel = () {
          cancelled = true;
        };

        unawaited(streaming.pipe(controller.stream));
        unawaited(streaming.done.catchError((_) {}));

        await streaming.abort();

        expect(cancelled, isTrue);
      });
    });

    group('onAbort', () {
      test('calls callback on client disconnect', () async {
        var abortCalled = false;

        streaming.onAbort(() {
          abortCalled = true;
        });

        mockResponse.simulateDisconnect();
        await Future.delayed(Duration(milliseconds: 10));

        expect(abortCalled, isTrue);
      });

      test('does not call callback after stream completes', () async {
        var abortCalled = false;

        streaming.onAbort(() {
          abortCalled = true;
        });

        await streaming.close();
        mockResponse.simulateDisconnect();
        await Future.delayed(Duration(milliseconds: 10));

        expect(abortCalled, isFalse);
      });
    });

    group('isClosed', () {
      test('returns false initially', () {
        expect(streaming.isClosed, isFalse);
      });

      test('returns true after close', () async {
        await streaming.close();
        expect(streaming.isClosed, isTrue);
      });

      test('returns true after abort', () async {
        unawaited(streaming.done.catchError((_) {}));
        await streaming.abort();
        expect(streaming.isClosed, isTrue);
      });
    });

    group('done future', () {
      test('completes on close', () async {
        final doneFuture = streaming.done;

        await streaming.close();

        await expectLater(doneFuture, completes);
      });

      test('completes with error on abort', () async {
        final doneFuture = streaming.done;

        await streaming.abort();

        await expectLater(doneFuture, throwsA(isA<StateError>()));
      });

      test('completes when piped stream ends', () async {
        final controller = StreamController<List<int>>();
        final doneFuture = streaming.done;

        unawaited(streaming.pipe(controller.stream));
        controller.add([1, 2, 3]);
        await controller.close();

        await expectLater(doneFuture, completes);
      });
    });

    group('edge cases', () {
      test('handles empty data writes', () async {
        await streaming.writeBytes([]);

        expect(mockResponse.writtenData, hasLength(1));
        expect(mockResponse.writtenData[0], isEmpty);
      });

      test('handles large data chunks', () async {
        final largeData = List.generate(1000000, (i) => i % 256);
        await streaming.writeBytes(largeData);

        expect(mockResponse.writtenData[0], hasLength(1000000));
      });

      test('handles rapid writes', () async {
        for (var i = 0; i < 100; i++) {
          await streaming.writeBytes([i]);
        }

        expect(mockResponse.writtenData, hasLength(100));
      });
    });
  });
}
