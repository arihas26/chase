import 'dart:io';

import 'package:chase/chase.dart';
import 'package:test/test.dart';

void main() {
  group('Error Handling', () {
    late Chase app;
    late HttpServer server;
    late HttpClient client;

    setUp(() async {
      app = Chase();
      client = HttpClient();
    });

    tearDown(() async {
      client.close();
      await server.close(force: true);
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

      server = await app.start(port: 0);
      final port = server.port;

      final request = await client.get('localhost', port, '/throw');
      final response = await request.close();
      final body = await response.transform(const SystemEncoding().decoder).join();

      expect(response.statusCode, HttpStatus.ok);
      expect(body, contains('Test error'));
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

      server = await app.start(port: 0);
      final port = server.port;

      final request = await client.get('localhost', port, '/fail');
      final response = await request.close();
      final body = await response.transform(const SystemEncoding().decoder).join();

      expect(response.statusCode, HttpStatus.ok);
      expect(response.headers.value('X-Error'), 'true');
      expect(body, contains('/fail'));
    });

    test('default error returns 500 when no handler', () async {
      app.get('/error').handle((ctx) {
        throw Exception('Unhandled');
      });

      server = await app.start(port: 0);
      final port = server.port;

      final request = await client.get('localhost', port, '/error');
      final response = await request.close();
      final body = await response.transform(const SystemEncoding().decoder).join();

      expect(response.statusCode, HttpStatus.internalServerError);
      expect(body, 'Internal Server Error');
    });

    test('onError can return string response', () async {
      app.onError((error, stackTrace, ctx) {
        return 'Error: ${error.toString()}';
      });

      app.get('/throw').handle((ctx) {
        throw FormatException('Bad format');
      });

      server = await app.start(port: 0);
      final port = server.port;

      final request = await client.get('localhost', port, '/throw');
      final response = await request.close();
      final body = await response.transform(const SystemEncoding().decoder).join();

      expect(response.statusCode, HttpStatus.ok);
      expect(body, contains('Bad format'));
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

      server = await app.start(port: 0);
      final port = server.port;

      final request = await client.get('localhost', port, '/protected');
      final response = await request.close();
      final body = await response.transform(const SystemEncoding().decoder).join();

      expect(errorCaught, isTrue);
      expect(body, contains('middleware_error'));
    });

    test('async errors are caught', () async {
      app.onError((error, stackTrace, ctx) {
        return {'async_error': error.toString()};
      });

      app.get('/async').handle((ctx) async {
        await Future.delayed(Duration(milliseconds: 10));
        throw Exception('Async failure');
      });

      server = await app.start(port: 0);
      final port = server.port;

      final request = await client.get('localhost', port, '/async');
      final response = await request.close();
      final body = await response.transform(const SystemEncoding().decoder).join();

      expect(response.statusCode, HttpStatus.ok);
      expect(body, contains('Async failure'));
    });
  });
}

class _ThrowingMiddleware implements Middleware {
  @override
  dynamic handle(Context ctx, NextFunction next) {
    throw UnimplementedError('Middleware error');
  }
}
