import 'dart:async';

import 'package:chase/src/core/context/context.dart';

/// A function that handles an HTTP request.
///
/// Handlers receive a [Context] containing the request and response,
/// and can perform any async operations to process the request.
///
/// Example:
/// ```dart
/// Handler myHandler = (ctx) async {
///   await ctx.res.json({'message': 'Hello!'});
/// };
/// ```
typedef Handler = FutureOr<dynamic> Function(Context ctx);

/// A function that handles errors during request processing.
///
/// Receives the error, stack trace, and context to allow custom error
/// responses.
///
/// Example:
/// ```dart
/// app.onError((error, stackTrace, ctx) {
///   print('Error: $error');
///   return {'error': error.toString()};
/// });
/// ```
typedef ErrorHandler = FutureOr<dynamic> Function(
  Object error,
  StackTrace stackTrace,
  Context ctx,
);
