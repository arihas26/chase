import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chase/src/core/context/context.dart';
import 'package:chase/src/core/exception/http_exception.dart';
import 'package:chase/src/core/middleware.dart';
import 'package:zlogger/zlogger.dart';

/// Middleware that catches exceptions and returns appropriate error responses.
///
/// - [HttpException]: Returns the exception's status code and message
/// - Other exceptions: Returns 500 Internal Server Error (details logged but not exposed)
///
/// Example:
/// ```dart
/// final app = Chase()
///   ..use(RequestId())        // Add request ID first
///   ..use(ExceptionHandler()) // Then exception handler
///   ..get('/').handle((ctx) {
///     throw HttpException.notFound('Resource not found');
///   });
/// ```
class ExceptionHandler implements Middleware {
  static final _log = Log.named('ExceptionHandler');

  @override
  FutureOr<void> handle(Context ctx, NextFunction next) async {
    try {
      await next();
    } on HttpException catch (e) {
      // HttpExceptions are intentional - log at debug level for 4xx, warn for 5xx
      if (e.statusCode >= 500) {
        _log.warn('HTTP ${e.statusCode}: ${e.message}', {
          'request_id': ctx.get<String>('_requestId'),
          'method': ctx.req.method,
          'path': ctx.req.path,
          'status': e.statusCode,
        });
      }

      ctx.res
        ..statusCode = e.statusCode
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'error': e.message, 'statusCode': e.statusCode}));
      await ctx.res.close();
    } catch (e, stackTrace) {
      // Unexpected exceptions - always log as error
      _log.error(
        'Unhandled exception',
        {
          'request_id': ctx.get<String>('_requestId'),
          'method': ctx.req.method,
          'path': ctx.req.path,
        },
        e,
        stackTrace,
      );

      ctx.res
        ..statusCode = 500
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({'error': 'Internal Server Error', 'statusCode': 500}),
        );
      await ctx.res.close();
    }
  }
}
