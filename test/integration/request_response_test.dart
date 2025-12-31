import 'package:chase/chase.dart';
import 'package:chase/testing/testing.dart';
import 'package:test/test.dart';

void main() {
  group('Request/Response Integration', () {
    late Chase app;
    late TestClient client;

    tearDown(() async {
      await client.close();
    });

    group('JSON handling', () {
      test('parses JSON request body', () async {
        app = Chase();
        app.post('/echo').handle((ctx) async {
          final body = await ctx.req.json();
          ctx.res.json({'received': body});
        });

        client = await TestClient.start(app);
        final res = await client.post(
          '/echo',
          body: {
            'name': 'John',
            'age': 30,
            'tags': ['a', 'b'],
          },
        );

        final json = await res.json;
        expect(json, hasJsonPath('received.name', 'John'));
        expect(json, hasJsonPath('received.age', 30));
        expect(json, hasJsonPath('received.tags', ['a', 'b']));
      });

      test('handles nested JSON', () async {
        app = Chase();
        app.post('/nested').handle((ctx) async {
          final body = await ctx.req.json() as Map<String, dynamic>;
          ctx.res.json({
            'user': body['user']['name'],
            'city': body['address']['city'],
          });
        });

        client = await TestClient.start(app);
        final res = await client.post(
          '/nested',
          body: {
            'user': {'name': 'Alice', 'email': 'alice@example.com'},
            'address': {'city': 'Tokyo', 'country': 'Japan'},
          },
        );

        final json = await res.json;
        expect(json, hasJsonPath('user', 'Alice'));
        expect(json, hasJsonPath('city', 'Tokyo'));
      });
    });

    group('response types', () {
      test('text response', () async {
        app = Chase();
        app.get('/text').handle((ctx) {
          ctx.res.text('Hello, World!');
        });

        client = await TestClient.start(app);
        final res = await client.get('/text');

        expect(res, isOkResponse);
        expect(await res.body, 'Hello, World!');
        expect(res, hasContentType('text/plain'));
      });

      test('JSON response', () async {
        app = Chase();
        app.get('/json').handle((ctx) {
          ctx.res.json({'message': 'Hello', 'count': 42});
        });

        client = await TestClient.start(app);
        final res = await client.get('/json');

        expect(res, isOkResponse);
        expect(res, hasContentType('application/json'));
        final json = await res.json;
        expect(json, hasJsonPath('message', 'Hello'));
        expect(json, hasJsonPath('count', 42));
      });

      test('HTML response', () async {
        app = Chase();
        app.get('/html').handle((ctx) {
          ctx.res.html('<h1>Hello</h1>');
        });

        client = await TestClient.start(app);
        final res = await client.get('/html');

        expect(res, isOkResponse);
        expect(res, hasContentType('text/html'));
        expect(await res.body, '<h1>Hello</h1>');
      });

      test('custom status code', () async {
        app = Chase();
        app.post('/users').handle((ctx) {
          ctx.res.json({'id': 1}, status: 201);
        });

        client = await TestClient.start(app);
        final res = await client.post('/users', body: {'name': 'John'});

        expect(res, hasStatus(201));
      });

      test('redirect response', () async {
        app = Chase();
        app.get('/old').handle((ctx) {
          ctx.res.redirect('/new');
        });
        app.get('/new').handle((ctx) {
          ctx.res.text('New location');
        });

        client = await TestClient.start(app);
        final res = await client.get('/old');

        // TestClient does not follow redirects to allow inspection
        expect(res, isRedirectResponse);
        expect(res, hasHeader('location', '/new'));
      });
    });

    group('headers', () {
      test('reads request headers', () async {
        app = Chase();
        app.get('/headers').handle((ctx) {
          ctx.res.json({
            'userAgent': ctx.req.userAgent,
            'accept': ctx.req.accept,
            'custom': ctx.req.header('x-custom'),
          });
        });

        client = await TestClient.start(app);
        final res = await client.get(
          '/headers',
          headers: {
            'User-Agent': 'TestClient/1.0',
            'Accept': 'application/json',
            'X-Custom': 'custom-value',
          },
        );

        final json = await res.json;
        expect(json, hasJsonPath('userAgent', 'TestClient/1.0'));
        expect(json, hasJsonPath('accept', 'application/json'));
        expect(json, hasJsonPath('custom', 'custom-value'));
      });

      test('sets response headers', () async {
        app = Chase();
        app.get('/set-headers').handle((ctx) {
          ctx.res.headers.set('X-Custom', 'value');
          ctx.res.headers.set('X-Request-Id', '12345');
          ctx.res.text('OK');
        });

        client = await TestClient.start(app);
        final res = await client.get('/set-headers');

        expect(res, hasHeader('x-custom', 'value'));
        expect(res, hasHeader('x-request-id', '12345'));
      });
    });

    group('context store', () {
      test('middleware can pass data to handlers via store', () async {
        app = Chase();
        app.use(_UserLoaderMiddleware());
        app.get('/profile').handle((ctx) {
          final user = ctx.get<Map<String, dynamic>>('user');
          ctx.res.json({'name': user?['name']});
        });

        client = await TestClient.start(app);
        final res = await client.get('/profile', headers: {'X-User-Id': '123'});

        expect(await res.json, hasJsonPath('name', 'User 123'));
      });
    });

    group('error handling', () {
      test('handles uncaught exceptions gracefully', () async {
        app = Chase();
        app.use(ExceptionHandler());
        app.get('/throw').handle((ctx) {
          throw Exception('Something went wrong');
        });

        client = await TestClient.start(app);
        final res = await client.get('/throw');

        expect(res, isServerErrorResponse);
      });

      test('HttpException sets correct status', () async {
        app = Chase();
        app.use(ExceptionHandler());

        app.get('/not-found').handle((ctx) {
          throw const NotFoundException('Resource not found');
        });
        app.get('/forbidden').handle((ctx) {
          throw const ForbiddenException('Access denied');
        });

        client = await TestClient.start(app);

        expect(await client.get('/not-found'), hasStatus(404));
        expect(await client.get('/forbidden'), hasStatus(403));
      });
    });
  });
}

class _UserLoaderMiddleware extends Middleware {
  @override
  Future<void> handle(Context ctx, NextFunction next) async {
    final userId = ctx.req.header('x-user-id');
    if (userId != null) {
      ctx.set('user', {'id': userId, 'name': 'User $userId'});
    }
    await next();
  }
}
