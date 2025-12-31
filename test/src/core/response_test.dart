import 'dart:convert';
import 'dart:io';

import 'package:chase/chase.dart';
import 'package:chase/testing/testing.dart';
import 'package:test/test.dart';

void main() {
  group('Response', () {
    group('constructors', () {
      test('creates response with status code and body', () {
        final response = Response(200, body: 'Hello');
        expect(response.statusCode, 200);
        expect(response.body, 'Hello');
        expect(response.headers, isEmpty);
      });

      test('creates response with headers', () {
        final response = Response(
          200,
          body: 'Hello',
          headers: {'x-custom': 'value'},
        );
        expect(response.headers['x-custom'], 'value');
      });
    });

    group('success responses (2xx)', () {
      test('ok() creates 200 response', () {
        final response = Response.ok('Hello');
        expect(response.statusCode, HttpStatus.ok);
        expect(response.body, 'Hello');
      });

      test('ok() with JSON body', () {
        final response = Response.ok({'message': 'Hello'});
        expect(response.statusCode, HttpStatus.ok);
        expect(response.body, {'message': 'Hello'});
      });

      test('created() creates 201 response', () {
        final response = Response.created({'id': 1});
        expect(response.statusCode, HttpStatus.created);
        expect(response.body, {'id': 1});
      });

      test('noContent() creates 204 response', () {
        final response = Response.noContent();
        expect(response.statusCode, HttpStatus.noContent);
        expect(response.body, isNull);
      });

      test('accepted() creates 202 response', () {
        final response = Response.accepted({'status': 'processing'});
        expect(response.statusCode, HttpStatus.accepted);
      });
    });

    group('redirection responses (3xx)', () {
      test('movedPermanently() creates 301 redirect', () {
        final response = Response.movedPermanently('/new-location');
        expect(response.statusCode, HttpStatus.movedPermanently);
        expect(response.headers['location'], '/new-location');
      });

      test('found() creates 302 redirect', () {
        final response = Response.found('/temporary');
        expect(response.statusCode, HttpStatus.found);
        expect(response.headers['location'], '/temporary');
      });

      test('seeOther() creates 303 redirect', () {
        final response = Response.seeOther('/other');
        expect(response.statusCode, HttpStatus.seeOther);
        expect(response.headers['location'], '/other');
      });

      test('temporaryRedirect() creates 307 redirect', () {
        final response = Response.temporaryRedirect('/temp');
        expect(response.statusCode, HttpStatus.temporaryRedirect);
        expect(response.headers['location'], '/temp');
      });

      test('permanentRedirect() creates 308 redirect', () {
        final response = Response.permanentRedirect('/permanent');
        expect(response.statusCode, HttpStatus.permanentRedirect);
        expect(response.headers['location'], '/permanent');
      });
    });

    group('client error responses (4xx)', () {
      test('badRequest() creates 400 response', () {
        final response = Response.badRequest({'error': 'Invalid input'});
        expect(response.statusCode, HttpStatus.badRequest);
      });

      test('unauthorized() creates 401 response', () {
        final response = Response.unauthorized({'error': 'Auth required'});
        expect(response.statusCode, HttpStatus.unauthorized);
      });

      test('forbidden() creates 403 response', () {
        final response = Response.forbidden({'error': 'Access denied'});
        expect(response.statusCode, HttpStatus.forbidden);
      });

      test('notFound() creates 404 response', () {
        final response = Response.notFound({'error': 'Not found'});
        expect(response.statusCode, HttpStatus.notFound);
      });

      test('methodNotAllowed() creates 405 response', () {
        final response = Response.methodNotAllowed();
        expect(response.statusCode, HttpStatus.methodNotAllowed);
      });

      test('conflict() creates 409 response', () {
        final response = Response.conflict({'error': 'Resource conflict'});
        expect(response.statusCode, HttpStatus.conflict);
      });

      test('unprocessableEntity() creates 422 response', () {
        final response = Response.unprocessableEntity({'errors': []});
        expect(response.statusCode, HttpStatus.unprocessableEntity);
      });

      test('tooManyRequests() creates 429 response', () {
        final response = Response.tooManyRequests({'error': 'Rate limited'});
        expect(response.statusCode, HttpStatus.tooManyRequests);
      });
    });

    group('server error responses (5xx)', () {
      test('internalServerError() creates 500 response', () {
        final response = Response.internalServerError({'error': 'Server error'});
        expect(response.statusCode, HttpStatus.internalServerError);
      });

      test('badGateway() creates 502 response', () {
        final response = Response.badGateway();
        expect(response.statusCode, HttpStatus.badGateway);
      });

      test('serviceUnavailable() creates 503 response', () {
        final response = Response.serviceUnavailable({'error': 'Maintenance'});
        expect(response.statusCode, HttpStatus.serviceUnavailable);
      });
    });

    group('convenience constructors', () {
      test('json() creates JSON response with content-type header', () {
        final response = Response.json({'key': 'value'});
        expect(response.statusCode, HttpStatus.ok);
        expect(response.headers['content-type'], 'application/json; charset=utf-8');
        expect(response.body, {'key': 'value'});
      });

      test('json() with custom status', () {
        final response = Response.json({'error': 'Not found'}, status: 404);
        expect(response.statusCode, 404);
      });

      test('text() creates text response with content-type header', () {
        final response = Response.text('Hello, World!');
        expect(response.statusCode, HttpStatus.ok);
        expect(response.headers['content-type'], 'text/plain; charset=utf-8');
        expect(response.body, 'Hello, World!');
      });

      test('html() creates HTML response with content-type header', () {
        final response = Response.html('<h1>Hello</h1>');
        expect(response.statusCode, HttpStatus.ok);
        expect(response.headers['content-type'], 'text/html; charset=utf-8');
        expect(response.body, '<h1>Hello</h1>');
      });
    });
  });

  group('Response integration', () {
    late Chase app;
    late TestClient client;

    setUp(() async {
      app = Chase();
      client = await TestClient.start(app);
    });

    tearDown(() async {
      await client.close();
    });

    test('handler can return Response.ok()', () async {
      app.get('/text').handle((ctx) {
        return Response.ok('Hello from Response!');
      });

      final res = await client.get('/text');
      expect(res.status, 200);
      expect(await res.body, 'Hello from Response!');
    });

    test('handler can return Response.json()', () async {
      app.get('/json').handle((ctx) {
        return Response.json({'message': 'Hello', 'framework': 'chase'});
      });

      final res = await client.get('/json');
      expect(res.status, 200);
      expect(res.headers['content-type']?.first, contains('application/json'));
      final body = jsonDecode(await res.body) as Map<String, dynamic>;
      expect(body['message'], 'Hello');
      expect(body['framework'], 'chase');
    });

    test('handler can return Response.created()', () async {
      app.post('/users').handle((ctx) {
        return Response.created({'id': 1, 'name': 'John'});
      });

      final res = await client.post('/users');
      expect(res.status, 201);
      final body = jsonDecode(await res.body) as Map<String, dynamic>;
      expect(body['id'], 1);
    });

    test('handler can return Response.notFound()', () async {
      app.get('/missing').handle((ctx) {
        return Response.notFound({'error': 'Resource not found'});
      });

      final res = await client.get('/missing');
      expect(res.status, 404);
    });

    test('handler can return Response with redirect', () async {
      app.get('/old').handle((ctx) {
        return Response.movedPermanently('/new');
      });

      final res = await client.get('/old');
      expect(res.status, 301);
      expect(res.headers['location']?.first, '/new');
    });

    test('handler can return Response.noContent()', () async {
      app.delete('/item').handle((ctx) {
        return Response.noContent();
      });

      final res = await client.delete('/item');
      expect(res.status, 204);
      expect(await res.body, isEmpty);
    });

    test('handler can still use ctx.res (imperative API)', () async {
      app.get('/imperative').handle((ctx) {
        ctx.res.text('Hello from ctx.res!');
      });

      final res = await client.get('/imperative');
      expect(res.status, 200);
      expect(await res.body, 'Hello from ctx.res!');
    });

    test('handler can mix ctx.res headers with Response', () async {
      app.get('/mixed').handle((ctx) {
        ctx.res.headers.set('x-custom', 'from-ctx');
        return Response.ok('Response body', {'x-response': 'from-response'});
      });

      final res = await client.get('/mixed');
      expect(res.status, 200);
      // Note: Response.writeTo() sets headers, which may override ctx.res headers
      expect(res.headers['x-response']?.first, 'from-response');
    });

    test('async handler can return Response', () async {
      app.get('/async').handle((ctx) async {
        await Future.delayed(Duration(milliseconds: 10));
        return Response.ok({'async': true});
      });

      final res = await client.get('/async');
      expect(res.status, 200);
      final body = jsonDecode(await res.body) as Map<String, dynamic>;
      expect(body['async'], true);
    });
  });

  group('Return value auto-handling', () {
    late Chase app;
    late TestClient client;

    setUp(() async {
      app = Chase();
      client = await TestClient.start(app);
    });

    tearDown(() async {
      await client.close();
    });

    test('returning String sends text/plain response', () async {
      app.get('/string').handle((ctx) {
        return 'Hello World';
      });

      final res = await client.get('/string');
      expect(res.status, 200);
      expect(await res.body, 'Hello World');
      expect(res.headers['content-type']?.first, contains('text/plain'));
    });

    test('returning Map sends application/json response', () async {
      app.get('/map').handle((ctx) {
        return {'message': 'Hello', 'count': 42};
      });

      final res = await client.get('/map');
      expect(res.status, 200);
      expect(res.headers['content-type']?.first, contains('application/json'));
      final body = jsonDecode(await res.body) as Map<String, dynamic>;
      expect(body['message'], 'Hello');
      expect(body['count'], 42);
    });

    test('returning List sends application/json response', () async {
      app.get('/list').handle((ctx) {
        return [1, 2, 3, 'four'];
      });

      final res = await client.get('/list');
      expect(res.status, 200);
      expect(res.headers['content-type']?.first, contains('application/json'));
      final body = jsonDecode(await res.body) as List;
      expect(body, [1, 2, 3, 'four']);
    });

    test('returning null (void) works with ctx.res', () async {
      app.get('/void').handle((ctx) {
        ctx.res.text('Via ctx.res');
        return null;
      });

      final res = await client.get('/void');
      expect(res.status, 200);
      expect(await res.body, 'Via ctx.res');
    });

    test('returning int converts to string', () async {
      app.get('/int').handle((ctx) {
        return 42;
      });

      final res = await client.get('/int');
      expect(res.status, 200);
      expect(await res.body, '42');
    });

    test('ctx.res.text() takes priority over return value', () async {
      app.get('/double').handle((ctx) {
        ctx.res.text('First');
        return 'Second'; // This will be ignored
      });

      final res = await client.get('/double');
      expect(res.status, 200);
      expect(await res.body, 'First'); // First response wins
    });
  });
}
