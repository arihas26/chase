import 'dart:convert';
import 'dart:io';

import 'package:chase/chase.dart';
import 'package:test/test.dart';

void main() {
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

    final request =
        await client.postUrl(Uri.parse('http://localhost:${server.port}/users'));
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode({'name': 'Alice'}));

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    expect(response.statusCode, HttpStatus.ok);
    expect(response.headers.contentType?.mimeType, ContentType.json.mimeType);
    expect(responseBody, '{"ok":true,"name":"Alice"}');
  });
}

