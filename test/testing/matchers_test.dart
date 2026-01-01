import 'package:chase/chase.dart';
import 'package:chase/testing/testing.dart';
import 'package:test/test.dart';

void main() {
  late Chase app;
  late TestClient client;

  setUp(() async {
    app = Chase(dev: true);
    client = await TestClient.start(app);
  });

  tearDown(() async {
    await client.close();
  });

  group('Status Matchers', () {
    test('isOkResponse matches 2xx responses', () async {
      app.get('/status/ok').handle((ctx) async {
        ctx.res.statusCode = 200;
        ctx.res.text('OK');
      });

      final res = await client.get('/status/ok');
      expect(res, isOkResponse);
    });

    test('isOkResponse does not match 4xx responses', () async {
      app.get('/status/notfound').handle((ctx) async {
        ctx.res.text('Not Found', status: 404);
      });

      final res = await client.get('/status/notfound');
      expect(res, isNot(isOkResponse));
      expect(res, isClientErrorResponse);
    });

    test('isServerErrorResponse matches 5xx responses', () async {
      app.get('/status/error').handle((ctx) async {
        ctx.res.text('Error', status: 500);
      });

      final res = await client.get('/status/error');
      expect(res, isServerErrorResponse);
    });

    test('isRedirectResponse matches 3xx responses', () async {
      app.get('/status/redirect').handle((ctx) async {
        ctx.res.headers.set('location', '/other');
        ctx.res.text('', status: 302);
      });

      final res = await client.get('/status/redirect');
      expect(res, isRedirectResponse);
    });

    test('hasStatus matches exact status code', () async {
      app.get('/status/created').handle((ctx) async {
        ctx.res.text('Created', status: 201);
      });

      final res = await client.get('/status/created');
      expect(res, hasStatus(201));
      expect(res, isNot(hasStatus(200)));
    });
  });

  group('Header Matchers', () {
    test('hasHeader checks for header presence', () async {
      app.get('/header/presence').handle((ctx) async {
        ctx.res.headers.set('x-custom', 'value');
        ctx.res.text('OK');
      });

      final res = await client.get('/header/presence');
      expect(res, hasHeader('x-custom'));
      expect(res, isNot(hasHeader('x-missing')));
    });

    test('hasHeader checks header value', () async {
      app.get('/header/value').handle((ctx) async {
        ctx.res.headers.set('x-custom', 'my-value');
        ctx.res.text('OK');
      });

      final res = await client.get('/header/value');
      expect(res, hasHeader('x-custom', 'my-value'));
      expect(res, isNot(hasHeader('x-custom', 'wrong-value')));
    });

    test('hasHeader works with matchers', () async {
      app.get('/header/matcher').handle((ctx) async {
        ctx.res.json({'key': 'value'});
      });

      final res = await client.get('/header/matcher');
      expect(res, hasHeader('content-type', contains('json')));
    });

    test('hasContentType convenience matcher', () async {
      app.get('/header/contenttype').handle((ctx) async {
        ctx.res.json({'key': 'value'});
      });

      final res = await client.get('/header/contenttype');
      expect(res, hasContentType('application/json'));
    });
  });

  group('JSON Path Matcher', () {
    test('hasJsonPath checks path value', () async {
      app.get('/json/user').handle((ctx) async {
        ctx.res.json({
          'user': {'name': 'John', 'age': 30},
          'items': [1, 2, 3],
        });
      });

      final res = await client.get('/json/user');
      final json = await res.json;

      expect(json, hasJsonPath('user.name', 'John'));
      expect(json, hasJsonPath('user.age', 30));
      expect(json, hasJsonPath('items.0', 1));
    });

    test('hasJsonPath works with matchers', () async {
      app.get('/json/items').handle((ctx) async {
        ctx.res.json({
          'items': [1, 2, 3, 4, 5],
        });
      });

      final res = await client.get('/json/items');
      final json = await res.json;

      expect(json, hasJsonPath('items', hasLength(5)));
    });
  });

  group('Cookie Matchers', () {
    test('hasCookie checks for cookie presence', () async {
      app.get('/cookie/presence').handle((ctx) async {
        ctx.res.cookie('session', 'abc123');
        ctx.res.text('OK');
      });

      final res = await client.get('/cookie/presence');
      expect(res, hasCookie('session'));
      expect(res, isNot(hasCookie('other')));
    });

    test('hasCookie checks cookie value', () async {
      app.get('/cookie/value').handle((ctx) async {
        ctx.res.cookie('token', 'xyz789');
        ctx.res.text('OK');
      });

      final res = await client.get('/cookie/value');
      expect(res, hasCookie('token', 'xyz789'));
      expect(res, isNot(hasCookie('token', 'wrong')));
    });
  });
}
