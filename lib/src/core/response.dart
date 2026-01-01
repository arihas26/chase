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
  /// ```dart
  /// return Response.json({'users': []});
  /// return Response.json({'error': 'Not found'}, status: 404);
  /// ```
  static Response json(Object? data, {int status = HttpStatus.ok}) {
    return Response(
      status,
      body: data,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }

  /// Creates an HTML response with 200 OK status (default).
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
  // Redirection Responses (3xx) - returns Response directly
  // ---------------------------------------------------------------------------

  /// Creates a 301 Moved Permanently redirect.
  Response.movedPermanently(String location)
      : this(HttpStatus.movedPermanently, headers: {'location': location});

  /// Creates a 302 Found (temporary) redirect.
  Response.redirect(String location)
      : this(HttpStatus.found, headers: {'location': location});

  /// Creates a 302 Found redirect builder (alias).
  static ResponseBuilder found() => ResponseBuilder(HttpStatus.found);

  /// Creates a 303 See Other redirect.
  Response.seeOther(String location)
      : this(HttpStatus.seeOther, headers: {'location': location});

  /// Creates a 307 Temporary Redirect.
  Response.temporaryRedirect(String location)
      : this(HttpStatus.temporaryRedirect, headers: {'location': location});

  /// Creates a 308 Permanent Redirect.
  Response.permanentRedirect(String location)
      : this(HttpStatus.permanentRedirect, headers: {'location': location});

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
    } else if (body is Map || body is List) {
      if (!headers.containsKey('content-type')) {
        response.headers.contentType = ContentType.json;
      }
      final encoded = prettyJson
          ? const JsonEncoder.withIndent('  ').convert(body)
          : jsonEncode(body);
      response.write(encoded);
    } else {
      if (!headers.containsKey('content-type')) {
        response.headers.contentType = ContentType.json;
      }
      final encoded = prettyJson
          ? const JsonEncoder.withIndent('  ').convert(body)
          : jsonEncode(body);
      response.write(encoded);
    }

    await response.close();
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

  /// Adds a header to the response.
  ///
  /// ```dart
  /// return Response.created()
  ///     .header('Location', '/users/1')
  ///     .json({'id': 1});
  /// ```
  ResponseBuilder header(String name, String value) {
    return ResponseBuilder(_statusCode, {..._headers, name: value});
  }

  /// Creates a JSON response.
  ///
  /// ```dart
  /// return Response.ok().json({'message': 'Success'});
  /// return Response.notFound().json({'error': 'Not found'});
  /// ```
  Response json(Object? data) {
    return Response(
      _statusCode,
      body: data,
      headers: {..._headers, 'content-type': 'application/json; charset=utf-8'},
    );
  }

  /// Creates an HTML response.
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

  /// Creates a response with raw bytes.
  ///
  /// ```dart
  /// return Response.ok()
  ///     .header('content-type', 'image/png')
  ///     .bytes(imageData);
  /// ```
  Response bytes(List<int> data) {
    return Response(_statusCode, body: data, headers: _headers);
  }
}
