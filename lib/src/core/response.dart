import 'dart:convert';
import 'dart:io';

/// An immutable HTTP response object.
///
/// This class provides a functional, declarative way to create responses.
/// Handlers return a [Response] using top-level helper functions or
/// the fluent builder API.
///
/// ## Simple responses (top-level functions)
///
/// ```dart
/// app.get('/users').handle((ctx) {
///   return json({'users': []});
/// });
///
/// app.get('/').handle((ctx) {
///   return html('<h1>Welcome</h1>');
/// });
/// ```
///
/// ## Responses with status codes (fluent API)
///
/// ```dart
/// app.post('/users').handle((ctx) async {
///   final user = await createUser();
///   return Response.created()
///     .header('Location', '/users/${user.id}')
///     .json(user);
/// });
///
/// app.get('/users/:id').handle((ctx) {
///   final user = findUser(ctx.req.param('id'));
///   if (user == null) {
///     return Response.notFound().json({'error': 'User not found'});
///   }
///   return json(user);
/// });
/// ```
class Response {
  /// The HTTP status code.
  final int statusCode;

  /// The response body.
  ///
  /// Can be:
  /// - [String] for text/plain or text/html
  /// - [Map] or [List] for application/json
  /// - [List<int>] for binary data
  /// - `null` for no body
  final Object? body;

  /// The response headers.
  final Map<String, String> headers;

  /// Creates a new response.
  const Response(this.statusCode, {this.body, this.headers = const {}});

  // ---------------------------------------------------------------------------
  // Status Code Constructors (for fluent chaining)
  // ---------------------------------------------------------------------------

  /// Creates a response with the given status code.
  ///
  /// ```dart
  /// return Response.status(418).json({'error': "I'm a teapot"});
  /// ```
  const Response.status(int code, {Map<String, String> headers = const {}})
      : this(code, headers: headers);

  /// Creates a 200 OK response.
  const Response.ok({Map<String, String> headers = const {}})
      : this(HttpStatus.ok, headers: headers);

  /// Creates a 201 Created response.
  ///
  /// ```dart
  /// return Response.created()
  ///   .header('Location', '/users/123')
  ///   .json({'id': 123});
  /// ```
  const Response.created({Map<String, String> headers = const {}})
      : this(HttpStatus.created, headers: headers);

  /// Creates a 202 Accepted response.
  const Response.accepted({Map<String, String> headers = const {}})
      : this(HttpStatus.accepted, headers: headers);

  /// Creates a 204 No Content response.
  const Response.noContent({Map<String, String> headers = const {}})
      : this(HttpStatus.noContent, headers: headers);

  // ---------------------------------------------------------------------------
  // Redirection Responses (3xx)
  // ---------------------------------------------------------------------------

  /// Creates a 301 Moved Permanently redirect.
  Response.movedPermanently(String location)
      : this(HttpStatus.movedPermanently, headers: {'location': location});

  /// Creates a 302 Found (temporary) redirect.
  Response.redirect(String location)
      : this(HttpStatus.found, headers: {'location': location});

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
  // Client Error Responses (4xx)
  // ---------------------------------------------------------------------------

  /// Creates a 400 Bad Request response.
  const Response.badRequest({Map<String, String> headers = const {}})
      : this(HttpStatus.badRequest, headers: headers);

  /// Creates a 401 Unauthorized response.
  const Response.unauthorized({Map<String, String> headers = const {}})
      : this(HttpStatus.unauthorized, headers: headers);

  /// Creates a 403 Forbidden response.
  const Response.forbidden({Map<String, String> headers = const {}})
      : this(HttpStatus.forbidden, headers: headers);

  /// Creates a 404 Not Found response.
  const Response.notFound({Map<String, String> headers = const {}})
      : this(HttpStatus.notFound, headers: headers);

  /// Creates a 405 Method Not Allowed response.
  const Response.methodNotAllowed({Map<String, String> headers = const {}})
      : this(HttpStatus.methodNotAllowed, headers: headers);

  /// Creates a 409 Conflict response.
  const Response.conflict({Map<String, String> headers = const {}})
      : this(HttpStatus.conflict, headers: headers);

  /// Creates a 422 Unprocessable Entity response.
  const Response.unprocessableEntity({Map<String, String> headers = const {}})
      : this(HttpStatus.unprocessableEntity, headers: headers);

  /// Creates a 429 Too Many Requests response.
  const Response.tooManyRequests({Map<String, String> headers = const {}})
      : this(HttpStatus.tooManyRequests, headers: headers);

  // ---------------------------------------------------------------------------
  // Server Error Responses (5xx)
  // ---------------------------------------------------------------------------

  /// Creates a 500 Internal Server Error response.
  const Response.internalServerError({Map<String, String> headers = const {}})
      : this(HttpStatus.internalServerError, headers: headers);

  /// Creates a 502 Bad Gateway response.
  const Response.badGateway({Map<String, String> headers = const {}})
      : this(HttpStatus.badGateway, headers: headers);

  /// Creates a 503 Service Unavailable response.
  const Response.serviceUnavailable({Map<String, String> headers = const {}})
      : this(HttpStatus.serviceUnavailable, headers: headers);

  /// Creates a 504 Gateway Timeout response.
  const Response.gatewayTimeout({Map<String, String> headers = const {}})
      : this(HttpStatus.gatewayTimeout, headers: headers);

  // ---------------------------------------------------------------------------
  // Fluent Builder Methods
  // ---------------------------------------------------------------------------

  /// Adds a header to the response.
  ///
  /// ```dart
  /// return Response.created()
  ///   .header('Location', '/users/123')
  ///   .header('X-Request-Id', requestId)
  ///   .json({'id': 123});
  /// ```
  Response header(String name, String value) {
    return Response(
      statusCode,
      body: body,
      headers: {...headers, name: value},
    );
  }

  /// Sets the response body as JSON.
  ///
  /// ```dart
  /// return Response.ok().json({'message': 'Success'});
  /// return Response.created().json({'id': 1});
  /// return Response.notFound().json({'error': 'Not found'});
  /// ```
  Response json(Object? data) {
    return Response(
      statusCode,
      body: data,
      headers: {...headers, 'content-type': 'application/json; charset=utf-8'},
    );
  }

  /// Sets the response body as HTML.
  ///
  /// ```dart
  /// return Response.ok().html('<h1>Hello</h1>');
  /// ```
  Response html(String content) {
    return Response(
      statusCode,
      body: content,
      headers: {...headers, 'content-type': 'text/html; charset=utf-8'},
    );
  }

  /// Sets the response body as plain text.
  ///
  /// ```dart
  /// return Response.ok().text('Hello, World!');
  /// ```
  Response text(String content) {
    return Response(
      statusCode,
      body: content,
      headers: {...headers, 'content-type': 'text/plain; charset=utf-8'},
    );
  }

  /// Sets the response body as raw bytes.
  ///
  /// ```dart
  /// return Response.ok()
  ///   .header('content-type', 'image/png')
  ///   .bytes(imageData);
  /// ```
  Response bytes(List<int> data) {
    return Response(
      statusCode,
      body: data,
      headers: headers,
    );
  }

  // ---------------------------------------------------------------------------
  // Write to HttpResponse
  // ---------------------------------------------------------------------------

  /// Writes this response to an [HttpResponse].
  ///
  /// This method is called internally by Chase to send the response.
  /// If [prettyJson] is true, JSON output will be formatted with indentation.
  Future<void> writeTo(HttpResponse response, {bool prettyJson = false}) async {
    // Set status code
    response.statusCode = statusCode;

    // Set headers
    for (final entry in headers.entries) {
      response.headers.set(entry.key, entry.value);
    }

    // Write body
    if (body == null) {
      await response.close();
      return;
    }

    if (body is String) {
      // Text body
      if (!headers.containsKey('content-type')) {
        response.headers.contentType = ContentType.text;
      }
      response.write(body);
    } else if (body is List<int>) {
      response.add(body as List<int>);
    } else if (body is Map || body is List) {
      // JSON body
      if (!headers.containsKey('content-type')) {
        response.headers.contentType = ContentType.json;
      }
      final encoded = prettyJson
          ? const JsonEncoder.withIndent('  ').convert(body)
          : jsonEncode(body);
      response.write(encoded);
    } else {
      // Objects with toJson() will be serialized
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

