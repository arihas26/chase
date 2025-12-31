/// Testing utilities for Chase framework.
///
/// Provides mock implementations and helpers for testing Chase applications.
///
/// Example:
/// ```dart
/// import 'package:chase/testing/testing.dart';
///
/// void main() {
///   test('handles GET request', () async {
///     final ctx = TestContext.get('/users?page=1');
///     await myHandler(ctx);
///
///     expect(ctx.response.statusCode, 200);
///     expect(ctx.response.body, contains('users'));
///   });
/// }
/// ```
library;

export 'helpers.dart';
export 'matchers.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:chase/chase.dart';

// -----------------------------------------------------------------------------
// MockHttpHeaders
// -----------------------------------------------------------------------------

/// Mock implementation of [HttpHeaders] for testing.
class MockHttpHeaders implements HttpHeaders {
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
  void remove(String name, Object value) {
    _values[name.toLowerCase()]?.remove(value.toString());
  }

  @override
  void removeAll(String name) {
    _values.remove(name.toLowerCase());
  }

  @override
  void clear() {
    _values.clear();
    _contentType = null;
  }

  @override
  String? value(String name) {
    final values = _values[name.toLowerCase()];
    if (values == null || values.isEmpty) return null;
    return values.last;
  }

  @override
  List<String>? operator [](String name) => _values[name.toLowerCase()];

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _values.forEach(action);
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
  int get contentLength {
    final value = this.value(HttpHeaders.contentLengthHeader);
    return value != null ? int.tryParse(value) ?? -1 : -1;
  }

  @override
  set contentLength(int length) {
    set(HttpHeaders.contentLengthHeader, length.toString());
  }

  @override
  String? get host => value(HttpHeaders.hostHeader);

  @override
  set host(String? value) {
    if (value != null) set(HttpHeaders.hostHeader, value);
  }

  @override
  int? get port => null;

  @override
  set port(int? value) {}

  @override
  DateTime? get date => null;

  @override
  set date(DateTime? value) {}

  @override
  DateTime? get expires => null;

  @override
  set expires(DateTime? value) {}

  @override
  DateTime? get ifModifiedSince => null;

  @override
  set ifModifiedSince(DateTime? value) {}

  @override
  bool get chunkedTransferEncoding => false;

  @override
  set chunkedTransferEncoding(bool value) {}

  @override
  bool get persistentConnection => true;

  @override
  set persistentConnection(bool value) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// -----------------------------------------------------------------------------
// MockHttpConnectionInfo
// -----------------------------------------------------------------------------

/// Mock implementation of [HttpConnectionInfo] for testing.
class MockHttpConnectionInfo implements HttpConnectionInfo {
  @override
  final InternetAddress remoteAddress;

  @override
  final int remotePort;

  @override
  final int localPort;

  MockHttpConnectionInfo({
    String remoteIp = '127.0.0.1',
    this.remotePort = 12345,
    this.localPort = 8080,
  }) : remoteAddress = MockInternetAddress(remoteIp);
}

/// Mock implementation of [InternetAddress] for testing.
class MockInternetAddress implements InternetAddress {
  @override
  final String address;

  MockInternetAddress(this.address);

  @override
  String get host => address;

  @override
  bool get isLoopback => address == '127.0.0.1' || address == '::1';

  @override
  bool get isMulticast => false;

  @override
  bool get isLinkLocal => false;

  @override
  Uint8List get rawAddress => Uint8List.fromList(
        address.split('.').map((e) => int.tryParse(e) ?? 0).toList(),
      );

  @override
  InternetAddressType get type => InternetAddressType.IPv4;

  @override
  Future<InternetAddress> reverse() async => this;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// -----------------------------------------------------------------------------
// MockHttpRequest
// -----------------------------------------------------------------------------

/// Mock implementation of [HttpRequest] for testing.
///
/// Example:
/// ```dart
/// final request = MockHttpRequest(
///   method: 'POST',
///   uri: Uri.parse('/api/users'),
///   body: '{"name": "John"}',
///   headers: {'content-type': 'application/json'},
/// );
/// ```
class MockHttpRequest extends Stream<Uint8List> implements HttpRequest {
  @override
  final String method;

  @override
  final Uri uri;

  @override
  final Uri requestedUri;

  @override
  final MockHttpHeaders headers = MockHttpHeaders();

  @override
  final HttpConnectionInfo? connectionInfo;

  final List<int> _bodyBytes;
  final int? _contentLengthOverride;

  /// Creates a mock HTTP request.
  ///
  /// - [method]: HTTP method (GET, POST, etc.)
  /// - [uri]: Request URI with path and query parameters
  /// - [body]: Request body as string (will be UTF-8 encoded)
  /// - [bodyBytes]: Request body as bytes (alternative to [body])
  /// - [headers]: Map of header name to value
  /// - [remoteIp]: Client IP address for testing IP-based logic
  /// - [contentLength]: Override Content-Length (for testing body limit checks)
  MockHttpRequest({
    this.method = 'GET',
    Uri? uri,
    String? body,
    List<int>? bodyBytes,
    Map<String, String>? headers,
    String remoteIp = '127.0.0.1',
    int? contentLength,
  })  : uri = uri ?? Uri.parse('/'),
        requestedUri = uri ?? Uri.parse('http://localhost/'),
        _bodyBytes = bodyBytes ?? (body != null ? utf8.encode(body) : const []),
        connectionInfo = MockHttpConnectionInfo(remoteIp: remoteIp),
        _contentLengthOverride = contentLength {
    headers?.forEach((key, value) {
      this.headers.set(key, value);
    });
  }

  @override
  int get contentLength => _contentLengthOverride ?? _bodyBytes.length;

  @override
  StreamSubscription<Uint8List> listen(
    void Function(Uint8List)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final stream = _bodyBytes.isEmpty
        ? const Stream<Uint8List>.empty()
        : Stream.value(Uint8List.fromList(_bodyBytes));
    return stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// -----------------------------------------------------------------------------
// MockHttpResponse
// -----------------------------------------------------------------------------

/// Mock implementation of [HttpResponse] for testing.
///
/// Captures all written data for assertions.
///
/// Example:
/// ```dart
/// final response = MockHttpResponse();
/// // ... run handler ...
/// expect(response.statusCode, 200);
/// expect(response.body, contains('success'));
/// ```
class MockHttpResponse implements HttpResponse {
  @override
  int statusCode = 200;

  @override
  String reasonPhrase = 'OK';

  @override
  final MockHttpHeaders headers = MockHttpHeaders();

  final List<List<int>> _written = [];
  bool _closed = false;
  final Completer<void> _closeCompleter = Completer<void>();

  /// Whether the response has been closed.
  bool get isClosed => _closed;

  /// Future that completes when [close] is called.
  @override
  Future<void> get done => _closeCompleter.future;

  /// All written bytes.
  List<int> get bodyBytes {
    final combined = <int>[];
    for (final chunk in _written) {
      combined.addAll(chunk);
    }
    return combined;
  }

  /// Written body decoded as UTF-8 string.
  String get body => utf8.decode(bodyBytes);

  /// Written body parsed as JSON.
  dynamic get bodyJson => jsonDecode(body);

  @override
  void add(List<int> data) {
    _written.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      add(chunk);
    }
  }

  @override
  void write(Object? object) {
    if (object != null) {
      add(utf8.encode(object.toString()));
    }
  }

  @override
  void writeAll(Iterable objects, [String separator = '']) {
    write(objects.join(separator));
  }

  @override
  void writeln([Object? object = '']) {
    write('$object\n');
  }

  @override
  void writeCharCode(int charCode) {
    add([charCode]);
  }

  @override
  Future<void> flush() async {}

  @override
  Future close() async {
    _closed = true;
    if (!_closeCompleter.isCompleted) {
      _closeCompleter.complete();
    }
  }

  @override
  Encoding get encoding => utf8;

  @override
  set encoding(Encoding value) {}

  @override
  bool get bufferOutput => true;

  @override
  set bufferOutput(bool value) {}

  @override
  int get contentLength => -1;

  @override
  set contentLength(int value) {}

  @override
  bool get persistentConnection => true;

  @override
  set persistentConnection(bool value) {}

  @override
  Duration? get deadline => null;

  @override
  set deadline(Duration? value) {}

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  List<Cookie> get cookies => [];

  @override
  Future<Socket> detachSocket({bool writeHeaders = true}) {
    throw UnsupportedError('Cannot detach socket from mock response');
  }

  @override
  Future redirect(Uri location, {int status = HttpStatus.movedTemporarily}) {
    throw UnsupportedError('Use ctx.res.redirect() instead');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// -----------------------------------------------------------------------------
// TestContext
// -----------------------------------------------------------------------------

/// Factory for creating test [Context] instances.
///
/// Provides convenient methods for common HTTP methods.
///
/// Example:
/// ```dart
/// // Simple GET request
/// final ctx = TestContext.get('/users');
///
/// // POST with JSON body
/// final ctx = TestContext.post(
///   '/users',
///   body: {'name': 'John'},
///   headers: {'authorization': 'Bearer token'},
/// );
///
/// // Access response after handler runs
/// await myHandler(ctx);
/// expect(ctx.response.statusCode, 200);
/// ```
class TestContext {
  TestContext._();

  /// Creates a test context with a GET request.
  static Context get(
    String path, {
    Map<String, String>? headers,
    String remoteIp = '127.0.0.1',
  }) {
    return _create('GET', path, headers: headers, remoteIp: remoteIp);
  }

  /// Creates a test context with a POST request.
  static Context post(
    String path, {
    Object? body,
    Map<String, String>? headers,
    String remoteIp = '127.0.0.1',
  }) {
    return _create('POST', path, body: body, headers: headers, remoteIp: remoteIp);
  }

  /// Creates a test context with a PUT request.
  static Context put(
    String path, {
    Object? body,
    Map<String, String>? headers,
    String remoteIp = '127.0.0.1',
  }) {
    return _create('PUT', path, body: body, headers: headers, remoteIp: remoteIp);
  }

  /// Creates a test context with a PATCH request.
  static Context patch(
    String path, {
    Object? body,
    Map<String, String>? headers,
    String remoteIp = '127.0.0.1',
  }) {
    return _create('PATCH', path, body: body, headers: headers, remoteIp: remoteIp);
  }

  /// Creates a test context with a DELETE request.
  static Context delete(
    String path, {
    Map<String, String>? headers,
    String remoteIp = '127.0.0.1',
  }) {
    return _create('DELETE', path, headers: headers, remoteIp: remoteIp);
  }

  /// Creates a test context with custom method.
  static Context create(
    String method,
    String path, {
    Object? body,
    Map<String, String>? headers,
    String remoteIp = '127.0.0.1',
    int? contentLength,
  }) {
    return _create(
      method,
      path,
      body: body,
      headers: headers,
      remoteIp: remoteIp,
      contentLength: contentLength,
    );
  }

  static Context _create(
    String method,
    String path, {
    Object? body,
    Map<String, String>? headers,
    String remoteIp = '127.0.0.1',
    int? contentLength,
  }) {
    String? bodyString;
    final effectiveHeaders = Map<String, String>.from(headers ?? {});

    if (body != null) {
      if (body is String) {
        bodyString = body;
      } else if (body is Map || body is List) {
        bodyString = jsonEncode(body);
        effectiveHeaders.putIfAbsent('content-type', () => 'application/json');
      } else {
        bodyString = body.toString();
      }
    }

    final request = MockHttpRequest(
      method: method,
      uri: Uri.parse(path),
      body: bodyString,
      headers: effectiveHeaders,
      remoteIp: remoteIp,
      contentLength: contentLength,
    );
    final response = MockHttpResponse();

    return Context(request, response);
  }
}

/// Extension to easily access mock response from [Context].
extension TestContextExtension on Context {
  /// Returns the [MockHttpResponse] for assertions.
  ///
  /// Example:
  /// ```dart
  /// expect(ctx.response.statusCode, 200);
  /// expect(ctx.response.body, contains('success'));
  /// ```
  MockHttpResponse get response => res.$raw as MockHttpResponse;
}

// -----------------------------------------------------------------------------
// Middleware Chain Builder
// -----------------------------------------------------------------------------

/// Builds a handler chain from middlewares.
///
/// Example:
/// ```dart
/// final chain = buildMiddlewareChain(
///   [AuthMiddleware(), LoggerMiddleware()],
///   (ctx) async {
///     await ctx.res.json({'status': 'ok'});
///   },
/// );
///
/// final ctx = TestContext.get('/');
/// await chain(ctx);
/// expect(ctx.response.statusCode, 200);
/// ```
Handler buildMiddlewareChain(List<Middleware> middlewares, Handler finalHandler) {
  Handler current = finalHandler;
  for (var i = middlewares.length - 1; i >= 0; i--) {
    final mw = middlewares[i];
    final next = current;
    current = (ctx) => mw.handle(ctx, () => next(ctx));
  }
  return current;
}

// -----------------------------------------------------------------------------
// TestResponse
// -----------------------------------------------------------------------------

/// Response wrapper for testing assertions.
///
/// Provides convenient accessors for status, headers, and body.
///
/// Example:
/// ```dart
/// final res = await client.get('/users');
/// expect(res.status, 200);
/// expect(res.json['name'], 'John');
/// ```
class TestResponse {
  final HttpClientResponse _raw;
  String? _body;
  List<int>? _bodyBytes;

  TestResponse(this._raw);

  /// HTTP status code.
  int get status => _raw.statusCode;

  /// Response headers.
  HttpHeaders get headers => _raw.headers;

  /// Response body as bytes (fetched lazily).
  Future<List<int>> get bodyBytes async {
    if (_bodyBytes == null) {
      final chunks = <List<int>>[];
      await for (final chunk in _raw) {
        chunks.add(chunk);
      }
      _bodyBytes = chunks.expand((c) => c).toList();
    }
    return _bodyBytes!;
  }

  /// Response body as string (fetched lazily).
  Future<String> get body async {
    _body ??= utf8.decode(await bodyBytes);
    return _body!;
  }

  /// Response body parsed as JSON (fetched lazily).
  Future<dynamic> get json async => jsonDecode(await body);

  /// Content-Type header value.
  String? get contentType => headers.value('content-type');

  /// Whether the response indicates success (2xx).
  bool get isOk => status >= 200 && status < 300;

  /// Whether the response is a redirect (3xx).
  bool get isRedirect => status >= 300 && status < 400;

  /// Whether the response is a client error (4xx).
  bool get isClientError => status >= 400 && status < 500;

  /// Whether the response is a server error (5xx).
  bool get isServerError => status >= 500;

  @override
  String toString() => 'TestResponse(status: $status)';
}

// -----------------------------------------------------------------------------
// TestClient
// -----------------------------------------------------------------------------

/// HTTP client for testing Chase applications.
///
/// Starts the app on an ephemeral port and sends real HTTP requests.
///
/// Example:
/// ```dart
/// void main() {
///   late Chase app;
///   late TestClient client;
///
///   setUp(() async {
///     app = Chase();
///     app.get('/users/:id').handle((ctx) {
///       ctx.res.json({'id': ctx.req.params['id']});
///     });
///     client = await TestClient.start(app);
///   });
///
///   tearDown(() async {
///     await client.close();
///   });
///
///   test('GET /users/:id returns user', () async {
///     final res = await client.get('/users/123');
///     expect(res.status, 200);
///     expect(res.json['id'], '123');
///   });
/// }
/// ```
class TestClient {
  final Chase _app;
  final HttpClient _client;
  final int _port;

  TestClient._(this._app, this._port) : _client = HttpClient();

  /// Starts the app and creates a test client.
  ///
  /// The app is started on an ephemeral port (port 0).
  /// Call [close] when done to stop the server.
  static Future<TestClient> start(Chase app) async {
    await runZoned(
      () => app.start(port: 0),
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) {
          // Suppress server startup message
        },
      ),
    );
    final port = app.server!.port;
    return TestClient._(app, port);
  }

  /// Stops the server and closes the HTTP client.
  Future<void> close() async {
    _client.close();
    await _app.stop();
  }

  /// Sends a GET request.
  Future<TestResponse> get(
    String path, {
    Map<String, String>? headers,
  }) =>
      request('GET', path, headers: headers);

  /// Sends a POST request.
  Future<TestResponse> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) =>
      request('POST', path, body: body, headers: headers);

  /// Sends a PUT request.
  Future<TestResponse> put(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) =>
      request('PUT', path, body: body, headers: headers);

  /// Sends a PATCH request.
  Future<TestResponse> patch(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) =>
      request('PATCH', path, body: body, headers: headers);

  /// Sends a DELETE request.
  Future<TestResponse> delete(
    String path, {
    Map<String, String>? headers,
  }) =>
      request('DELETE', path, headers: headers);

  /// Sends a request with any HTTP method.
  Future<TestResponse> request(
    String method,
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('http://localhost:$_port$path');

    final req = await _client.openUrl(method, uri);

    // Disable automatic redirect following so tests can inspect redirect responses
    req.followRedirects = false;

    // Set headers
    headers?.forEach((key, value) {
      req.headers.set(key, value);
    });

    // Write body
    if (body != null) {
      String bodyString;
      if (body is String) {
        bodyString = body;
      } else if (body is Map || body is List) {
        bodyString = jsonEncode(body);
        req.headers.set('content-type', 'application/json');
      } else {
        bodyString = body.toString();
      }
      req.write(bodyString);
    }

    final res = await req.close();
    return TestResponse(res);
  }
}
