import 'package:chase/chase.dart';
import 'package:chase/testing/testing.dart';
import 'package:test/test.dart';

void main() {
  group('HttpException', () {
    test('HttpException has statusCode and message', () {
      final e = HttpException(404, 'Not found');
      expect(e.statusCode, 404);
      expect(e.message, 'Not found');
    });

    test('BadRequestException has 400 status code', () {
      final e = BadRequestException('Invalid input');
      expect(e.statusCode, 400);
      expect(e.message, 'Invalid input');
    });

    test('UnauthorizedException has 401 status code', () {
      final e = UnauthorizedException('Invalid token');
      expect(e.statusCode, 401);
      expect(e.message, 'Invalid token');
    });

    test('ForbiddenException has 403 status code', () {
      final e = ForbiddenException('Access denied');
      expect(e.statusCode, 403);
      expect(e.message, 'Access denied');
    });

    test('NotFoundException has 404 status code', () {
      final e = NotFoundException('User not found');
      expect(e.statusCode, 404);
      expect(e.message, 'User not found');
    });

    test('ConflictException has 409 status code', () {
      final e = ConflictException('Resource already exists');
      expect(e.statusCode, 409);
      expect(e.message, 'Resource already exists');
    });

    test('ValidationException has 422 status code', () {
      final e = ValidationException([
        ValidationError(
          field: 'email',
          message: 'Invalid email format',
          rule: 'email',
        ),
      ]);
      expect(e.statusCode, 422);
      expect(e.message, 'Validation failed');
    });

    test('InternalServerErrorException has 500 status code', () {
      final e = InternalServerErrorException('Database error');
      expect(e.statusCode, 500);
      expect(e.message, 'Database error');
    });

    test('ServiceUnavailableException has 503 status code', () {
      final e = ServiceUnavailableException('Service down');
      expect(e.statusCode, 503);
      expect(e.message, 'Service down');
    });
  });

  group('ExceptionHandler - HttpException Handling', () {
    test('catches HttpException and returns appropriate status code', () async {
      final ctx = TestContext.get('/');
      await buildMiddlewareChain([ExceptionHandler()], (_) async {
        throw HttpException(404, 'Resource not found');
      })(ctx);

      expect(ctx.response.statusCode, 404);
      expect(ctx.response.body, contains('Resource not found'));
      expect(ctx.response.body, contains('404'));
    });

    test('catches NotFoundException and returns 404', () async {
      final ctx = TestContext.get('/');
      await buildMiddlewareChain([ExceptionHandler()], (_) async {
        throw NotFoundException('User not found');
      })(ctx);

      expect(ctx.response.statusCode, 404);
      expect(ctx.response.body, contains('User not found'));
    });

    test('catches UnauthorizedException and returns 401', () async {
      final ctx = TestContext.get('/');
      await buildMiddlewareChain([ExceptionHandler()], (_) async {
        throw UnauthorizedException('Invalid token');
      })(ctx);

      expect(ctx.response.statusCode, 401);
      expect(ctx.response.body, contains('Invalid token'));
    });

    test('catches ValidationException and returns 422', () async {
      final ctx = TestContext.get('/');
      await buildMiddlewareChain([ExceptionHandler()], (_) async {
        throw ValidationException([
          ValidationError(
            field: 'email',
            message: 'Email is required',
            rule: 'required',
          ),
        ]);
      })(ctx);

      expect(ctx.response.statusCode, 422);
      expect(ctx.response.body, contains('Validation failed'));
    });
  });

  group('ExceptionHandler - Generic Exception Handling', () {
    test('catches StateError and returns 500', () async {
      final ctx = TestContext.get('/');
      await buildMiddlewareChain([ExceptionHandler()], (_) async {
        throw StateError('Invalid state');
      })(ctx);

      expect(ctx.response.statusCode, 500);
    });

    test('catches ArgumentError and returns 500', () async {
      final ctx = TestContext.get('/');
      await buildMiddlewareChain([ExceptionHandler()], (_) async {
        throw ArgumentError('Invalid argument');
      })(ctx);

      expect(ctx.response.statusCode, 500);
    });
  });

  group('ExceptionHandler - Middleware Chain Integration', () {
    test('allows successful requests to pass through', () async {
      final ctx = TestContext.get('/');
      final tracker = <String>[];

      await buildMiddlewareChain([ExceptionHandler()], (ctx) async {
        tracker.add('success');
        ctx.res
          ..statusCode = 200
          ..write('OK')
          ..close();
      })(ctx);

      expect(tracker, ['success']);
      expect(ctx.response.statusCode, 200);
      expect(ctx.response.body, contains('OK'));
    });

    test(
      'error handler as first middleware catches all downstream errors',
      () async {
        final ctx = TestContext.get('/');
        final tracker = <String>[];

        await buildMiddlewareChain(
          [ExceptionHandler(), _TrackingMiddleware(tracker, 'mw1')],
          (_) async {
            tracker.add('handler-error');
            throw ValidationException([
              ValidationError(
                field: 'data',
                message: 'Validation failed',
                rule: 'required',
              ),
            ]);
          },
        )(ctx);

        expect(tracker, ['mw1-before', 'handler-error']);
        expect(ctx.response.statusCode, 422);
      },
    );

    test(
      'error handler not as first middleware does not catch upstream errors',
      () async {
        final ctx = TestContext.get('/');

        final chain = buildMiddlewareChain([
          _ThrowingMiddleware(),
          ExceptionHandler(),
        ], (_) async {});

        expect(() => chain(ctx), throwsA(isA<NotFoundException>()));
      },
    );
  });

  group('ExceptionHandler - Edge Cases', () {
    test('handles empty message in HttpException', () async {
      final ctx = TestContext.get('/');
      await buildMiddlewareChain([ExceptionHandler()], (_) async {
        throw HttpException(500, '');
      })(ctx);

      expect(ctx.response.statusCode, 500);
    });

    test('handles multiple errors in sequence', () async {
      final handler = ExceptionHandler();

      final ctx1 = TestContext.get('/');
      await buildMiddlewareChain([handler], (_) async {
        throw NotFoundException('First error');
      })(ctx1);
      expect(ctx1.response.statusCode, 404);

      final ctx2 = TestContext.get('/');
      await buildMiddlewareChain([handler], (_) async {
        throw UnauthorizedException('Second error');
      })(ctx2);
      expect(ctx2.response.statusCode, 401);
    });

    test('preserves response if handler closes it before throwing', () async {
      final ctx = TestContext.get('/');
      await buildMiddlewareChain([ExceptionHandler()], (ctx) async {
        ctx.res
          ..statusCode = 200
          ..write('Partial response')
          ..close();
        throw Exception('Error after close');
      })(ctx);

      expect(ctx.response.statusCode, 500);
    });
  });
}

class _TrackingMiddleware extends Middleware {
  final List<String> tracker;
  final String name;

  _TrackingMiddleware(this.tracker, this.name);

  @override
  Future<void> handle(Context ctx, NextFunction next) async {
    tracker.add('$name-before');
    await next();
    tracker.add('$name-after');
  }
}

class _ThrowingMiddleware extends Middleware {
  @override
  Future<void> handle(Context ctx, NextFunction next) async {
    throw NotFoundException('Error in first middleware');
  }
}
