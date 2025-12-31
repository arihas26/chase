import 'dart:io';

import 'package:chase/chase.dart';
import 'package:chase/testing/testing.dart';
import 'package:test/test.dart';

void main() {
  group('Error Handling', () {
    late Chase app;
    late TestClient client;

    setUp(() async {
      app = Chase();
    });

    tearDown(() async {
      await client.close();
    });

    test('onError catches handler exceptions', () async {
      Object? capturedError;
      StackTrace? capturedStackTrace;

      app.onError((error, stackTrace, ctx) {
        capturedError = error;
        capturedStackTrace = stackTrace;
        return {'error': error.toString()};
      });

      app.get('/throw').handle((ctx) {
        throw Exception('Test error');
      });

      client = await TestClient.start(app);

      final res = await client.get('/throw');

      expect(res.status, HttpStatus.ok);
      expect(await res.body, contains('Test error'));
      expect(capturedError, isA<Exception>());
      expect(capturedStackTrace, isNotNull);
    });

    test('onError receives context for custom responses', () async {
      app.onError((error, stackTrace, ctx) {
        ctx.res.headers.set('X-Error', 'true');
        return {'error': 'handled', 'path': ctx.req.path};
      });

      app.get('/fail').handle((ctx) {
        throw StateError('Intentional failure');
      });

      client = await TestClient.start(app);

      final res = await client.get('/fail');

      expect(res.status, HttpStatus.ok);
      expect(res.headers.value('X-Error'), 'true');
      expect(await res.body, contains('/fail'));
    });

    test('default error returns 500 when no handler', () async {
      app.get('/error').handle((ctx) {
        throw Exception('Unhandled');
      });

      client = await TestClient.start(app);

      final res = await client.get('/error');

      expect(res.status, HttpStatus.internalServerError);
      expect(await res.body, 'Internal Server Error');
    });

    test('onError can return string response', () async {
      app.onError((error, stackTrace, ctx) {
        return 'Error: ${error.toString()}';
      });

      app.get('/throw').handle((ctx) {
        throw FormatException('Bad format');
      });

      client = await TestClient.start(app);

      final res = await client.get('/throw');

      expect(res.status, HttpStatus.ok);
      expect(await res.body, contains('Bad format'));
    });

    test('middleware errors are caught', () async {
      var errorCaught = false;

      app.onError((error, stackTrace, ctx) {
        errorCaught = true;
        return {'middleware_error': true};
      });

      app.get('/protected').use(_ThrowingMiddleware()).handle((ctx) {
        return {'success': true};
      });

      client = await TestClient.start(app);

      final res = await client.get('/protected');

      expect(errorCaught, isTrue);
      expect(await res.body, contains('middleware_error'));
    });

    test('async errors are caught', () async {
      app.onError((error, stackTrace, ctx) {
        return {'async_error': error.toString()};
      });

      app.get('/async').handle((ctx) async {
        await Future.delayed(Duration(milliseconds: 10));
        throw Exception('Async failure');
      });

      client = await TestClient.start(app);

      final res = await client.get('/async');

      expect(res.status, HttpStatus.ok);
      expect(await res.body, contains('Async failure'));
    });
  });
}

class _ThrowingMiddleware implements Middleware {
  @override
  dynamic handle(Context ctx, NextFunction next) {
    throw UnimplementedError('Middleware error');
  }
}
