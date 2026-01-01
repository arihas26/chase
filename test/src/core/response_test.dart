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
        final response = Response.ok().text('Hello');
        expect(response.statusCode, HttpStatus.ok);
        expect(response.body, 'Hello');
      });

      test('ok() with JSON body', () {
        final response = Response.ok().json({'message': 'Hello'});
        expect(response.statusCode, HttpStatus.ok);
        expect(response.body, {'message': 'Hello'});
      });

      test('created() creates 201 response', () {
        final response = Response.created().json({'id': 1});
        expect(response.statusCode, HttpStatus.created);
        expect(response.body, {'id': 1});
      });

      test('noContent() creates 204 response', () {
        final response = Response.noContent();
        expect(response.statusCode, HttpStatus.noContent);
        expect(response.body, isNull);
      });

      test('accepted() creates 202 response', () {
        final response = Response.accepted().json({'status': 'processing'});
        expect(response.statusCode, HttpStatus.accepted);
      });
    });

    group('redirection responses (3xx)', () {
      test('movedPermanently() creates 301 redirect', () {
        final response = Response.movedPermanently('/new-location');
        expect(response.statusCode, HttpStatus.movedPermanently);
        expect(response.headers['location'], '/new-location');
      });

      test('redirect() creates 302 redirect', () {
        final response = Response.redirect('/temporary');
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
        final response = Response.badRequest().json({'error': 'Invalid input'});
        expect(response.statusCode, HttpStatus.badRequest);
      });

      test('unauthorized() creates 401 response', () {
        final response = Response.unauthorized().json({'error': 'Auth required'});
        expect(response.statusCode, HttpStatus.unauthorized);
      });

      test('forbidden() creates 403 response', () {
        final response = Response.forbidden().json({'error': 'Access denied'});
        expect(response.statusCode, HttpStatus.forbidden);
      });

      test('notFound() creates 404 response', () {
        final response = Response.notFound().json({'error': 'Not found'});
        expect(response.statusCode, HttpStatus.notFound);
      });

      test('methodNotAllowed() creates 405 response', () {
        final response = Response.methodNotAllowed().json({'error': 'Method not allowed'});
        expect(response.statusCode, HttpStatus.methodNotAllowed);
      });

      test('conflict() creates 409 response', () {
        final response = Response.conflict().json({'error': 'Resource conflict'});
        expect(response.statusCode, HttpStatus.conflict);
      });

      test('unprocessableEntity() creates 422 response', () {
        final response = Response.unprocessableEntity().json({'errors': []});
        expect(response.statusCode, HttpStatus.unprocessableEntity);
      });

      test('tooManyRequests() creates 429 response', () {
        final response = Response.tooManyRequests().json({'error': 'Rate limited'});
        expect(response.statusCode, HttpStatus.tooManyRequests);
      });
    });

    group('server error responses (5xx)', () {
      test('internalServerError() creates 500 response', () {
        final response = Response.internalServerError().json({'error': 'Server error'});
        expect(response.statusCode, HttpStatus.internalServerError);
      });

      test('badGateway() creates 502 response', () {
        final response = Response.badGateway().json({'error': 'Bad gateway'});
        expect(response.statusCode, HttpStatus.badGateway);
      });

      test('serviceUnavailable() creates 503 response', () {
        final response = Response.serviceUnavailable().json({'error': 'Maintenance'});
        expect(response.statusCode, HttpStatus.serviceUnavailable);
      });
    });


    group('fluent API', () {
      test('Response.status() creates response with custom status', () {
        final response = Response.status(418).json({'error': "I'm a teapot"});
        expect(response.statusCode, 418);
        expect(response.body, {'error': "I'm a teapot"});
      });

      test('header() adds headers and chains', () {
        final response = Response.created()
            .header('Location', '/users/1')
            .header('X-Custom', 'value')
            .json({'id': 1});
        expect(response.statusCode, HttpStatus.created);
        expect(response.headers['Location'], '/users/1');
        expect(response.headers['X-Custom'], 'value');
        expect(response.body, {'id': 1});
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

    test('handler can return Response.ok().text()', () async {
      app.get('/text').handle((ctx) {
        return Response.ok().text('Hello from Response!');
      });

      final res = await client.get('/text');
      expect(res.status, 200);
      expect(await res.body, 'Hello from Response!');
    });

    test('handler can return Response.ok().json()', () async {
      app.get('/json').handle((ctx) {
        return Response.ok().json({'message': 'Hello', 'framework': 'chase'});
      });

      final res = await client.get('/json');
      expect(res.status, 200);
      expect(res.headers['content-type']?.first, contains('application/json'));
      final body = jsonDecode(await res.body) as Map<String, dynamic>;
      expect(body['message'], 'Hello');
      expect(body['framework'], 'chase');
    });

    test('handler can return Response.created().json()', () async {
      app.post('/users').handle((ctx) {
        return Response.created().json({'id': 1, 'name': 'John'});
      });

      final res = await client.post('/users');
      expect(res.status, 201);
      final body = jsonDecode(await res.body) as Map<String, dynamic>;
      expect(body['id'], 1);
    });

    test('handler can return Response.notFound().json()', () async {
      app.get('/missing').handle((ctx) {
        return Response.notFound().json({'error': 'Resource not found'});
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
        return Response.ok()
            .header('x-response', 'from-response')
            .text('Response body');
      });

      final res = await client.get('/mixed');
      expect(res.status, 200);
      // Note: Response.writeTo() sets headers, which may override ctx.res headers
      expect(res.headers['x-response']?.first, 'from-response');
    });

    test('async handler can return Response', () async {
      app.get('/async').handle((ctx) async {
        await Future.delayed(Duration(milliseconds: 10));
        return Response.ok().json({'async': true});
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

    test('returning object with toJson() serializes to JSON', () async {
      app.get('/user').handle((ctx) {
        return _User(id: 1, name: 'John', email: 'john@example.com');
      });

      final res = await client.get('/user');
      expect(res.status, 200);
      expect(res.headers['content-type']?.first, contains('application/json'));
      final body = jsonDecode(await res.body) as Map<String, dynamic>;
      expect(body['id'], 1);
      expect(body['name'], 'John');
      expect(body['email'], 'john@example.com');
    });

    test('returning nested object with toJson() serializes to JSON', () async {
      app.get('/company').handle((ctx) {
        return _Company(
          name: 'Acme Corp',
          employees: [
            _User(id: 1, name: 'Alice', email: 'alice@acme.com'),
            _User(id: 2, name: 'Bob', email: 'bob@acme.com'),
          ],
        );
      });

      final res = await client.get('/company');
      expect(res.status, 200);
      expect(res.headers['content-type']?.first, contains('application/json'));
      final body = jsonDecode(await res.body) as Map<String, dynamic>;
      expect(body['name'], 'Acme Corp');
      expect(body['employees'], hasLength(2));
      expect(body['employees'][0]['name'], 'Alice');
    });

    test('returning Map<String, Object> sends JSON response', () async {
      app.get('/map-object').handle((ctx) {
        final Map<String, Object> data = {'name': 'Test', 'count': 42};
        return data;
      });

      final res = await client.get('/map-object');
      expect(res.status, 200);
      expect(res.headers['content-type']?.first, contains('application/json'));
      final body = jsonDecode(await res.body) as Map<String, dynamic>;
      expect(body['name'], 'Test');
      expect(body['count'], 42);
    });

    test('returning Map<String, String> sends JSON response', () async {
      app.get('/map-string').handle((ctx) {
        final Map<String, String> data = {'key1': 'value1', 'key2': 'value2'};
        return data;
      });

      final res = await client.get('/map-string');
      expect(res.status, 200);
      expect(res.headers['content-type']?.first, contains('application/json'));
      final body = jsonDecode(await res.body) as Map<String, dynamic>;
      expect(body['key1'], 'value1');
      expect(body['key2'], 'value2');
    });
  });
}

/// Test class with toJson() method
class _User {
  final int id;
  final String name;
  final String email;

  _User({required this.id, required this.name, required this.email});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
      };
}

/// Test class with nested toJson() objects
class _Company {
  final String name;
  final List<_User> employees;

  _Company({required this.name, required this.employees});

  Map<String, dynamic> toJson() => {
        'name': name,
        'employees': employees.map((e) => e.toJson()).toList(),
      };
}
