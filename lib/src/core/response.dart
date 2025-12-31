import 'dart:convert';
import 'dart:io';

/// An immutable HTTP response object.
///
/// This class provides a functional, declarative way to create responses.
/// Handlers can return a [Response] instead of using [Context.res] methods.
///
/// ## Example
///
/// ```dart
/// app.get('/users/:id').handle((ctx) {
///   final id = ctx.req.params['id'];
///   return Response.ok({'id': id, 'name': 'John'});
/// });
///
/// app.post('/users').handle((ctx) async {
///   final body = await ctx.req.json();
///   return Response.created({'id': 1, ...body});
/// });
/// ```
///
/// ## See also
///
/// * [Context.res], for the imperative response API.
class Response {
  /// The HTTP status code.
  final int statusCode;

  /// The response body.
  ///
  /// Can be:
  /// - [String] for text/plain
  /// - [Map] or [List] for application/json
  /// - [List<int>] for binary data
  /// - `null` for no body
  final Object? body;

  /// The response headers.
  final Map<String, String> headers;

  /// Creates a new response.
  const Response(this.statusCode, {this.body, this.headers = const {}});

  // ---------------------------------------------------------------------------
  // Success Responses (2xx)
  // ---------------------------------------------------------------------------

  /// Creates a 200 OK response.
  ///
  /// ```dart
  /// return Response.ok('Hello, World!');
  /// return Response.ok({'message': 'Success'});
  /// ```
  const Response.ok([Object? body, Map<String, String> headers = const {}])
    : this(HttpStatus.ok, body: body, headers: headers);

  /// Creates a 201 Created response.
  ///
  /// ```dart
  /// return Response.created({'id': 1, 'name': 'New Item'});
  /// ```
  const Response.created([Object? body, Map<String, String> headers = const {}])
    : this(HttpStatus.created, body: body, headers: headers);

  /// Creates a 204 No Content response.
  ///
  /// ```dart
  /// return Response.noContent();
  /// ```
  const Response.noContent([Map<String, String> headers = const {}])
    : this(HttpStatus.noContent, headers: headers);

  /// Creates a 202 Accepted response.
  const Response.accepted([
    Object? body,
    Map<String, String> headers = const {},
  ]) : this(HttpStatus.accepted, body: body, headers: headers);

  // ---------------------------------------------------------------------------
  // Redirection Responses (3xx)
  // ---------------------------------------------------------------------------

  /// Creates a 301 Moved Permanently redirect.
  Response.movedPermanently(String location)
    : this(HttpStatus.movedPermanently, headers: {'location': location});

  /// Creates a 302 Found redirect.
  Response.found(String location)
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
  ///
  /// ```dart
  /// return Response.badRequest({'error': 'Invalid input'});
  /// ```
  const Response.badRequest([
    Object? body,
    Map<String, String> headers = const {},
  ]) : this(HttpStatus.badRequest, body: body, headers: headers);

  /// Creates a 401 Unauthorized response.
  ///
  /// ```dart
  /// return Response.unauthorized({'error': 'Authentication required'});
  /// ```
  const Response.unauthorized([
    Object? body,
    Map<String, String> headers = const {},
  ]) : this(HttpStatus.unauthorized, body: body, headers: headers);

  /// Creates a 403 Forbidden response.
  const Response.forbidden([
    Object? body,
    Map<String, String> headers = const {},
  ]) : this(HttpStatus.forbidden, body: body, headers: headers);

  /// Creates a 404 Not Found response.
  ///
  /// ```dart
  /// return Response.notFound({'error': 'User not found'});
  /// ```
  const Response.notFound([
    Object? body,
    Map<String, String> headers = const {},
  ]) : this(HttpStatus.notFound, body: body, headers: headers);

  /// Creates a 405 Method Not Allowed response.
  const Response.methodNotAllowed([
    Object? body,
    Map<String, String> headers = const {},
  ]) : this(HttpStatus.methodNotAllowed, body: body, headers: headers);

  /// Creates a 409 Conflict response.
  const Response.conflict([
    Object? body,
    Map<String, String> headers = const {},
  ]) : this(HttpStatus.conflict, body: body, headers: headers);

  /// Creates a 422 Unprocessable Entity response.
  const Response.unprocessableEntity([
    Object? body,
    Map<String, String> headers = const {},
  ]) : this(HttpStatus.unprocessableEntity, body: body, headers: headers);

  /// Creates a 429 Too Many Requests response.
  const Response.tooManyRequests([
    Object? body,
    Map<String, String> headers = const {},
  ]) : this(HttpStatus.tooManyRequests, body: body, headers: headers);

  // ---------------------------------------------------------------------------
  // Server Error Responses (5xx)
  // ---------------------------------------------------------------------------

  /// Creates a 500 Internal Server Error response.
  ///
  /// ```dart
  /// return Response.internalServerError({'error': 'Something went wrong'});
  /// ```
  const Response.internalServerError([
    Object? body,
    Map<String, String> headers = const {},
  ]) : this(HttpStatus.internalServerError, body: body, headers: headers);

  /// Creates a 502 Bad Gateway response.
  const Response.badGateway([
    Object? body,
    Map<String, String> headers = const {},
  ]) : this(HttpStatus.badGateway, body: body, headers: headers);

  /// Creates a 503 Service Unavailable response.
  const Response.serviceUnavailable([
    Object? body,
    Map<String, String> headers = const {},
  ]) : this(HttpStatus.serviceUnavailable, body: body, headers: headers);

  // ---------------------------------------------------------------------------
  // Convenience Constructors
  // ---------------------------------------------------------------------------

  /// Creates a JSON response with the given body and status code.
  ///
  /// ```dart
  /// return Response.json({'key': 'value'});
  /// return Response.json({'error': 'Not found'}, status: 404);
  /// ```
  factory Response.json(
    Object body, {
    int status = HttpStatus.ok,
    Map<String, String> headers = const {},
  }) {
    return Response(
      status,
      body: body,
      headers: {...headers, 'content-type': 'application/json; charset=utf-8'},
    );
  }

  /// Creates a plain text response.
  ///
  /// ```dart
  /// return Response.text('Hello, World!');
  /// ```
  factory Response.text(
    String body, {
    int status = HttpStatus.ok,
    Map<String, String> headers = const {},
  }) {
    return Response(
      status,
      body: body,
      headers: {...headers, 'content-type': 'text/plain; charset=utf-8'},
    );
  }

  /// Creates an HTML response.
  ///
  /// ```dart
  /// return Response.html('<h1>Hello</h1>');
  /// ```
  factory Response.html(
    String body, {
    int status = HttpStatus.ok,
    Map<String, String> headers = const {},
  }) {
    return Response(
      status,
      body: body,
      headers: {...headers, 'content-type': 'text/html; charset=utf-8'},
    );
  }

  // ---------------------------------------------------------------------------
  // Write to HttpResponse
  // ---------------------------------------------------------------------------

  /// Writes this response to an [HttpResponse].
  ///
  /// This method is called internally by Chase to send the response.
  Future<void> writeTo(HttpResponse response) async {
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
      response.write(jsonEncode(body));
    } else {
      // Objects with toJson() will be serialized
      if (!headers.containsKey('content-type')) {
        response.headers.contentType = ContentType.json;
      }
      response.write(jsonEncode(body));
    }

    await response.close();
  }
}
