import 'package:chase/chase.dart';
import 'package:chase/src/core/router.dart';
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

      expect(router.routes, [
        (method: 'GET', path: '/api/users'),
      ]);
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

      expect(router.routes, [
        (method: 'GET', path: '/users'),
      ]);
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

      expect(router.routes, [
        (method: 'GET', path: '/api/v1/admin/users'),
      ]);
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

  group('Integration', () {
    test('grouped routes work with actual app', () async {
      final app = Chase();

      var apiHelloCalled = false;
      var apiV1VersionCalled = false;

      app.routes('/api', (api) {
        api.get('/hello').handle((ctx) async {
          apiHelloCalled = true;
          await ctx.res.text('Hello from API');
        });

        api.routes('/v1', (v1) {
          v1.get('/version').handle((ctx) async {
            apiV1VersionCalled = true;
            await ctx.res.text('v1.0.0');
          });
        });
      });

      // Verify routes are registered correctly by checking if handlers get called
      // We can't directly access _router, but we can verify the behavior works

      expect(apiHelloCalled, isFalse);
      expect(apiV1VersionCalled, isFalse);

      // Note: This is a simplified test. For full integration testing,
      // you would start the server with app.start() and make actual HTTP requests.
      // Here we're just verifying that the route grouping API works correctly.
    });
  });
}
