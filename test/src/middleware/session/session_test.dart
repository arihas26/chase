import 'dart:async';
import 'dart:convert';
import 'dart:io' hide SameSite;
import 'dart:math';

import 'package:chase/src/core/context/context.dart';
import 'package:chase/src/core/context/cookie.dart';
import 'package:chase/src/middleware/session/session.dart';
import 'package:test/test.dart';

// Mock HttpRequest for testing
class MockHttpRequest implements HttpRequest {
  final String _remoteAddress;
  final MockHttpHeaders _headers;

  MockHttpRequest({
    String remoteAddress = '127.0.0.1',
    Map<String, String>? headers,
  })  : _remoteAddress = remoteAddress,
        _headers = MockHttpHeaders(headers ?? {});

  @override
  HttpConnectionInfo? get connectionInfo => MockHttpConnectionInfo(_remoteAddress);

  @override
  HttpHeaders get headers => _headers;

  @override
  Uri get uri => Uri.parse('http://localhost/test');

  @override
  String get method => 'GET';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockHttpConnectionInfo implements HttpConnectionInfo {
  final String _remoteAddress;

  MockHttpConnectionInfo(this._remoteAddress);

  @override
  InternetAddress get remoteAddress => MockInternetAddress(_remoteAddress);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockInternetAddress implements InternetAddress {
  @override
  final String address;

  MockInternetAddress(this.address);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockHttpHeaders implements HttpHeaders {
  final Map<String, String> _headers;
  final List<String> _setCookies = [];

  MockHttpHeaders([Map<String, String>? initial]) : _headers = initial ?? {};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _headers[name.toLowerCase()] = value.toString();
  }

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    if (name.toLowerCase() == 'set-cookie') {
      _setCookies.add(value.toString());
    } else {
      _headers[name.toLowerCase()] = value.toString();
    }
  }

  @override
  String? value(String name) => _headers[name.toLowerCase()];

  String? get(String name) => _headers[name.toLowerCase()];

  /// Get all Set-Cookie headers
  List<String> get setCookies => _setCookies;

  @override
  set contentType(ContentType? contentType) {
    if (contentType != null) {
      _headers['content-type'] = contentType.toString();
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// Mock HttpResponse for testing
class MockHttpResponse implements HttpResponse {
  @override
  int statusCode = 200;

  final StringBuffer writtenData = StringBuffer();
  bool _closed = false;

  @override
  final MockHttpHeaders headers = MockHttpHeaders();

  final List<Cookie> _cookies = [];

  @override
  List<Cookie> get cookies => _cookies;

  @override
  void write(Object? object) {
    writtenData.write(object);
  }

  @override
  Future close() async {
    _closed = true;
  }

  bool get isClosed => _closed;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('SessionData', () {
    test('create() creates new session with isNew=true', () {
      final session = SessionData.create('test-id');

      expect(session.id, equals('test-id'));
      expect(session.isNew, isTrue);
      expect(session.isModified, isFalse);
      expect(session.data, isEmpty);
    });

    test('set() marks session as modified', () {
      final session = SessionData.create('test-id');

      session.set('key', 'value');

      expect(session.isModified, isTrue);
      expect(session.get<String>('key'), equals('value'));
    });

    test('get() returns typed value', () {
      final session = SessionData.create('test-id');

      session.set('string', 'hello');
      session.set('int', 42);
      session.set('list', [1, 2, 3]);

      expect(session.get<String>('string'), equals('hello'));
      expect(session.get<int>('int'), equals(42));
      expect(session.get<List<int>>('list'), equals([1, 2, 3]));
    });

    // Note: In debug mode, get<T>() with wrong type triggers an assert.
    // This is intentional to catch type mismatches early in development.

    test('get() returns null for missing key', () {
      final session = SessionData.create('test-id');

      expect(session.get<String>('missing'), isNull);
    });

    test('remove() marks session as modified', () {
      final session = SessionData.fromStore('test-id', {'key': 'value'}, DateTime.now());
      expect(session.isModified, isFalse);

      session.remove('key');

      expect(session.isModified, isTrue);
      expect(session.has('key'), isFalse);
    });

    test('remove() does not modify if key does not exist', () {
      final session = SessionData.fromStore('test-id', {}, DateTime.now());

      session.remove('nonexistent');

      expect(session.isModified, isFalse);
    });

    test('has() returns true for existing key', () {
      final session = SessionData.create('test-id');

      session.set('key', 'value');

      expect(session.has('key'), isTrue);
      expect(session.has('other'), isFalse);
    });

    test('clear() removes all data and marks modified', () {
      final session = SessionData.fromStore('test-id', {'a': 1, 'b': 2}, DateTime.now());

      session.clear();

      expect(session.data, isEmpty);
      expect(session.isModified, isTrue);
    });

    test('clear() does not mark modified if already empty', () {
      final session = SessionData.fromStore('test-id', {}, DateTime.now());

      session.clear();

      expect(session.isModified, isFalse);
    });

    test('touch() updates lastAccess', () async {
      final original = DateTime.now().subtract(const Duration(seconds: 10));
      final session = SessionData.fromStore('test-id', {}, original);

      await Future.delayed(const Duration(milliseconds: 10));
      session.touch();

      expect(session.lastAccess.isAfter(original), isTrue);
    });

    test('data returns unmodifiable map', () {
      final session = SessionData.create('test-id');
      session.set('key', 'value');

      expect(() => session.data['new'] = 'test', throwsA(isA<UnsupportedError>()));
    });

    test('fromStore creates session with isNew=false', () {
      final session = SessionData.fromStore('test-id', {'key': 'value'}, DateTime.now());

      expect(session.isNew, isFalse);
      expect(session.isModified, isFalse);
      expect(session.get<String>('key'), equals('value'));
    });
  });

  group('MemorySessionStore', () {
    test('get() returns null for non-existent session', () {
      final store = MemorySessionStore();

      expect(store.get('nonexistent'), isNull);
    });

    test('set() and get() round-trip session data', () {
      final store = MemorySessionStore();
      final session = SessionData.create('test-id');
      session.set('user', 'alice');

      store.set('test-id', session);
      final retrieved = store.get('test-id');

      expect(retrieved, isNotNull);
      expect(retrieved!.id, equals('test-id'));
      expect(retrieved.get<String>('user'), equals('alice'));
    });

    test('delete() removes session', () {
      final store = MemorySessionStore();
      final session = SessionData.create('test-id');

      store.set('test-id', session);
      store.delete('test-id');

      expect(store.get('test-id'), isNull);
    });

    test('cleanup() removes expired sessions', () async {
      final store = MemorySessionStore();

      // Create old session
      final oldSession = SessionData.fromStore(
        'old',
        {'key': 'value'},
        DateTime.now().subtract(const Duration(hours: 25)),
      );
      store.set('old', oldSession);

      // Create recent session
      final recentSession = SessionData.create('recent');
      store.set('recent', recentSession);

      store.cleanup(const Duration(hours: 24));

      expect(store.get('old'), isNull);
      expect(store.get('recent'), isNotNull);
    });

    test('length returns session count', () {
      final store = MemorySessionStore();

      expect(store.length, equals(0));

      store.set('a', SessionData.create('a'));
      store.set('b', SessionData.create('b'));

      expect(store.length, equals(2));
    });

    test('dispose() clears all sessions', () {
      final store = MemorySessionStore();
      store.set('test', SessionData.create('test'));

      store.dispose();

      expect(store.length, equals(0));
    });

    test('auto-cleanup timer works', () async {
      final store = MemorySessionStore(
        cleanupInterval: const Duration(milliseconds: 50),
      );

      // Create expired session
      final expired = SessionData.fromStore(
        'expired',
        {},
        DateTime.now().subtract(const Duration(hours: 25)),
      );
      store.set('expired', expired);

      // Wait for cleanup
      await Future.delayed(const Duration(milliseconds: 100));

      expect(store.get('expired'), isNull);

      store.dispose();
    });

    test('stored data is independent of original', () {
      final store = MemorySessionStore();
      final session = SessionData.create('test-id');
      session.set('key', 'value1');

      store.set('test-id', session);

      // Modify original
      session.set('key', 'value2');

      // Retrieved should still have original value
      final retrieved = store.get('test-id');
      expect(retrieved!.get<String>('key'), equals('value1'));
    });
  });

  group('SessionOptions', () {
    test('default options', () {
      const options = SessionOptions();

      expect(options.cookieName, equals('session_id'));
      expect(options.maxAge, equals(const Duration(hours: 24)));
      expect(options.rolling, isFalse);
      expect(options.saveUnmodified, isFalse);
      expect(options.cookieHttpOnly, isTrue);
      expect(options.cookieSameSite, equals(SameSite.lax));
    });

    test('secure preset', () {
      const options = SessionOptions.secure();

      expect(options.cookieSecure, isTrue);
      expect(options.cookieHttpOnly, isTrue);
      expect(options.cookieSameSite, equals(SameSite.strict));
    });

    test('shortLived preset', () {
      const options = SessionOptions.shortLived();

      expect(options.maxAge, equals(const Duration(minutes: 30)));
      expect(options.rolling, isTrue);
    });

    test('custom id generator', () {
      var callCount = 0;
      final options = SessionOptions(
        idGenerator: () {
          callCount++;
          return 'custom-id-$callCount';
        },
      );

      expect(options.idGenerator, isNotNull);
      expect(options.idGenerator!(), equals('custom-id-1'));
      expect(options.idGenerator!(), equals('custom-id-2'));
    });
  });

  group('Session middleware', () {
    late MemorySessionStore store;
    late MockHttpResponse response;
    bool nextCalled = false;

    setUp(() {
      store = MemorySessionStore();
      response = MockHttpResponse();
      nextCalled = false;
    });

    tearDown(() {
      store.dispose();
    });

    Future<void> createNext(Context ctx) async {
      nextCalled = true;
    }

    test('creates new session on first request', () async {
      final request = MockHttpRequest();
      final ctx = Context(request, response);
      final middleware = Session(store);

      await middleware.handle(ctx, () => createNext(ctx));

      expect(nextCalled, isTrue);
      expect(store.length, equals(1));

      // Session cookie should be set via Set-Cookie header
      expect(response.headers.setCookies.length, equals(1));
      expect(response.headers.setCookies.first, contains('session_id='));
    });

    test('loads existing session from cookie', () async {
      // Create initial session
      final initialSession = SessionData.create('existing-session-id');
      initialSession.set('user', 'alice');
      store.set('existing-session-id', initialSession);

      // Request with session cookie
      final request = MockHttpRequest(headers: {
        'cookie': 'session_id=existing-session-id',
      });
      final ctx = Context(request, response);
      final middleware = Session(store);

      String? foundUser;
      await middleware.handle(ctx, () async {
        foundUser = ctx.session.get<String>('user');
      });

      expect(foundUser, equals('alice'));
    });

    test('creates new session if cookie ID not in store', () async {
      final request = MockHttpRequest(headers: {
        'cookie': 'session_id=nonexistent-id',
      });
      final ctx = Context(request, response);
      final middleware = Session(store);

      await middleware.handle(ctx, () => createNext(ctx));

      expect(nextCalled, isTrue);
      expect(store.length, equals(1));
      // New session should be created
      expect(store.get('nonexistent-id'), isNull);
    });

    test('saves modified session', () async {
      final request = MockHttpRequest();
      final ctx = Context(request, response);
      final middleware = Session(store);

      String? sessionId;
      await middleware.handle(ctx, () async {
        ctx.session.set('key', 'value');
        sessionId = ctx.session.id;
      });

      final stored = store.get(sessionId!);
      expect(stored, isNotNull);
      expect(stored!.get<String>('key'), equals('value'));
    });

    test('does not save unmodified session by default', () async {
      // Create existing session
      final existingSession = SessionData.create('test-session');
      store.set('test-session', existingSession);

      final request = MockHttpRequest(headers: {
        'cookie': 'session_id=test-session',
      });
      final ctx = Context(request, response);
      final middleware = Session(store);

      // Access session but don't modify
      await middleware.handle(ctx, () async {
        // Just read session id, don't modify
        final _ = ctx.session.id;
      });

      // Cookie should not be re-set for existing unmodified session
      expect(response.headers.setCookies, isEmpty);
    });

    test('saves unmodified session when saveUnmodified=true', () async {
      // Create existing session
      final existingSession = SessionData.create('test-session');
      store.set('test-session', existingSession);

      final request = MockHttpRequest(headers: {
        'cookie': 'session_id=test-session',
      });
      final ctx = Context(request, response);
      final middleware = Session(store, const SessionOptions(saveUnmodified: true));

      await middleware.handle(ctx, () async {
        final _ = ctx.session.id;
      });

      // Session should still be in store
      expect(store.get('test-session'), isNotNull);
    });

    test('uses custom session ID generator', () async {
      final request = MockHttpRequest();
      final ctx = Context(request, response);
      final middleware = Session(
        store,
        SessionOptions(idGenerator: () => 'custom-generated-id'),
      );

      await middleware.handle(ctx, () async {
        ctx.session.set('key', 'value');
      });

      expect(store.get('custom-generated-id'), isNotNull);
    });

    test('sets cookie with correct options', () async {
      final request = MockHttpRequest();
      final ctx = Context(request, response);
      final middleware = Session(store, const SessionOptions.secure());

      await middleware.handle(ctx, () async {
        ctx.session.set('key', 'value');
      });

      expect(response.headers.setCookies.length, equals(1));
      final setCookie = response.headers.setCookies.first;
      expect(setCookie, contains('HttpOnly'));
      expect(setCookie, contains('Secure'));
      expect(setCookie, contains('SameSite=Strict'));
    });

    test('sets new cookie when rolling=true', () async {
      // Create existing session
      final existingSession = SessionData.create('test-session');
      store.set('test-session', existingSession);

      final request = MockHttpRequest(headers: {
        'cookie': 'session_id=test-session',
      });
      final ctx = Context(request, response);
      final middleware = Session(store, const SessionOptions(rolling: true));

      await middleware.handle(ctx, () => createNext(ctx));

      // Cookie should be re-set even for existing session
      expect(response.headers.setCookies.length, equals(1));
    });
  });

  group('SessionContextExtension', () {
    late MemorySessionStore store;
    late MockHttpResponse response;

    setUp(() {
      store = MemorySessionStore();
      response = MockHttpResponse();
    });

    tearDown(() {
      store.dispose();
    });

    test('session throws without middleware', () {
      final request = MockHttpRequest();
      final ctx = Context(request, response);

      expect(() => ctx.session, throwsA(isA<StateError>()));
    });

    test('sessionOrNull returns null without middleware', () {
      final request = MockHttpRequest();
      final ctx = Context(request, response);

      expect(ctx.sessionOrNull, isNull);
    });

    test('destroySession creates new session', () async {
      final request = MockHttpRequest();
      final ctx = Context(request, response);
      final middleware = Session(store);

      String? originalId;
      String? newId;

      await middleware.handle(ctx, () async {
        ctx.session.set('data', 'secret');
        originalId = ctx.session.id;

        ctx.destroySession();
        newId = ctx.session.id;

        // Data should be gone
        expect(ctx.session.get<String>('data'), isNull);

      });

      expect(newId, isNot(equals(originalId)));
    });

    test('regenerateSession preserves data with new ID', () async {
      final request = MockHttpRequest();
      final ctx = Context(request, response);
      final middleware = Session(store);

      String? originalId;
      String? newId;
      String? preservedData;

      await middleware.handle(ctx, () async {
        ctx.session.set('user', 'alice');
        originalId = ctx.session.id;

        ctx.regenerateSession();
        newId = ctx.session.id;
        preservedData = ctx.session.get<String>('user');

      });

      expect(newId, isNot(equals(originalId)));
      expect(preservedData, equals('alice'));
    });

    test('regenerateSession does nothing without session', () {
      final request = MockHttpRequest();
      final ctx = Context(request, response);

      // Should not throw
      ctx.regenerateSession();
    });
  });

  group('Session ID generation', () {
    test('generates unique IDs', () {
      final ids = <String>{};

      for (var i = 0; i < 100; i++) {
        final session = SessionData.create(_generateTestId());
        expect(ids.add(session.id), isTrue, reason: 'Duplicate ID generated');
      }
    });

    test('generates URL-safe IDs', () {
      for (var i = 0; i < 10; i++) {
        final id = _generateTestId();
        expect(id, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
        expect(id.length, greaterThanOrEqualTo(32));
      }
    });
  });
}

/// Generates a test session ID similar to the Session middleware
String _generateTestId() {
  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}

