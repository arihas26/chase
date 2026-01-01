import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:chase/src/core/context/cookie.dart';
import 'package:chase/src/core/context/multipart.dart';
import 'package:chase/src/core/websocket/websocket.dart';
import 'package:chase/src/core/exception/http_exception.dart';

/// HTTP request wrapper providing convenient access to request data.
///
/// This class wraps the raw [HttpRequest] and provides:
/// - Easy access to common request properties
/// - Body parsing with caching (bytes, text, JSON, form data)
/// - Authentication helpers (Bearer token, Basic auth)
/// - Content-type detection
///
/// Example:
/// ```dart
/// app.post('/api/users', (ctx) async {
///   // Access request properties
///   print('Method: ${ctx.req.method}');
///   print('Path: ${ctx.req.path}');
///   print('IP: ${ctx.req.ip}');
///
///   // Check content type
///   if (ctx.req.isJson) {
///     final data = await ctx.req.json();
///     // ...
///   }
///
///   // Get auth token
///   final token = ctx.req.bearerToken;
/// });
/// ```
class Req {
  final HttpRequest _raw;
  final Map<String, String> _params;
  final String? _methodOverride;
  Uint8List? _cachedBytes;
  String? _cachedText;
  Object? _cachedJson;
  bool _jsonParsed = false;
  Map<String, String>? _cachedForm;
  Map<String, String>? _cachedCookies;
  MultipartBody? _cachedMultipart;

  Req(this._raw, [Map<String, String>? params, String? methodOverride])
      : _params = params ?? {},
        _methodOverride = methodOverride;

  // ---------------------------------------------------------------------------
  // Basic Request Info
  // ---------------------------------------------------------------------------

  /// HTTP method (GET, POST, PUT, DELETE, etc.)
  ///
  /// Returns the overridden method if method override is enabled,
  /// otherwise returns the original request method.
  String get method => _methodOverride ?? _raw.method;

  /// The original HTTP method before any override.
  String get rawMethod => _raw.method;

  /// Full request URI including query parameters.
  Uri get uri => _raw.uri;

  /// URL path without query string (e.g., `/users/123`).
  String get path => _raw.uri.path;

  // ---------------------------------------------------------------------------
  // URL Path Parameters
  // ---------------------------------------------------------------------------

  /// All URL path parameters as an unmodifiable map.
  ///
  /// Example:
  /// ```dart
  /// // Route: /users/:userId/posts/:postId
  /// // URL: /users/42/posts/100
  /// ctx.req.params // {'userId': '42', 'postId': '100'}
  /// ```
  Map<String, String> get params => Map.unmodifiable(_params);

  /// Gets a URL path parameter with optional type conversion.
  ///
  /// Supports `String` (default), `int`, `double`, and `bool`.
  ///
  /// Example:
  /// ```dart
  /// // Route: /users/:id
  /// ctx.req.param<int>('id')        // int?
  /// ctx.req.param<String>('name')   // String?
  /// ```
  T? param<T>(String key) {
    final value = _params[key];
    if (value == null) return null;
    return _parseValue<T>(value);
  }

  /// Gets a URL path parameter with a fallback value.
  ///
  /// Example:
  /// ```dart
  /// ctx.req.paramOr<int>('id', 0)        // int
  /// ctx.req.paramOr<String>('name', '')  // String
  /// ```
  T paramOr<T>(String key, T fallback) {
    final value = _params[key];
    if (value == null) return fallback;
    return _parseValue<T>(value) ?? fallback;
  }

  // ---------------------------------------------------------------------------
  // Host and Security
  // ---------------------------------------------------------------------------

  /// Host from the Host header (e.g., `example.com:8080`).
  String get host => _raw.headers.host ?? '';

  /// Whether the request is over HTTPS.
  bool get isSecure => _raw.requestedUri.isScheme('https');

  // ---------------------------------------------------------------------------
  // Client Info
  // ---------------------------------------------------------------------------

  /// Client IP address with X-Forwarded-For support.
  ///
  /// Returns the first IP from X-Forwarded-For header if present,
  /// otherwise returns the direct connection IP.
  String get ip {
    // Check X-Forwarded-For first (for proxied requests)
    final forwarded = header('x-forwarded-for');
    if (forwarded != null && forwarded.isNotEmpty) {
      // X-Forwarded-For can contain multiple IPs: "client, proxy1, proxy2"
      final firstIp = forwarded.split(',').first.trim();
      if (firstIp.isNotEmpty) return firstIp;
    }
    // Fall back to direct connection
    return _raw.connectionInfo?.remoteAddress.address ?? 'unknown';
  }

  /// Direct connection IP address (without proxy headers).
  String get remoteAddress =>
      _raw.connectionInfo?.remoteAddress.address ?? 'unknown';

  /// Remote port of the client connection.
  int? get remotePort => _raw.connectionInfo?.remotePort;

  /// Local port the server is listening on.
  int? get localPort => _raw.connectionInfo?.localPort;

  /// Connection information object.
  ///
  /// Provides structured access to connection details:
  /// ```dart
  /// final info = ctx.req.connInfo;
  /// print('Remote: ${info.remote.address}:${info.remote.port}');
  /// print('Local port: ${info.local.port}');
  /// print('Address type: ${info.remote.addressType}');
  /// ```
  ConnInfo get connInfo => ConnInfo._(
        remote: NetAddrInfo._(
          address: remoteAddress,
          port: remotePort,
          addressType: _detectAddressType(remoteAddress),
          transport: 'tcp',
        ),
        local: NetAddrInfo._(
          port: localPort,
          transport: 'tcp',
        ),
      );

  static AddressType? _detectAddressType(String address) {
    if (address == 'unknown') return null;
    if (address.contains(':')) return AddressType.ipv6;
    if (RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(address)) {
      return AddressType.ipv4;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Headers
  // ---------------------------------------------------------------------------

  /// Gets a single header value by name (case-insensitive).
  String? header(String name) => _raw.headers.value(name);

  /// Gets all values for a header (for multi-value headers).
  List<String> headerAll(String name) => _raw.headers[name] ?? const [];

  /// Iterates over all headers.
  void forEachHeader(void Function(String name, List<String> values) fn) {
    _raw.headers.forEach(fn);
  }

  /// Content-Type header parsed as ContentType.
  ContentType? get contentType => _raw.headers.contentType;

  /// Content-Length header value (-1 if not present).
  int get contentLength => _raw.contentLength;

  /// Accept header value.
  String? get accept => header('accept');

  /// Accept-Language header value.
  String? get acceptLanguage => header('accept-language');

  /// Accept-Encoding header value.
  String? get acceptEncoding => header('accept-encoding');

  // ---------------------------------------------------------------------------
  // Content Negotiation
  // ---------------------------------------------------------------------------

  /// Performs content negotiation for the Accept header.
  ///
  /// Returns the best match from [supported] types, or [defaultValue] if none match.
  ///
  /// ```dart
  /// final type = ctx.req.accepts(['json', 'html', 'xml'], defaultValue: 'json');
  /// if (type == 'json') {
  ///   return ctx.res.json(data);
  /// } else if (type == 'html') {
  ///   return ctx.res.html(renderHtml(data));
  /// }
  /// ```
  ///
  /// Supports shorthand types:
  /// - `'json'` → `'application/json'`
  /// - `'html'` → `'text/html'`
  /// - `'xml'` → `'application/xml'`
  /// - `'text'` → `'text/plain'`
  String accepts(List<String> supported, {required String defaultValue}) {
    return _negotiate(accept, supported, defaultValue, _expandMimeType);
  }

  /// Performs content negotiation for the Accept-Language header.
  ///
  /// ```dart
  /// final lang = ctx.req.acceptsLanguages(['en', 'ja', 'zh'], defaultValue: 'en');
  /// ```
  String acceptsLanguages(List<String> supported, {required String defaultValue}) {
    return _negotiate(acceptLanguage, supported, defaultValue);
  }

  /// Performs content negotiation for the Accept-Encoding header.
  ///
  /// ```dart
  /// final encoding = ctx.req.acceptsEncodings(['gzip', 'deflate', 'br'], defaultValue: 'identity');
  /// ```
  String acceptsEncodings(List<String> supported, {required String defaultValue}) {
    return _negotiate(acceptEncoding, supported, defaultValue);
  }

  /// Performs content negotiation for the Accept-Charset header.
  ///
  /// ```dart
  /// final charset = ctx.req.acceptsCharsets(['utf-8', 'iso-8859-1'], defaultValue: 'utf-8');
  /// ```
  String acceptsCharsets(List<String> supported, {required String defaultValue}) {
    return _negotiate(header('accept-charset'), supported, defaultValue);
  }

  String _negotiate(
    String? headerValue,
    List<String> supported,
    String defaultValue, [
    String Function(String)? expand,
  ]) {
    if (headerValue == null || headerValue.isEmpty) {
      return defaultValue;
    }

    final accepts = _parseAcceptHeader(headerValue);
    final expandedSupported = expand != null
        ? supported.map((s) => MapEntry(s, expand(s))).toList()
        : supported.map((s) => MapEntry(s, s.toLowerCase())).toList();

    for (final accept in accepts) {
      // Wildcard matches first supported
      if (accept.value == '*' || accept.value == '*/*') {
        return supported.first;
      }

      for (final entry in expandedSupported) {
        if (_matchesAccept(accept.value, entry.value)) {
          return entry.key;
        }
      }
    }

    return defaultValue;
  }

  List<({String value, double quality})> _parseAcceptHeader(String header) {
    final parts = header.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty);
    final result = <({String value, double quality})>[];

    for (final part in parts) {
      final segments = part.split(';').map((s) => s.trim()).toList();
      final value = segments.first.toLowerCase();
      var quality = 1.0;

      for (var i = 1; i < segments.length; i++) {
        if (segments[i].startsWith('q=')) {
          quality = double.tryParse(segments[i].substring(2)) ?? 1.0;
          break;
        }
      }

      result.add((value: value, quality: quality));
    }

    // Sort by quality (descending)
    result.sort((a, b) => b.quality.compareTo(a.quality));
    return result;
  }

  bool _matchesAccept(String accept, String supported) {
    if (accept == supported) return true;

    // Handle wildcards like text/* or */xml
    if (accept.contains('*')) {
      final acceptParts = accept.split('/');
      final supportedParts = supported.split('/');
      if (acceptParts.length == 2 && supportedParts.length == 2) {
        final typeMatch = acceptParts[0] == '*' || acceptParts[0] == supportedParts[0];
        final subtypeMatch = acceptParts[1] == '*' || acceptParts[1] == supportedParts[1];
        return typeMatch && subtypeMatch;
      }
    }

    return false;
  }

  static String _expandMimeType(String type) {
    return switch (type.toLowerCase()) {
      'json' => 'application/json',
      'html' => 'text/html',
      'xml' => 'application/xml',
      'text' => 'text/plain',
      'css' => 'text/css',
      'js' || 'javascript' => 'application/javascript',
      'form' => 'application/x-www-form-urlencoded',
      'multipart' => 'multipart/form-data',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'svg' => 'image/svg+xml',
      'pdf' => 'application/pdf',
      _ => type.toLowerCase(),
    };
  }

  /// User-Agent header value.
  String? get userAgent => header('user-agent');

  /// Authorization header value.
  String? get authorization => header('authorization');

  /// Referer header value.
  String? get referer => header('referer');

  /// Origin header value (for CORS).
  String? get origin => header('origin');

  /// If-None-Match header value (for ETag).
  String? get ifNoneMatch => header('if-none-match');

  /// If-Modified-Since header value.
  String? get ifModifiedSince => header('if-modified-since');

  // ---------------------------------------------------------------------------
  // Content Type Checks
  // ---------------------------------------------------------------------------

  /// Whether the request has JSON content type.
  bool get isJson {
    final ct = contentType;
    if (ct == null) return false;
    return ct.mimeType == 'application/json' || ct.subType.endsWith('+json');
  }

  /// Whether the request has form-urlencoded content type.
  bool get isForm {
    final ct = contentType;
    return ct?.mimeType == 'application/x-www-form-urlencoded';
  }

  /// Whether the request has multipart/form-data content type.
  bool get isMultipart {
    final ct = contentType;
    return ct?.mimeType == 'multipart/form-data';
  }

  /// Whether the request has text content type.
  bool get isText {
    final ct = contentType;
    if (ct == null) return false;
    return ct.primaryType == 'text' ||
        ct.mimeType == 'application/json' ||
        ct.mimeType == 'application/xml';
  }

  // ---------------------------------------------------------------------------
  // Authentication Helpers
  // ---------------------------------------------------------------------------

  /// Extracts Bearer token from Authorization header.
  ///
  /// Returns null if no Bearer token is present.
  String? get bearerToken {
    final auth = authorization;
    if (auth == null) return null;
    if (auth.toLowerCase().startsWith('bearer ')) {
      return auth.substring(7).trim();
    }
    return null;
  }

  /// Extracts Basic auth credentials from Authorization header.
  ///
  /// Returns a record with (username, password) or null if not present.
  ({String username, String password})? get basicAuth {
    final auth = authorization;
    if (auth == null) return null;
    if (!auth.toLowerCase().startsWith('basic ')) return null;
    try {
      final encoded = auth.substring(6).trim();
      final decoded = utf8.decode(base64.decode(encoded));
      final colonIndex = decoded.indexOf(':');
      if (colonIndex == -1) return null;
      return (
        username: decoded.substring(0, colonIndex),
        password: decoded.substring(colonIndex + 1),
      );
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Query Parameters
  // ---------------------------------------------------------------------------

  /// Gets a query parameter value with optional type conversion.
  ///
  /// Supports `String` (default), `int`, `double`, `bool`, and `num`.
  ///
  /// Example:
  /// ```dart
  /// ctx.req.query('name')           // String?
  /// ctx.req.query<int>('page')      // int?
  /// ctx.req.query<bool>('active')   // bool? (true: '1', 'true', 'yes')
  /// ctx.req.query<double>('price')  // double?
  /// ```
  T? query<T>(String key) {
    final value = _raw.uri.queryParameters[key];
    if (value == null) return null;
    return _parseValue<T>(value);
  }

  /// Gets a query parameter value with fallback.
  ///
  /// Example:
  /// ```dart
  /// ctx.req.queryOr('name', 'guest')     // String
  /// ctx.req.queryOr<int>('page', 1)      // int
  /// ctx.req.queryOr<bool>('active', false) // bool
  /// ```
  T queryOr<T>(String key, T fallback) {
    final value = _raw.uri.queryParameters[key];
    if (value == null) return fallback;
    return _parseValue<T>(value) ?? fallback;
  }

  /// Parses a string value to the specified type.
  ///
  /// Supported types: [String], [int], [double], [num], [bool], [dynamic], [Object].
  /// Returns `null` for unsupported types instead of throwing.
  T? _parseValue<T>(String value) {
    if (T == String) return value as T;
    if (T == int) return int.tryParse(value) as T?;
    if (T == double) return double.tryParse(value) as T?;
    if (T == num) return num.tryParse(value) as T?;
    if (T == bool) return _parseBool(value) as T?;
    // For dynamic/Object, return the string value
    if (T == dynamic || T == Object) return value as T;
    // Unsupported type - return null instead of throwing
    return null;
  }

  /// Parses a boolean string value.
  bool _parseBool(String value) {
    final v = value.toLowerCase();
    return v == 'true' || v == '1' || v == 'yes' || v == 'on';
  }

  /// Gets all values for a query parameter (for repeated params).
  List<String> queryList(String key) =>
      _raw.uri.queryParametersAll[key] ?? const [];

  /// All query parameters as a single-value map.
  Map<String, String> get queries => _raw.uri.queryParameters;

  /// All query parameters including multi-values.
  Map<String, List<String>> get queriesAll => _raw.uri.queryParametersAll;

  // ---------------------------------------------------------------------------
  // Cookies
  // ---------------------------------------------------------------------------

  /// Gets a cookie value by name.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final sessionId = ctx.req.cookie('session');
  /// ```
  String? cookie(String name) => cookies[name];

  /// Gets a signed cookie value by name, verifying its signature.
  ///
  /// Returns null if the cookie doesn't exist or if the signature is invalid.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final userId = ctx.req.signedCookie('userId', 'my-secret-key');
  /// if (userId == null) {
  ///   // Cookie missing or tampered with
  /// }
  /// ```
  String? signedCookie(String name, String secret) {
    final value = cookie(name);
    if (value == null) return null;
    return verifySignedCookieValue(value, secret);
  }

  /// Gets a JSON cookie value by name.
  ///
  /// Returns null if the cookie doesn't exist or if decoding fails.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final prefs = ctx.req.jsonCookie<Map<String, dynamic>>('prefs');
  /// if (prefs != null) {
  ///   final theme = prefs['theme'];
  /// }
  /// ```
  T? jsonCookie<T>(String name) {
    final value = cookie(name);
    if (value == null) return null;
    return decodeCookieJson<T>(value);
  }

  /// Gets a signed JSON cookie value by name.
  ///
  /// First verifies the signature, then decodes the JSON.
  /// Returns null if the cookie doesn't exist, signature is invalid, or decoding fails.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final session = ctx.req.signedJsonCookie<Map<String, dynamic>>('session', 'secret');
  /// if (session != null) {
  ///   final userId = session['userId'];
  /// }
  /// ```
  T? signedJsonCookie<T>(String name, String secret) {
    final value = signedCookie(name, secret);
    if (value == null) return null;
    return decodeCookieJson<T>(value);
  }

  /// All cookies as a map.
  Map<String, String> get cookies {
    if (_cachedCookies != null) return _cachedCookies!;
    final header = _raw.headers.value(HttpHeaders.cookieHeader);
    _cachedCookies = parseCookieHeader(header);
    return _cachedCookies!;
  }

  // ---------------------------------------------------------------------------
  // Body Reading
  // ---------------------------------------------------------------------------

  /// Raw body stream for streaming scenarios.
  ///
  /// Note: Can only be read once. Use [bytes] or [text] for cached access.
  Stream<List<int>> get bodyStream => _raw;

  /// Reads the entire body as bytes (cached).
  Future<Uint8List> bytes() async {
    if (_cachedBytes != null) return _cachedBytes!;
    final builder = BytesBuilder(copy: false);
    await for (final chunk in _raw) {
      builder.add(chunk);
    }
    _cachedBytes = builder.takeBytes();
    return _cachedBytes!;
  }

  /// Reads the entire body as UTF-8 text (cached).
  Future<String> text() async {
    if (_cachedText != null) return _cachedText!;
    final body = utf8.decode(await bytes());
    _cachedText = body;
    return _cachedText!;
  }

  /// Parses the body as JSON (cached).
  ///
  /// The result is cached, so subsequent calls return the same value
  /// without re-parsing. This works correctly even when the JSON body
  /// is `null`.
  Future<Object?> json() async {
    if (_jsonParsed) return _cachedJson;
    _jsonParsed = true;
    final body = await text();
    final decoded = jsonDecode(body);
    _cachedJson = decoded;
    return decoded;
  }

  /// Parses the body as URL-encoded form data (cached).
  Future<Map<String, String>> form() async {
    if (_cachedForm != null) return _cachedForm!;
    final body = await text();
    final params = Uri.splitQueryString(body);
    _cachedForm = params;
    return params;
  }

  /// Parses the body as URL-encoded form data with content-type validation.
  Future<Map<String, String>> formData() async {
    final ct = contentType;
    if (ct != null && ct.mimeType != 'application/x-www-form-urlencoded') {
      throw BadRequestException('Invalid Content-Type for form data.');
    }
    return form();
  }

  /// Parses the body as multipart/form-data (cached).
  Future<MultipartBody> multipart() async {
    if (_cachedMultipart != null) return _cachedMultipart!;
    final ct = contentType;
    if (ct == null || ct.mimeType != 'multipart/form-data') {
      throw BadRequestException(
          'Invalid Content-Type for multipart form data.');
    }
    final boundary = ct.parameters['boundary'];
    if (boundary == null || boundary.isEmpty) {
      throw BadRequestException('Missing multipart boundary.');
    }

    final fields = <String, List<String>>{};
    final files = <String, List<MultipartFile>>{};

    final body = await bytes();
    final boundaryBytes = ascii.encode('--$boundary');

    int indexOfBoundary(int start) {
      for (var i = start; i <= body.length - boundaryBytes.length; i++) {
        var ok = true;
        for (var j = 0; j < boundaryBytes.length; j++) {
          if (body[i + j] != boundaryBytes[j]) {
            ok = false;
            break;
          }
        }
        if (ok) return i;
      }
      return -1;
    }

    var pos = indexOfBoundary(0);
    if (pos == -1) {
      throw BadRequestException('Invalid multipart body.');
    }

    while (pos != -1) {
      pos += boundaryBytes.length;

      // Final boundary: "--"
      if (pos + 1 < body.length && body[pos] == 45 && body[pos + 1] == 45) {
        break;
      }

      // Skip leading CRLF
      if (pos + 1 < body.length && body[pos] == 13 && body[pos + 1] == 10) {
        pos += 2;
      }

      final next = indexOfBoundary(pos);
      if (next == -1) break;

      // Part bytes include trailing CRLF just before boundary.
      var partEnd = next;
      if (partEnd >= 2 && body[partEnd - 2] == 13 && body[partEnd - 1] == 10) {
        partEnd -= 2;
      }

      final part = body.sublist(pos, partEnd);
      final headerSep = _indexOfBytes(part, [13, 10, 13, 10]);
      if (headerSep == -1) {
        pos = next;
        continue;
      }

      final headerBytes = part.sublist(0, headerSep);
      final contentBytes = part.sublist(headerSep + 4);
      final headerText = ascii.decode(headerBytes);
      final headers = _parseHeaders(headerText);

      final contentDisposition = headers['content-disposition'];
      if (contentDisposition == null) {
        pos = next;
        continue;
      }

      final name = _parseContentDispositionParam(contentDisposition, 'name');
      if (name == null || name.isEmpty) {
        pos = next;
        continue;
      }

      final filename =
          _parseContentDispositionParam(contentDisposition, 'filename');
      final partCt = headers['content-type'];
      final partContentType = partCt == null ? null : ContentType.parse(partCt);

      if (filename != null && filename.isNotEmpty) {
        files.putIfAbsent(name, () => []).add(MultipartFile(
          filename: filename,
          bytes: Uint8List.fromList(contentBytes),
          contentType: partContentType,
        ));
      } else {
        fields.putIfAbsent(name, () => []).add(utf8.decode(contentBytes));
      }

      pos = next;
    }

    _cachedMultipart = MultipartBody(fields: fields, files: files);
    return _cachedMultipart!;
  }

  // ---------------------------------------------------------------------------
  // Internal: For framework use only
  // ---------------------------------------------------------------------------

  /// @nodoc
  /// Internal access to raw HttpRequest.
  /// This should not be used by application code.
  HttpRequest get $raw => _raw;

  // ---------------------------------------------------------------------------
  // WebSocket
  // ---------------------------------------------------------------------------

  /// Upgrades the HTTP connection to a WebSocket connection.
  ///
  /// This method performs the WebSocket handshake and returns a [ChaseWebSocket]
  /// instance for bidirectional communication.
  ///
  /// ## Example
  ///
  /// ```dart
  /// app.get('/ws', (ctx) async {
  ///   final ws = await ctx.req.upgrade();
  ///   ws.onMessage((msg) => ws.send('Echo: $msg'));
  /// });
  /// ```
  ///
  /// Throws [WebSocketException] if the upgrade fails.
  Future<ChaseWebSocket> upgrade() async {
    final socket = await WebSocketTransformer.upgrade(_raw);
    return ChaseWebSocket(socket);
  }

  // ---------------------------------------------------------------------------
  // Private Helpers
  // ---------------------------------------------------------------------------

  int _indexOfBytes(List<int> haystack, List<int> needle) {
    if (needle.isEmpty) return 0;
    for (var i = 0; i <= haystack.length - needle.length; i++) {
      var ok = true;
      for (var j = 0; j < needle.length; j++) {
        if (haystack[i + j] != needle[j]) {
          ok = false;
          break;
        }
      }
      if (ok) return i;
    }
    return -1;
  }

  Map<String, String> _parseHeaders(String rawHeaders) {
    final map = <String, String>{};
    for (final line in rawHeaders.split('\r\n')) {
      final index = line.indexOf(':');
      if (index <= 0) continue;
      final name = line.substring(0, index).trim().toLowerCase();
      final value = line.substring(index + 1).trim();
      map[name] = value;
    }
    return map;
  }

  String? _parseContentDispositionParam(String header, String key) {
    final match = RegExp(
      '(?:^|;)\\s*$key="?([^";]+)"?',
      caseSensitive: false,
    ).firstMatch(header);
    return match?.group(1);
  }
}

// =============================================================================
// Connection Info
// =============================================================================

/// Connection information for the current request.
///
/// Provides structured access to remote and local connection details.
///
/// ```dart
/// final info = ctx.req.connInfo;
/// print('Client: ${info.remote.address}:${info.remote.port}');
/// print('Server port: ${info.local.port}');
/// ```
class ConnInfo {
  /// Remote (client) connection information.
  final NetAddrInfo remote;

  /// Local (server) connection information.
  final NetAddrInfo local;

  const ConnInfo._({required this.remote, required this.local});

  @override
  String toString() => 'ConnInfo(remote: $remote, local: $local)';
}

/// Network address information.
///
/// Contains details about a network endpoint.
class NetAddrInfo {
  /// IP address or hostname.
  final String? address;

  /// Port number.
  final int? port;

  /// Address type (IPv4, IPv6, or unknown).
  final AddressType? addressType;

  /// Transport protocol (tcp or udp).
  final String? transport;

  const NetAddrInfo._({
    this.address,
    this.port,
    this.addressType,
    this.transport,
  });

  @override
  String toString() =>
      'NetAddrInfo(address: $address, port: $port, type: $addressType)';
}

/// IP address type.
enum AddressType {
  /// IPv4 address (e.g., 192.168.1.1)
  ipv4,

  /// IPv6 address (e.g., ::1, 2001:db8::1)
  ipv6,
}
