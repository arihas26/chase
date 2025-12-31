import 'dart:convert';
import 'dart:io';

import 'package:chase/src/core/context/cookie.dart';
import 'package:chase/src/core/http/sse.dart';
import 'package:chase/src/core/http/streaming.dart';
import 'package:chase/src/core/http/text_streaming.dart';

/// HTTP response wrapper providing convenient access to response methods.
///
/// Example:
/// ```dart
/// app.get('/api/users', (ctx) async {
///   await ctx.res.json({'users': []});
/// });
///
/// app.get('/stream', (ctx) async {
///   ctx.res.statusCode = 200;
///   ctx.res.headers.contentType = ContentType.binary;
///   ctx.res.write('Hello');
///   await ctx.res.close();
/// });
/// ```
class Res {
  final HttpResponse _raw;
  bool _sent = false;

  Res(this._raw);

  /// Returns true if response has already been sent.
  bool get isSent => _sent;

  // ---------------------------------------------------------------------------
  // Status Code
  // ---------------------------------------------------------------------------

  /// HTTP status code for the response.
  int get statusCode => _raw.statusCode;
  set statusCode(int code) => _raw.statusCode = code;

  // ---------------------------------------------------------------------------
  // Headers
  // ---------------------------------------------------------------------------

  /// Response headers.
  HttpHeaders get headers => _raw.headers;

  // ---------------------------------------------------------------------------
  // Convenience Methods
  // ---------------------------------------------------------------------------

  /// Sends a plain text response.
  Future<void> text(String body, {int status = HttpStatus.ok}) async {
    if (_sent) return;
    _sent = true;
    _raw
      ..statusCode = status
      ..write(body);
    await _raw.close();
  }

  /// Sends a JSON response.
  Future<void> json(Object? body, {int status = HttpStatus.ok}) async {
    if (_sent) return;
    _sent = true;
    _raw
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    await _raw.close();
  }

  /// Sends an HTML response.
  Future<void> html(String body, {int status = HttpStatus.ok}) async {
    if (_sent) return;
    _sent = true;
    _raw
      ..statusCode = status
      ..headers.contentType = ContentType.html
      ..write(body);
    await _raw.close();
  }

  /// Sends a redirect response.
  Future<void> redirect(String location, {int status = HttpStatus.found}) async {
    if (_sent) return;
    _sent = true;
    _raw
      ..statusCode = status
      ..headers.set(HttpHeaders.locationHeader, location);
    await _raw.close();
  }

  /// Sends a 404 Not Found response.
  Future<void> notFound([String body = '404 Not Found']) async {
    await text(body, status: HttpStatus.notFound);
  }

  /// Sends a 201 Created response with optional JSON body.
  ///
  /// ## Example
  ///
  /// ```dart
  /// ctx.res.created({'id': 1, 'name': 'New Item'});
  /// ```
  Future<void> created([Object? body]) async {
    if (body != null) {
      await json(body, status: HttpStatus.created);
    } else {
      await text('', status: HttpStatus.created);
    }
  }

  /// Sends a 204 No Content response.
  ///
  /// ## Example
  ///
  /// ```dart
  /// ctx.res.noContent();
  /// ```
  Future<void> noContent() async {
    if (_sent) return;
    _sent = true;
    _raw.statusCode = HttpStatus.noContent;
    await _raw.close();
  }

  /// Sends a 400 Bad Request response.
  ///
  /// ## Example
  ///
  /// ```dart
  /// ctx.res.badRequest('Invalid email format');
  /// ctx.res.badRequest({'error': 'Invalid email', 'field': 'email'});
  /// ```
  Future<void> badRequest([Object? body = 'Bad Request']) async {
    if (body is String) {
      await text(body, status: HttpStatus.badRequest);
    } else {
      await json(body, status: HttpStatus.badRequest);
    }
  }

  /// Sends a 401 Unauthorized response.
  ///
  /// ## Example
  ///
  /// ```dart
  /// ctx.res.unauthorized();
  /// ctx.res.unauthorized({'error': 'Invalid token'});
  /// ```
  Future<void> unauthorized([Object? body = 'Unauthorized']) async {
    if (body is String) {
      await text(body, status: HttpStatus.unauthorized);
    } else {
      await json(body, status: HttpStatus.unauthorized);
    }
  }

  /// Sends a 403 Forbidden response.
  ///
  /// ## Example
  ///
  /// ```dart
  /// ctx.res.forbidden();
  /// ctx.res.forbidden({'error': 'Access denied'});
  /// ```
  Future<void> forbidden([Object? body = 'Forbidden']) async {
    if (body is String) {
      await text(body, status: HttpStatus.forbidden);
    } else {
      await json(body, status: HttpStatus.forbidden);
    }
  }

  /// Sends a 500 Internal Server Error response.
  ///
  /// ## Example
  ///
  /// ```dart
  /// ctx.res.serverError();
  /// ctx.res.serverError({'error': 'Something went wrong'});
  /// ```
  Future<void> serverError([Object? body = 'Internal Server Error']) async {
    if (body is String) {
      await text(body, status: HttpStatus.internalServerError);
    } else {
      await json(body, status: HttpStatus.internalServerError);
    }
  }

  // ---------------------------------------------------------------------------
  // Cookies
  // ---------------------------------------------------------------------------

  /// Sets a cookie.
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Simple session cookie
  /// ctx.res.cookie('session', 'abc123');
  ///
  /// // With options
  /// ctx.res.cookie('user', 'john',
  ///   maxAge: CookieDuration.week,
  ///   httpOnly: true,
  ///   secure: true,
  ///   sameSite: SameSite.strict,
  /// );
  /// ```
  void cookie(
    String name,
    String value, {
    Duration? maxAge,
    DateTime? expires,
    String? domain,
    String? path,
    bool httpOnly = true,
    bool secure = false,
    SameSite? sameSite,
    bool partitioned = false,
    CookiePrefix prefix = CookiePrefix.none,
  }) {
    final header = formatSetCookie(
      name,
      value,
      maxAge: maxAge,
      expires: expires,
      domain: domain,
      path: path,
      httpOnly: httpOnly,
      secure: secure,
      sameSite: sameSite,
      partitioned: partitioned,
      prefix: prefix,
    );
    _raw.headers.add(HttpHeaders.setCookieHeader, header);
  }

  /// Sets a signed cookie using HMAC-SHA256.
  ///
  /// The cookie value is signed with the provided secret, allowing you to
  /// verify its integrity when reading it back.
  ///
  /// ## Example
  ///
  /// ```dart
  /// ctx.res.signedCookie('userId', '12345', 'my-secret-key',
  ///   maxAge: CookieDuration.day,
  /// );
  /// ```
  void signedCookie(
    String name,
    String value,
    String secret, {
    Duration? maxAge,
    DateTime? expires,
    String? domain,
    String? path,
    bool httpOnly = true,
    bool secure = false,
    SameSite? sameSite,
    bool partitioned = false,
    CookiePrefix prefix = CookiePrefix.none,
  }) {
    final signedValue = signCookieValue(value, secret);
    cookie(
      name,
      signedValue,
      maxAge: maxAge,
      expires: expires,
      domain: domain,
      path: path,
      httpOnly: httpOnly,
      secure: secure,
      sameSite: sameSite,
      partitioned: partitioned,
      prefix: prefix,
    );
  }

  /// Sets a JSON cookie.
  ///
  /// The value is JSON-encoded and base64url-encoded for safe cookie storage.
  ///
  /// ## Example
  ///
  /// ```dart
  /// ctx.res.jsonCookie('prefs', {'theme': 'dark', 'lang': 'en'},
  ///   maxAge: CookieDuration.year,
  /// );
  /// ```
  void jsonCookie(
    String name,
    Object? value, {
    Duration? maxAge,
    DateTime? expires,
    String? domain,
    String? path,
    bool httpOnly = true,
    bool secure = false,
    SameSite? sameSite,
    bool partitioned = false,
    CookiePrefix prefix = CookiePrefix.none,
  }) {
    final encoded = encodeCookieJson(value);
    cookie(
      name,
      encoded,
      maxAge: maxAge,
      expires: expires,
      domain: domain,
      path: path,
      httpOnly: httpOnly,
      secure: secure,
      sameSite: sameSite,
      partitioned: partitioned,
      prefix: prefix,
    );
  }

  /// Sets a signed JSON cookie.
  ///
  /// Combines JSON encoding with HMAC-SHA256 signing.
  ///
  /// ## Example
  ///
  /// ```dart
  /// ctx.res.signedJsonCookie('session', {'userId': 123}, 'secret',
  ///   maxAge: CookieDuration.day,
  /// );
  /// ```
  void signedJsonCookie(
    String name,
    Object? value,
    String secret, {
    Duration? maxAge,
    DateTime? expires,
    String? domain,
    String? path,
    bool httpOnly = true,
    bool secure = false,
    SameSite? sameSite,
    bool partitioned = false,
    CookiePrefix prefix = CookiePrefix.none,
  }) {
    final encoded = encodeCookieJson(value);
    signedCookie(
      name,
      encoded,
      secret,
      maxAge: maxAge,
      expires: expires,
      domain: domain,
      path: path,
      httpOnly: httpOnly,
      secure: secure,
      sameSite: sameSite,
      partitioned: partitioned,
      prefix: prefix,
    );
  }

  /// Deletes a cookie by setting it to expire immediately.
  ///
  /// ## Example
  ///
  /// ```dart
  /// ctx.res.deleteCookie('session');
  /// ctx.res.deleteCookie('token', path: '/api');
  /// ```
  void deleteCookie(
    String name, {
    String? domain,
    String? path,
    bool httpOnly = true,
    bool secure = false,
    SameSite? sameSite,
  }) {
    cookie(
      name,
      '',
      domain: domain,
      path: path,
      httpOnly: httpOnly,
      secure: secure,
      sameSite: sameSite,
      maxAge: Duration.zero,
      expires: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  // ---------------------------------------------------------------------------
  // Writing Data
  // ---------------------------------------------------------------------------

  /// Writes string data to the response body.
  void write(Object? object) => _raw.write(object);

  /// Writes string data followed by a newline.
  void writeln([Object? object = '']) => _raw.writeln(object);

  /// Writes all objects from an iterable.
  void writeAll(Iterable objects, [String separator = '']) =>
      _raw.writeAll(objects, separator);

  /// Writes a character code to the response.
  void writeCharCode(int charCode) => _raw.writeCharCode(charCode);

  /// Adds binary data to the response.
  void add(List<int> data) => _raw.add(data);

  /// Adds a stream of binary data to the response.
  Future addStream(Stream<List<int>> stream) => _raw.addStream(stream);

  // ---------------------------------------------------------------------------
  // Flushing and Closing
  // ---------------------------------------------------------------------------

  /// Flushes any buffered data to the client.
  Future flush() => _raw.flush();

  /// Closes the response and sends all data to the client.
  Future close() {
    _sent = true;
    return _raw.close();
  }

  /// A future that completes when the response is finished.
  Future get done => _raw.done;

  // ---------------------------------------------------------------------------
  // Streaming Configuration
  // ---------------------------------------------------------------------------

  /// Whether to buffer output before sending.
  bool get bufferOutput => _raw.bufferOutput;
  set bufferOutput(bool value) => _raw.bufferOutput = value;

  /// Whether chunked transfer encoding is used.
  bool get chunkedTransferEncoding => _raw.headers.chunkedTransferEncoding;
  set chunkedTransferEncoding(bool value) =>
      _raw.headers.chunkedTransferEncoding = value;

  // ---------------------------------------------------------------------------
  // Connection Info
  // ---------------------------------------------------------------------------

  /// The persistent connection state.
  bool get persistentConnection => _raw.persistentConnection;
  set persistentConnection(bool value) => _raw.persistentConnection = value;

  /// Content length of the response.
  int get contentLength => _raw.contentLength;
  set contentLength(int length) => _raw.contentLength = length;

  // ---------------------------------------------------------------------------
  // Streaming
  // ---------------------------------------------------------------------------

  /// Creates a binary streaming instance for the current response.
  ///
  /// Use this for streaming binary data to the client, such as files,
  /// video, audio, or any other binary content.
  ///
  /// Example:
  /// ```dart
  /// app.get('/download', (ctx) async {
  ///   final file = File('large-file.dat');
  ///   ctx.res.headers.contentType = ContentType.binary;
  ///
  ///   final streaming = ctx.res.stream();
  ///   await streaming.pipe(file.openRead());
  ///   await streaming.done;
  /// });
  /// ```
  Streaming stream() => Streaming(_raw);

  /// Creates a text streaming instance for the current response.
  ///
  /// Use this for streaming text data to the client, such as logs,
  /// progressive HTML rendering, or NDJSON.
  ///
  /// Example:
  /// ```dart
  /// app.get('/logs', (ctx) async {
  ///   ctx.res.headers.contentType = ContentType.text;
  ///
  ///   final streaming = ctx.res.textStream();
  ///   await streaming.writeln('Log started');
  ///   await streaming.writeln('Processing...');
  ///   await streaming.writeln('Complete!');
  ///   await streaming.close();
  /// });
  /// ```
  TextStreaming textStream() => TextStreaming(_raw);

  /// Creates a Server-Sent Events (SSE) instance for the current response.
  ///
  /// SSE provides a standardized way to push updates from server to client
  /// over HTTP. Remember to set the appropriate headers before using SSE.
  ///
  /// Example:
  /// ```dart
  /// app.get('/events', (ctx) async {
  ///   ctx.res.headers.contentType = ContentType('text', 'event-stream');
  ///   ctx.res.headers.set('cache-control', 'no-cache');
  ///   ctx.res.headers.set('connection', 'keep-alive');
  ///
  ///   final sse = ctx.res.sse();
  ///   await sse.send('Hello, SSE!');
  ///   await sse.send({'type': 'notification', 'message': 'New update'});
  ///   await sse.close();
  /// });
  /// ```
  Sse sse() => Sse(_raw);

  // ---------------------------------------------------------------------------
  // Internal: For framework use only
  // ---------------------------------------------------------------------------

  /// @nodoc
  HttpResponse get $raw => _raw;
}
