import 'package:chase/chase.dart';
import 'package:chase/testing/testing.dart';
import 'package:test/test.dart';

void main() {
  group('RequestId', () {
    late TestClient client;

    tearDown(() async {
      await client.close();
    });

    group('basic functionality', () {
      test('generates unique request ID', () async {
        final app = Chase();
        app.use(RequestId());
        app.get('/').handle((ctx) async {
          await ctx.res.json({'id': ctx.requestId});
        });

        client = await TestClient.start(app);
        final res = await client.get('/');

        expect(res.status, 200);
        expect(res.headers['x-request-id'], isNotNull);
        expect(res.headers['x-request-id'], isNotEmpty);

        // Check UUID format
        final id = res.headers['x-request-id']!.first;
        expect(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ).hasMatch(id),
          isTrue,
          reason: 'Should be a valid UUID v4',
        );
      });

      test('generates different IDs for each request', () async {
        final app = Chase();
        app.use(RequestId());
        app.get('/').handle((ctx) async {
          await ctx.res.json({'id': ctx.requestId});
        });

        client = await TestClient.start(app);
        final res1 = await client.get('/');
        final res2 = await client.get('/');

        final id1 = res1.headers['x-request-id']!.first;
        final id2 = res2.headers['x-request-id']!.first;

        expect(id1, isNot(equals(id2)));
      });
    });

    group('response header', () {
      test('sets response header by default', () async {
        final app = Chase();
        app.use(RequestId());
        app.get('/').handle((ctx) async {
          await ctx.res.text('ok');
        });

        client = await TestClient.start(app);
        final res = await client.get('/');

        expect(res.headers['x-request-id'], isNotNull);
      });

      test('can disable response header', () async {
        final app = Chase();
        app.use(RequestId(const RequestIdOptions(setResponseHeader: false)));
        app.get('/').handle((ctx) async {
          await ctx.res.json({'id': ctx.requestId});
        });

        client = await TestClient.start(app);
        final res = await client.get('/');

        expect(res.headers['x-request-id'], isNull);
        // But requestId should still be available in context
        final body = await res.json;
        expect(body['id'], isNotNull);
      });
    });

    group('custom header name', () {
      test('uses custom header name', () async {
        final app = Chase();
        app.use(
          RequestId(const RequestIdOptions(headerName: 'X-Correlation-Id')),
        );
        app.get('/').handle((ctx) async {
          await ctx.res.text('ok');
        });

        client = await TestClient.start(app);
        final res = await client.get('/');

        expect(res.headers['x-correlation-id'], isNotNull);
        expect(res.headers['x-request-id'], isNull);
      });
    });

    group('incoming request ID', () {
      test('uses incoming request ID when present', () async {
        final app = Chase();
        app.use(RequestId());
        app.get('/').handle((ctx) async {
          await ctx.res.json({'id': ctx.requestId});
        });

        client = await TestClient.start(app);
        final res = await client.get(
          '/',
          headers: {'x-request-id': 'incoming-123'},
        );

        expect(res.headers['x-request-id']!.first, 'incoming-123');
        final body = await res.json;
        expect(body['id'], 'incoming-123');
      });

      test('can disable using incoming IDs', () async {
        final app = Chase();
        app.use(RequestId(const RequestIdOptions(useIncoming: false)));
        app.get('/').handle((ctx) async {
          await ctx.res.json({'id': ctx.requestId});
        });

        client = await TestClient.start(app);
        final res = await client.get(
          '/',
          headers: {'x-request-id': 'incoming-123'},
        );

        // Should generate new ID, not use incoming
        expect(res.headers['x-request-id']!.first, isNot('incoming-123'));
      });
    });

    group('custom generator', () {
      test('uses custom generator', () async {
        var counter = 0;
        final app = Chase();
        app.use(
          RequestId(RequestIdOptions(generator: () => 'custom-${++counter}')),
        );
        app.get('/').handle((ctx) async {
          await ctx.res.json({'id': ctx.requestId});
        });

        client = await TestClient.start(app);

        final res1 = await client.get('/');
        final res2 = await client.get('/');

        expect(res1.headers['x-request-id']!.first, 'custom-1');
        expect(res2.headers['x-request-id']!.first, 'custom-2');
      });
    });

    group('validator', () {
      test('validates incoming IDs', () async {
        final app = Chase();
        app.use(
          RequestId(
            RequestIdOptions(validator: (id) => id.startsWith('valid-')),
          ),
        );
        app.get('/').handle((ctx) async {
          await ctx.res.json({'id': ctx.requestId});
        });

        client = await TestClient.start(app);

        // Valid incoming ID
        final res1 = await client.get(
          '/',
          headers: {'x-request-id': 'valid-123'},
        );
        expect(res1.headers['x-request-id']!.first, 'valid-123');

        // Invalid incoming ID - should generate new
        final res2 = await client.get(
          '/',
          headers: {'x-request-id': 'invalid-123'},
        );
        expect(res2.headers['x-request-id']!.first, isNot('invalid-123'));
      });
    });

    group('context extension', () {
      test('requestId getter works', () async {
        final app = Chase();
        app.use(RequestId());
        app.get('/').handle((ctx) async {
          expect(ctx.requestId, isNotEmpty);
          await ctx.res.text('ok');
        });

        client = await TestClient.start(app);
        await client.get('/');
      });

      test('requestIdOrNull returns null without middleware', () async {
        final app = Chase();
        app.get('/').handle((ctx) async {
          expect(ctx.requestIdOrNull, isNull);
          await ctx.res.text('ok');
        });

        client = await TestClient.start(app);
        await client.get('/');
      });

      test('requestId throws without middleware', () async {
        final app = Chase();
        app.get('/').handle((ctx) async {
          expect(() => ctx.requestId, throwsA(isA<StateError>()));
          await ctx.res.text('ok');
        });

        client = await TestClient.start(app);
        await client.get('/');
      });
    });

    group('convenience function', () {
      test('requestId() creates middleware', () async {
        final app = Chase();
        app.use(requestId(headerName: 'X-Trace-Id'));
        app.get('/').handle((ctx) async {
          await ctx.res.text('ok');
        });

        client = await TestClient.start(app);
        final res = await client.get('/');

        expect(res.headers['x-trace-id'], isNotNull);
      });
    });
  });
}
