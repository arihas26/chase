import 'package:chase/chase.dart';
import 'package:chase/testing/testing.dart';
import 'package:test/test.dart';

/// A mock router that records all route registrations for testing.
class _RecordingRouter implements Router {
  final List<({String method, String path})> routes = [];

  @override
  void add(String method, String path, Handler handler) {
    routes.add((method: method, path: path));
  }

  @override
  RouteMatch? match(String method, String path) => null;
}

void main() {
  group('Chase', () {
    test('get returns a builder', () {
      final app = Chase();
      final builder = app.get();

      expect(builder, isA<ChaseBuilder>());
    });

    test('handle registers the route', () {
      final router = _RecordingRouter();
      final app = Chase(router: router);
      app.get('/hello').handle((c) => c);
      expect(router.routes.length, 1);
      expect(router.routes.first.method, 'GET');
      expect(router.routes.first.path, '/hello');
    });
  });

  group('Route Grouping', () {
    test('path() creates a group with prefix', () {
      final router = _RecordingRouter();
      final app = Chase(router: router);

      final api = app.path('/api');
      api.get('/users').handle((c) => c);

      expect(router.routes, [(method: 'GET', path: '/api/users')]);
    });

    test('routes() defines routes within a group', () {
      final router = _RecordingRouter();
      final app = Chase(router: router);

      app.routes('/api', (api) {
        api.get('/users').handle((c) => c);
        api.post('/users').handle((c) => c);
      });

      expect(router.routes, [
        (method: 'GET', path: '/api/users'),
        (method: 'POST', path: '/api/users'),
      ]);
    });

    test('nested groups combine prefixes', () {
      final router = _RecordingRouter();
      final app = Chase(router: router);

      app.routes('/api', (api) {
        api.routes('/v1', (v1) {
          v1.get('/users').handle((c) => c);
          v1.post('/posts').handle((c) => c);
        });
      });

      expect(router.routes, [
        (method: 'GET', path: '/api/v1/users'),
        (method: 'POST', path: '/api/v1/posts'),
      ]);
    });

    test('supports all HTTP methods in groups', () {
      final router = _RecordingRouter();
      final app = Chase(router: router);

      final api = app.path('/api');
      api.get('/users').handle((c) => c);
      api.post('/users').handle((c) => c);
      api.put('/users/1').handle((c) => c);
      api.delete('/users/1').handle((c) => c);

      expect(router.routes, [
        (method: 'GET', path: '/api/users'),
        (method: 'POST', path: '/api/users'),
        (method: 'PUT', path: '/api/users/1'),
        (method: 'DELETE', path: '/api/users/1'),
      ]);
    });

    test('static files work with groups', () {
      final router = _RecordingRouter();
      final app = Chase(router: router);

      final assets = app.path('/assets');
      assets.staticFiles('/images', './public/images');

      expect(router.routes, [
        (method: 'GET', path: '/assets/images'),
        (method: 'GET', path: '/assets/images/*path'),
      ]);
    });

    test('handles root path group correctly', () {
      final router = _RecordingRouter();
      final app = Chase(router: router);

      final root = app.path('/');
      root.get('/users').handle((c) => c);

      expect(router.routes, [(method: 'GET', path: '/users')]);
    });

    test('normalizes paths correctly', () {
      final router = _RecordingRouter();
      final app = Chase(router: router);

      // Test various path formats
      app.path('/api').get('/users').handle((c) => c);
      app.path('api/').get('users').handle((c) => c);
      app.path('/api/').get('/users/').handle((c) => c);

      // All should normalize to the same path
      expect(router.routes, [
        (method: 'GET', path: '/api/users'),
        (method: 'GET', path: '/api/users'),
        (method: 'GET', path: '/api/users'),
      ]);
    });

    test('deeply nested groups work correctly', () {
      final router = _RecordingRouter();
      final app = Chase(router: router);

      app.routes('/api', (api) {
        api.routes('/v1', (v1) {
          v1.routes('/admin', (admin) {
            admin.get('/users').handle((c) => c);
          });
        });
      });

      expect(router.routes, [(method: 'GET', path: '/api/v1/admin/users')]);
    });

    test('group returns this for chaining', () {
      final app = Chase();

      final result = app.routes('/api', (api) {
        api.get('/users').handle((c) => c);
      });

      expect(result, same(app));
    });

    test('multiple groups can be created from same app', () {
      final router = _RecordingRouter();
      final app = Chase(router: router);

      final api = app.path('/api');
      final admin = app.path('/admin');

      api.get('/users').handle((c) => c);
      admin.get('/dashboard').handle((c) => c);

      expect(router.routes, [
        (method: 'GET', path: '/api/users'),
        (method: 'GET', path: '/admin/dashboard'),
      ]);
    });
  });

  group('HTTP Methods', () {
    test('patch registers PATCH route', () {
      final router = _RecordingRouter();
      final app = Chase(router: router);

      app.patch('/users/1').handle((c) => c);

      expect(router.routes, [(method: 'PATCH', path: '/users/1')]);
    });

    test('head registers HEAD route', () {
      final router = _RecordingRouter();
      final app = Chase(router: router);

      app.head('/users').handle((c) => c);

      expect(router.routes, [(method: 'HEAD', path: '/users')]);
    });

    test('options registers OPTIONS route', () {
      final router = _RecordingRouter();
      final app = Chase(router: router);

      app.options('/users').handle((c) => c);

      expect(router.routes, [(method: 'OPTIONS', path: '/users')]);
    });

    test('route registers custom method', () {
      final router = _RecordingRouter();
      final app = Chase(router: router);

      app.route('CUSTOM', '/endpoint').handle((c) => c);

      expect(router.routes, [(method: 'CUSTOM', path: '/endpoint')]);
    });

    test('all registers all HTTP methods', () {
      final router = _RecordingRouter();
      final app = Chase(router: router);

      app.all('/api').handle((c) => c);

      expect(router.routes, [
        (method: 'GET', path: '/api'),
        (method: 'POST', path: '/api'),
        (method: 'PUT', path: '/api'),
        (method: 'DELETE', path: '/api'),
        (method: 'PATCH', path: '/api'),
        (method: 'HEAD', path: '/api'),
        (method: 'OPTIONS', path: '/api'),
      ]);
    });

    test('all works with groups', () {
      final router = _RecordingRouter();
      final app = Chase(router: router);

      final api = app.path('/api');
      api.all('/proxy').handle((c) => c);

      expect(router.routes.length, 7);
      expect(router.routes.first.path, '/api/proxy');
    });

    test('on registers specified HTTP methods', () {
      final router = _RecordingRouter();
      final app = Chase(router: router);

      app.on(['GET', 'POST'], '/form').handle((c) => c);

      expect(router.routes, [
        (method: 'GET', path: '/form'),
        (method: 'POST', path: '/form'),
      ]);
    });

    test('on normalizes method names to uppercase', () {
      final router = _RecordingRouter();
      final app = Chase(router: router);

      app.on(['get', 'post', 'Put'], '/mixed').handle((c) => c);

      expect(router.routes, [
        (method: 'GET', path: '/mixed'),
        (method: 'POST', path: '/mixed'),
        (method: 'PUT', path: '/mixed'),
      ]);
    });

    test('on works with groups', () {
      final router = _RecordingRouter();
      final app = Chase(router: router);

      final api = app.path('/api');
      api.on(['GET', 'HEAD'], '/resource').handle((c) => c);

      expect(router.routes, [
        (method: 'GET', path: '/api/resource'),
        (method: 'HEAD', path: '/api/resource'),
      ]);
    });
  });

  group('Lifecycle', () {
    test('onStart callback is called when server starts', () async {
      final app = Chase();
      var startCalled = false;

      app.onStart(() {
        startCalled = true;
      });

      app.get('/').handle((ctx) => 'ok');

      final client = await TestClient.start(app);
      addTearDown(() => client.close());

      expect(startCalled, isTrue);
    });

    test('multiple onStart callbacks are called in order', () async {
      final app = Chase();
      final calls = <int>[];

      app.onStart(() => calls.add(1));
      app.onStart(() => calls.add(2));
      app.onStart(() => calls.add(3));

      app.get('/').handle((ctx) => 'ok');

      final client = await TestClient.start(app);
      addTearDown(() => client.close());

      expect(calls, [1, 2, 3]);
    });

    test('isRunning returns correct state', () async {
      final app = Chase();
      app.get('/').handle((ctx) => 'ok');

      expect(app.isRunning, isFalse);

      final client = await TestClient.start(app);

      expect(app.isRunning, isTrue);

      await client.close();

      expect(app.isRunning, isFalse);
    });
  });

  group('Not Found', () {
    test('default 404 handler returns Not Found', () async {
      final app = Chase();
      app.get('/exists').handle((ctx) => 'ok');

      final client = await TestClient.start(app);
      addTearDown(() => client.close());

      final res = await client.get('/does-not-exist');

      expect(res.status, 404);
      expect(await res.body, '404 Not Found');
    });

    test('custom notFound handler is used', () async {
      final app = Chase();

      app.notFound((ctx) {
        return {'error': 'Custom not found', 'path': ctx.req.path};
      });

      app.get('/exists').handle((ctx) => 'ok');

      final client = await TestClient.start(app);
      addTearDown(() => client.close());

      final res = await client.get('/missing');

      expect(res.status, 200);
      expect(await res.body, contains('Custom not found'));
      expect(await res.body, contains('/missing'));
    });
  });

  group('Integration', () {
    test('grouped routes work with actual HTTP requests', () async {
      final app = Chase();

      app.routes('/api', (api) {
        api.get('/hello').handle((ctx) => 'Hello from API');

        api.routes('/v1', (v1) {
          v1.get('/version').handle((ctx) => 'v1.0.0');
        });
      });

      final client = await TestClient.start(app);
      addTearDown(() => client.close());

      final res1 = await client.get('/api/hello');
      expect(res1.status, 200);
      expect(await res1.body, 'Hello from API');

      final res2 = await client.get('/api/v1/version');
      expect(res2.status, 200);
      expect(await res2.body, 'v1.0.0');
    });

    test('all() handles multiple HTTP methods', () async {
      final app = Chase();

      app.all('/echo').handle((ctx) => 'Method: ${ctx.req.method}');

      final client = await TestClient.start(app);
      addTearDown(() => client.close());

      final getRes = await client.get('/echo');
      expect(getRes.status, 200);
      expect(await getRes.body, 'Method: GET');

      final postRes = await client.post('/echo');
      expect(postRes.status, 200);
      expect(await postRes.body, 'Method: POST');

      final putRes = await client.put('/echo');
      expect(putRes.status, 200);
      expect(await putRes.body, 'Method: PUT');

      final deleteRes = await client.delete('/echo');
      expect(deleteRes.status, 200);
      expect(await deleteRes.body, 'Method: DELETE');
    });

    test('on() handles specified HTTP methods only', () async {
      final app = Chase();

      app.on(['GET', 'POST'], '/form').handle((ctx) => 'OK: ${ctx.req.method}');

      final client = await TestClient.start(app);
      addTearDown(() => client.close());

      final getRes = await client.get('/form');
      expect(getRes.status, 200);
      expect(await getRes.body, 'OK: GET');

      final postRes = await client.post('/form');
      expect(postRes.status, 200);
      expect(await postRes.body, 'OK: POST');

      // PUT is not registered, should return 404
      final putRes = await client.put('/form');
      expect(putRes.status, 404);
    });
  });
}
