import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:chase/chase.dart';
import 'package:test/test.dart';

class _MockHeaders implements HttpHeaders {
  final Map<String, List<String>> _values = {};
  ContentType? _contentType;

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _values[name.toLowerCase()] = [value.toString()];
  }

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _values.putIfAbsent(name.toLowerCase(), () => []).add(value.toString());
  }

  @override
  String? value(String name) {
    final values = _values[name.toLowerCase()];
    if (values == null || values.isEmpty) return null;
    return values.last;
  }

  @override
  ContentType? get contentType => _contentType;

  @override
  set contentType(ContentType? value) {
    _contentType = value;
    if (value != null) {
      set(HttpHeaders.contentTypeHeader, value.toString());
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockRequest extends Stream<Uint8List> implements HttpRequest {
  final Stream<Uint8List> _stream = const Stream<Uint8List>.empty();

  @override
  final HttpHeaders headers = _MockHeaders();

  @override
  final String method;

  @override
  final Uri uri;

  _MockRequest({
    required this.method,
    required this.uri,
    String? acceptEncoding,
  }) {
    if (acceptEncoding != null) {
      headers.set(HttpHeaders.acceptEncodingHeader, acceptEncoding);
    }
  }

  @override
  StreamSubscription<Uint8List> listen(
    void Function(Uint8List)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockResponse implements HttpResponse {
  @override
  int statusCode = 200;

  @override
  final HttpHeaders headers = _MockHeaders();

  bool closed = false;
  final List<List<int>> _written = [];

  @override
  void add(List<int> data) {
    _written.add(data);
  }

  @override
  void write(Object? object) {
    if (object != null) {
      add(utf8.encode(object.toString()));
    }
  }

  @override
  Future close() async {
    closed = true;
  }

  String get body {
    if (_written.isEmpty) return '';
    final combined = <int>[];
    for (final chunk in _written) {
      combined.addAll(chunk);
    }
    return utf8.decode(combined);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Handler _buildChain(List<Middleware> middlewares, Handler finalHandler) {
  Handler current = finalHandler;
  for (var i = middlewares.length - 1; i >= 0; i--) {
    final mw = middlewares[i];
    final next = current;
    current = (ctx) => mw.handle(ctx, () => next(ctx));
  }
  return current;
}

void main() {
  group('Compress', () {
    test('selects gzip when requested', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        acceptEncoding: 'gzip',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final compress = Compress();
      final chain = _buildChain([compress], (ctx) async {});

      await chain(ctx);

      expect(res.headers.value('content-encoding'), 'gzip');
      expect(ctx.get<String>('content-encoding'), 'gzip');
    });

    test('selects deflate when requested', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        acceptEncoding: 'deflate',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final compress = Compress();
      final chain = _buildChain([compress], (ctx) async {});

      await chain(ctx);

      expect(res.headers.value('content-encoding'), 'deflate');
    });

    test('selects brotli when requested', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        acceptEncoding: 'br',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final compress = Compress();
      final chain = _buildChain([compress], (ctx) async {});

      await chain(ctx);

      expect(res.headers.value('content-encoding'), 'br');
    });

    test('prefers brotli over gzip when both available', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        acceptEncoding: 'gzip, br',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final compress = Compress();
      final chain = _buildChain([compress], (ctx) async {});

      await chain(ctx);

      expect(res.headers.value('content-encoding'), 'br');
    });

    test('prefers gzip over deflate when both available', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        acceptEncoding: 'deflate, gzip',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final compress = Compress();
      final chain = _buildChain([compress], (ctx) async {});

      await chain(ctx);

      expect(res.headers.value('content-encoding'), 'gzip');
    });

    test('skips compression when no Accept-Encoding header', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final compress = Compress();
      final chain = _buildChain([compress], (ctx) async {});

      await chain(ctx);

      expect(res.headers.value('content-encoding'), isNull);
      expect(ctx.get<String>('content-encoding'), isNull);
    });

    test('sets Vary header for caching', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        acceptEncoding: 'gzip',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final compress = Compress();
      final chain = _buildChain([compress], (ctx) async {});

      await chain(ctx);

      expect(res.headers.value('vary'), 'Accept-Encoding');
    });

    test('appends to existing Vary header', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        acceptEncoding: 'gzip',
      );
      final res = _MockResponse();
      res.headers.set('Vary', 'User-Agent');
      final ctx = Context(req, res);

      final compress = Compress();
      final chain = _buildChain([compress], (ctx) async {});

      await chain(ctx);

      expect(res.headers.value('vary'), 'User-Agent, Accept-Encoding');
    });

    test('does not duplicate Vary: Accept-Encoding', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        acceptEncoding: 'gzip',
      );
      final res = _MockResponse();
      res.headers.set('Vary', 'Accept-Encoding');
      final ctx = Context(req, res);

      final compress = Compress();
      final chain = _buildChain([compress], (ctx) async {});

      await chain(ctx);

      expect(res.headers.value('vary'), 'Accept-Encoding');
    });

    test('stores compression threshold in params', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        acceptEncoding: 'gzip',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final compress = Compress(threshold: 2048);
      final chain = _buildChain([compress], (ctx) async {});

      await chain(ctx);

      expect(ctx.get<int>('compression-threshold'), 2048);
    });

    test('calls next handler', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        acceptEncoding: 'gzip',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      var handlerCalled = false;
      final compress = Compress();
      final chain = _buildChain([compress], (ctx) async {
        handlerCalled = true;
      });

      await chain(ctx);

      expect(handlerCalled, isTrue);
    });
  });

  group('Compress quality values', () {
    test('respects quality values (higher quality wins)', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        acceptEncoding: 'gzip;q=0.8, deflate;q=1.0',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final compress = Compress();
      final chain = _buildChain([compress], (ctx) async {});

      await chain(ctx);

      expect(res.headers.value('content-encoding'), 'deflate');
    });

    test('uses preference when quality is equal', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        acceptEncoding: 'gzip;q=1.0, br;q=1.0',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final compress = Compress();
      final chain = _buildChain([compress], (ctx) async {});

      await chain(ctx);

      // br has higher preference than gzip
      expect(res.headers.value('content-encoding'), 'br');
    });

    test('ignores encodings with quality 0', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        acceptEncoding: 'gzip;q=0, deflate',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final compress = Compress();
      final chain = _buildChain([compress], (ctx) async {});

      await chain(ctx);

      expect(res.headers.value('content-encoding'), 'deflate');
    });

    test('handles wildcard with quality value', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        acceptEncoding: '*;q=0.5',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final compress = Compress();
      final chain = _buildChain([compress], (ctx) async {});

      await chain(ctx);

      // br should be selected (highest preference)
      expect(res.headers.value('content-encoding'), 'br');
    });

    test('specific encoding overrides wildcard', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        acceptEncoding: 'gzip;q=1.0, *;q=0.5',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final compress = Compress();
      final chain = _buildChain([compress], (ctx) async {});

      await chain(ctx);

      expect(res.headers.value('content-encoding'), 'gzip');
    });

    test('handles complex Accept-Encoding header', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        acceptEncoding: 'gzip;q=0.9, deflate;q=0.8, br;q=1.0, *;q=0.1',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final compress = Compress();
      final chain = _buildChain([compress], (ctx) async {});

      await chain(ctx);

      expect(res.headers.value('content-encoding'), 'br');
    });
  });

  group('Compress configuration', () {
    test('disables brotli when configured', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        acceptEncoding: 'br, gzip',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final compress = Compress(enableBrotli: false);
      final chain = _buildChain([compress], (ctx) async {});

      await chain(ctx);

      expect(res.headers.value('content-encoding'), 'gzip');
    });

    test('disables gzip when configured', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        acceptEncoding: 'gzip, deflate',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final compress = Compress(enableGzip: false);
      final chain = _buildChain([compress], (ctx) async {});

      await chain(ctx);

      expect(res.headers.value('content-encoding'), 'deflate');
    });

    test('disables deflate when configured', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        acceptEncoding: 'deflate',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final compress = Compress(enableDeflate: false);
      final chain = _buildChain([compress], (ctx) async {});

      await chain(ctx);

      expect(res.headers.value('content-encoding'), isNull);
    });

    test('allows only specific encodings', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        acceptEncoding: 'br, gzip, deflate',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final compress = Compress(
        enableBrotli: false,
        enableGzip: true,
        enableDeflate: false,
      );
      final chain = _buildChain([compress], (ctx) async {});

      await chain(ctx);

      expect(res.headers.value('content-encoding'), 'gzip');
    });

    test('respects custom threshold', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        acceptEncoding: 'gzip',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final compress = Compress(threshold: 5000);
      final chain = _buildChain([compress], (ctx) async {});

      await chain(ctx);

      expect(ctx.get<int>('compression-threshold'), 5000);
    });
  });

  group('Edge cases', () {
    test('handles empty Accept-Encoding header', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        acceptEncoding: '',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final compress = Compress();
      final chain = _buildChain([compress], (ctx) async {});

      await chain(ctx);

      expect(res.headers.value('content-encoding'), isNull);
    });

    test('handles whitespace in Accept-Encoding', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        acceptEncoding: '  gzip  ,  deflate  ',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final compress = Compress();
      final chain = _buildChain([compress], (ctx) async {});

      await chain(ctx);

      expect(res.headers.value('content-encoding'), 'gzip');
    });

    test('handles unknown encodings', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        acceptEncoding: 'unknown, compress',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final compress = Compress();
      final chain = _buildChain([compress], (ctx) async {});

      await chain(ctx);

      expect(res.headers.value('content-encoding'), isNull);
    });

    test('handles case-insensitive encodings', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        acceptEncoding: 'GZIP, DEFLATE, BR',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final compress = Compress();
      final chain = _buildChain([compress], (ctx) async {});

      await chain(ctx);

      expect(res.headers.value('content-encoding'), 'br');
    });

    test('handles malformed quality values', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        acceptEncoding: 'gzip;q=invalid, deflate',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final compress = Compress();
      final chain = _buildChain([compress], (ctx) async {});

      await chain(ctx);

      // Should fallback to default quality (1.0) for gzip
      expect(res.headers.value('content-encoding'), 'gzip');
    });

    test('handles all encodings disabled', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        acceptEncoding: 'gzip, deflate, br',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final compress = Compress(
        enableBrotli: false,
        enableGzip: false,
        enableDeflate: false,
      );
      final chain = _buildChain([compress], (ctx) async {});

      await chain(ctx);

      expect(res.headers.value('content-encoding'), isNull);
    });
  });
}
