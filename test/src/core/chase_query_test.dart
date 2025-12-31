import 'dart:convert';
import 'dart:io';

import 'package:chase/chase.dart';
import 'package:test/test.dart';

void main() {
  test('req.query and req.queries parse query parameters', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));

    server.listen((req) async {
      final ctx = Context(req, req.response);
      await ctx.res.json({
        'q': ctx.req.query('q'),
        'page': ctx.req.query('page'),
        'missingWithDefault': ctx.req.queryOr('missing', '10'),
        'tags': ctx.req.queryList('tag'),
        'allMulti': ctx.req.queriesAll,
        'all': ctx.req.queries,
      });
    });

    final client = HttpClient();
    addTearDown(client.close);

    final request = await client.getUrl(
      Uri.parse(
        'http://localhost:${server.port}/search?q=hello%20world&page=2&tag=a&tag=b',
      ),
    );
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();

    expect(response.statusCode, HttpStatus.ok);
    expect(response.headers.contentType?.mimeType, ContentType.json.mimeType);

    final decoded = jsonDecode(body) as Map<String, dynamic>;
    expect(decoded['q'], 'hello world');
    expect(decoded['page'], '2');
    expect(decoded['missingWithDefault'], '10');
    expect(decoded['tags'], ['a', 'b']);
    expect(decoded['allMulti'], {
      'q': ['hello world'],
      'page': ['2'],
      'tag': ['a', 'b'],
    });
    expect(decoded['all'], {'q': 'hello world', 'page': '2', 'tag': 'b'});
  });
}
