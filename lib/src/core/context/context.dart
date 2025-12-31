import 'dart:io';

import 'package:chase/src/core/context/request.dart';
import 'package:chase/src/core/context/response.dart';

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

  Context(HttpRequest req, HttpResponse res, [Map<String, String>? params])
      : _req = Req(req, params),
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
  /// Example:
  /// ```dart
  /// final user = ctx.get<User>('user');
  /// final requestId = ctx.get<String>('requestId');
  /// ```
  T? get<T>(String key) {
    final value = _store[key];
    return value is T ? value : null;
  }
}
