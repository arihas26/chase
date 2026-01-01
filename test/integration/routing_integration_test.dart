import 'package:chase/chase.dart';
import 'package:chase/testing/testing.dart';
import 'package:test/test.dart';

void main() {
  group('Routing Integration', () {
    late Chase app;
    late TestClient client;

    tearDown(() async {
      await client.close();
    });

    group('route groups', () {
      test('nested groups with middleware', () async {
        app = Chase();

        final api = app.path('/api');
        api.use(_PrefixMiddleware('api'));

        final v1 = api.path('/v1');
        v1.use(_PrefixMiddleware('v1'));

        v1.get('/users').handle((ctx) {
          ctx.res.json({'version': 'v1', 'users': []});
        });

        final v2 = api.path('/v2');
        v2.use(_PrefixMiddleware('v2'));

        v2.get('/users').handle((ctx) {
          ctx.res.json({'version': 'v2', 'users': []});
        });

        client = await TestClient.start(app);

        final res1 = await client.get('/api/v1/users');
        expect(res1.status, 200);
        // Group middleware is applied per-group
        expect(res1.headers.value('x-prefix'), 'v1');

        final res2 = await client.get('/api/v2/users');
        expect(res2.status, 200);
        expect(res2.headers.value('x-prefix'), 'v2');
      });

      test('routes callback syntax', () async {
        app = Chase();

        app.routes('/admin', (admin) {
          admin.get('/dashboard').handle((ctx) {
            ctx.res.text('Dashboard');
          });
          admin.get('/settings').handle((ctx) {
            ctx.res.text('Settings');
          });
        });

        client = await TestClient.start(app);

        expect((await client.get('/admin/dashboard')).status, 200);
        expect((await client.get('/admin/settings')).status, 200);
        expect((await client.get('/admin/unknown')).status, 404);
      });
    });

    group('route parameters', () {
      test('captures multiple params', () async {
        app = Chase();
        app.get('/users/:userId/posts/:postId/comments/:commentId').handle((
          ctx,
        ) {
          ctx.res.json({
            'userId': ctx.req.params['userId'],
            'postId': ctx.req.params['postId'],
            'commentId': ctx.req.params['commentId'],
          });
        });

        client = await TestClient.start(app);
        final res = await client.get('/users/1/posts/2/comments/3');

        final json = await res.json;
        expect(json['userId'], '1');
        expect(json['postId'], '2');
        expect(json['commentId'], '3');
      });
    });

    group('HTTP methods', () {
      test('all HTTP methods work correctly', () async {
        app = Chase();

        app.get('/resource').handle((ctx) => ctx.res.json({'method': 'GET'}));
        app.post('/resource').handle((ctx) => ctx.res.json({'method': 'POST'}));
        app.put('/resource').handle((ctx) => ctx.res.json({'method': 'PUT'}));
        app
            .patch('/resource')
            .handle((ctx) => ctx.res.json({'method': 'PATCH'}));
        app
            .delete('/resource')
            .handle((ctx) => ctx.res.json({'method': 'DELETE'}));

        client = await TestClient.start(app);

        expect((await (await client.get('/resource')).json)['method'], 'GET');
        expect((await (await client.post('/resource')).json)['method'], 'POST');
        expect((await (await client.put('/resource')).json)['method'], 'PUT');
        expect(
          (await (await client.patch('/resource')).json)['method'],
          'PATCH',
        );
        expect(
          (await (await client.delete('/resource')).json)['method'],
          'DELETE',
        );
      });

      test('custom method with route()', () async {
        app = Chase();
        app.route('CUSTOM', '/custom').handle((ctx) {
          ctx.res.text('Custom method');
        });

        client = await TestClient.start(app);
        final res = await client.request('CUSTOM', '/custom');

        expect(res.status, 200);
        expect(await res.body, 'Custom method');
      });
    });

    group('query parameters', () {
      test('parses query parameters', () async {
        app = Chase();
        app.get('/search').handle((ctx) {
          ctx.res.json({
            'q': ctx.req.query('q'),
            'page': ctx.req.query('page'),
            'tags': ctx.req.queryList('tags'),
          });
        });

        client = await TestClient.start(app);
        final res = await client.get('/search?q=hello&page=2&tags=a&tags=b');

        final json = await res.json;
        expect(json['q'], 'hello');
        expect(json['page'], '2');
        expect(json['tags'], ['a', 'b']);
      });
    });
  });
}

class _PrefixMiddleware extends Middleware {
  final String prefix;

  _PrefixMiddleware(this.prefix);

  @override
  Future<void> handle(Context ctx, NextFunction next) async {
    final current = ctx.req.header('x-prefix') ?? '';
    final newPrefix = current.isEmpty ? prefix : '$current,$prefix';
    ctx.res.headers.set('x-prefix', newPrefix);
    await next();
  }
}
