import 'dart:io';

import 'package:chase/src/core/context/request.dart';
import 'package:chase/src/core/context/response.dart';
import 'package:chase/src/core/response.dart';
import 'package:zlogger/zlogger.dart' as zlogger;

/// The context for handling HTTP requests and responses.
///
/// Context provides access to:
/// - Request data via [req] (including path params, query params, body)
/// - Response via [res]
/// - Arbitrary context data via [get] and [set]
class Context {
  final Req _req;
  final Res _res;

  /// General-purpose storage for sharing data between middleware and handlers.
  final Map<String, dynamic> _store = {};

  Context(
    HttpRequest req,
    HttpResponse res, [
    Map<String, String>? params,
    String? methodOverride,
  ])  : _req = Req(req, params, methodOverride),
        _res = Res(res);

  /// The HTTP request.
  Req get req => _req;

  /// The HTTP response.
  Res get res => _res;

  // ---------------------------------------------------------------------------
  // Context Store (for middleware data sharing)
  // ---------------------------------------------------------------------------

  /// Stores a value in the context.
  ///
  /// Use this to pass data from middleware to downstream handlers.
  ///
  /// Example:
  /// ```dart
  /// // In auth middleware
  /// ctx.set('user', authenticatedUser);
  /// ctx.set('requestId', 'abc-123');
  ///
  /// // In handler
  /// final user = ctx.get<User>('user');
  /// ```
  void set<T>(String key, T value) {
    _store[key] = value;
  }

  /// Retrieves a value from the context.
  ///
  /// Returns null if the key doesn't exist or if the value
  /// is not of the expected type.
  ///
  /// In debug mode, an assertion will fail if the key exists but
  /// the type doesn't match, helping to catch type mismatches early.
  ///
  /// Example:
  /// ```dart
  /// final user = ctx.get<User>('user');
  /// final requestId = ctx.get<String>('requestId');
  /// ```
  T? get<T>(String key) {
    final value = _store[key];
    assert(
      value == null || value is T,
      'Context type mismatch: key "$key" has type ${value.runtimeType}, '
      'but expected $T',
    );
    return value is T ? value : null;
  }

  // ---------------------------------------------------------------------------
  // Logging
  // ---------------------------------------------------------------------------

  /// Logger for this request context.
  ///
  /// When used with [LogContext] middleware, automatically includes
  /// request-specific fields like `request_id` via Zone context.
  ///
  /// Example:
  /// ```dart
  /// ctx.log.info('Processing request');
  /// ctx.log.debug('User authenticated', {'userId': user.id});
  /// ctx.log.error('Failed to save', {'error': e.toString()}, e);
  /// ```
  zlogger.Log get log => zlogger.log;

  // ---------------------------------------------------------------------------
  // Response Builder State (for fluent chaining)
  // ---------------------------------------------------------------------------

  int _statusCode = HttpStatus.ok;
  final Map<String, String> _headers = {};

  // ---------------------------------------------------------------------------
  // Fluent Response API (Hono-style)
  // ---------------------------------------------------------------------------

  /// Sets the response status code and returns `this` for chaining.
  ///
  /// Example:
  /// ```dart
  /// return ctx.status(201).json({'created': true});
  /// ```
  Context status(int code) {
    _statusCode = code;
    return this;
  }

  /// Sets a response header and returns `this` for chaining.
  ///
  /// Example:
  /// ```dart
  /// return ctx.header('X-Custom', 'value').json({'ok': true});
  /// ```
  Context header(String name, String value) {
    _headers[name] = value;
    return this;
  }

  /// Returns a JSON response.
  ///
  /// Example:
  /// ```dart
  /// return ctx.json({'message': 'Hello'});
  /// return ctx.status(201).json({'id': 1, 'created': true});
  /// ```
  Response json(Object? data) {
    return Response(
      _statusCode,
      body: data,
      headers: {..._headers, 'content-type': 'application/json; charset=utf-8'},
    );
  }

  /// Returns a plain text response.
  ///
  /// Example:
  /// ```dart
  /// return ctx.text('Hello, World!');
  /// return ctx.status(200).text('OK');
  /// ```
  Response text(String body) {
    return Response(
      _statusCode,
      body: body,
      headers: {..._headers, 'content-type': 'text/plain; charset=utf-8'},
    );
  }

  /// Returns an HTML response.
  ///
  /// Example:
  /// ```dart
  /// return ctx.html('<h1>Hello</h1>');
  /// return ctx.status(200).html('<html>...</html>');
  /// ```
  Response html(String body) {
    return Response(
      _statusCode,
      body: body,
      headers: {..._headers, 'content-type': 'text/html; charset=utf-8'},
    );
  }

  /// Returns a redirect response.
  ///
  /// Example:
  /// ```dart
  /// return ctx.redirect('/login');
  /// return ctx.redirect('/new-url', status: 301);
  /// ```
  Response redirect(String location, {int status = HttpStatus.found}) {
    return Response(status, headers: {..._headers, 'location': location});
  }

  /// Returns an empty body response.
  ///
  /// Example:
  /// ```dart
  /// return ctx.status(204).body(null);
  /// return ctx.body('Plain body');
  /// ```
  Response body(String? content) {
    return Response(_statusCode, body: content, headers: _headers);
  }

  /// Returns a 404 Not Found response.
  ///
  /// Example:
  /// ```dart
  /// return ctx.notFound();
  /// return ctx.notFound('Resource not found');
  /// ```
  Response notFound([String message = 'Not Found']) {
    return Response(
      HttpStatus.notFound,
      body: message,
      headers: {..._headers, 'content-type': 'text/plain; charset=utf-8'},
    );
  }
}
