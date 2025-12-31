import 'package:chase/chase.dart';
import 'package:chase/testing/testing.dart';
import 'package:test/test.dart';

void main() {
  group('TestClient', () {
    late Chase app;
    late TestClient client;

    setUp(() async {
      app = Chase();
      // Routes are set up before starting
    });

    tearDown(() async {
      await client.close();
    });

    group('HTTP methods', () {
      test('GET request', () async {
        app.get('/hello').handle((ctx) {
          ctx.res.text('Hello, World!');
        });
        client = await TestClient.start(app);

        final res = await client.get('/hello');

        expect(res, isOkResponse);
        expect(await res.body, 'Hello, World!');
      });

      test('POST request with JSON body', () async {
        app.post('/users').handle((ctx) async {
          final body = await ctx.req.json();
          ctx.res.json({'received': body});
        });
        client = await TestClient.start(app);

        final res = await client.post('/users', body: {'name': 'John'});

        expect(res, isOkResponse);
        expect(await res.json, hasJsonPath('received.name', 'John'));
      });

      test('PUT request', () async {
        app.put('/users/:id').handle((ctx) {
          ctx.res.json({'updated': ctx.req.params['id']});
        });
        client = await TestClient.start(app);

        final res = await client.put('/users/123', body: {'name': 'Jane'});

        expect(res, isOkResponse);
        expect(await res.json, hasJsonPath('updated', '123'));
      });

      test('PATCH request', () async {
        app.patch('/users/:id').handle((ctx) {
          ctx.res.json({'patched': ctx.req.params['id']});
        });
        client = await TestClient.start(app);

        final res = await client.patch('/users/456');

        expect(res, isOkResponse);
        expect(await res.json, hasJsonPath('patched', '456'));
      });

      test('DELETE request', () async {
        app.delete('/users/:id').handle((ctx) {
          ctx.res.text('Deleted ${ctx.req.params['id']}');
        });
        client = await TestClient.start(app);

        final res = await client.delete('/users/789');

        expect(res, isOkResponse);
        expect(await res.body, 'Deleted 789');
      });
    });

    group('route parameters', () {
      test('extracts single parameter', () async {
        app.get('/users/:id').handle((ctx) {
          ctx.res.json({'id': ctx.req.params['id']});
        });
        client = await TestClient.start(app);

        final res = await client.get('/users/42');

        expect(await res.json, hasJsonPath('id', '42'));
      });

      test('extracts multiple parameters', () async {
        app.get('/users/:userId/posts/:postId').handle((ctx) {
          ctx.res.json({
            'userId': ctx.req.params['userId'],
            'postId': ctx.req.params['postId'],
          });
        });
        client = await TestClient.start(app);

        final res = await client.get('/users/1/posts/99');

        final json = await res.json;
        expect(json, hasJsonPath('userId', '1'));
        expect(json, hasJsonPath('postId', '99'));
      });
    });

    group('middleware', () {
      test('applies global middleware', () async {
        app.use(_AddHeaderMiddleware('X-Custom', 'test-value'));
        app.get('/').handle((ctx) {
          ctx.res.text('OK');
        });
        client = await TestClient.start(app);

        final res = await client.get('/');

        expect(res, hasHeader('x-custom', 'test-value'));
      });

      test('applies route-specific middleware', () async {
        app
            .get('/protected')
            .use(_AddHeaderMiddleware('X-Auth', 'required'))
            .handle((ctx) {
          ctx.res.text('Secret');
        });
        client = await TestClient.start(app);

        final res = await client.get('/protected');

        expect(res, hasHeader('x-auth', 'required'));
        expect(await res.body, 'Secret');
      });
    });

    group('404 handling', () {
      test('returns 404 for unknown route', () async {
        client = await TestClient.start(app);

        final res = await client.get('/unknown');

        expect(res, isClientErrorResponse);
        expect(res, hasStatus(404));
        expect(await res.body, '404 Not Found');
      });
    });

    group('headers', () {
      test('sends custom headers', () async {
        app.get('/echo-header').handle((ctx) {
          final auth = ctx.req.header('authorization');
          ctx.res.json({'auth': auth});
        });
        client = await TestClient.start(app);

        final res = await client.getWithAuth('/echo-header', 'token123');

        expect(await res.json, hasJsonPath('auth', 'Bearer token123'));
      });
    });

    group('TestResponse helpers', () {
      test('isOk returns true for 2xx', () async {
        app.get('/ok').handle((ctx) => ctx.res.text('OK'));
        app.get('/created').handle((ctx) => ctx.res.text('Created', status: 201));
        client = await TestClient.start(app);

        expect(await client.get('/ok'), isOkResponse);
        expect(await client.get('/created'), isOkResponse);
      });

      test('isClientError returns true for 4xx', () async {
        app.get('/bad').handle((ctx) => ctx.res.text('Bad', status: 400));
        app.get('/notfound').handle((ctx) => ctx.res.text('Not Found', status: 404));
        client = await TestClient.start(app);

        expect(await client.get('/bad'), isClientErrorResponse);
        expect(await client.get('/notfound'), isClientErrorResponse);
      });

      test('isServerError returns true for 5xx', () async {
        app.get('/error').handle((ctx) => ctx.res.text('Error', status: 500));
        client = await TestClient.start(app);

        expect(await client.get('/error'), isServerErrorResponse);
      });

      test('contentType returns content-type header', () async {
        app.get('/json').handle((ctx) => ctx.res.json({'a': 1}));
        client = await TestClient.start(app);

        final res = await client.get('/json');

        expect(res, hasContentType('application/json'));
      });
    });

    group('route groups', () {
      test('works with route groups', () async {
        final api = app.path('/api');
        api.get('/users').handle((ctx) => ctx.res.json({'users': []}));
        api.get('/posts').handle((ctx) => ctx.res.json({'posts': []}));
        client = await TestClient.start(app);

        final usersRes = await client.get('/api/users');
        final postsRes = await client.get('/api/posts');

        expect(await usersRes.json, hasJsonPath('users', []));
        expect(await postsRes.json, hasJsonPath('posts', []));
      });
    });
  });
}

class _AddHeaderMiddleware extends Middleware {
  final String name;
  final String value;

  _AddHeaderMiddleware(this.name, this.value);

  @override
  Future<void> handle(Context ctx, NextFunction next) async {
    ctx.res.headers.set(name, value);
    await next();
  }
}
