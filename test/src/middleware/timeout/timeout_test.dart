import 'dart:io';

import 'package:chase/src/middleware/timeout/timeout.dart';
import 'package:chase/testing/testing.dart';
import 'package:test/test.dart' hide Timeout;

void main() {
  group('TimeoutOptions', () {
    test('default options', () {
      const options = TimeoutOptions();
      expect(options.duration, const Duration(seconds: 30));
      expect(options.statusCode, HttpStatus.serviceUnavailable);
      expect(options.errorMessage, isNull);
      expect(options.onTimeout, isNull);
      expect(options.includeDuration, isFalse);
    });

    test('seconds constructor', () {
      final options = TimeoutOptions.seconds(10);
      expect(options.duration, const Duration(seconds: 10));
    });

    test('milliseconds constructor', () {
      final options = TimeoutOptions.milliseconds(500);
      expect(options.duration, const Duration(milliseconds: 500));
    });

    test('short preset', () {
      expect(TimeoutOptions.short.duration, const Duration(seconds: 5));
    });

    test('medium preset', () {
      expect(TimeoutOptions.medium.duration, const Duration(seconds: 30));
    });

    test('long preset', () {
      expect(TimeoutOptions.long.duration, const Duration(seconds: 120));
    });

    test('custom options', () {
      const options = TimeoutOptions(
        duration: Duration(seconds: 15),
        statusCode: HttpStatus.gatewayTimeout,
        errorMessage: 'Custom timeout',
        includeDuration: true,
      );
      expect(options.duration, const Duration(seconds: 15));
      expect(options.statusCode, HttpStatus.gatewayTimeout);
      expect(options.errorMessage, 'Custom timeout');
      expect(options.includeDuration, isTrue);
    });
  });

  group('TimeoutException', () {
    test('creates with duration', () {
      const e = TimeoutException(Duration(seconds: 5));
      expect(e.duration, const Duration(seconds: 5));
      expect(e.message, isNull);
    });

    test('creates with message', () {
      const e = TimeoutException(Duration(seconds: 5), 'Custom message');
      expect(e.message, 'Custom message');
    });

    test('toString without message', () {
      const e = TimeoutException(Duration(seconds: 5));
      expect(e.toString(), contains('5000ms'));
    });

    test('toString with message', () {
      const e = TimeoutException(Duration(seconds: 5), 'Slow query');
      expect(e.toString(), contains('Slow query'));
      expect(e.toString(), contains('5000ms'));
    });
  });

  group('Timeout middleware', () {
    test('allows fast requests to complete', () async {
      final ctx = TestContext.get('/');
      const middleware = Timeout(TimeoutOptions(duration: Duration(milliseconds: 100)));

      await middleware.handle(ctx, () async {
        await Future.delayed(const Duration(milliseconds: 10));
      });

      expect(ctx.response.isClosed, isFalse);
    });

    test('times out slow requests', () async {
      final ctx = TestContext.get('/');
      const middleware = Timeout(TimeoutOptions(duration: Duration(milliseconds: 50)));

      await middleware.handle(ctx, () async {
        await Future.delayed(const Duration(milliseconds: 200));
      });

      expect(ctx.response.statusCode, HttpStatus.serviceUnavailable);
      expect(ctx.response.isClosed, isTrue);
      expect(ctx.response.body, contains('timeout'));
    });

    test('uses custom status code', () async {
      final ctx = TestContext.get('/');
      const middleware = Timeout(TimeoutOptions(
        duration: Duration(milliseconds: 50),
        statusCode: HttpStatus.gatewayTimeout,
      ));

      await middleware.handle(ctx, () async {
        await Future.delayed(const Duration(milliseconds: 200));
      });

      expect(ctx.response.statusCode, HttpStatus.gatewayTimeout);
    });

    test('uses custom error message', () async {
      final ctx = TestContext.get('/');
      const middleware = Timeout(TimeoutOptions(
        duration: Duration(milliseconds: 50),
        errorMessage: 'Server overloaded',
      ));

      await middleware.handle(ctx, () async {
        await Future.delayed(const Duration(milliseconds: 200));
      });

      expect(ctx.response.body, contains('Server overloaded'));
    });

    test('includes duration when configured', () async {
      final ctx = TestContext.get('/');
      const middleware = Timeout(TimeoutOptions(
        duration: Duration(milliseconds: 50),
        includeDuration: true,
      ));

      await middleware.handle(ctx, () async {
        await Future.delayed(const Duration(milliseconds: 200));
      });

      expect(ctx.response.body, contains('duration_ms'));
      expect(ctx.response.body, contains('50'));
    });

    test('calls custom timeout handler', () async {
      var handlerCalled = false;
      final ctx = TestContext.get('/');
      final middleware = Timeout(TimeoutOptions(
        duration: const Duration(milliseconds: 50),
        onTimeout: (ctx) async {
          handlerCalled = true;
          ctx.res.statusCode = 599;
          await ctx.res.close();
        },
      ));

      await middleware.handle(ctx, () async {
        await Future.delayed(const Duration(milliseconds: 200));
      });

      expect(handlerCalled, isTrue);
      expect(ctx.response.statusCode, 599);
    });

    test('works with default constructor', () async {
      final ctx = TestContext.get('/');
      const middleware = Timeout();

      await middleware.handle(ctx, () async {});

      expect(ctx.response.isClosed, isFalse);
    });

    test('short preset works', () async {
      final ctx = TestContext.get('/');
      const middleware = Timeout(TimeoutOptions.short);

      await middleware.handle(ctx, () async {});

      expect(ctx.response.isClosed, isFalse);
    });
  });

  group('Timeout context extension', () {
    test('deadline is null by default', () {
      final ctx = TestContext.get('/');
      expect(ctx.deadline, isNull);
    });

    test('setDeadline stores deadline', () {
      final ctx = TestContext.get('/');
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      ctx.setDeadline(deadline);
      expect(ctx.deadline, deadline);
    });

    test('isExpired returns false when no deadline', () {
      final ctx = TestContext.get('/');
      expect(ctx.isExpired, isFalse);
    });

    test('isExpired returns false before deadline', () {
      final ctx = TestContext.get('/');
      ctx.setDeadline(DateTime.now().add(const Duration(seconds: 10)));
      expect(ctx.isExpired, isFalse);
    });

    test('isExpired returns true after deadline', () {
      final ctx = TestContext.get('/');
      ctx.setDeadline(DateTime.now().subtract(const Duration(seconds: 1)));
      expect(ctx.isExpired, isTrue);
    });

    test('remainingTime is null when no deadline', () {
      final ctx = TestContext.get('/');
      expect(ctx.remainingTime, isNull);
    });

    test('remainingTime returns positive duration before deadline', () {
      final ctx = TestContext.get('/');
      ctx.setDeadline(DateTime.now().add(const Duration(seconds: 10)));
      expect(ctx.remainingTime, isNotNull);
      expect(ctx.remainingTime!.inSeconds, greaterThan(0));
    });

    test('remainingTime returns zero after deadline', () {
      final ctx = TestContext.get('/');
      ctx.setDeadline(DateTime.now().subtract(const Duration(seconds: 1)));
      expect(ctx.remainingTime, Duration.zero);
    });
  });
}
