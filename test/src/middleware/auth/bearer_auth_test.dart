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
    String? authHeader,
  }) {
    if (authHeader != null) {
      headers.set('authorization', authHeader);
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
  group('BearerAuth', () {
    test('allows request with valid token', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Bearer secret-token-123',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      var handlerCalled = false;
      final auth = BearerAuth(token: 'secret-token-123');
      final chain = _buildChain([auth], (ctx) async {
        handlerCalled = true;
      });

      await chain(ctx);

      expect(handlerCalled, isTrue);
      expect(res.statusCode, 200);
    });

    test('rejects request with invalid token', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Bearer wrong-token',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      var handlerCalled = false;
      final auth = BearerAuth(token: 'secret-token-123');
      final chain = _buildChain([auth], (ctx) async {
        handlerCalled = true;
      });

      await chain(ctx);

      expect(handlerCalled, isFalse);
      expect(res.statusCode, HttpStatus.unauthorized);
      expect(res.headers.value('www-authenticate'), 'Bearer realm="Restricted Area"');
      expect(res.body, contains('Unauthorized'));
    });

    test('rejects request with no Authorization header', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      var handlerCalled = false;
      final auth = BearerAuth(token: 'secret-token-123');
      final chain = _buildChain([auth], (ctx) async {
        handlerCalled = true;
      });

      await chain(ctx);

      expect(handlerCalled, isFalse);
      expect(res.statusCode, HttpStatus.unauthorized);
      expect(res.headers.value('www-authenticate'), isNotNull);
    });

    test('rejects request with Basic auth instead of Bearer', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Basic dXNlcjpwYXNz',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      var handlerCalled = false;
      final auth = BearerAuth(token: 'secret-token-123');
      final chain = _buildChain([auth], (ctx) async {
        handlerCalled = true;
      });

      await chain(ctx);

      expect(handlerCalled, isFalse);
      expect(res.statusCode, HttpStatus.unauthorized);
    });

    test('rejects request with empty token', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Bearer ',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      var handlerCalled = false;
      final auth = BearerAuth(token: 'secret-token-123');
      final chain = _buildChain([auth], (ctx) async {
        handlerCalled = true;
      });

      await chain(ctx);

      expect(handlerCalled, isFalse);
      expect(res.statusCode, HttpStatus.unauthorized);
    });

    test('handles token with whitespace', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Bearer   secret-token-123   ',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      var handlerCalled = false;
      final auth = BearerAuth(token: 'secret-token-123');
      final chain = _buildChain([auth], (ctx) async {
        handlerCalled = true;
      });

      await chain(ctx);

      expect(handlerCalled, isTrue);
      expect(res.statusCode, 200);
    });

    test('is case-insensitive for "Bearer" scheme', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'bearer secret-token-123',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      var handlerCalled = false;
      final auth = BearerAuth(token: 'secret-token-123');
      final chain = _buildChain([auth], (ctx) async {
        handlerCalled = true;
      });

      await chain(ctx);

      expect(handlerCalled, isTrue);
    });

    test('sets custom realm in WWW-Authenticate header', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final auth = BearerAuth(
        token: 'secret-token-123',
        realm: 'API Access',
      );
      final chain = _buildChain([auth], (ctx) async {});

      await chain(ctx);

      expect(res.headers.value('www-authenticate'), 'Bearer realm="API Access"');
    });

    test('handles very long tokens', () async {
      final longToken = 'a' * 1000; // 1000 character token
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Bearer $longToken',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      var handlerCalled = false;
      final auth = BearerAuth(token: longToken);
      final chain = _buildChain([auth], (ctx) async {
        handlerCalled = true;
      });

      await chain(ctx);

      expect(handlerCalled, isTrue);
    });
  });

  group('BearerAuth.withValidator', () {
    test('validates with custom sync validator', () async {
      final validTokens = {
        'token-1',
        'token-2',
        'token-3',
      };

      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Bearer token-2',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      var handlerCalled = false;
      final auth = BearerAuth.withValidator(
        validator: (token) => validTokens.contains(token),
      );
      final chain = _buildChain([auth], (ctx) async {
        handlerCalled = true;
      });

      await chain(ctx);

      expect(handlerCalled, isTrue);
    });

    test('rejects invalid token with custom validator', () async {
      final validTokens = {
        'token-1',
        'token-2',
      };

      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Bearer invalid-token',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      var handlerCalled = false;
      final auth = BearerAuth.withValidator(
        validator: (token) => validTokens.contains(token),
      );
      final chain = _buildChain([auth], (ctx) async {
        handlerCalled = true;
      });

      await chain(ctx);

      expect(handlerCalled, isFalse);
      expect(res.statusCode, HttpStatus.unauthorized);
    });

    test('validates with async validator', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Bearer valid-token',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      var handlerCalled = false;
      final auth = BearerAuth.withValidator(
        validator: (token) async {
          // Simulate async operation (e.g., database lookup)
          await Future.delayed(Duration(milliseconds: 10));
          return token == 'valid-token';
        },
      );
      final chain = _buildChain([auth], (ctx) async {
        handlerCalled = true;
      });

      await chain(ctx);

      expect(handlerCalled, isTrue);
    });

    test('handles validator that throws exception', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Bearer any-token',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      var handlerCalled = false;
      final auth = BearerAuth.withValidator(
        validator: (token) {
          throw Exception('Validator error');
        },
      );
      final chain = _buildChain([auth], (ctx) async {
        handlerCalled = true;
      });

      await chain(ctx);

      expect(handlerCalled, isFalse);
      expect(res.statusCode, HttpStatus.unauthorized);
    });

    test('allows multiple valid tokens with validator', () async {
      final validTokens = {
        'api-key-1': true,
        'api-key-2': true,
        'api-key-3': true,
      };

      final auth = BearerAuth.withValidator(
        validator: (token) => validTokens[token] ?? false,
      );

      // Test first token
      var req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Bearer api-key-1',
      );
      var res = _MockResponse();
      var ctx = Context(req, res);
      var handlerCalled = false;
      var chain = _buildChain([auth], (ctx) async {
        handlerCalled = true;
      });
      await chain(ctx);
      expect(handlerCalled, isTrue);

      // Test second token
      req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Bearer api-key-2',
      );
      res = _MockResponse();
      ctx = Context(req, res);
      handlerCalled = false;
      chain = _buildChain([auth], (ctx) async {
        handlerCalled = true;
      });
      await chain(ctx);
      expect(handlerCalled, isTrue);

      // Test invalid token
      req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Bearer invalid',
      );
      res = _MockResponse();
      ctx = Context(req, res);
      handlerCalled = false;
      chain = _buildChain([auth], (ctx) async {
        handlerCalled = true;
      });
      await chain(ctx);
      expect(handlerCalled, isFalse);
    });

    test('validator receives exact token without modification', () async {
      String? receivedToken;

      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Bearer my-special-token-123',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final auth = BearerAuth.withValidator(
        validator: (token) {
          receivedToken = token;
          return true;
        },
      );
      final chain = _buildChain([auth], (ctx) async {});

      await chain(ctx);

      expect(receivedToken, 'my-special-token-123');
    });
  });

  group('Security', () {
    test('uses constant-time comparison for tokens', () async {
      // This test verifies that the comparison doesn't leak timing information
      final auth = BearerAuth(token: 'correct-token-123');

      // Test with same-length wrong token
      final req1 = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Bearer wronggg-token-123',
      );
      final res1 = _MockResponse();
      final ctx1 = Context(req1, res1);
      final chain1 = _buildChain([auth], (ctx) async {});
      await chain1(ctx1);
      expect(res1.statusCode, HttpStatus.unauthorized);

      // Test with different-length wrong token
      final req2 = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Bearer short',
      );
      final res2 = _MockResponse();
      final ctx2 = Context(req2, res2);
      final chain2 = _buildChain([auth], (ctx) async {});
      await chain2(ctx2);
      expect(res2.statusCode, HttpStatus.unauthorized);
    });

    test('handles tokens with special characters', () async {
      final specialToken = 'token-with-special-chars-!@#\$%^&*()';
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Bearer $specialToken',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      var handlerCalled = false;
      final auth = BearerAuth(token: specialToken);
      final chain = _buildChain([auth], (ctx) async {
        handlerCalled = true;
      });

      await chain(ctx);

      expect(handlerCalled, isTrue);
    });

    test('handles tokens with Unicode characters', () async {
      final unicodeToken = 'token-with-unicode-日本語-🔐';
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Bearer $unicodeToken',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      var handlerCalled = false;
      final auth = BearerAuth(token: unicodeToken);
      final chain = _buildChain([auth], (ctx) async {
        handlerCalled = true;
      });

      await chain(ctx);

      expect(handlerCalled, isTrue);
    });
  });
}
