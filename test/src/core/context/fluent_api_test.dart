import 'package:chase/chase.dart';
import 'package:chase/testing/testing.dart';
import 'package:test/test.dart';

void main() {
  group('Fluent Response API (Hono-style)', () {
    late TestClient client;

    tearDown(() async {
      await client.close();
    });

    group('ctx.status()', () {
      test('sets status code', () async {
        final app = Chase();
        app.get('/test').handle((ctx) {
          return ctx.status(201).json({'ok': true});
        });

        client = await TestClient.start(app);
        final res = await client.get('/test');

        expect(res.status, 201);
        expect(await res.json, {'ok': true});
      });

      test('chains with header()', () async {
        final app = Chase();
        app.get('/test').handle((ctx) {
          return ctx.status(201).header('X-Custom', 'value').json({'ok': true});
        });

        client = await TestClient.start(app);
        final res = await client.get('/test');

        expect(res.status, 201);
        expect(res.headers.value('X-Custom'), 'value');
      });
    });

    group('ctx.header()', () {
      test('sets response header', () async {
        final app = Chase();
        app.get('/test').handle((ctx) {
          return ctx.header('X-Custom', 'test-value').text('OK');
        });

        client = await TestClient.start(app);
        final res = await client.get('/test');

        expect(res.headers.value('X-Custom'), 'test-value');
        expect(await res.body, 'OK');
      });

      test('chains multiple headers', () async {
        final app = Chase();
        app.get('/test').handle((ctx) {
          return ctx
              .header('X-First', 'one')
              .header('X-Second', 'two')
              .json({'ok': true});
        });

        client = await TestClient.start(app);
        final res = await client.get('/test');

        expect(res.headers.value('X-First'), 'one');
        expect(res.headers.value('X-Second'), 'two');
      });
    });

    group('ctx.json()', () {
      test('sends JSON response', () async {
        final app = Chase();
        app.get('/test').handle((ctx) {
          return ctx.json({'message': 'Hello'});
        });

        client = await TestClient.start(app);
        final res = await client.get('/test');

        expect(res.status, 200);
        expect(res.headers.contentType?.mimeType, 'application/json');
        expect(await res.json, {'message': 'Hello'});
      });
    });

    group('ctx.text()', () {
      test('sends plain text response', () async {
        final app = Chase();
        app.get('/test').handle((ctx) {
          return ctx.text('Hello, World!');
        });

        client = await TestClient.start(app);
        final res = await client.get('/test');

        expect(res.status, 200);
        expect(res.headers.contentType?.mimeType, 'text/plain');
        expect(await res.body, 'Hello, World!');
      });
    });

    group('ctx.html()', () {
      test('sends HTML response', () async {
        final app = Chase();
        app.get('/test').handle((ctx) {
          return ctx.html('<h1>Hello</h1>');
        });

        client = await TestClient.start(app);
        final res = await client.get('/test');

        expect(res.status, 200);
        expect(res.headers.contentType?.mimeType, 'text/html');
        expect(await res.body, '<h1>Hello</h1>');
      });
    });

    group('ctx.redirect()', () {
      test('redirect method works', () async {
        final app = Chase();
        var redirectCalled = false;
        app.get('/old').handle((ctx) {
          redirectCalled = true;
          return ctx.redirect('/new');
        });

        client = await TestClient.start(app);
        await client.get('/old');

        expect(redirectCalled, isTrue);
      });
    });

    group('ctx.body()', () {
      test('sends plain body', () async {
        final app = Chase();
        app.get('/test').handle((ctx) {
          return ctx.status(200).body('Plain body');
        });

        client = await TestClient.start(app);
        final res = await client.get('/test');

        expect(res.status, 200);
        expect(await res.body, 'Plain body');
      });

      test('sends empty body with 204', () async {
        final app = Chase();
        app.delete('/resource').handle((ctx) {
          return ctx.status(204).body(null);
        });

        client = await TestClient.start(app);
        final res = await client.delete('/resource');

        expect(res.status, 204);
      });
    });

    group('ctx.notFound()', () {
      test('sends 404 with default message', () async {
        final app = Chase();
        app.get('/missing').handle((ctx) {
          return ctx.notFound();
        });

        client = await TestClient.start(app);
        final res = await client.get('/missing');

        expect(res.status, 404);
      });

      test('sends 404 with custom message', () async {
        final app = Chase();
        app.get('/missing').handle((ctx) {
          return ctx.notFound('Resource not found');
        });

        client = await TestClient.start(app);
        final res = await client.get('/missing');

        expect(res.status, 404);
        expect(await res.body, 'Resource not found');
      });
    });

    group('complex chaining', () {
      test('status + header + json', () async {
        final app = Chase();
        app.post('/users').handle((ctx) {
          return ctx
              .status(201)
              .header('X-Created-Id', '123')
              .header('Cache-Control', 'no-cache')
              .json({'id': 123, 'name': 'John'});
        });

        client = await TestClient.start(app);
        final res = await client.post('/users');

        expect(res.status, 201);
        expect(res.headers.value('X-Created-Id'), '123');
        expect(res.headers.value('Cache-Control'), 'no-cache');
        expect(await res.json, {'id': 123, 'name': 'John'});
      });
    });

    group('Response class (functional style)', () {
      test('Response.ok', () async {
        final app = Chase();
        app.get('/test').handle((ctx) {
          return Response.ok({'message': 'OK'});
        });

        client = await TestClient.start(app);
        final res = await client.get('/test');

        expect(res.status, 200);
        expect(await res.json, {'message': 'OK'});
      });

      test('Response.created', () async {
        final app = Chase();
        app.post('/test').handle((ctx) {
          return Response.created({'id': 1});
        });

        client = await TestClient.start(app);
        final res = await client.post('/test');

        expect(res.status, 201);
        expect(await res.json, {'id': 1});
      });

      test('Response.noContent', () async {
        final app = Chase();
        app.delete('/test').handle((ctx) {
          return Response.noContent();
        });

        client = await TestClient.start(app);
        final res = await client.delete('/test');

        expect(res.status, 204);
      });

      test('Response.notFound', () async {
        final app = Chase();
        app.get('/test').handle((ctx) {
          return Response.notFound({'error': 'Not found'});
        });

        client = await TestClient.start(app);
        final res = await client.get('/test');

        expect(res.status, 404);
        expect(await res.json, {'error': 'Not found'});
      });
    });
  });
}
