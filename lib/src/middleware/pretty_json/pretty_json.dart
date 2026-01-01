import 'dart:async';

import 'package:chase/chase.dart';

/// Middleware that formats JSON responses with indentation.
///
/// This is useful for development and debugging, making JSON responses
/// easier to read in browsers and API clients.
///
/// ## Example
///
/// ```dart
/// final app = Chase();
///
/// // Enable pretty JSON for all routes
/// app.use(PrettyJson());
///
/// // Or conditionally for development
/// if (isDevelopment) {
///   app.use(PrettyJson());
/// }
///
/// app.get('/api/users').handle((ctx) {
///   return {'users': [{'id': 1, 'name': 'John'}]};
/// });
/// ```
///
/// ## Output
///
/// Without PrettyJson:
/// ```json
/// {"users":[{"id":1,"name":"John"}]}
/// ```
///
/// With PrettyJson:
/// ```json
/// {
///   "users": [
///     {
///       "id": 1,
///       "name": "John"
///     }
///   ]
/// }
/// ```
class PrettyJson implements Middleware {
  /// Creates a PrettyJson middleware.
  ///
  /// The [condition] parameter allows conditional enabling based on
  /// request context (e.g., query parameter or header).
  ///
  /// ```dart
  /// // Enable only when ?pretty=true is present
  /// app.use(PrettyJson(
  ///   condition: (ctx) => ctx.req.query('pretty') == 'true',
  /// ));
  /// ```
  const PrettyJson({this.condition});

  /// Optional condition to enable pretty JSON.
  ///
  /// If null, pretty JSON is always enabled.
  /// If provided, pretty JSON is only enabled when this returns true.
  final bool Function(Context ctx)? condition;

  @override
  FutureOr<void> handle(Context ctx, NextFunction next) async {
    if (condition == null || condition!(ctx)) {
      ctx.res.prettyJson = true;
    }
    await next();
  }
}

/// Formats JSON responses with indentation.
///
/// ```dart
/// app.use(prettyJson());
///
/// // With condition
/// app.use(prettyJson(condition: (ctx) => ctx.req.query('pretty') == 'true'));
/// ```
PrettyJson prettyJson({bool Function(Context ctx)? condition}) {
  return PrettyJson(condition: condition);
}
