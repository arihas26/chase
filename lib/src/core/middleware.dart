import 'dart:async';

import 'package:chase/src/core/context/context.dart';

typedef NextFunction = FutureOr<dynamic> Function();

abstract class Middleware {
  FutureOr<dynamic> handle(Context ctx, NextFunction next);
}
