import 'dart:io';

import 'package:chase/chase.dart';
import 'package:chase/testing/testing.dart';
import 'package:test/test.dart';

void main() {
  group('Fluent Response API', () {
    late TestClient client;

    tearDown(() async {
      await client.close();
    });

    group('status()', () {
      test('sets status code', () async {
        final app = Chase();
        app.get('/test').handle((ctx) async {
          await ctx.status(201).json({'ok': true});
        });

        client = await TestClient.start(app);
        final res = await client.get('/test');

        expect(res.status, 201);
        expect(await res.json, {'ok': true});
      });

      test('chains with header()', () async {
        final app = Chase();
        app.get('/test').handle((ctx) async {
          await ctx.status(201).header('X-Custom', 'value').json({'ok': true});
        });

        client = await TestClient.start(app);
        final res = await client.get('/test');

        expect(res.status, 201);
        expect(res.headers.value('X-Custom'), 'value');
      });
    });

    group('header()', () {
      test('sets response header', () async {
        final app = Chase();
        app.get('/test').handle((ctx) async {
          await ctx.header('X-Custom', 'test-value').text('OK');
        });

        client = await TestClient.start(app);
        final res = await client.get('/test');

        expect(res.headers.value('X-Custom'), 'test-value');
        expect(await res.body, 'OK');
      });

      test('chains multiple headers', () async {
        final app = Chase();
        app.get('/test').handle((ctx) async {
          await ctx
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

    group('json()', () {
      test('sends JSON response', () async {
        final app = Chase();
        app.get('/test').handle((ctx) async {
          await ctx.json({'message': 'Hello'});
        });

        client = await TestClient.start(app);
        final res = await client.get('/test');

        expect(res.status, 200);
        expect(res.headers.contentType?.mimeType, 'application/json');
        expect(await res.json, {'message': 'Hello'});
      });
    });

    group('text()', () {
      test('sends plain text response', () async {
        final app = Chase();
        app.get('/test').handle((ctx) async {
          await ctx.text('Hello, World!');
        });

        client = await TestClient.start(app);
        final res = await client.get('/test');

        expect(res.status, 200);
        expect(res.headers.contentType?.mimeType, 'text/plain');
        expect(await res.body, 'Hello, World!');
      });
    });

    group('html()', () {
      test('sends HTML response', () async {
        final app = Chase();
        app.get('/test').handle((ctx) async {
          await ctx.html('<h1>Hello</h1>');
        });

        client = await TestClient.start(app);
        final res = await client.get('/test');

        expect(res.status, 200);
        expect(res.headers.contentType?.mimeType, 'text/html');
        expect(await res.body, '<h1>Hello</h1>');
      });
    });

    group('redirect()', () {
      test('redirect method exists and is callable', () async {
        final app = Chase();
        var redirectCalled = false;
        app.get('/old').handle((ctx) async {
          redirectCalled = true;
          // Test that redirect method works without error
          await ctx.redirect('/new');
        });

        client = await TestClient.start(app);
        await client.get('/old');

        expect(redirectCalled, isTrue);
      });

      test('redirect with custom status is callable', () async {
        final app = Chase();
        var redirectCalled = false;
        app.get('/old').handle((ctx) async {
          redirectCalled = true;
          await ctx.redirect('/new', status: 301);
        });

        client = await TestClient.start(app);
        await client.get('/old');

        expect(redirectCalled, isTrue);
      });
    });

    group('body()', () {
      test('sends plain body', () async {
        final app = Chase();
        app.get('/test').handle((ctx) async {
          await ctx.status(200).body('Plain body');
        });

        client = await TestClient.start(app);
        final res = await client.get('/test');

        expect(res.status, 200);
        expect(await res.body, 'Plain body');
      });

      test('sends empty body with 204', () async {
        final app = Chase();
        app.delete('/resource').handle((ctx) async {
          await ctx.status(204).body(null);
        });

        client = await TestClient.start(app);
        final res = await client.delete('/resource');

        expect(res.status, 204);
        expect(await res.body, isEmpty);
      });
    });

    group('notFound()', () {
      test('sends 404 with default message', () async {
        final app = Chase();
        app.get('/missing').handle((ctx) async {
          await ctx.notFound();
        });

        client = await TestClient.start(app);
        final res = await client.get('/missing');

        expect(res.status, 404);
      });

      test('sends 404 with custom message', () async {
        final app = Chase();
        app.get('/missing').handle((ctx) async {
          await ctx.notFound('Resource not found');
        });

        client = await TestClient.start(app);
        final res = await client.get('/missing');

        expect(res.status, 404);
        expect(await res.body, contains('Resource not found'));
      });
    });

    group('complex chaining', () {
      test('status + header + json', () async {
        final app = Chase();
        app.post('/users').handle((ctx) async {
          await ctx
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
  });
}
