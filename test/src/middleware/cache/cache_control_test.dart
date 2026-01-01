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

  _MockRequest({required this.method, required this.uri});

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
  group('CacheControl', () {
    test('sets max-age directive', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final cache = CacheControl(maxAge: Duration(seconds: 3600));
      final chain = _buildChain([cache], (ctx) async {});

      await chain(ctx);

      expect(res.headers.value('cache-control'), 'max-age=3600');
    });

    test('sets s-maxage directive', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final cache = CacheControl(
        maxAge: Duration(seconds: 3600),
        sMaxAge: Duration(seconds: 7200),
      );
      final chain = _buildChain([cache], (ctx) async {});

      await chain(ctx);

      expect(res.headers.value('cache-control'), 'max-age=3600, s-maxage=7200');
    });

    test('sets private directive', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final cache = CacheControl(private: true);
      final chain = _buildChain([cache], (ctx) async {});

      await chain(ctx);

      expect(res.headers.value('cache-control'), 'private');
    });

    test('sets public directive', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final cache = CacheControl(public: true);
      final chain = _buildChain([cache], (ctx) async {});

      await chain(ctx);

      expect(res.headers.value('cache-control'), 'public');
    });

    test('sets no-cache directive', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final cache = CacheControl(noCache: true);
      final chain = _buildChain([cache], (ctx) async {});

      await chain(ctx);

      expect(res.headers.value('cache-control'), 'no-cache');
    });

    test('sets no-store directive', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final cache = CacheControl(noStore: true);
      final chain = _buildChain([cache], (ctx) async {});

      await chain(ctx);

      expect(res.headers.value('cache-control'), 'no-store');
    });

    test('sets must-revalidate directive', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final cache = CacheControl(mustRevalidate: true);
      final chain = _buildChain([cache], (ctx) async {});

      await chain(ctx);

      expect(res.headers.value('cache-control'), 'must-revalidate');
    });

    test('sets proxy-revalidate directive', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final cache = CacheControl(proxyRevalidate: true);
      final chain = _buildChain([cache], (ctx) async {});

      await chain(ctx);

      expect(res.headers.value('cache-control'), 'proxy-revalidate');
    });

    test('sets immutable directive', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final cache = CacheControl(immutable: true);
      final chain = _buildChain([cache], (ctx) async {});

      await chain(ctx);

      expect(res.headers.value('cache-control'), 'immutable');
    });

    test('sets stale-while-revalidate directive', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final cache = CacheControl(
        staleWhileRevalidate: Duration(seconds: 86400),
      );
      final chain = _buildChain([cache], (ctx) async {});

      await chain(ctx);

      expect(
        res.headers.value('cache-control'),
        'stale-while-revalidate=86400',
      );
    });

    test('sets stale-if-error directive', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final cache = CacheControl(staleIfError: Duration(seconds: 86400));
      final chain = _buildChain([cache], (ctx) async {});

      await chain(ctx);

      expect(res.headers.value('cache-control'), 'stale-if-error=86400');
    });

    test('combines multiple directives', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final cache = CacheControl(
        maxAge: Duration(hours: 1),
        public: true,
        mustRevalidate: true,
      );
      final chain = _buildChain([cache], (ctx) async {});

      await chain(ctx);

      final header = res.headers.value('cache-control');
      expect(header, contains('max-age=3600'));
      expect(header, contains('public'));
      expect(header, contains('must-revalidate'));
    });

    test('converts durations to seconds correctly', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final cache = CacheControl(
        maxAge: Duration(days: 1),
        sMaxAge: Duration(hours: 2),
        staleWhileRevalidate: Duration(minutes: 30),
      );
      final chain = _buildChain([cache], (ctx) async {});

      await chain(ctx);

      final header = res.headers.value('cache-control');
      expect(header, contains('max-age=86400')); // 1 day = 86400 seconds
      expect(header, contains('s-maxage=7200')); // 2 hours = 7200 seconds
      expect(
        header,
        contains('stale-while-revalidate=1800'),
      ); // 30 minutes = 1800 seconds
    });

    test('does not set header when no directives are configured', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final cache = CacheControl();
      final chain = _buildChain([cache], (ctx) async {});

      await chain(ctx);

      expect(res.headers.value('cache-control'), isNull);
    });

    test('calls next handler', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      var handlerCalled = false;
      final cache = CacheControl(maxAge: Duration(seconds: 60));
      final chain = _buildChain([cache], (ctx) async {
        handlerCalled = true;
      });

      await chain(ctx);

      expect(handlerCalled, isTrue);
    });
  });

  group('CacheControl.static', () {
    test('creates cache control for static assets', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final cache = CacheControl.static(duration: Duration(days: 365));
      final chain = _buildChain([cache], (ctx) async {});

      await chain(ctx);

      final header = res.headers.value('cache-control');
      expect(header, contains('max-age=31536000')); // 365 days
      expect(header, contains('public'));
      expect(header, contains('immutable'));
    });

    test('uses custom duration', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final cache = CacheControl.static(duration: Duration(days: 7));
      final chain = _buildChain([cache], (ctx) async {});

      await chain(ctx);

      expect(
        res.headers.value('cache-control'),
        contains('max-age=604800'),
      ); // 7 days
    });
  });

  group('CacheControl.api', () {
    test('creates cache control for API responses', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final cache = CacheControl.api(duration: Duration(minutes: 5));
      final chain = _buildChain([cache], (ctx) async {});

      await chain(ctx);

      final header = res.headers.value('cache-control');
      expect(header, contains('max-age=300')); // 5 minutes
      expect(header, contains('private'));
      expect(header, contains('must-revalidate'));
    });

    test('uses custom duration', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final cache = CacheControl.api(duration: Duration(seconds: 30));
      final chain = _buildChain([cache], (ctx) async {});

      await chain(ctx);

      expect(res.headers.value('cache-control'), contains('max-age=30'));
    });
  });

  group('CacheControl.noCache', () {
    test('prevents all caching', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final cache = CacheControl.noCache();
      final chain = _buildChain([cache], (ctx) async {});

      await chain(ctx);

      final header = res.headers.value('cache-control');
      expect(header, contains('no-cache'));
      expect(header, contains('no-store'));
      expect(header, contains('must-revalidate'));
    });
  });

  group('Validation', () {
    test('throws assertion error when both public and private are true', () {
      expect(
        () => CacheControl(public: true, private: true),
        throwsA(isA<AssertionError>()),
      );
    });

    test('allows public without private', () {
      expect(() => CacheControl(public: true), returnsNormally);
    });

    test('allows private without public', () {
      expect(() => CacheControl(private: true), returnsNormally);
    });
  });

  group('Edge cases', () {
    test('handles zero duration', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final cache = CacheControl(maxAge: Duration.zero);
      final chain = _buildChain([cache], (ctx) async {});

      await chain(ctx);

      expect(res.headers.value('cache-control'), 'max-age=0');
    });

    test('handles all directives together', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final cache = CacheControl(
        maxAge: Duration(seconds: 60),
        sMaxAge: Duration(seconds: 120),
        public: true,
        noCache: true,
        noStore: true,
        mustRevalidate: true,
        proxyRevalidate: true,
        immutable: true,
        staleWhileRevalidate: Duration(seconds: 30),
        staleIfError: Duration(seconds: 600),
      );
      final chain = _buildChain([cache], (ctx) async {});

      await chain(ctx);

      final header = res.headers.value('cache-control');
      expect(header, contains('max-age=60'));
      expect(header, contains('s-maxage=120'));
      expect(header, contains('public'));
      expect(header, contains('no-cache'));
      expect(header, contains('no-store'));
      expect(header, contains('must-revalidate'));
      expect(header, contains('proxy-revalidate'));
      expect(header, contains('immutable'));
      expect(header, contains('stale-while-revalidate=30'));
      expect(header, contains('stale-if-error=600'));
    });
  });
}
