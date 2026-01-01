import 'dart:async';

import 'package:chase/src/core/context/context.dart';
import 'package:chase/src/core/logger.dart';
import 'package:chase/src/core/middleware.dart';

/// Middleware that establishes a log context zone for the request.
///
/// This middleware wraps the request handling in a Zone that includes
/// context fields (like request_id) which are automatically added to
/// all [Log] calls within that zone.
///
/// This enables logging from Services, Repositories, or any class
/// without passing the context explicitly.
///
/// Example:
/// ```dart
/// final app = Chase();
///
/// // Add RequestId first to generate request IDs
/// app.use(RequestId());
///
/// // Then add LogContext to propagate it to all Log calls
/// app.use(LogContext());
///
/// app.get('/users/:id').handle((ctx) async {
///   // Service can use Log.info() and request_id is included automatically
///   final user = await userService.findUser(ctx.req.params['id']!);
///   ctx.res.json(user);
/// });
/// ```
///
/// In your service:
/// ```dart
/// class UserService {
///   Future<User> findUser(String id) async {
///     Log.info('Finding user', {'userId': id});
///     // Output: ... [INFO] Finding user request_id=abc-123 userId=42
///     return await _repository.find(id);
///   }
/// }
/// ```
class LogContext implements Middleware {
  /// Additional fields to include in the log context.
  ///
  /// These fields are merged with the automatically extracted fields.
  final Map<String, dynamic> Function(Context ctx)? fieldsBuilder;

  /// Creates a LogContext middleware.
  ///
  /// By default, includes `request_id` if available in the context store.
  ///
  /// Use [fieldsBuilder] to add custom fields:
  /// ```dart
  /// app.use(LogContext(
  ///   fieldsBuilder: (ctx) => {
  ///     'user_id': ctx.get<String>('userId'),
  ///     'tenant': ctx.get<String>('tenant'),
  ///   },
  /// ));
  /// ```
  const LogContext({this.fieldsBuilder});

  @override
  FutureOr<void> handle(Context ctx, NextFunction next) {
    final fields = <String, dynamic>{};

    // Auto-include request_id if available
    final requestId = ctx.get<String>('requestId');
    if (requestId != null) {
      fields['request_id'] = requestId;
    }

    // Add custom fields from builder
    if (fieldsBuilder != null) {
      final customFields = fieldsBuilder!(ctx);
      fields.addAll(customFields);
    }

    // Run the rest of the middleware chain within the log context zone
    return Log.runWithContextAsync(fields, () async {
      await next();
    });
  }
}
