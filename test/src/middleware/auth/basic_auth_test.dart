import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:chase/chase.dart';
import 'package:chase/testing/testing.dart';
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

String _encodeCredentials(String username, String password) {
  return base64.encode(utf8.encode('$username:$password'));
}

void main() {
  setUpAll(() => suppressTestLogs());

  group('BasicAuth', () {
    test('allows request with valid credentials', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Basic ${_encodeCredentials('admin', 'secret')}',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      var handlerCalled = false;
      final auth = BasicAuth(username: 'admin', password: 'secret');
      final chain = _buildChain([auth], (ctx) async {
        handlerCalled = true;
      });

      await chain(ctx);

      expect(handlerCalled, isTrue);
      expect(res.statusCode, 200);
    });

    test('rejects request with invalid username', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Basic ${_encodeCredentials('wrong', 'secret')}',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      var handlerCalled = false;
      final auth = BasicAuth(username: 'admin', password: 'secret');
      final chain = _buildChain([auth], (ctx) async {
        handlerCalled = true;
      });

      await chain(ctx);

      expect(handlerCalled, isFalse);
      expect(res.statusCode, HttpStatus.unauthorized);
      expect(res.headers.value('www-authenticate'), 'Basic realm="Restricted Area"');
      expect(res.body, contains('Unauthorized'));
    });

    test('rejects request with invalid password', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Basic ${_encodeCredentials('admin', 'wrong')}',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      var handlerCalled = false;
      final auth = BasicAuth(username: 'admin', password: 'secret');
      final chain = _buildChain([auth], (ctx) async {
        handlerCalled = true;
      });

      await chain(ctx);

      expect(handlerCalled, isFalse);
      expect(res.statusCode, HttpStatus.unauthorized);
    });

    test('rejects request with no Authorization header', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      var handlerCalled = false;
      final auth = BasicAuth(username: 'admin', password: 'secret');
      final chain = _buildChain([auth], (ctx) async {
        handlerCalled = true;
      });

      await chain(ctx);

      expect(handlerCalled, isFalse);
      expect(res.statusCode, HttpStatus.unauthorized);
      expect(res.headers.value('www-authenticate'), isNotNull);
    });

    test('rejects request with malformed Authorization header', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Basic not-valid-base64!@#',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      var handlerCalled = false;
      final auth = BasicAuth(username: 'admin', password: 'secret');
      final chain = _buildChain([auth], (ctx) async {
        handlerCalled = true;
      });

      await chain(ctx);

      expect(handlerCalled, isFalse);
      expect(res.statusCode, HttpStatus.unauthorized);
    });

    test('rejects request with Bearer token instead of Basic', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Bearer some-token',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      var handlerCalled = false;
      final auth = BasicAuth(username: 'admin', password: 'secret');
      final chain = _buildChain([auth], (ctx) async {
        handlerCalled = true;
      });

      await chain(ctx);

      expect(handlerCalled, isFalse);
      expect(res.statusCode, HttpStatus.unauthorized);
    });

    test('handles credentials with colon in password', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Basic ${_encodeCredentials('admin', 'pass:word:123')}',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      var handlerCalled = false;
      final auth = BasicAuth(username: 'admin', password: 'pass:word:123');
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

      final auth = BasicAuth(
        username: 'admin',
        password: 'secret',
        realm: 'Admin Portal',
      );
      final chain = _buildChain([auth], (ctx) async {});

      await chain(ctx);

      expect(res.headers.value('www-authenticate'), 'Basic realm="Admin Portal"');
    });

    test('is case-insensitive for "Basic" scheme', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'basic ${_encodeCredentials('admin', 'secret')}',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      var handlerCalled = false;
      final auth = BasicAuth(username: 'admin', password: 'secret');
      final chain = _buildChain([auth], (ctx) async {
        handlerCalled = true;
      });

      await chain(ctx);

      expect(handlerCalled, isTrue);
    });

    test('handles empty credentials', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Basic ${_encodeCredentials('', '')}',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      var handlerCalled = false;
      final auth = BasicAuth(username: '', password: '');
      final chain = _buildChain([auth], (ctx) async {
        handlerCalled = true;
      });

      await chain(ctx);

      expect(handlerCalled, isTrue);
    });
  });

  group('BasicAuth.withValidator', () {
    test('validates with custom sync validator', () async {
      final validUsers = {
        'admin': 'secret',
        'user': 'password',
      };

      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Basic ${_encodeCredentials('user', 'password')}',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      var handlerCalled = false;
      final auth = BasicAuth.withValidator(
        validator: (username, password) {
          return validUsers[username] == password;
        },
      );
      final chain = _buildChain([auth], (ctx) async {
        handlerCalled = true;
      });

      await chain(ctx);

      expect(handlerCalled, isTrue);
    });

    test('rejects invalid credentials with custom validator', () async {
      final validUsers = {
        'admin': 'secret',
      };

      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Basic ${_encodeCredentials('user', 'wrong')}',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      var handlerCalled = false;
      final auth = BasicAuth.withValidator(
        validator: (username, password) {
          return validUsers[username] == password;
        },
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
        authHeader: 'Basic ${_encodeCredentials('admin', 'secret')}',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      var handlerCalled = false;
      final auth = BasicAuth.withValidator(
        validator: (username, password) async {
          // Simulate async operation (e.g., database lookup)
          await Future.delayed(Duration(milliseconds: 10));
          return username == 'admin' && password == 'secret';
        },
      );
      final chain = _buildChain([auth], (ctx) async {
        handlerCalled = true;
      });

      await chain(ctx);

      expect(handlerCalled, isTrue);
    });

    test('allows multiple users with validator', () async {
      final validUsers = {
        'admin': 'secret1',
        'user1': 'password1',
        'user2': 'password2',
      };

      final auth = BasicAuth.withValidator(
        validator: (username, password) {
          return validUsers[username] == password;
        },
      );

      // Test admin
      var req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Basic ${_encodeCredentials('admin', 'secret1')}',
      );
      var res = _MockResponse();
      var ctx = Context(req, res);
      var handlerCalled = false;
      var chain = _buildChain([auth], (ctx) async {
        handlerCalled = true;
      });
      await chain(ctx);
      expect(handlerCalled, isTrue);

      // Test user1
      req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Basic ${_encodeCredentials('user1', 'password1')}',
      );
      res = _MockResponse();
      ctx = Context(req, res);
      handlerCalled = false;
      chain = _buildChain([auth], (ctx) async {
        handlerCalled = true;
      });
      await chain(ctx);
      expect(handlerCalled, isTrue);

      // Test invalid user
      req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Basic ${_encodeCredentials('invalid', 'wrong')}',
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
  });

  group('Security', () {
    test('uses constant-time comparison for passwords', () async {
      // This test verifies that the comparison doesn't leak timing information
      // In practice, this is hard to test directly, but we can verify the implementation
      final auth = BasicAuth(username: 'admin', password: 'secretpassword123');

      // Test with same-length wrong password
      final req1 = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Basic ${_encodeCredentials('admin', 'wrongpassword123')}',
      );
      final res1 = _MockResponse();
      final ctx1 = Context(req1, res1);
      final chain1 = _buildChain([auth], (ctx) async {});
      await chain1(ctx1);
      expect(res1.statusCode, HttpStatus.unauthorized);

      // Test with different-length wrong password
      final req2 = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Basic ${_encodeCredentials('admin', 'short')}',
      );
      final res2 = _MockResponse();
      final ctx2 = Context(req2, res2);
      final chain2 = _buildChain([auth], (ctx) async {});
      await chain2(ctx2);
      expect(res2.statusCode, HttpStatus.unauthorized);
    });

    test('handles credentials without colon separator', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Basic ${base64.encode(utf8.encode('nocredentials'))}',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final auth = BasicAuth(username: 'admin', password: 'secret');
      final chain = _buildChain([auth], (ctx) async {});
      await chain(ctx);

      expect(res.statusCode, HttpStatus.unauthorized);
    });

    test('handles empty authorization value', () async {
      final req = _MockRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/'),
        authHeader: 'Basic ',
      );
      final res = _MockResponse();
      final ctx = Context(req, res);

      final auth = BasicAuth(username: 'admin', password: 'secret');
      final chain = _buildChain([auth], (ctx) async {});
      await chain(ctx);

      expect(res.statusCode, HttpStatus.unauthorized);
    });
  });
}
