import 'dart:io';

import 'package:chase/chase.dart';
import 'package:chase/testing/testing.dart';
import 'package:test/test.dart';

void main() {
  group('Method Override', () {
    group('form field', () {
      late Chase app;
      late TestClient client;

      setUp(() async {
        app = Chase()..methodOverride();
        app.delete('/posts/:id').handle((ctx) {
          return {'deleted': ctx.req.param('id'), 'method': ctx.req.method};
        });
        app.put('/posts/:id').handle((ctx) {
          return {'updated': ctx.req.param('id'), 'method': ctx.req.method};
        });
        app.patch('/posts/:id').handle((ctx) {
          return {'patched': ctx.req.param('id'), 'method': ctx.req.method};
        });
        client = await TestClient.start(app);
      });

      tearDown(() => client.close());

      test('overrides POST to DELETE via form field', () async {
        final res = await client.post(
          '/posts/123',
          headers: {'content-type': 'application/x-www-form-urlencoded'},
          body: '_method=DELETE',
        );
        expect(res, hasStatus(200));
        final json = await res.json;
        expect(json['deleted'], '123');
        expect(json['method'], 'DELETE');
      });

      test('overrides POST to PUT via form field', () async {
        final res = await client.post(
          '/posts/123',
          headers: {'content-type': 'application/x-www-form-urlencoded'},
          body: '_method=PUT',
        );
        expect(res, hasStatus(200));
        final json = await res.json;
        expect(json['updated'], '123');
        expect(json['method'], 'PUT');
      });

      test('overrides POST to PATCH via form field', () async {
        final res = await client.post(
          '/posts/123',
          headers: {'content-type': 'application/x-www-form-urlencoded'},
          body: '_method=PATCH',
        );
        expect(res, hasStatus(200));
        final json = await res.json;
        expect(json['patched'], '123');
        expect(json['method'], 'PATCH');
      });

      test('case insensitive method value', () async {
        final res = await client.post(
          '/posts/123',
          headers: {'content-type': 'application/x-www-form-urlencoded'},
          body: '_method=delete',
        );
        expect(res, hasStatus(200));
        final json = await res.json;
        expect(json['method'], 'DELETE');
      });

      test('ignores invalid method override', () async {
        final res = await client.post(
          '/posts/123',
          headers: {'content-type': 'application/x-www-form-urlencoded'},
          body: '_method=GET',
        );
        expect(res, hasStatus(404)); // POST /posts/123 not found
      });
    });

    group('header', () {
      late Chase app;
      late TestClient client;

      setUp(() async {
        app = Chase()..methodOverride(form: null, header: 'X-HTTP-Method-Override');
        app.delete('/posts/:id').handle((ctx) {
          return {'deleted': ctx.req.param('id')};
        });
        client = await TestClient.start(app);
      });

      tearDown(() => client.close());

      test('overrides POST to DELETE via header', () async {
        final res = await client.post(
          '/posts/123',
          headers: {'X-HTTP-Method-Override': 'DELETE'},
        );
        expect(res, hasStatus(200));
        final json = await res.json;
        expect(json['deleted'], '123');
      });
    });

    group('query parameter', () {
      late Chase app;
      late TestClient client;

      setUp(() async {
        app = Chase()..methodOverride(form: null, query: '_method');
        app.delete('/posts/:id').handle((ctx) {
          return {'deleted': ctx.req.param('id')};
        });
        client = await TestClient.start(app);
      });

      tearDown(() => client.close());

      test('overrides POST to DELETE via query parameter', () async {
        final res = await client.post('/posts/123?_method=DELETE');
        expect(res, hasStatus(200));
        final json = await res.json;
        expect(json['deleted'], '123');
      });
    });

    group('rawMethod', () {
      late Chase app;
      late TestClient client;

      setUp(() async {
        app = Chase()..methodOverride();
        app.delete('/posts/:id').handle((ctx) {
          return {
            'method': ctx.req.method,
            'rawMethod': ctx.req.rawMethod,
          };
        });
        client = await TestClient.start(app);
      });

      tearDown(() => client.close());

      test('rawMethod returns original method', () async {
        final res = await client.post(
          '/posts/123',
          headers: {'content-type': 'application/x-www-form-urlencoded'},
          body: '_method=DELETE',
        );
        expect(res, hasStatus(200));
        final json = await res.json;
        expect(json['method'], 'DELETE');
        expect(json['rawMethod'], 'POST');
      });
    });

    group('only applies to POST', () {
      late Chase app;
      late TestClient client;

      setUp(() async {
        app = Chase()..methodOverride(form: null, query: '_method');
        app.get('/posts/:id').handle((ctx) {
          return {'method': ctx.req.method};
        });
        app.delete('/posts/:id').handle((ctx) {
          return {'method': ctx.req.method};
        });
        client = await TestClient.start(app);
      });

      tearDown(() => client.close());

      test('does not override GET requests', () async {
        final res = await client.get('/posts/123?_method=DELETE');
        expect(res, hasStatus(200));
        final json = await res.json;
        expect(json['method'], 'GET');
      });
    });

    group('disabled by default', () {
      late Chase app;
      late TestClient client;

      setUp(() async {
        app = Chase();
        app.delete('/posts/:id').handle((ctx) {
          return {'deleted': ctx.req.param('id')};
        });
        client = await TestClient.start(app);
      });

      tearDown(() => client.close());

      test('does not override without calling methodOverride()', () async {
        final res = await client.post(
          '/posts/123',
          headers: {'content-type': 'application/x-www-form-urlencoded'},
          body: '_method=DELETE',
        );
        expect(res, hasStatus(404)); // POST /posts/123 not found
      });
    });

    group('priority', () {
      late Chase app;
      late TestClient client;

      setUp(() async {
        app = Chase()
          ..methodOverride(
            form: '_method',
            header: 'X-Method',
            query: 'method',
          );
        app.delete('/posts/:id').handle((ctx) => {'method': 'DELETE'});
        app.put('/posts/:id').handle((ctx) => {'method': 'PUT'});
        app.patch('/posts/:id').handle((ctx) => {'method': 'PATCH'});
        client = await TestClient.start(app);
      });

      tearDown(() => client.close());

      test('header takes priority over query and form', () async {
        final res = await client.post(
          '/posts/123?method=PATCH',
          headers: {
            'X-Method': 'DELETE',
            'content-type': 'application/x-www-form-urlencoded',
          },
          body: '_method=PUT',
        );
        expect(res, hasStatus(200));
        final json = await res.json;
        expect(json['method'], 'DELETE');
      });

      test('query takes priority over form', () async {
        final res = await client.post(
          '/posts/123?method=PATCH',
          headers: {'content-type': 'application/x-www-form-urlencoded'},
          body: '_method=PUT',
        );
        expect(res, hasStatus(200));
        final json = await res.json;
        expect(json['method'], 'PATCH');
      });
    });
  });
}
