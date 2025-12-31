import 'dart:convert';
import 'dart:io';

import 'package:chase/src/core/context/context.dart';
import 'package:test/test.dart';

class _FakeRequest implements HttpRequest {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHeaders implements HttpHeaders {
  ContentType? _contentType;
  final Map<String, List<Object>> _values = {};

  @override
  ContentType? get contentType => _contentType;

  @override
  set contentType(ContentType? value) => _contentType = value;

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _values[name.toLowerCase()] = [value];
  }

  @override
  String? value(String name) {
    final values = _values[name.toLowerCase()];
    if (values == null || values.isEmpty) return null;
    return values.single.toString();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingResponse implements HttpResponse {
  @override
  int statusCode = 200;

  @override
  final HttpHeaders headers = _FakeHeaders();

  final StringBuffer buffer = StringBuffer();
  bool closed = false;

  @override
  void write(Object? obj) {
    buffer.write(obj);
  }

  @override
  Future close() async {
    closed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('res.statusCode and res.headers.set work correctly', () {
    final res = _RecordingResponse();
    final ctx = Context(_FakeRequest(), res);

    ctx.res.statusCode = HttpStatus.created;
    ctx.res.headers.set('X-Test', '1');

    expect(res.statusCode, HttpStatus.created);
    expect(res.headers.value('x-test'), '1');
    expect(res.closed, isFalse);
  });

  test('text writes body and status', () async {
    final res = _RecordingResponse();
    final ctx = Context(_FakeRequest(), res);

    await ctx.res.text('Hello', status: HttpStatus.accepted);

    expect(res.statusCode, HttpStatus.accepted);
    expect(res.buffer.toString(), 'Hello');
    expect(res.closed, isTrue);
  });

  test('json writes body and content type', () async {
    final res = _RecordingResponse();
    final ctx = Context(_FakeRequest(), res);

    await ctx.res.json({'ok': true});

    expect(res.statusCode, HttpStatus.ok);
    expect(res.buffer.toString(), jsonEncode({'ok': true}));
    expect(res.headers.contentType, ContentType.json);
    expect(res.closed, isTrue);
  });

  test('html writes body and content type', () async {
    final res = _RecordingResponse();
    final ctx = Context(_FakeRequest(), res);

    await ctx.res.html('<h1>Hello</h1>');

    expect(res.statusCode, HttpStatus.ok);
    expect(res.buffer.toString(), '<h1>Hello</h1>');
    expect(res.headers.contentType, ContentType.html);
    expect(res.closed, isTrue);
  });

  test('redirect sets location header and status', () async {
    final res = _RecordingResponse();
    final ctx = Context(_FakeRequest(), res);

    await ctx.res.redirect('/login');

    expect(res.statusCode, HttpStatus.found);
    expect(res.headers.value(HttpHeaders.locationHeader), '/login');
    expect(res.closed, isTrue);
  });

  test('notFound writes 404 and closes', () async {
    final res = _RecordingResponse();
    final ctx = Context(_FakeRequest(), res);

    await ctx.res.notFound();

    expect(res.statusCode, HttpStatus.notFound);
    expect(res.buffer.toString(), '404 Not Found');
    expect(res.closed, isTrue);
  });

  test('params exposes stored values and is unmodifiable', () {
    final ctx = Context(_FakeRequest(), _RecordingResponse(), {'id': '1', 'name': 'alice'});

    expect(ctx.req.params, {'id': '1', 'name': 'alice'});
    expect(() => ctx.req.params['id'] = '2', throwsUnsupportedError);
  });

  group('param<T>', () {
    test('returns String value', () {
      final ctx = Context(_FakeRequest(), _RecordingResponse(), {'name': 'alice'});
      expect(ctx.req.param<String>('name'), 'alice');
    });

    test('parses int value', () {
      final ctx = Context(_FakeRequest(), _RecordingResponse(), {'id': '42'});
      expect(ctx.req.param<int>('id'), 42);
    });

    test('returns null for invalid int', () {
      final ctx = Context(_FakeRequest(), _RecordingResponse(), {'id': 'abc'});
      expect(ctx.req.param<int>('id'), isNull);
    });

    test('parses double value', () {
      final ctx = Context(_FakeRequest(), _RecordingResponse(), {'price': '19.99'});
      expect(ctx.req.param<double>('price'), 19.99);
    });

    test('returns null for invalid double', () {
      final ctx = Context(_FakeRequest(), _RecordingResponse(), {'price': 'free'});
      expect(ctx.req.param<double>('price'), isNull);
    });

    test('parses bool true values', () {
      final ctx1 = Context(_FakeRequest(), _RecordingResponse(), {'active': 'true'});
      final ctx2 = Context(_FakeRequest(), _RecordingResponse(), {'active': '1'});
      final ctx3 = Context(_FakeRequest(), _RecordingResponse(), {'active': 'yes'});

      expect(ctx1.req.param<bool>('active'), isTrue);
      expect(ctx2.req.param<bool>('active'), isTrue);
      expect(ctx3.req.param<bool>('active'), isTrue);
    });

    test('parses bool false values', () {
      final ctx = Context(_FakeRequest(), _RecordingResponse(), {'active': 'false'});
      expect(ctx.req.param<bool>('active'), isFalse);
    });

    test('returns null for missing key', () {
      final ctx = Context(_FakeRequest(), _RecordingResponse(), {'id': '1'});
      expect(ctx.req.param<int>('missing'), isNull);
    });
  });
}
