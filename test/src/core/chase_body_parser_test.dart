import 'dart:convert';
import 'dart:io';

import 'package:chase/chase.dart';
import 'package:test/test.dart';

void main() {
  test('req.formData parses application/x-www-form-urlencoded', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));

    server.listen((req) async {
      final ctx = Context(req, req.response);
      final form = await ctx.req.formData();
      await ctx.res.json(form);
    });

    final client = HttpClient();
    addTearDown(client.close);

    final request = await client.postUrl(
      Uri.parse('http://localhost:${server.port}/users'),
    );
    request.headers.contentType = ContentType.parse(
      'application/x-www-form-urlencoded',
    );
    request.write('name=Alice&city=hello%20world');

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    expect(response.statusCode, HttpStatus.ok);
    expect(response.headers.contentType?.mimeType, ContentType.json.mimeType);
    expect(jsonDecode(responseBody), {'name': 'Alice', 'city': 'hello world'});
  });

  test('req.multipart parses multipart/form-data (fields + file)', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));

    server.listen((req) async {
      final ctx = Context(req, req.response);
      final body = await ctx.req.multipart();
      await ctx.res.json({
        'fields': body.fields,
        'files': body.files.map(
          (k, v) => MapEntry(k, {'filename': v.filename}),
        ),
      });
    });

    final client = HttpClient();
    addTearDown(client.close);

    const boundary = 'dart_boundary';
    final request = await client.postUrl(
      Uri.parse('http://localhost:${server.port}/upload'),
    );
    request.headers.set(
      HttpHeaders.contentTypeHeader,
      'multipart/form-data; boundary=$boundary',
    );

    request.write('--$boundary\r\n');
    request.write('Content-Disposition: form-data; name="title"\r\n\r\n');
    request.write('hello\r\n');

    request.write('--$boundary\r\n');
    request.write(
      'Content-Disposition: form-data; name="file"; filename="a.txt"\r\n',
    );
    request.write('Content-Type: text/plain\r\n\r\n');
    request.write('file-content\r\n');

    request.write('--$boundary--\r\n');

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    final decoded = jsonDecode(responseBody) as Map<String, dynamic>;

    expect(response.statusCode, HttpStatus.ok);
    expect(decoded['fields'], {'title': 'hello'});
    expect(decoded['files'], {
      'file': {'filename': 'a.txt'},
    });
  });
}
