import 'dart:convert';
import 'dart:io';

import 'package:chase/chase.dart';
import 'package:chase/testing/testing.dart';
import 'package:test/test.dart';

void main() {
  group('JSON body parsing', () {
    test('handler reads json body and responds', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      server.listen((req) async {
        final ctx = Context(req, req.response);
        final body = await ctx.req.json() as Map<String, dynamic>?;
        await ctx.res.json({'ok': body != null, 'name': body?['name']});
      });

      final client = HttpClient();
      addTearDown(client.close);

      final request = await client.postUrl(
        Uri.parse('http://localhost:${server.port}/users'),
      );
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'name': 'Alice'}));

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      expect(response.statusCode, HttpStatus.ok);
      expect(response.headers.contentType?.mimeType, ContentType.json.mimeType);
      expect(responseBody, '{"ok":true,"name":"Alice"}');
    });

    test('json() caches null value correctly', () async {
      // Create a request with JSON body 'null'
      final ctx = TestContext.post(
        '/test',
        body: 'null',
        headers: {'content-type': 'application/json'},
      );

      // First call should return null
      final result1 = await ctx.req.json();
      expect(result1, isNull);

      // Second call should also return null (cached)
      final result2 = await ctx.req.json();
      expect(result2, isNull);
    });

    test('json() caches result and does not re-parse', () async {
      final ctx = TestContext.post(
        '/test',
        body: '{"key": "value"}',
        headers: {'content-type': 'application/json'},
      );

      // First call
      final result1 = await ctx.req.json() as Map<String, dynamic>;
      expect(result1['key'], 'value');

      // Second call should return cached result
      final result2 = await ctx.req.json() as Map<String, dynamic>;
      expect(result2['key'], 'value');

      // Both results should be the same instance
      expect(identical(result1, result2), isTrue);
    });
  });
}
