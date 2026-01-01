import 'dart:io';

import 'package:chase/src/core/context/request.dart';
import 'package:chase/src/core/context/response.dart';
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
  // Fluent Response API
  // ---------------------------------------------------------------------------

  /// Sets the response status code and returns `this` for chaining.
  ///
  /// Example:
  /// ```dart
  /// await ctx.status(201).json({'created': true});
  /// await ctx.status(204).body(null);
  /// ```
  Context status(int code) {
    _res.statusCode = code;
    return this;
  }

  /// Sets a response header and returns `this` for chaining.
  ///
  /// Example:
  /// ```dart
  /// await ctx.header('X-Custom', 'value').json({'ok': true});
  /// await ctx.header('Cache-Control', 'no-cache').text('Hello');
  /// ```
  Context header(String name, String value) {
    _res.headers.set(name, value);
    return this;
  }

  /// Sends a JSON response.
  ///
  /// Shorthand for `ctx.res.json()` that works with fluent chaining.
  ///
  /// Example:
  /// ```dart
  /// await ctx.json({'message': 'Hello'});
  /// await ctx.status(201).json({'id': 1, 'created': true});
  /// ```
  Future<void> json(Object? data) => _res.json(data, status: _res.statusCode);

  /// Sends a plain text response.
  ///
  /// Shorthand for `ctx.res.text()` that works with fluent chaining.
  ///
  /// Example:
  /// ```dart
  /// await ctx.text('Hello, World!');
  /// await ctx.status(200).text('OK');
  /// ```
  Future<void> text(String body) => _res.text(body, status: _res.statusCode);

  /// Sends an HTML response.
  ///
  /// Shorthand for `ctx.res.html()` that works with fluent chaining.
  ///
  /// Example:
  /// ```dart
  /// await ctx.html('<h1>Hello</h1>');
  /// await ctx.status(200).html('<html>...</html>');
  /// ```
  Future<void> html(String body) => _res.html(body, status: _res.statusCode);

  /// Sends a redirect response.
  ///
  /// Shorthand for `ctx.res.redirect()` that works with fluent chaining.
  ///
  /// Example:
  /// ```dart
  /// await ctx.redirect('/login');
  /// await ctx.redirect('/new-url', status: 301);
  /// ```
  Future<void> redirect(String location, {int status = 302}) =>
      _res.redirect(location, status: status);

  /// Sends an empty body response with optional status code.
  ///
  /// Useful for 204 No Content or other empty responses.
  ///
  /// Example:
  /// ```dart
  /// await ctx.status(204).body(null);
  /// await ctx.body('Plain body');
  /// ```
  Future<void> body(String? content) async {
    if (content != null) {
      _res.write(content);
    }
    await _res.close();
  }

  /// Sends a 404 Not Found response.
  ///
  /// Example:
  /// ```dart
  /// await ctx.notFound();
  /// await ctx.notFound('Resource not found');
  /// ```
  Future<void> notFound([String message = 'Not Found']) => _res.notFound(message);
}
