import 'dart:convert';
import 'dart:io';

import 'package:chase/chase.dart';
import 'package:chase/src/core/router.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

class _RecordingRouter implements Router {
  final List<({String method, String path, Handler handler})> calls = [];

  @override
  void add(String method, String path, Handler handler) {
    calls.add((method: method, path: path, handler: handler));
  }

  @override
  RouteMatch? match(String method, String path) => null;
}

void main() {
  group('Chase.static', () {
    test('registers mount + wildcard routes', () {
      final router = _RecordingRouter();
      final app = Chase(router: router);

      app.staticFiles('/assets', './public');

      expect(router.calls.map((c) => (c.method, c.path)).toList(), [
        ('GET', '/assets'),
        ('GET', '/assets/*path'),
      ]);
    });
  });

  group('StaticFileHandler', () {
    late String root;

    setUp(() {
      root = p.join(Directory.current.path, 'test', 'fixtures', 'static_public');
    });

    test('serves index.html when param is empty', () async {
      final handler = StaticFileHandler(root);

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      server.listen((req) async {
        final ctx = Context(req, req.response, {'path': ''});
        await handler(ctx);
      });

      final client = HttpClient();
      addTearDown(client.close);

      final response =
          await (await client.getUrl(Uri.parse('http://localhost:${server.port}/assets'))).close();
      final body = await response.transform(utf8.decoder).join();

      expect(response.statusCode, HttpStatus.ok);
      expect(body, contains('INDEX'));
    });

    test('serves extension fallback', () async {
      final handler = StaticFileHandler(
        root,
        options: const StaticOptions(extensions: ['.html']),
      );

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      server.listen((req) async {
        final ctx = Context(req, req.response, {'path': 'hello'});
        await handler(ctx);
      });

      final client = HttpClient();
      addTearDown(client.close);

      final response =
          await (await client.getUrl(Uri.parse('http://localhost:${server.port}/assets/hello'))).close();
      final body = await response.transform(utf8.decoder).join();

      expect(response.statusCode, HttpStatus.ok);
      expect(body, contains('HELLO'));
    });

    test('returns 304 when If-None-Match matches ETag', () async {
      final handler = StaticFileHandler(
        root,
        options: const StaticOptions(etag: true),
      );

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      server.listen((req) async {
        final ctx = Context(req, req.response, {'path': 'hello.html'});
        await handler(ctx);
      });

      final client = HttpClient();
      addTearDown(client.close);

      final url = Uri.parse('http://localhost:${server.port}/assets/hello.html');

      final first = await (await client.getUrl(url)).close();
      final etag = first.headers.value(HttpHeaders.etagHeader);
      await first.drain();

      expect(first.statusCode, HttpStatus.ok);
      expect(etag, isNotNull);

      final secondReq = await client.getUrl(url);
      secondReq.headers.set(HttpHeaders.ifNoneMatchHeader, etag!);
      final second = await secondReq.close();
      final body = await second.transform(utf8.decoder).join();

      expect(second.statusCode, HttpStatus.notModified);
      expect(body, isEmpty);
    });

    test('rejects directory traversal', () async {
      final handler = StaticFileHandler(root);

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      server.listen((req) async {
        final ctx = Context(req, req.response, {'path': '../secret.txt'});
        await handler(ctx);
      });

      final client = HttpClient();
      addTearDown(client.close);

      final response =
          await (await client.getUrl(Uri.parse('http://localhost:${server.port}/assets/traversal'))).close();
      final body = await response.transform(utf8.decoder).join();

      expect(response.statusCode, HttpStatus.notFound);
      expect(body, contains('404 Not Found'));
    });

    test('sets Cache-Control when maxAge is provided', () async {
      final handler = StaticFileHandler(
        root,
        options: const StaticOptions(maxAge: Duration(seconds: 60)),
      );

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      server.listen((req) async {
        final ctx = Context(req, req.response, {'path': 'hello.html'});
        await handler(ctx);
      });

      final client = HttpClient();
      addTearDown(client.close);

      final response = await (await client
              .getUrl(Uri.parse('http://localhost:${server.port}/assets/hello.html')))
          .close();
      await response.drain();

      expect(response.statusCode, HttpStatus.ok);
      expect(
        response.headers.value(HttpHeaders.cacheControlHeader),
        'public, max-age=60',
      );
    });
  });
}

