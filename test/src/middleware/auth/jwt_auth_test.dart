import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:chase/chase.dart';
import 'package:chase/testing/testing.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
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

  _MockRequest({required this.method, required this.uri, String? authHeader}) {
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

String _createToken(
  String secretKey,
  Map<String, dynamic> payload, {
  JWTAlgorithm algorithm = JWTAlgorithm.HS256,
}) {
  final jwt = JWT(payload);
  return jwt.sign(SecretKey(secretKey), algorithm: algorithm);
}

void main() {
  setUpAll(() => suppressTestLogs());

  const secretKey = 'test-secret-key-min-32-characters-long';

  group('JwtAuth', () {
    test('allows request with valid JWT token', () async {
      final payload = {'sub': 'user123', 'name': 'Test User'};
      final token = _createToken(secretKey, payload);

      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Bearer $token',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      var handlerCalled = false;
      final auth = JwtAuth(secretKey: secretKey);
      final chain = _buildChain([auth], (ctx) async {
        handlerCalled = true;
      });

      await chain(ctx);

      expect(handlerCalled, isTrue);
      expect(res.statusCode, 200);
      expect(ctx.get<Map<String, dynamic>>('_jwt_payload'), isNotNull);
      expect(ctx.get<String>('_jwt_token'), token);
    });

    test('rejects request with invalid JWT signature', () async {
      final payload = {'sub': 'user123'};
      final token = _createToken('wrong-secret-key', payload);

      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Bearer $token',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      var handlerCalled = false;
      final auth = JwtAuth(secretKey: secretKey);
      final chain = _buildChain([auth], (ctx) async {
        handlerCalled = true;
      });

      await chain(ctx);

      expect(handlerCalled, isFalse);
      expect(res.statusCode, HttpStatus.unauthorized);
      expect(res.body, contains('Invalid token'));
    });

    test('rejects expired JWT token', () async {
      final payload = {
        'sub': 'user123',
        'exp':
            DateTime.now()
                .subtract(Duration(hours: 1))
                .millisecondsSinceEpoch ~/
            1000,
      };
      final token = _createToken(secretKey, payload);

      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Bearer $token',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      var handlerCalled = false;
      final auth = JwtAuth(secretKey: secretKey);
      final chain = _buildChain([auth], (ctx) async {
        handlerCalled = true;
      });

      await chain(ctx);

      expect(handlerCalled, isFalse);
      expect(res.statusCode, HttpStatus.unauthorized);
      expect(res.body, contains('expired'));
    });

    test('allows non-expired JWT token', () async {
      final payload = {
        'sub': 'user123',
        'exp':
            DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch ~/
            1000,
      };
      final token = _createToken(secretKey, payload);

      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Bearer $token',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      var handlerCalled = false;
      final auth = JwtAuth(secretKey: secretKey);
      final chain = _buildChain([auth], (ctx) async {
        handlerCalled = true;
      });

      await chain(ctx);

      expect(handlerCalled, isTrue);
      expect(res.statusCode, 200);
    });

    test('rejects request with no Authorization header', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      var handlerCalled = false;
      final auth = JwtAuth(secretKey: secretKey);
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
      final auth = JwtAuth(secretKey: secretKey);
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
      final auth = JwtAuth(secretKey: secretKey);
      final chain = _buildChain([auth], (ctx) async {
        handlerCalled = true;
      });

      await chain(ctx);

      expect(handlerCalled, isFalse);
      expect(res.statusCode, HttpStatus.unauthorized);
    });

    test('is case-insensitive for "Bearer" scheme', () async {
      final payload = {'sub': 'user123'};
      final token = _createToken(secretKey, payload);

      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'bearer $token',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      var handlerCalled = false;
      final auth = JwtAuth(secretKey: secretKey);
      final chain = _buildChain([auth], (ctx) async {
        handlerCalled = true;
      });

      await chain(ctx);

      expect(handlerCalled, isTrue);
      expect(res.statusCode, 200);
    });

    test('sets custom realm in WWW-Authenticate header', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final auth = JwtAuth(secretKey: secretKey, realm: 'API Access');
      final chain = _buildChain([auth], (ctx) async {});

      await chain(ctx);

      expect(
        res.headers.value('www-authenticate'),
        'Bearer realm="API Access"',
      );
    });

    test('handles token with whitespace', () async {
      final payload = {'sub': 'user123'};
      final token = _createToken(secretKey, payload);

      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Bearer   $token   ',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      var handlerCalled = false;
      final auth = JwtAuth(secretKey: secretKey);
      final chain = _buildChain([auth], (ctx) async {
        handlerCalled = true;
      });

      await chain(ctx);

      expect(handlerCalled, isTrue);
      expect(res.statusCode, 200);
    });

    test('supports different JWT algorithms', () async {
      final payload = {'sub': 'user123'};
      final token = _createToken(
        secretKey,
        payload,
        algorithm: JWTAlgorithm.HS512,
      );

      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Bearer $token',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      var handlerCalled = false;
      final auth = JwtAuth(secretKey: secretKey, algorithm: JWTAlgorithm.HS512);
      final chain = _buildChain([auth], (ctx) async {
        handlerCalled = true;
      });

      await chain(ctx);

      expect(handlerCalled, isTrue);
      expect(res.statusCode, 200);
    });

    test('stores JWT payload in context params', () async {
      final payload = {'sub': 'user123', 'name': 'John Doe', 'role': 'admin'};
      final token = _createToken(secretKey, payload);

      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Bearer $token',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final auth = JwtAuth(secretKey: secretKey);
      final chain = _buildChain([auth], (ctx) async {
        final payload = ctx.get<Map<String, dynamic>>('_jwt_payload');
        expect(payload, isNotNull);

        expect(payload!['sub'], 'user123');
        expect(payload['name'], 'John Doe');
        expect(payload['role'], 'admin');
      });

      await chain(ctx);
    });
  });

  group('JwtAuth with payload validator', () {
    test('validates with custom sync validator', () async {
      final payload = {'sub': 'user123', 'role': 'admin'};
      final token = _createToken(secretKey, payload);

      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Bearer $token',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      var handlerCalled = false;
      final auth = JwtAuth(
        secretKey: secretKey,
        payloadValidator: (payload) {
          final role = payload['role'] as String?;
          return role == 'admin';
        },
      );
      final chain = _buildChain([auth], (ctx) async {
        handlerCalled = true;
      });

      await chain(ctx);

      expect(handlerCalled, isTrue);
      expect(res.statusCode, 200);
    });

    test('rejects invalid payload with custom validator', () async {
      final payload = {'sub': 'user123', 'role': 'user'};
      final token = _createToken(secretKey, payload);

      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Bearer $token',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      var handlerCalled = false;
      final auth = JwtAuth(
        secretKey: secretKey,
        payloadValidator: (payload) {
          final role = payload['role'] as String?;
          return role == 'admin';
        },
      );
      final chain = _buildChain([auth], (ctx) async {
        handlerCalled = true;
      });

      await chain(ctx);

      expect(handlerCalled, isFalse);
      expect(res.statusCode, HttpStatus.unauthorized);
      expect(res.body, contains('Invalid token payload'));
    });

    test('validates with async validator', () async {
      final payload = {'sub': 'user123'};
      final token = _createToken(secretKey, payload);

      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Bearer $token',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      var handlerCalled = false;
      final auth = JwtAuth(
        secretKey: secretKey,
        payloadValidator: (payload) async {
          // Simulate async operation (e.g., database lookup)
          await Future.delayed(Duration(milliseconds: 10));
          final userId = payload['sub'] as String?;
          return userId == 'user123';
        },
      );
      final chain = _buildChain([auth], (ctx) async {
        handlerCalled = true;
      });

      await chain(ctx);

      expect(handlerCalled, isTrue);
      expect(res.statusCode, 200);
    });

    test('handles validator that throws exception', () async {
      final payload = {'sub': 'user123'};
      final token = _createToken(secretKey, payload);

      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Bearer $token',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      var handlerCalled = false;
      final auth = JwtAuth(
        secretKey: secretKey,
        payloadValidator: (payload) {
          throw Exception('Validator error');
        },
      );
      final chain = _buildChain([auth], (ctx) async {
        handlerCalled = true;
      });

      await chain(ctx);

      expect(handlerCalled, isFalse);
      expect(res.statusCode, HttpStatus.unauthorized);
      expect(res.body, contains('Invalid token payload'));
    });

    test('validates multiple claims', () async {
      final payload = {
        'sub': 'user123',
        'role': 'admin',
        'scope': 'read:users write:users',
      };
      final token = _createToken(secretKey, payload);

      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Bearer $token',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      var handlerCalled = false;
      final auth = JwtAuth(
        secretKey: secretKey,
        payloadValidator: (payload) {
          final role = payload['role'] as String?;
          final scope = payload['scope'] as String?;
          return role == 'admin' &&
              scope != null &&
              scope.contains('write:users');
        },
      );
      final chain = _buildChain([auth], (ctx) async {
        handlerCalled = true;
      });

      await chain(ctx);

      expect(handlerCalled, isTrue);
      expect(res.statusCode, 200);
    });

    test('validator receives complete payload', () async {
      Map<String, dynamic>? receivedPayload;

      final payload = {
        'sub': 'user123',
        'name': 'John Doe',
        'role': 'admin',
        'custom': 'value',
      };
      final token = _createToken(secretKey, payload);

      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Bearer $token',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final auth = JwtAuth(
        secretKey: secretKey,
        payloadValidator: (payload) {
          receivedPayload = payload;
          return true;
        },
      );
      final chain = _buildChain([auth], (ctx) async {});

      await chain(ctx);

      expect(receivedPayload, isNotNull);
      expect(receivedPayload!['sub'], 'user123');
      expect(receivedPayload!['name'], 'John Doe');
      expect(receivedPayload!['role'], 'admin');
      expect(receivedPayload!['custom'], 'value');
    });
  });

  group('Security', () {
    test('handles malformed JWT token', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Bearer not-a-valid-jwt-token',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      var handlerCalled = false;
      final auth = JwtAuth(secretKey: secretKey);
      final chain = _buildChain([auth], (ctx) async {
        handlerCalled = true;
      });

      await chain(ctx);

      expect(handlerCalled, isFalse);
      expect(res.statusCode, HttpStatus.unauthorized);
    });

    test('handles JWT with missing required claims', () async {
      // Empty payload
      final payload = <String, dynamic>{};
      final token = _createToken(secretKey, payload);

      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Bearer $token',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      var handlerCalled = false;
      final auth = JwtAuth(
        secretKey: secretKey,
        payloadValidator: (payload) {
          // Require 'sub' claim
          return payload.containsKey('sub');
        },
      );
      final chain = _buildChain([auth], (ctx) async {
        handlerCalled = true;
      });

      await chain(ctx);

      expect(handlerCalled, isFalse);
      expect(res.statusCode, HttpStatus.unauthorized);
    });

    test('handles JWT with tampered payload', () async {
      // Create valid token then try to tamper with it
      final payload = {'sub': 'user123', 'role': 'user'};
      var token = _createToken(secretKey, payload);

      // Try to tamper by modifying the token (this will invalidate the signature)
      final parts = token.split('.');
      if (parts.length == 3) {
        // Modify the payload part (decode, change, re-encode)
        final payloadPart = base64Url.decode(base64Url.normalize(parts[1]));
        final tamperedPayload = jsonDecode(utf8.decode(payloadPart));
        tamperedPayload['role'] = 'admin'; // Try to escalate privileges
        final newPayloadPart = base64Url.encode(
          utf8.encode(jsonEncode(tamperedPayload)),
        );
        token = '${parts[0]}.$newPayloadPart.${parts[2]}';
      }

      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Bearer $token',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      var handlerCalled = false;
      final auth = JwtAuth(secretKey: secretKey);
      final chain = _buildChain([auth], (ctx) async {
        handlerCalled = true;
      });

      await chain(ctx);

      expect(handlerCalled, isFalse);
      expect(res.statusCode, HttpStatus.unauthorized);
    });
  });
}
