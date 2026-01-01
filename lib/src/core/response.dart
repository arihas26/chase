import 'dart:convert';
import 'dart:io';

/// An immutable HTTP response object.
///
/// Use static factory methods for common responses:
///
/// ```dart
/// // Simple responses
/// return Response.json({'users': []});
/// return Response.html('<h1>Welcome</h1>');
/// return Response.text('OK');
///
/// // With custom status
/// return Response.json({'error': 'Not found'}, status: 404);
///
/// // Add headers to any response
/// return Response.json({'data': 1}).header('X-Custom', 'value');
/// ```
///
/// Use builder pattern for more control:
///
/// ```dart
/// return Response.created()
///     .header('Location', '/users/1')
///     .json({'id': 1});
///
/// return Response.notFound().json({'error': 'User not found'});
/// ```
///
/// ## Security Notes
///
/// - **XSS**: `Response.html()` does NOT escape content. Always sanitize
///   user input before including it in HTML responses.
/// - **Open Redirect**: Validate redirect URLs before using `Response.redirect()`.
///   Consider allowing only relative URLs or whitelisted domains.
class Response {
  /// The HTTP status code.
  final int statusCode;

  /// The response body.
  final Object? body;

  /// The response headers.
  final Map<String, String> headers;

  /// Creates a new response.
  const Response(this.statusCode, {this.body, this.headers = const {}});

  // ---------------------------------------------------------------------------
  // Static Factory Methods (shorthand for 200 OK)
  // ---------------------------------------------------------------------------

  /// Creates a JSON response with 200 OK status (default).
  ///
  /// By default, adds `X-Content-Type-Options: nosniff` to prevent MIME sniffing.
  ///
  /// ```dart
  /// return Response.json({'users': []});
  /// return Response.json({'error': 'Not found'}, status: 404);
  /// ```
  ///
  /// Throws [JsonEncodingError] if the data cannot be serialized to JSON.
  static Response json(Object? data, {int status = HttpStatus.ok}) {
    return Response(
      status,
      body: data,
      headers: {
        'content-type': 'application/json; charset=utf-8',
        'x-content-type-options': 'nosniff',
      },
    );
  }

  /// Creates an HTML response with 200 OK status (default).
  ///
  /// **Security Warning**: This method does NOT escape the content.
  /// Always sanitize user input before including it in HTML to prevent XSS.
  /// For user input, use [htmlEscaped] instead.
  ///
  /// ```dart
  /// return Response.html('<h1>Welcome</h1>');
  /// ```
  static Response html(String content, {int status = HttpStatus.ok}) {
    return Response(
      status,
      body: content,
      headers: {'content-type': 'text/html; charset=utf-8'},
    );
  }

  /// Creates an HTML response with escaped content to prevent XSS.
  ///
  /// Use this for displaying user input safely. The content is escaped
  /// using [HtmlEscape] from `dart:convert`.
  ///
  /// ```dart
  /// // Safe: user input is escaped
  /// return Response.htmlEscaped(userInput);
  /// // <script>alert("XSS")</script> → &lt;script&gt;alert(&quot;XSS&quot;)&lt;/script&gt;
  /// ```
  static Response htmlEscaped(String content, {int status = HttpStatus.ok}) {
    return Response(
      status,
      body: const HtmlEscape().convert(content),
      headers: {'content-type': 'text/html; charset=utf-8'},
    );
  }

  /// Creates a plain text response with 200 OK status (default).
  ///
  /// ```dart
  /// return Response.text('OK');
  /// ```
  static Response text(String content, {int status = HttpStatus.ok}) {
    return Response(
      status,
      body: content,
      headers: {'content-type': 'text/plain; charset=utf-8'},
    );
  }

  // ---------------------------------------------------------------------------
  // Builder Factory Methods (returns ResponseBuilder for chaining)
  // ---------------------------------------------------------------------------

  /// Creates a builder with the given status code.
  ///
  /// ```dart
  /// return Response.status(418).json({'error': "I'm a teapot"});
  /// ```
  static ResponseBuilder status(int code) => ResponseBuilder(code);

  /// Creates a 200 OK response builder with a header.
  ///
  /// Shortcut for `Response.ok().header(name, value)`.
  ///
  /// ```dart
  /// return Response.header('X-Custom', 'value').json({'data': 1});
  /// ```
  static ResponseBuilder header(String name, String value) {
    return ResponseBuilder(HttpStatus.ok, {
      _sanitizeHeaderName(name): _sanitizeHeaderValue(value),
    });
  }

  /// Creates a 200 OK response builder.
  static ResponseBuilder ok() => ResponseBuilder(HttpStatus.ok);

  /// Creates a 201 Created response builder.
  ///
  /// ```dart
  /// return Response.created()
  ///     .header('Location', '/users/1')
  ///     .json({'id': 1});
  /// ```
  static ResponseBuilder created() => ResponseBuilder(HttpStatus.created);

  /// Creates a 202 Accepted response builder.
  static ResponseBuilder accepted() => ResponseBuilder(HttpStatus.accepted);

  /// Creates a 204 No Content response.
  static Response noContent() => const Response(HttpStatus.noContent);

  // ---------------------------------------------------------------------------
  // Redirection Responses (3xx)
  // ---------------------------------------------------------------------------

  /// Creates a 304 Not Modified response.
  ///
  /// Used for cache validation. Should not contain a body.
  ///
  /// ```dart
  /// if (request.headers['if-none-match'] == etag) {
  ///   return Response.notModified();
  /// }
  /// ```
  static Response notModified() => const Response(HttpStatus.notModified);

  /// Creates a safe redirect that only allows relative URLs.
  ///
  /// This prevents open redirect vulnerabilities by rejecting:
  /// - Absolute URLs (http://, https://, //)
  /// - javascript: and data: URLs
  /// - URLs with encoded characters that could bypass validation
  ///
  /// Throws [ArgumentError] if the URL is not a safe relative path.
  ///
  /// ```dart
  /// return Response.safeRedirect('/dashboard');  // OK
  /// return Response.safeRedirect('https://evil.com');  // Throws!
  /// ```
  static Response safeRedirect(
    String location, {
    int status = HttpStatus.found,
  }) {
    if (!_isRelativeUrl(location)) {
      throw ArgumentError.value(
        location,
        'location',
        'Only relative URLs are allowed. Use redirect() for absolute URLs.',
      );
    }
    return Response(
      status,
      headers: {'location': _sanitizeHeaderValue(location)},
    );
  }

  /// Checks if a URL is a safe relative path.
  static bool _isRelativeUrl(String url) {
    // Reject empty or whitespace-only
    if (url.trim().isEmpty) return false;

    // Decode and check again to prevent encoded bypass attacks
    final decoded = Uri.decodeFull(url).toLowerCase();

    // Reject absolute URLs
    if (decoded.startsWith('http://') ||
        decoded.startsWith('https://') ||
        decoded.startsWith('//')) {
      return false;
    }

    // Reject dangerous schemes
    if (decoded.startsWith('javascript:') ||
        decoded.startsWith('data:') ||
        decoded.startsWith('vbscript:')) {
      return false;
    }

    // Must start with / or be a relative path
    return url.startsWith('/') || !url.contains(':');
  }

  /// Creates a 301 Moved Permanently redirect.
  ///
  /// **Security Warning**: Validate the location URL to prevent open redirect
  /// vulnerabilities. Consider allowing only relative URLs or whitelisted domains.
  ///
  /// ```dart
  /// return Response.movedPermanently('/new-path');
  /// ```
  static Response movedPermanently(String location) => Response(
    HttpStatus.movedPermanently,
    headers: {'location': _sanitizeHeaderValue(location)},
  );

  /// Creates a 302 Found (temporary) redirect.
  ///
  /// **Security Warning**: Validate the location URL to prevent open redirect
  /// vulnerabilities.
  ///
  /// ```dart
  /// return Response.redirect('/login');
  /// ```
  static Response redirect(String location) => Response(
    HttpStatus.found,
    headers: {'location': _sanitizeHeaderValue(location)},
  );

  /// Creates a 303 See Other redirect.
  static Response seeOther(String location) => Response(
    HttpStatus.seeOther,
    headers: {'location': _sanitizeHeaderValue(location)},
  );

  /// Creates a 307 Temporary Redirect.
  static Response temporaryRedirect(String location) => Response(
    HttpStatus.temporaryRedirect,
    headers: {'location': _sanitizeHeaderValue(location)},
  );

  /// Creates a 308 Permanent Redirect.
  static Response permanentRedirect(String location) => Response(
    HttpStatus.permanentRedirect,
    headers: {'location': _sanitizeHeaderValue(location)},
  );

  // ---------------------------------------------------------------------------
  // Client Error Response Builders (4xx)
  // ---------------------------------------------------------------------------

  /// Creates a 400 Bad Request response builder.
  static ResponseBuilder badRequest() => ResponseBuilder(HttpStatus.badRequest);

  /// Creates a 401 Unauthorized response builder.
  static ResponseBuilder unauthorized() =>
      ResponseBuilder(HttpStatus.unauthorized);

  /// Creates a 403 Forbidden response builder.
  static ResponseBuilder forbidden() => ResponseBuilder(HttpStatus.forbidden);

  /// Creates a 404 Not Found response builder.
  static ResponseBuilder notFound() => ResponseBuilder(HttpStatus.notFound);

  /// Creates a 405 Method Not Allowed response builder.
  static ResponseBuilder methodNotAllowed() =>
      ResponseBuilder(HttpStatus.methodNotAllowed);

  /// Creates a 409 Conflict response builder.
  static ResponseBuilder conflict() => ResponseBuilder(HttpStatus.conflict);

  /// Creates a 422 Unprocessable Entity response builder.
  static ResponseBuilder unprocessableEntity() =>
      ResponseBuilder(HttpStatus.unprocessableEntity);

  /// Creates a 429 Too Many Requests response builder.
  static ResponseBuilder tooManyRequests() =>
      ResponseBuilder(HttpStatus.tooManyRequests);

  // ---------------------------------------------------------------------------
  // Server Error Response Builders (5xx)
  // ---------------------------------------------------------------------------

  /// Creates a 500 Internal Server Error response builder.
  static ResponseBuilder internalServerError() =>
      ResponseBuilder(HttpStatus.internalServerError);

  /// Creates a 502 Bad Gateway response builder.
  static ResponseBuilder badGateway() => ResponseBuilder(HttpStatus.badGateway);

  /// Creates a 503 Service Unavailable response builder.
  static ResponseBuilder serviceUnavailable() =>
      ResponseBuilder(HttpStatus.serviceUnavailable);

  /// Creates a 504 Gateway Timeout response builder.
  static ResponseBuilder gatewayTimeout() =>
      ResponseBuilder(HttpStatus.gatewayTimeout);

  // ---------------------------------------------------------------------------
  // Write to HttpResponse
  // ---------------------------------------------------------------------------

  /// Writes this response to an [HttpResponse].
  Future<void> writeTo(HttpResponse response, {bool prettyJson = false}) async {
    response.statusCode = statusCode;

    for (final entry in headers.entries) {
      response.headers.set(entry.key, entry.value);
    }

    if (body == null) {
      await response.close();
      return;
    }

    if (body is String) {
      if (!headers.containsKey('content-type')) {
        response.headers.contentType = ContentType.text;
      }
      response.write(body);
    } else if (body is List<int>) {
      response.add(body as List<int>);
    } else if (body is _JsonSecureWrapper) {
      // XSSI-protected JSON
      response.write(_JsonSecureWrapper.prefix);
      _writeJson(response, (body as _JsonSecureWrapper).data, prettyJson);
    } else {
      // Map, List, or any other object - encode as JSON
      if (!headers.containsKey('content-type')) {
        response.headers.contentType = ContentType.json;
      }
      _writeJson(response, body, prettyJson);
    }

    await response.close();
  }

  /// Encodes and writes JSON to the response.
  static void _writeJson(HttpResponse response, Object? body, bool prettyJson) {
    try {
      final encoded = prettyJson
          ? const JsonEncoder.withIndent('  ').convert(body)
          : jsonEncode(body);
      response.write(encoded);
    } on JsonUnsupportedObjectError catch (e) {
      throw JsonEncodingError('Failed to encode response body: $e');
    }
  }

  /// Sanitizes header values to prevent CRLF injection.
  static String _sanitizeHeaderValue(String value) {
    return value.replaceAll(RegExp(r'[\r\n]'), '');
  }

  /// Sanitizes header names to prevent injection attacks.
  /// Header names must be valid HTTP token characters.
  static String _sanitizeHeaderName(String name) {
    // Remove CRLF, colons, and other invalid characters
    return name.replaceAll(RegExp(r'[\r\n:]'), '');
  }
}

// =============================================================================
// ResponseBuilder - Fluent API for building responses
// =============================================================================

/// A builder for creating [Response] objects with fluent API.
///
/// ```dart
/// return Response.created()
///     .header('Location', '/users/1')
///     .header('X-Request-Id', requestId)
///     .json({'id': 1});
/// ```
class ResponseBuilder {
  final int _statusCode;
  final Map<String, String> _headers;

  /// Creates a new response builder with the given status code.
  const ResponseBuilder(this._statusCode, [this._headers = const {}]);

  /// Sets the status code of the response.
  ResponseBuilder status(int code) => ResponseBuilder(code, _headers);

  /// Adds a header to the response.
  ///
  /// ```dart
  /// return Response.created()
  ///     .header('Location', '/users/1')
  ///     .json({'id': 1});
  /// ```
  ResponseBuilder header(String name, String value) {
    return ResponseBuilder(_statusCode, {
      ..._headers,
      Response._sanitizeHeaderName(name): Response._sanitizeHeaderValue(value),
    });
  }

  /// Adds multiple headers at once.
  ///
  /// ```dart
  /// return Response.ok()
  ///     .headers({'X-Request-Id': '123', 'X-Custom': 'value'})
  ///     .json({'data': 1});
  /// ```
  ResponseBuilder headers(Map<String, String> headers) {
    final sanitized = headers.map(
      (key, value) => MapEntry(
        Response._sanitizeHeaderName(key),
        Response._sanitizeHeaderValue(value),
      ),
    );
    return ResponseBuilder(_statusCode, {..._headers, ...sanitized});
  }

  /// Creates a JSON response.
  ///
  /// By default, adds `X-Content-Type-Options: nosniff` to prevent MIME sniffing.
  ///
  /// ```dart
  /// return Response.ok().json({'message': 'Success'});
  /// return Response.notFound().json({'error': 'Not found'});
  /// ```
  Response json(Object? data) {
    return Response(
      _statusCode,
      body: data,
      headers: {
        ..._headers,
        'content-type': 'application/json; charset=utf-8',
        'x-content-type-options': 'nosniff',
      },
    );
  }

  /// Creates a JSON response with XSSI (Cross-Site Script Inclusion) protection.
  ///
  /// Prepends `)]}',\n` to the response to prevent JSON hijacking via script tags.
  /// The client must strip this prefix before parsing.
  ///
  /// ```dart
  /// return Response.ok().jsonSecure({'sensitive': 'data'});
  /// // Response body: )]}',\n{"sensitive":"data"}
  /// ```
  Response jsonSecure(Object? data) {
    return Response(
      _statusCode,
      body: _JsonSecureWrapper(data),
      headers: {
        ..._headers,
        'content-type': 'application/json; charset=utf-8',
        'x-content-type-options': 'nosniff',
      },
    );
  }

  /// Creates an HTML response.
  ///
  /// **Security Warning**: This method does NOT escape the content.
  /// Always sanitize user input before including it in HTML to prevent XSS.
  /// For user input, use [htmlEscaped] instead.
  ///
  /// ```dart
  /// return Response.ok().html('<h1>Hello</h1>');
  /// ```
  Response html(String content) {
    return Response(
      _statusCode,
      body: content,
      headers: {..._headers, 'content-type': 'text/html; charset=utf-8'},
    );
  }

  /// Creates an HTML response with escaped content to prevent XSS.
  ///
  /// ```dart
  /// return Response.ok().htmlEscaped(userInput);
  /// ```
  Response htmlEscaped(String content) {
    return Response(
      _statusCode,
      body: const HtmlEscape().convert(content),
      headers: {..._headers, 'content-type': 'text/html; charset=utf-8'},
    );
  }

  /// Creates a plain text response.
  ///
  /// ```dart
  /// return Response.ok().text('Hello, World!');
  /// ```
  Response text(String content) {
    return Response(
      _statusCode,
      body: content,
      headers: {..._headers, 'content-type': 'text/plain; charset=utf-8'},
    );
  }

  // ---------------------------------------------------------------------------
  // Security Headers
  // ---------------------------------------------------------------------------

  /// Adds common security headers to prevent common attacks.
  ///
  /// Includes:
  /// - `X-Content-Type-Options: nosniff` - Prevents MIME sniffing
  /// - `X-Frame-Options: DENY` - Prevents clickjacking
  /// - `X-XSS-Protection: 1; mode=block` - Legacy XSS filter
  /// - `Referrer-Policy: strict-origin-when-cross-origin`
  ///
  /// ```dart
  /// return Response.ok().secure().json({'data': 1});
  /// ```
  ResponseBuilder secure() {
    return ResponseBuilder(_statusCode, {
      ..._headers,
      'x-content-type-options': 'nosniff',
      'x-frame-options': 'DENY',
      'x-xss-protection': '1; mode=block',
      'referrer-policy': 'strict-origin-when-cross-origin',
    });
  }

  /// Adds X-Content-Type-Options: nosniff header.
  ///
  /// Prevents browsers from MIME-sniffing the content type.
  ResponseBuilder noSniff() {
    return header('x-content-type-options', 'nosniff');
  }

  /// Adds X-Frame-Options header to prevent clickjacking.
  ///
  /// - `deny`: Page cannot be displayed in a frame
  /// - `sameorigin`: Page can only be displayed in a frame on the same origin
  ResponseBuilder frameOptions([String value = 'DENY']) {
    return header('x-frame-options', value);
  }

  /// Adds Content-Security-Policy header.
  ///
  /// ```dart
  /// return Response.ok()
  ///     .csp("default-src 'self'; script-src 'self'")
  ///     .html(content);
  /// ```
  ResponseBuilder csp(String policy) {
    return header('content-security-policy', policy);
  }

  /// Adds Strict-Transport-Security (HSTS) header.
  ///
  /// Forces HTTPS for the specified duration.
  ///
  /// ```dart
  /// return Response.ok()
  ///     .hsts(maxAge: Duration(days: 365), includeSubdomains: true)
  ///     .json({'data': 1});
  /// ```
  ResponseBuilder hsts({
    Duration maxAge = const Duration(days: 365),
    bool includeSubdomains = false,
    bool preload = false,
  }) {
    var value = 'max-age=${maxAge.inSeconds}';
    if (includeSubdomains) value += '; includeSubDomains';
    if (preload) value += '; preload';
    return header('strict-transport-security', value);
  }

  /// Adds Cache-Control header to prevent caching of sensitive data.
  ///
  /// ```dart
  /// return Response.ok().noCache().json({'sensitive': 'data'});
  /// ```
  ResponseBuilder noCache() {
    return header(
      'cache-control',
      'no-store, no-cache, must-revalidate, private',
    );
  }

  // ---------------------------------------------------------------------------
  // Response Body Methods
  // ---------------------------------------------------------------------------

  /// Creates a response with raw bytes.
  ///
  /// ```dart
  /// return Response.ok().bytes(imageData, contentType: 'image/png');
  /// return Response.ok().bytes(pdfData); // defaults to application/octet-stream
  /// ```
  Response bytes(
    List<int> data, {
    String contentType = 'application/octet-stream',
  }) {
    return Response(
      _statusCode,
      body: data,
      headers: {..._headers, 'content-type': contentType},
    );
  }

  /// Creates a file download response.
  ///
  /// Sets appropriate headers for browser file download.
  ///
  /// ```dart
  /// return Response.ok().download(pdfBytes, 'report.pdf');
  /// return Response.ok().download(imageBytes, 'photo.png', contentType: 'image/png');
  /// ```
  Response download(
    List<int> data,
    String filename, {
    String contentType = 'application/octet-stream',
  }) {
    final sanitizedFilename = filename.replaceAll('"', '\\"');
    return Response(
      _statusCode,
      body: data,
      headers: {
        ..._headers,
        'content-type': contentType,
        'content-disposition': 'attachment; filename="$sanitizedFilename"',
      },
    );
  }
}

// =============================================================================
// Exceptions
// =============================================================================

/// Thrown when JSON encoding fails.
class JsonEncodingError implements Exception {
  final String message;
  JsonEncodingError(this.message);

  @override
  String toString() => 'JsonEncodingError: $message';
}

/// Wrapper for JSON data with XSSI protection prefix.
class _JsonSecureWrapper {
  static const prefix = ")]}',\n";
  final Object? data;
  const _JsonSecureWrapper(this.data);
}
