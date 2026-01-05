import 'package:chase/chase.dart';
import 'package:chase/testing/testing.dart';
import 'package:test/test.dart';

void main() {
  group('Middleware Integration', () {
    late Chase app;
    late TestClient client;

    tearDown(() async {
      await client.close();
    });

    test('multiple middleware execute in order', () async {
      app = Chase();
      final order = <String>[];

      app.use(_OrderTracker('first', order));
      app.use(_OrderTracker('second', order));
      app.use(_OrderTracker('third', order));

      app.get('/').handle((ctx) {
        order.add('handler');
        ctx.res.text('OK');
      });

      client = await TestClient.start(app);
      await client.get('/');

      expect(order, ['first', 'second', 'third', 'handler']);
    });

    test('middleware can short-circuit request', () async {
      app = Chase();

      app.use(_AuthMiddleware('secret-token'));
      app.get('/protected').handle((ctx) {
        ctx.res.text('Secret data');
      });

      client = await TestClient.start(app);

      // Without token
      final res1 = await client.get('/protected');
      expect(res1.status, 401);

      // With valid token
      final res2 = await client.get(
        '/protected',
        headers: {'Authorization': 'Bearer secret-token'},
      );
      expect(res2.status, 200);
      expect(await res2.body, 'Secret data');
    });

    test('CORS + Auth middleware work together', () async {
      app = Chase();
      app.use(Cors());
      app.use(_AuthMiddleware('token'));
      app.get('/api/data').handle((ctx) {
        ctx.res.json({'data': 'value'});
      });

      client = await TestClient.start(app);

      final res = await client.get(
        '/api/data',
        headers: {
          'Origin': 'https://example.com',
          'Authorization': 'Bearer token',
        },
      );

      expect(res.status, 200);
      expect(res.headers.value('access-control-allow-origin'), '*');
    });

    test('exception handler catches errors', () async {
      app = Chase();
      app.use(ExceptionHandler());
      app.get('/error').handle((ctx) {
        throw const BadRequestException('Invalid input');
      });

      client = await TestClient.start(app);
      final res = await client.get('/error');

      expect(res.status, 400);
      expect(await res.body, contains('Invalid input'));
    });

    test('rate limit middleware limits requests', () async {
      app = Chase();
      app.use(
        RateLimit(const RateLimitOptions(maxRequests: 3, windowMs: 10000)),
      );
      app.get('/').handle((ctx) => ctx.res.text('OK'));

      client = await TestClient.start(app);

      // First 3 requests should succeed
      for (var i = 0; i < 3; i++) {
        final res = await client.get('/');
        expect(res.status, 200);
      }

      // 4th request should be rate limited
      final res = await client.get('/');
      expect(res.status, 429);
    });

    group('path() route groups with middleware', () {
      test('CORS preflight works with path() groups', () async {
        app = Chase();
        final api = app.path('/api');
        api.use(Cors());
        // Register both GET and OPTIONS routes for CORS preflight
        api.get('/users').handle((ctx) => {'users': []});
        api.options('/users').handle((ctx) => null);

        client = await TestClient.start(app);

        // Send preflight OPTIONS request
        final res = await client.request(
          'OPTIONS',
          '/api/users',
          headers: {
            'Origin': 'https://example.com',
            'Access-Control-Request-Method': 'GET',
          },
        );

        expect(res.status, 204);
        expect(res.headers.value('access-control-allow-origin'), '*');
      });

      test('rate limit works with path() groups', () async {
        app = Chase();
        final api = app.path('/api');
        api.use(
          RateLimit(const RateLimitOptions(maxRequests: 2, windowMs: 10000)),
        );
        api.get('/data').handle((ctx) => 'OK');

        client = await TestClient.start(app);

        // First 2 requests should succeed
        final res1 = await client.get('/api/data');
        expect(res1.status, 200);

        final res2 = await client.get('/api/data');
        expect(res2.status, 200);

        // 3rd request should be rate limited
        final res3 = await client.get('/api/data');
        expect(res3.status, 429);
      });

      test('body limit works with path() groups', () async {
        app = Chase();
        final api = app.path('/api');
        api.use(BodyLimit(const BodyLimitOptions(maxSize: 100)));
        api.post('/upload').handle((ctx) => 'OK');

        client = await TestClient.start(app);

        // Small body should succeed
        final res1 = await client.post(
          '/api/upload',
          headers: {'Content-Length': '50'},
          body: 'x' * 50,
        );
        expect(res1.status, 200);

        // Large body should be rejected
        final res2 = await client.post(
          '/api/upload',
          headers: {'Content-Length': '200'},
          body: 'x' * 200,
        );
        expect(res2.status, 413);
      });

      test('exception handler works with path() groups', () async {
        app = Chase();
        final api = app.path('/api');
        api.use(ExceptionHandler());
        api.get('/error').handle((ctx) {
          throw const NotFoundException('Resource not found');
        });

        client = await TestClient.start(app);

        final res = await client.get('/api/error');
        expect(res.status, 404);
        expect(await res.body, contains('Resource not found'));
      });

      test('nested path() groups with middleware', () async {
        app = Chase();
        app.use(Cors());

        final api = app.path('/api');
        api.use(
          RateLimit(const RateLimitOptions(maxRequests: 5, windowMs: 10000)),
        );

        final v1 = api.path('/v1');
        v1.use(ExceptionHandler());
        v1.get('/users').handle((ctx) => {'users': []});

        client = await TestClient.start(app);

        // Verify CORS headers are present
        final res = await client.get(
          '/api/v1/users',
          headers: {'Origin': 'https://example.com'},
        );
        expect(res.status, 200);
        expect(res.headers.value('access-control-allow-origin'), '*');
      });

      test('middleware short-circuits correctly in path() groups', () async {
        app = Chase();
        var handlerCalled = false;

        final api = app.path('/api');
        api.use(_AuthMiddleware('secret'));
        api.get('/protected').handle((ctx) {
          handlerCalled = true;
          return 'Secret data';
        });

        client = await TestClient.start(app);

        // Without auth, handler should not be called
        final res = await client.get('/api/protected');
        expect(res.status, 401);
        expect(handlerCalled, false);
      });
    });
  });
}

class _OrderTracker extends Middleware {
  final String name;
  final List<String> order;

  _OrderTracker(this.name, this.order);

  @override
  Future<void> handle(Context ctx, NextFunction next) async {
    order.add(name);
    await next();
  }
}

class _AuthMiddleware extends Middleware {
  final String validToken;

  _AuthMiddleware(this.validToken);

  @override
  Future<void> handle(Context ctx, NextFunction next) async {
    final auth = ctx.req.header('authorization');
    if (auth != 'Bearer $validToken') {
      ctx.res.text('Unauthorized', status: 401);
      return;
    }
    await next();
  }
}
