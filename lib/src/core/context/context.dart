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

}
