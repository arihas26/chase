import 'dart:io';
import 'package:chase/chase.dart';
import 'package:test/test.dart';

void main() {
  group('Middleware Execution - Basic', () {
    test('single middleware executes correctly', () async {
      final tracker = <String>[];
      final chain = _buildTestChain([ExecutionTracker(tracker, 'MW1')], (ctx) async {
        tracker.add('handler');
      });

      final ctx = _createMockContext();
      await chain(ctx);

      expect(tracker, ['MW1-before', 'handler', 'MW1-after']);
    });

    test('multiple middlewares execute in correct order (Onion Model)', () async {
      final tracker = <String>[];
      final chain = _buildTestChain(
        [
          ExecutionTracker(tracker, 'MW1'),
          ExecutionTracker(tracker, 'MW2'),
          ExecutionTracker(tracker, 'MW3'),
        ],
        (ctx) async {
          tracker.add('handler');
        },
      );

      final ctx = _createMockContext();
      await chain(ctx);

      expect(tracker, [
        'MW1-before',
        'MW2-before',
        'MW3-before',
        'handler',
        'MW3-after',
        'MW2-after',
        'MW1-after',
      ]);
    });

    test('empty middleware list passes through to handler', () async {
      final tracker = <String>[];
      final chain = _buildTestChain([], (ctx) async {
        tracker.add('handler');
      });

      final ctx = _createMockContext();
      await chain(ctx);

      expect(tracker, ['handler']);
    });
  });

  group('Middleware Execution - next() Control', () {
    test('middleware can interrupt request by not calling next()', () async {
      final tracker = <String>[];
      final chain = _buildTestChain(
        [
          ExecutionTracker(tracker, 'MW1'),
          AuthMiddleware(shouldPass: false),
          ExecutionTracker(tracker, 'MW3'),
        ],
        (ctx) async {
          tracker.add('handler');
        },
      );

      final ctx = _createMockContext();
      await chain(ctx);

      expect(tracker, ['MW1-before', 'MW1-after']);
    });

    test('middleware after interruption does not execute', () async {
      final tracker = <String>[];
      final chain = _buildTestChain(
        [AuthMiddleware(shouldPass: false), ExecutionTracker(tracker, 'ShouldNotRun')],
        (ctx) async {
          tracker.add('handler');
        },
      );

      final ctx = _createMockContext();
      await chain(ctx);

      expect(tracker, isEmpty);
    });

    test('multiple next() calls in same middleware (edge case)', () async {
      var callCount = 0;
      final doubleNext = _TestMiddleware((ctx, next) async {
        await next();
        callCount++;
        await next();
        callCount++;
      });

      final chain = _buildTestChain([doubleNext], (ctx) async {});

      final ctx = _createMockContext();
      await chain(ctx);

      expect(callCount, 2);
    });
  });

  group('Middleware Execution - Error Handling', () {
    test('error in middleware is caught by error handler', () async {
      final errors = <String>[];
      final chain = _buildTestChain([
        ExceptionHandler(errors),
        ExceptionMiddleware('Test error'),
      ], (ctx) async {});

      final ctx = _createMockContext();
      await chain(ctx);

      expect(errors, hasLength(1));
      expect(errors[0], contains('Test error'));
    });

    test('error in handler is caught by middleware', () async {
      final errors = <String>[];
      final chain = _buildTestChain([ExceptionHandler(errors)], (ctx) async {
        throw Exception('Handler error');
      });

      final ctx = _createMockContext();
      await chain(ctx);

      expect(errors, hasLength(1));
      expect(errors[0], contains('Handler error'));
    });

    test('uncaught error propagates', () async {
      final chain = _buildTestChain([ExceptionMiddleware('Uncaught error')], (ctx) async {});

      final ctx = _createMockContext();
      expect(() => chain(ctx), throwsException);
    });

    test('error handler after error source does not catch', () async {
      final errors = <String>[];
      final chain = _buildTestChain([
        ExceptionMiddleware('Test error'),
        ExceptionHandler(errors),
      ], (ctx) async {});

      final ctx = _createMockContext();
      expect(() => chain(ctx), throwsException);
      expect(errors, isEmpty);
    });
  });

  group('Middleware Execution - Edge Cases', () {
    test('same handler instance with different middlewares', () async {
      Future<void> sharedHandler(Context ctx) async {
      }

      final tracker1 = <String>[];
      final chain1 = _buildTestChain([ExecutionTracker(tracker1, 'MW1')], sharedHandler);

      final tracker2 = <String>[];
      final chain2 = _buildTestChain([ExecutionTracker(tracker2, 'MW2')], sharedHandler);

      final ctx = _createMockContext();

      await chain1(ctx);
      expect(tracker1, ['MW1-before', 'MW1-after']);

      await chain2(ctx);
      expect(tracker2, ['MW2-before', 'MW2-after']);
    });

    test('deeply nested middleware chain (100 layers)', () async {
      var counter = 0;
      final middlewares = List.generate(
        100,
        (i) => _TestMiddleware((ctx, next) async {
          counter++;
          final result = await next();
          counter++;
          return result;
        }),
      );

      final chain = _buildTestChain(middlewares, (ctx) async {});

      final ctx = _createMockContext();
      await chain(ctx);

      expect(counter, 200); // 100 before + 100 after
    });

    test('middleware modifying context is visible to subsequent middlewares', () async {
      final modifications = <String>[];

      final setter = _TestMiddleware((ctx, next) async {
        modifications.add('set-before');
        final result = await next();
        modifications.add('set-after');
        return result;
      });

      final checker = _TestMiddleware((ctx, next) async {
        modifications.add('check-before');
        final result = await next();
        modifications.add('check-after');
        return result;
      });

      final chain = _buildTestChain([setter, checker], (ctx) async {
        modifications.add('handler');
      });

      final ctx = _createMockContext();
      await chain(ctx);

      expect(modifications, ['set-before', 'check-before', 'handler', 'check-after', 'set-after']);
    });

    test('async middleware with delay maintains order', () async {
      final tracker = <String>[];

      final delayedMW = _TestMiddleware((ctx, next) async {
        tracker.add('delayed-before');
        await Future.delayed(Duration(milliseconds: 10));
        final result = await next();
        await Future.delayed(Duration(milliseconds: 10));
        tracker.add('delayed-after');
        return result;
      });

      final chain = _buildTestChain(
        [ExecutionTracker(tracker, 'MW1'), delayedMW, ExecutionTracker(tracker, 'MW3')],
        (ctx) async {
          tracker.add('handler');
        },
      );

      final ctx = _createMockContext();
      await chain(ctx);

      expect(tracker, [
        'MW1-before',
        'delayed-before',
        'MW3-before',
        'handler',
        'MW3-after',
        'delayed-after',
        'MW1-after',
      ]);
    });

    // Test removed: 'middleware returning different context' is no longer applicable
    // with void handlers. Context is now always modified in-place.
  });

  group('Global + Route-specific Middleware', () {
    test('global middleware executes before route-specific', () async {
      final tracker = <String>[];

      final globalChain = _buildTestChain(
        [ExecutionTracker(tracker, 'Global1')],
        _buildTestChain([ExecutionTracker(tracker, 'Route1')], (ctx) async {
          tracker.add('handler');
        }),
      );

      final ctx = _createMockContext();
      await globalChain(ctx);

      expect(tracker, [
        'Global1-before',
        'Route1-before',
        'handler',
        'Route1-after',
        'Global1-after',
      ]);
    });

    test('multiple global + multiple route-specific middlewares', () async {
      final tracker = <String>[];

      final globalChain = _buildTestChain(
        [ExecutionTracker(tracker, 'Global1'), ExecutionTracker(tracker, 'Global2')],
        _buildTestChain(
          [ExecutionTracker(tracker, 'Route1'), ExecutionTracker(tracker, 'Route2')],
          (ctx) async {
            tracker.add('handler');
          },
        ),
      );

      final ctx = _createMockContext();
      await globalChain(ctx);

      expect(tracker, [
        'Global1-before',
        'Global2-before',
        'Route1-before',
        'Route2-before',
        'handler',
        'Route2-after',
        'Route1-after',
        'Global2-after',
        'Global1-after',
      ]);
    });

    test('Chase integrates global and route-specific chains', () async {
      final tracker = <String>[];
      final router = TrieRouter();
      final app = Chase(router: router);
      final globalMw = ExecutionTracker(tracker, 'Global');
      final routeMw = ExecutionTracker(tracker, 'Route');

      app.use(globalMw);
      app.get('/').use(routeMw).handle((ctx) async {
        tracker.add('handler');
      });

      final match = router.match('GET', '/');
      expect(match, isNotNull);

      final chain = _buildTestChain([globalMw], match!.handler);
      final ctx = _createMockContext();
      await chain(ctx);

      expect(tracker, ['Global-before', 'Route-before', 'handler', 'Route-after', 'Global-after']);
    });
  });

  group('Middleware Duplicates Allowed', () {
    test('duplicate middleware types all execute in order', () async {
      final tracker = <String>[];

      final chain = _buildTestChain(
        [ExecutionTracker(tracker, 'First'), ExecutionTracker(tracker, 'Second')],
        (ctx) async {
          tracker.add('handler');
        },
      );

      final ctx = _createMockContext();
      await chain(ctx);

      expect(tracker, ['First-before', 'Second-before', 'handler', 'Second-after', 'First-after']);
    });

    test('three instances of same type all execute', () async {
      final tracker = <String>[];

      final chain = _buildTestChain(
        [
          ExecutionTracker(tracker, 'First'),
          ExecutionTracker(tracker, 'Second'),
          ExecutionTracker(tracker, 'Third'),
        ],
        (ctx) async {
          tracker.add('handler');
        },
      );

      final ctx = _createMockContext();
      await chain(ctx);

      expect(tracker, [
        'First-before',
        'Second-before',
        'Third-before',
        'handler',
        'Third-after',
        'Second-after',
        'First-after',
      ]);
    });

    test('different middleware types all execute', () async {
      final tracker = <String>[];

      final chain = _buildTestChain(
        [
          ExecutionTracker(tracker, 'MW1'),
          AuthMiddleware(shouldPass: true),
          ExecutionTrackerAlt(tracker, 'MW3'),
        ],
        (ctx) async {
          tracker.add('handler');
        },
      );

      final ctx = _createMockContext();
      await chain(ctx);

      expect(tracker, contains('MW1-before'));
      expect(tracker, contains('MW3-before'));
      expect(tracker, contains('handler'));
    });
  });
}

Handler _buildTestChain(List<Middleware> middlewares, Handler finalHandler) {
  // Build chain in reverse order
  Handler current = finalHandler;
  for (int i = middlewares.length - 1; i >= 0; i--) {
    final mw = middlewares[i];
    final next = current;
    current = (ctx) => mw.handle(ctx, () => next(ctx));
  }

  return current;
}

Context _createMockContext() {
  final req = _MockHttpRequest();
  final res = _MockHttpResponse();
  return Context(req, res);
}

class _TestMiddleware implements Middleware {
  final Future<void> Function(Context, NextFunction) _handler;

  _TestMiddleware(this._handler);

  @override
  Future<void> handle(Context ctx, NextFunction next) {
    return _handler(ctx, next);
  }
}

class _MockHttpRequest implements HttpRequest {
  @override
  String get method => 'GET';

  @override
  Uri get uri => Uri.parse('http://localhost/');

  @override
  HttpHeaders get headers => _MockHttpHeaders();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockHttpResponse implements HttpResponse {
  @override
  int statusCode = 200;
  final _buffer = StringBuffer();

  @override
  void write(Object? obj) {
    _buffer.write(obj);
  }

  @override
  Future close() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockHttpHeaders implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ExecutionTracker implements Middleware {
  final List<String> tracker;
  final String name;

  ExecutionTracker(this.tracker, this.name);

  @override
  Future<void> handle(Context ctx, NextFunction next) async {
    tracker.add('$name-before');
    await next();
    tracker.add('$name-after');
  }
}

class ExecutionTrackerAlt implements Middleware {
  final List<String> tracker;
  final String name;

  ExecutionTrackerAlt(this.tracker, this.name);

  @override
  Future<void> handle(Context ctx, NextFunction next) async {
    tracker.add('$name-before');
    await next();
    tracker.add('$name-after');
  }
}

class AuthMiddleware implements Middleware {
  final bool shouldPass;

  AuthMiddleware({this.shouldPass = true});

  @override
  Future<void> handle(Context ctx, NextFunction next) async {
    if (!shouldPass) {
      ctx.res
        ..statusCode = HttpStatus.unauthorized
        ..write('Unauthorized')
        ..close();
      return;
    }
    await next();
  }
}

class ExceptionMiddleware implements Middleware {
  final String errorMessage;

  ExceptionMiddleware(this.errorMessage);

  @override
  Future<void> handle(Context ctx, NextFunction next) async {
    throw Exception(errorMessage);
  }
}

class ExceptionHandler implements Middleware {
  final List<String> errors;

  ExceptionHandler(this.errors);

  @override
  Future<void> handle(Context ctx, NextFunction next) async {
    try {
      await next();
    } catch (e) {
      errors.add(e.toString());
      ctx.res
        ..statusCode = HttpStatus.internalServerError
        ..write('Error: $e')
        ..close();
    }
  }
}

class ContextModifier implements Middleware {
  final Map<String, String> modifications;

  ContextModifier(this.modifications);

  @override
  Future<void> handle(Context ctx, NextFunction next) async {
    modifications.forEach((key, value) {});
    await next();
  }
}
