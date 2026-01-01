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

  group('Response.header() static method', () {
    test('creates builder with header and returns JSON response', () {
      final response = Response.header('X-Custom', 'value').json({'data': 1});
      expect(response.headers['X-Custom'], 'value');
      expect(response.headers['content-type'], 'application/json; charset=utf-8');
      expect(response.body, {'data': 1});
      expect(response.statusCode, HttpStatus.ok);
    });

    test('creates builder with header and returns text response', () {
      final response = Response.header('X-Request-Id', 'abc123').text('Hello');
      expect(response.headers['X-Request-Id'], 'abc123');
      expect(response.body, 'Hello');
    });

    test('creates builder with header and returns HTML response', () {
      final response = Response.header('X-Frame-Options', 'DENY').html('<p>Hi</p>');
      expect(response.headers['X-Frame-Options'], 'DENY');
    });

    test('chains multiple headers', () {
      final response = Response.header('X-First', 'first')
          .header('X-Second', 'second')
          .header('X-Third', 'third')
          .json({'ok': true});
      expect(response.headers['X-First'], 'first');
      expect(response.headers['X-Second'], 'second');
      expect(response.headers['X-Third'], 'third');
    });

    test('sanitizes header values (CRLF injection)', () {
      final response = Response.header('X-Evil', 'value\r\nInjected: bad').json({});
      expect(response.headers['X-Evil'], 'valueInjected: bad');
      expect(response.headers.containsKey('Injected'), isFalse);
    });

    test('can change status with .status()', () {
      final response = Response.header('X-Custom', 'value')
          .status(HttpStatus.created)
          .json({'id': 1});
      expect(response.statusCode, HttpStatus.created);
      expect(response.headers['X-Custom'], 'value');
    });

    test('later header overrides earlier one', () {
      final response = Response.header('X-Override', 'first')
          .header('X-Override', 'second')
          .json({});
      expect(response.headers['X-Override'], 'second');
    });
  });

  group('Response static factory methods with custom status', () {
    test('json() with default status 200', () {
      final response = Response.json({'key': 'value'});
      expect(response.statusCode, HttpStatus.ok);
      expect(response.body, {'key': 'value'});
      expect(response.headers['content-type'], 'application/json; charset=utf-8');
    });

    test('json() with custom status', () {
      final response = Response.json({'error': 'Not found'}, status: 404);
      expect(response.statusCode, 404);
      expect(response.body, {'error': 'Not found'});
    });

    test('json() with 201 Created status', () {
      final response = Response.json({'id': 1}, status: HttpStatus.created);
      expect(response.statusCode, HttpStatus.created);
    });

    test('json() with null body', () {
      final response = Response.json(null);
      expect(response.statusCode, HttpStatus.ok);
      expect(response.body, isNull);
    });

    test('json() with list body', () {
      final response = Response.json([1, 2, 3]);
      expect(response.body, [1, 2, 3]);
    });

    test('json() with nested object', () {
      final response = Response.json({
        'user': {'name': 'John', 'age': 30},
        'tags': ['admin', 'user'],
      });
      expect(response.body, {
        'user': {'name': 'John', 'age': 30},
        'tags': ['admin', 'user'],
      });
    });

    test('html() with default status 200', () {
      final response = Response.html('<h1>Hello</h1>');
      expect(response.statusCode, HttpStatus.ok);
      expect(response.body, '<h1>Hello</h1>');
      expect(response.headers['content-type'], 'text/html; charset=utf-8');
    });

    test('html() with custom status', () {
      final response = Response.html('<h1>Not Found</h1>', status: 404);
      expect(response.statusCode, 404);
      expect(response.body, '<h1>Not Found</h1>');
    });

    test('html() with complex HTML', () {
      const htmlContent = '''
<!DOCTYPE html>
<html>
<head><title>Test</title></head>
<body><p>Hello World</p></body>
</html>''';
      final response = Response.html(htmlContent);
      expect(response.body, htmlContent);
    });

    test('text() with default status 200', () {
      final response = Response.text('Hello World');
      expect(response.statusCode, HttpStatus.ok);
      expect(response.body, 'Hello World');
      expect(response.headers['content-type'], 'text/plain; charset=utf-8');
    });

    test('text() with custom status', () {
      final response = Response.text('Error occurred', status: 500);
      expect(response.statusCode, 500);
      expect(response.body, 'Error occurred');
    });

    test('text() with empty string', () {
      final response = Response.text('');
      expect(response.body, '');
    });

    test('text() with unicode characters', () {
      final response = Response.text('こんにちは世界 🌍');
      expect(response.body, 'こんにちは世界 🌍');
    });
  });

  group('Response.notModified()', () {
    test('creates 304 Not Modified response', () {
      final response = Response.notModified();
      expect(response.statusCode, HttpStatus.notModified);
      expect(response.body, isNull);
    });
  });

  group('ResponseBuilder.download()', () {
    test('creates response with download headers', () {
      final data = [1, 2, 3];
      final response = Response.ok().download(data, 'file.pdf');
      expect(response.statusCode, HttpStatus.ok);
      expect(response.body, data);
      expect(response.headers['content-type'], 'application/octet-stream');
      expect(response.headers['content-disposition'], 'attachment; filename="file.pdf"');
    });

    test('uses custom content-type', () {
      final response = Response.ok().download([1, 2], 'image.png', contentType: 'image/png');
      expect(response.headers['content-type'], 'image/png');
      expect(response.headers['content-disposition'], 'attachment; filename="image.png"');
    });

    test('escapes quotes in filename', () {
      final response = Response.ok().download([1], 'file"with"quotes.txt');
      expect(response.headers['content-disposition'], 'attachment; filename="file\\"with\\"quotes.txt"');
    });

    test('preserves custom headers', () {
      final response = Response.ok()
          .header('X-Custom', 'value')
          .download([1, 2, 3], 'data.bin');
      expect(response.headers['X-Custom'], 'value');
      expect(response.headers['content-disposition'], contains('data.bin'));
    });
  });

  group('ResponseBuilder methods', () {
    group('headers() bulk method', () {
      test('adds multiple headers at once', () {
        final response = Response.ok()
            .headers({
              'X-Custom-1': 'value1',
              'X-Custom-2': 'value2',
              'X-Custom-3': 'value3',
            })
            .json({'data': 1});

        expect(response.headers['X-Custom-1'], 'value1');
        expect(response.headers['X-Custom-2'], 'value2');
        expect(response.headers['X-Custom-3'], 'value3');
      });

      test('headers() can be chained with header()', () {
        final response = Response.ok()
            .header('X-First', 'first')
            .headers({'X-Second': 'second', 'X-Third': 'third'})
            .header('X-Fourth', 'fourth')
            .text('body');

        expect(response.headers['X-First'], 'first');
        expect(response.headers['X-Second'], 'second');
        expect(response.headers['X-Third'], 'third');
        expect(response.headers['X-Fourth'], 'fourth');
      });

      test('later headers override earlier ones', () {
        final response = Response.ok()
            .header('X-Override', 'first')
            .headers({'X-Override': 'second'})
            .json({});

        expect(response.headers['X-Override'], 'second');
      });

      test('headers() with empty map', () {
        final response = Response.ok().headers({}).json({'data': 1});
        expect(response.headers['content-type'], 'application/json; charset=utf-8');
      });
    });

    group('header() chaining', () {
      test('multiple header() calls chain correctly', () {
        final response = Response.created()
            .header('Location', '/users/1')
            .header('X-Request-Id', 'abc123')
            .header('X-Correlation-Id', 'xyz789')
            .json({'id': 1});

        expect(response.headers['Location'], '/users/1');
        expect(response.headers['X-Request-Id'], 'abc123');
        expect(response.headers['X-Correlation-Id'], 'xyz789');
      });

      test('header() preserves immutability', () {
        final builder1 = Response.ok().header('X-First', 'first');
        final builder2 = builder1.header('X-Second', 'second');

        final response1 = builder1.text('body1');
        final response2 = builder2.text('body2');

        expect(response1.headers['X-First'], 'first');
        expect(response1.headers.containsKey('X-Second'), isFalse);
        expect(response2.headers['X-First'], 'first');
        expect(response2.headers['X-Second'], 'second');
      });
    });

    group('bytes() method', () {
      test('creates response with byte data and default content-type', () {
        final data = [72, 101, 108, 108, 111]; // "Hello" in ASCII
        final response = Response.ok().bytes(data);

        expect(response.statusCode, HttpStatus.ok);
        expect(response.body, data);
        expect(response.headers['content-type'], 'application/octet-stream');
      });

      test('bytes() with custom contentType parameter', () {
        final data = [0x89, 0x50, 0x4E, 0x47]; // PNG magic bytes
        final response = Response.ok().bytes(data, contentType: 'image/png');

        expect(response.headers['content-type'], 'image/png');
        expect(response.body, data);
      });

      test('bytes() with empty list', () {
        final response = Response.ok().bytes([]);
        expect(response.body, isEmpty);
        expect(response.headers['content-type'], 'application/octet-stream');
      });

      test('bytes() preserves custom headers', () {
        final response = Response.ok()
            .header('X-Custom', 'value')
            .bytes([1, 2, 3], contentType: 'application/pdf');

        expect(response.headers['X-Custom'], 'value');
        expect(response.headers['content-type'], 'application/pdf');
      });

      test('bytes() contentType overrides header()', () {
        final response = Response.ok()
            .header('content-type', 'text/plain')
            .bytes([1, 2, 3], contentType: 'image/jpeg');

        expect(response.headers['content-type'], 'image/jpeg');
      });
    });

    group('content type methods', () {
      test('json() sets correct content-type', () {
        final response = Response.ok().json({'key': 'value'});
        expect(response.headers['content-type'], 'application/json; charset=utf-8');
      });

      test('html() sets correct content-type', () {
        final response = Response.ok().html('<p>test</p>');
        expect(response.headers['content-type'], 'text/html; charset=utf-8');
      });

      test('text() sets correct content-type', () {
        final response = Response.ok().text('plain text');
        expect(response.headers['content-type'], 'text/plain; charset=utf-8');
      });

      test('custom header does not override content-type from json()', () {
        final response = Response.ok()
            .header('content-type', 'text/plain')
            .json({'key': 'value'});
        // json() should set application/json
        expect(response.headers['content-type'], 'application/json; charset=utf-8');
      });
    });
  });

  group('Header name sanitization', () {
    test('removes CRLF from header names', () {
      final response = Response.header('X-Evil\r\nName', 'value').json({});
      expect(response.headers.containsKey('X-Evil\r\nName'), isFalse);
      expect(response.headers['X-EvilName'], 'value');
    });

    test('removes colons from header names', () {
      final response = Response.ok().header('X-Evil:Name', 'value').json({});
      expect(response.headers.containsKey('X-Evil:Name'), isFalse);
      expect(response.headers['X-EvilName'], 'value');
    });

    test('sanitizes header names in headers() bulk method', () {
      final response = Response.ok()
          .headers({
            'X-First\nEvil': 'first',
            'X-Second:Bad': 'second',
          })
          .json({});
      expect(response.headers['X-FirstEvil'], 'first');
      expect(response.headers['X-SecondBad'], 'second');
    });
  });

  group('CRLF injection prevention', () {
    test('redirect sanitizes location header', () {
      final response = Response.redirect('/path\r\nX-Injected: value');
      expect(response.headers['location'], '/pathX-Injected: value');
      expect(response.headers.containsKey('X-Injected'), isFalse);
    });

    test('movedPermanently sanitizes location header', () {
      final response = Response.movedPermanently('/path\r\n\r\nBody');
      expect(response.headers['location'], '/pathBody');
    });

    test('seeOther sanitizes location header', () {
      final response = Response.seeOther('/redirect\nEvil: header');
      expect(response.headers['location'], '/redirectEvil: header');
    });

    test('temporaryRedirect sanitizes location header', () {
      final response = Response.temporaryRedirect('/temp\r\nSet-Cookie: stolen');
      expect(response.headers['location'], '/tempSet-Cookie: stolen');
    });

    test('permanentRedirect sanitizes location header', () {
      final response = Response.permanentRedirect('/perm\r\n');
      expect(response.headers['location'], '/perm');
    });

    test('ResponseBuilder.header() sanitizes values', () {
      final response = Response.ok()
          .header('X-Custom', 'value\r\nX-Injected: evil')
          .text('body');
      expect(response.headers['X-Custom'], 'valueX-Injected: evil');
      expect(response.headers.containsKey('X-Injected'), isFalse);
    });

    test('ResponseBuilder.headers() sanitizes all values', () {
      final response = Response.ok()
          .headers({
            'X-First': 'first\r\nX-Evil: bad',
            'X-Second': 'second\nAnother: header',
          })
          .text('body');
      expect(response.headers['X-First'], 'firstX-Evil: bad');
      expect(response.headers['X-Second'], 'secondAnother: header');
    });

    test('sanitizes both CR and LF characters', () {
      final response = Response.redirect('/path\rcarriage\nline\r\nboth');
      expect(response.headers['location'], '/pathcarriagelineboth');
    });
  });

  group('Response.status() builder', () {
    test('creates builder with custom status code', () {
      final response = Response.status(418).text("I'm a teapot");
      expect(response.statusCode, 418);
    });

    test('status() with all body types', () {
      expect(Response.status(200).json({}).statusCode, 200);
      expect(Response.status(201).html('<p>').statusCode, 201);
      expect(Response.status(202).text('ok').statusCode, 202);
      expect(Response.status(204).bytes([]).statusCode, 204);
    });

    test('status() with headers', () {
      final response = Response.status(299)
          .header('X-Custom', 'value')
          .json({'custom': true});
      expect(response.statusCode, 299);
      expect(response.headers['X-Custom'], 'value');
    });
  });

  group('ResponseBuilder.status() method', () {
    test('changes status code in builder chain', () {
      final response = Response.ok()
          .header('X-Custom', 'value')
          .status(HttpStatus.created)
          .json({'id': 1});
      expect(response.statusCode, HttpStatus.created);
      expect(response.headers['X-Custom'], 'value');
    });

    test('preserves headers when changing status', () {
      final response = Response.header('X-First', 'first')
          .header('X-Second', 'second')
          .status(404)
          .json({'error': 'Not found'});
      expect(response.statusCode, 404);
      expect(response.headers['X-First'], 'first');
      expect(response.headers['X-Second'], 'second');
    });

    test('can chain status multiple times', () {
      final response = Response.ok()
          .status(201)
          .status(202)
          .status(203)
          .text('Final');
      expect(response.statusCode, 203);
    });
  });

  group('Server error responses (5xx) - additional', () {
    test('gatewayTimeout() creates 504 response', () {
      final response = Response.gatewayTimeout().json({'error': 'Gateway timeout'});
      expect(response.statusCode, HttpStatus.gatewayTimeout);
      expect(response.body, {'error': 'Gateway timeout'});
    });
  });

  group('Response writeTo', () {
    late Chase app;
    late TestClient client;

    setUp(() async {
      app = Chase();
      client = await TestClient.start(app);
    });

    tearDown(() async {
      await client.close();
    });

    test('writes string body correctly', () async {
      app.get('/string').handle((ctx) => Response.text('Hello World'));
      final res = await client.get('/string');
      expect(await res.body, 'Hello World');
    });

    test('writes JSON body correctly', () async {
      app.get('/json').handle((ctx) => Response.json({'key': 'value', 'number': 42}));
      final res = await client.get('/json');
      final body = jsonDecode(await res.body);
      expect(body['key'], 'value');
      expect(body['number'], 42);
    });

    test('writes list JSON body correctly', () async {
      app.get('/list').handle((ctx) => Response.json([1, 2, 3, 'four']));
      final res = await client.get('/list');
      final body = jsonDecode(await res.body);
      expect(body, [1, 2, 3, 'four']);
    });

    test('writes bytes body correctly', () async {
      app.get('/bytes').handle((ctx) {
        return Response.ok()
            .header('content-type', 'application/octet-stream')
            .bytes([0x48, 0x65, 0x6C, 0x6C, 0x6F]); // "Hello"
      });
      final res = await client.get('/bytes');
      expect(await res.body, 'Hello');
    });

    test('writes null body (no content)', () async {
      app.get('/empty').handle((ctx) => Response.noContent());
      final res = await client.get('/empty');
      expect(res.status, 204);
      expect(await res.body, isEmpty);
    });

    test('writes response with custom headers', () async {
      app.get('/headers').handle((ctx) {
        return Response.ok()
            .header('X-Custom-Header', 'custom-value')
            .header('X-Another', 'another-value')
            .text('body');
      });
      final res = await client.get('/headers');
      expect(res.headers['x-custom-header']?.first, 'custom-value');
      expect(res.headers['x-another']?.first, 'another-value');
    });

    test('writes redirect response correctly', () async {
      app.get('/redirect').handle((ctx) => Response.redirect('/target'));
      final res = await client.get('/redirect');
      expect(res.status, 302);
      expect(res.headers['location']?.first, '/target');
    });

    test('writes nested object as JSON', () async {
      app.get('/nested').handle((ctx) => Response.json({
            'user': {
              'name': 'John',
              'address': {
                'city': 'Tokyo',
                'country': 'Japan',
              },
            },
            'tags': ['tag1', 'tag2'],
          }));
      final res = await client.get('/nested');
      final body = jsonDecode(await res.body);
      expect(body['user']['name'], 'John');
      expect(body['user']['address']['city'], 'Tokyo');
      expect(body['tags'], ['tag1', 'tag2']);
    });
  });

  group('JsonEncodingError', () {
    test('toString returns formatted message', () {
      final error = JsonEncodingError('Test error message');
      expect(error.toString(), 'JsonEncodingError: Test error message');
    });

    test('message property returns the message', () {
      final error = JsonEncodingError('Custom message');
      expect(error.message, 'Custom message');
    });
  });

  group('Edge cases', () {
    test('Response with empty headers map', () {
      final response = Response(200, body: 'test', headers: {});
      expect(response.headers, isEmpty);
    });

    test('Response with special characters in body', () {
      final response = Response.text('Special: <>&"\' chars');
      expect(response.body, 'Special: <>&"\' chars');
    });

    test('Response with very long body', () {
      final longBody = 'x' * 10000;
      final response = Response.text(longBody);
      expect(response.body, longBody);
    });

    test('Response.json with boolean body', () {
      final response = Response.json(true);
      expect(response.body, true);
    });

    test('Response.json with numeric body', () {
      final response = Response.json(42);
      expect(response.body, 42);
    });

    test('Response.json with string body (valid JSON string)', () {
      final response = Response.json('just a string');
      expect(response.body, 'just a string');
    });

    test('ResponseBuilder with no headers', () {
      final response = Response.ok().json({'data': 1});
      expect(response.headers['content-type'], 'application/json; charset=utf-8');
    });

    test('Multiple status builders are independent', () {
      final builder1 = Response.ok();
      final builder2 = Response.created();
      final builder3 = Response.notFound();

      expect(builder1.json({}).statusCode, 200);
      expect(builder2.json({}).statusCode, 201);
      expect(builder3.json({}).statusCode, 404);
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
