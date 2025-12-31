import 'dart:async';
import 'dart:convert';

import 'package:chase/src/core/middleware.dart';
import 'package:chase/src/core/exception/http_exception.dart';

class ExceptionHandler implements Middleware {
  @override
  FutureOr<void> handle(ctx, NextFunction next) async {
    try {
      await next();
    } on HttpException catch (e) {
      ctx.res
        ..statusCode = e.statusCode
        ..write(jsonEncode({'error': e.message, 'statusCode': e.statusCode}))
        ..close();
      return;
    } catch (e) {
      ctx.res
        ..statusCode = 500
        ..write(jsonEncode({'error': 'Internal Server Error', 'statusCode': 500}))
        ..close();
      return;
    }
  }
}
