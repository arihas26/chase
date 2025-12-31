import 'dart:io';

import 'package:chase/chase.dart';
import 'package:test/test.dart';

class _FakeRequest implements HttpRequest {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHeaders implements HttpHeaders {
  ContentType? _contentType;

  @override
  ContentType? get contentType => _contentType;

  @override
  set contentType(ContentType? value) => _contentType = value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingResponse implements HttpResponse {
  @override
  int statusCode = 200;

  @override
  final HttpHeaders headers = _FakeHeaders();

  final StringBuffer buffer = StringBuffer();

  @override
  void write(Object? obj) {
    buffer.write(obj);
  }

  @override
  Future close() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('handler reads params and responds with text', () async {
    final router = TrieRouter();
    router.add('GET', '/hello/:name', (ctx) async {
      final name = ctx.req.params['name'] ?? 'Guest';
      await ctx.res.text('Hello, $name!');
    });

    final match = router.match('GET', '/hello/Alice');
    expect(match, isNotNull);

    final res = _RecordingResponse();
    final ctx = Context(_FakeRequest(), res, match!.params);
    await match.handler(ctx);

    expect(res.statusCode, HttpStatus.ok);
    expect(res.buffer.toString(), 'Hello, Alice!');
  });

  test('handler reads wildcard params and responds with json', () async {
    final router = TrieRouter();
    router.add('GET', '/files/*path', (ctx) async {
      final path = ctx.req.params['path'] ?? '';
      await ctx.res.json({'path': path});
    });

    final match = router.match('GET', '/files/a/b/c.txt');
    expect(match, isNotNull);

    final res = _RecordingResponse();
    final ctx = Context(_FakeRequest(), res, match!.params);
    await match.handler(ctx);

    expect(res.statusCode, HttpStatus.ok);
    expect(res.buffer.toString(), '{"path":"a/b/c.txt"}');
    expect(res.headers.contentType, ContentType.json);
  });
}
