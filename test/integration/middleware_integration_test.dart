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
