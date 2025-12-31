import 'dart:convert';

import 'package:chase/chase.dart';
import 'package:chase/testing/testing.dart';
import 'package:test/test.dart';

void main() {
  group('AuthHelper', () {
    test('bearer creates Authorization header', () {
      final headers = AuthHelper.bearer('my-token');
      expect(headers['authorization'], 'Bearer my-token');
    });

    test('basic creates Base64 encoded header', () {
      final headers = AuthHelper.basic('user', 'pass');
      final expected = base64Encode(utf8.encode('user:pass'));
      expect(headers['authorization'], 'Basic $expected');
    });

    test('custom creates custom scheme header', () {
      final headers = AuthHelper.custom('ApiKey', 'secret123');
      expect(headers['authorization'], 'ApiKey secret123');
    });
  });

  group('RequestHelper', () {
    test('jsonHeaders has correct content-type', () {
      expect(RequestHelper.jsonHeaders['content-type'], 'application/json');
    });

    test('formHeaders has correct content-type', () {
      expect(
        RequestHelper.formHeaders['content-type'],
        'application/x-www-form-urlencoded',
      );
    });

    test('mergeHeaders combines multiple maps', () {
      final merged = RequestHelper.mergeHeaders(
        {'a': '1'},
        {'b': '2'},
        {'c': '3'},
      );
      expect(merged, {'a': '1', 'b': '2', 'c': '3'});
    });

    test('encodeForm encodes map as form data', () {
      final encoded = RequestHelper.encodeForm({
        'name': 'John Doe',
        'email': 'john@example.com',
      });
      expect(encoded, 'name=John%20Doe&email=john%40example.com');
    });
  });

  group('FluentAssertions', () {
    late Chase app;
    late TestClient client;

    setUp(() async {
      app = Chase(dev: true);
      client = await TestClient.start(app);
    });

    tearDown(() async {
      await client.close();
    });

    test('expect.status passes for matching status', () async {
      app.get('/fluent/ok').handle((ctx) async {
        ctx.res.statusCode = 200;
        ctx.res.text('OK');
      });

      final res = await client.get('/fluent/ok');
      res.expect.status(200);
    });

    test('expect.status throws for non-matching status', () async {
      app.get('/fluent/notfound').handle((ctx) async {
        ctx.res.text('Not Found', status: 404);
      });

      final res = await client.get('/fluent/notfound');
      expect(() => res.expect.status(200), throwsA(isA<ChaseTestFailure>()));
    });

    test('expect.isOk passes for 2xx', () async {
      app.get('/fluent/created').handle((ctx) async {
        ctx.res.text('Created', status: 201);
      });

      final res = await client.get('/fluent/created');
      res.expect.isOk();
    });

    test('expect.isClientError passes for 4xx', () async {
      app.get('/fluent/bad').handle((ctx) async {
        ctx.res.text('Bad Request', status: 400);
      });

      final res = await client.get('/fluent/bad');
      res.expect.isClientError();
    });

    test('expect.header checks header value', () async {
      app.get('/fluent/headers').handle((ctx) async {
        ctx.res.headers.set('x-custom', 'value');
        ctx.res.text('OK');
      });

      final res = await client.get('/fluent/headers');
      res.expect.header('x-custom', 'value');
    });

    test('expect.contentType checks content-type', () async {
      app.get('/fluent/json').handle((ctx) async {
        ctx.res.json({'ok': true});
      });

      final res = await client.get('/fluent/json');
      res.expect.contentType('json');
    });

    test('expect.jsonPath checks JSON values', () async {
      app.get('/fluent/user').handle((ctx) async {
        ctx.res.json({'user': {'name': 'Alice'}});
      });

      final res = await client.get('/fluent/user');
      await res.expect.jsonPath('user.name', 'Alice');
    });

    test('chained assertions work', () async {
      app.get('/fluent/api').handle((ctx) async {
        ctx.res.json({'status': 'ok'});
      });

      final res = await client.get('/fluent/api');
      await res.expect.status(200).contentType('json').jsonPath('status', 'ok');
    });
  });

  group('CookieTestingExtension', () {
    late Chase app;
    late TestClient client;

    setUp(() async {
      app = Chase(dev: true);
      client = await TestClient.start(app);
    });

    tearDown(() async {
      await client.close();
    });

    test('cookieValues returns all cookies', () async {
      app.get('/cookie/all').handle((ctx) async {
        ctx.res.cookie('a', '1');
        ctx.res.cookie('b', '2');
        ctx.res.text('OK');
      });

      final res = await client.get('/cookie/all');
      expect(res.cookieValues, {'a': '1', 'b': '2'});
    });

    test('getCookie returns specific cookie value', () async {
      app.get('/cookie/get').handle((ctx) async {
        ctx.res.cookie('token', 'secret');
        ctx.res.text('OK');
      });

      final res = await client.get('/cookie/get');
      expect(res.getCookie('token'), 'secret');
      expect(res.getCookie('missing'), isNull);
    });

    test('hasCookieNamed checks cookie existence', () async {
      app.get('/cookie/exists').handle((ctx) async {
        ctx.res.cookie('session', 'abc');
        ctx.res.text('OK');
      });

      final res = await client.get('/cookie/exists');
      expect(res.hasCookieNamed('session'), isTrue);
      expect(res.hasCookieNamed('other'), isFalse);
    });
  });

  group('TestClientExtensions', () {
    late Chase app;
    late TestClient client;

    setUp(() async {
      app = Chase(dev: true);
      client = await TestClient.start(app);
    });

    tearDown(() async {
      await client.close();
    });

    test('getWithAuth sends Bearer token', () async {
      app.get('/ext/protected').handle((ctx) async {
        final auth = ctx.req.header('authorization');
        ctx.res.json({'auth': auth});
      });

      final res = await client.getWithAuth('/ext/protected', 'my-token');
      final json = await res.json;
      expect(json['auth'], 'Bearer my-token');
    });

    test('postJson sends JSON body with content-type', () async {
      app.post('/ext/users').handle((ctx) async {
        final body = await ctx.req.json();
        ctx.res.json(body);
      });

      final res = await client.postJson('/ext/users', {'name': 'John'});
      final json = await res.json;
      expect(json['name'], 'John');
    });

    test('postJson with token sends auth header', () async {
      app.post('/ext/users/auth').handle((ctx) async {
        final auth = ctx.req.header('authorization');
        final body = await ctx.req.json();
        ctx.res.json({'auth': auth, ...body as Map});
      });

      final res = await client.postJson(
        '/ext/users/auth',
        {'name': 'John'},
        token: 'jwt-token',
      );
      final json = await res.json;
      expect(json['auth'], 'Bearer jwt-token');
      expect(json['name'], 'John');
    });
  });
}
