import 'dart:io';

import 'package:chase/src/middleware/rate_limit/rate_limit.dart';
import 'package:chase/testing/testing.dart';
import 'package:test/test.dart';

void main() {
  group('RateLimitOptions', () {
    test('creates with default values', () {
      const options = RateLimitOptions();
      expect(options.maxRequests, 100);
      expect(options.windowMs, 60000);
      expect(options.errorMessage, isNull);
      expect(options.includeHeaders, isTrue);
      expect(options.skipSuccessfulRequests, isFalse);
      expect(options.skipFailedRequests, isFalse);
    });

    test('creates with custom values', () {
      const options = RateLimitOptions(
        maxRequests: 50,
        windowMs: 30000,
        errorMessage: 'Custom error',
        includeHeaders: false,
      );
      expect(options.maxRequests, 50);
      expect(options.windowMs, 30000);
      expect(options.errorMessage, 'Custom error');
      expect(options.includeHeaders, isFalse);
    });

    test('perSecond creates correct window', () {
      const options = RateLimitOptions.perSecond(10);
      expect(options.maxRequests, 10);
      expect(options.windowMs, 1000);
    });

    test('perMinute creates correct window', () {
      const options = RateLimitOptions.perMinute(60);
      expect(options.maxRequests, 60);
      expect(options.windowMs, 60000);
    });

    test('perHour creates correct window', () {
      const options = RateLimitOptions.perHour(1000);
      expect(options.maxRequests, 1000);
      expect(options.windowMs, 3600000);
    });

    test('perSecond with custom options', () {
      const options = RateLimitOptions.perSecond(
        5,
        errorMessage: 'Too fast',
        includeHeaders: false,
      );
      expect(options.maxRequests, 5);
      expect(options.windowMs, 1000);
      expect(options.errorMessage, 'Too fast');
      expect(options.includeHeaders, isFalse);
    });
  });

  group('RateLimitInfo', () {
    test('calculates isExceeded correctly', () {
      final info = RateLimitInfo(
        key: 'test',
        requestCount: 11,
        maxRequests: 10,
        resetInMs: 1000,
        resetAt: DateTime.now().add(const Duration(seconds: 1)),
      );
      expect(info.isExceeded, isTrue);

      final infoAtLimit = RateLimitInfo(
        key: 'test',
        requestCount: 10,
        maxRequests: 10,
        resetInMs: 1000,
        resetAt: DateTime.now().add(const Duration(seconds: 1)),
      );
      expect(infoAtLimit.isExceeded, isFalse);
    });

    test('calculates remaining correctly', () {
      final info = RateLimitInfo(
        key: 'test',
        requestCount: 7,
        maxRequests: 10,
        resetInMs: 1000,
        resetAt: DateTime.now().add(const Duration(seconds: 1)),
      );
      expect(info.remaining, 3);
    });

    test('remaining is clamped to 0', () {
      final info = RateLimitInfo(
        key: 'test',
        requestCount: 15,
        maxRequests: 10,
        resetInMs: 1000,
        resetAt: DateTime.now().add(const Duration(seconds: 1)),
      );
      expect(info.remaining, 0);
    });
  });

  group('RateLimitStore', () {
    late RateLimitStore store;

    setUp(() => store = RateLimitStore());
    tearDown(() => store.dispose());

    test('increments count for new key', () {
      const options = RateLimitOptions(maxRequests: 10, windowMs: 60000);
      final info = store.increment('test-key', options);
      expect(info.requestCount, 1);
      expect(info.maxRequests, 10);
    });

    test('increments count for existing key', () {
      const options = RateLimitOptions(maxRequests: 10, windowMs: 60000);
      store.increment('test-key', options);
      store.increment('test-key', options);
      final info = store.increment('test-key', options);
      expect(info.requestCount, 3);
    });

    test('peek returns info without incrementing', () {
      const options = RateLimitOptions(maxRequests: 10, windowMs: 60000);
      store.increment('test-key', options);
      final peeked = store.peek('test-key', options);
      final afterPeek = store.increment('test-key', options);
      expect(peeked?.requestCount, 1);
      expect(afterPeek.requestCount, 2);
    });

    test('peek returns null for unknown key', () {
      const options = RateLimitOptions(maxRequests: 10, windowMs: 60000);
      expect(store.peek('unknown', options), isNull);
    });

    test('reset clears key', () {
      const options = RateLimitOptions(maxRequests: 10, windowMs: 60000);
      store.increment('test-key', options);
      store.increment('test-key', options);
      store.reset('test-key');
      final info = store.increment('test-key', options);
      expect(info.requestCount, 1);
    });

    test('clear removes all keys', () {
      const options = RateLimitOptions(maxRequests: 10, windowMs: 60000);
      store.increment('key1', options);
      store.increment('key2', options);
      store.clear();
      expect(store.peek('key1', options), isNull);
      expect(store.peek('key2', options), isNull);
    });

    test('starts new window after expiry', () async {
      const options = RateLimitOptions(maxRequests: 10, windowMs: 50);
      store.increment('test-key', options);
      store.increment('test-key', options);
      await Future.delayed(const Duration(milliseconds: 60));
      final info = store.increment('test-key', options);
      expect(info.requestCount, 1);
    });
  });

  group('RateLimit middleware', () {
    late RateLimitStore store;

    setUp(() => store = RateLimitStore());
    tearDown(() => store.dispose());

    test('allows requests within limit', () async {
      final ctx = TestContext.get('/');
      final middleware = RateLimit(
        const RateLimitOptions(maxRequests: 5, windowMs: 60000),
        store,
      );
      var called = false;
      await middleware.handle(ctx, () async {
        called = true;
      });
      expect(called, isTrue);
      expect(ctx.response.isClosed, isFalse);
    });

    test('rejects requests exceeding limit', () async {
      final middleware = RateLimit(
        const RateLimitOptions(maxRequests: 2, windowMs: 60000),
        store,
      );

      for (var i = 0; i < 2; i++) {
        final ctx = TestContext.get('/');
        await middleware.handle(ctx, () async {});
      }

      final ctx = TestContext.get('/');
      var called = false;
      await runMiddleware(
        middleware,
        ctx,
        () async {
          called = true;
        },
      );
      expect(called, isFalse);
      expect(ctx.response.statusCode, HttpStatus.tooManyRequests);
      expect(ctx.response.isClosed, isTrue);
    });

    test('adds rate limit headers', () async {
      final ctx = TestContext.get('/');
      final middleware = RateLimit(
        const RateLimitOptions(maxRequests: 10, windowMs: 60000),
        store,
      );
      await middleware.handle(ctx, () async {});
      expect(ctx.response.headers.value('x-ratelimit-limit'), '10');
      expect(ctx.response.headers.value('x-ratelimit-remaining'), '9');
      expect(ctx.response.headers.value('x-ratelimit-reset'), isNotNull);
    });

    test('does not add headers when disabled', () async {
      final ctx = TestContext.get('/');
      final middleware = RateLimit(
        const RateLimitOptions(
          maxRequests: 10,
          windowMs: 60000,
          includeHeaders: false,
        ),
        store,
      );
      await middleware.handle(ctx, () async {});
      expect(ctx.response.headers.value('x-ratelimit-limit'), isNull);
    });

    test('adds Retry-After header on 429', () async {
      final middleware = RateLimit(
        const RateLimitOptions(maxRequests: 1, windowMs: 60000),
        store,
      );
      await middleware.handle(TestContext.get('/'), () async {});

      final ctx = TestContext.get('/');
      await runMiddleware(middleware, ctx, () async {});
      expect(ctx.response.headers.value('retry-after'), isNotNull);
    });

    test('uses custom error message', () async {
      final middleware = RateLimit(
        const RateLimitOptions(
          maxRequests: 1,
          windowMs: 60000,
          errorMessage: 'Custom limit message',
        ),
        store,
      );
      await middleware.handle(TestContext.get('/'), () async {});

      final ctx = TestContext.get('/');
      await runMiddleware(middleware, ctx, () async {});
      expect(ctx.response.body, contains('Custom limit message'));
    });

    test('tracks different IPs separately', () async {
      final middleware = RateLimit(
        const RateLimitOptions(maxRequests: 2, windowMs: 60000),
        store,
      );

      for (var i = 0; i < 2; i++) {
        await middleware.handle(
          TestContext.get('/', remoteIp: '192.168.1.1'),
          () async {},
        );
      }

      var called = false;
      await middleware.handle(
        TestContext.get('/', remoteIp: '192.168.1.1'),
        () async {
          called = true;
        },
      );
      expect(called, isFalse);

      called = false;
      await middleware.handle(
        TestContext.get('/', remoteIp: '192.168.1.2'),
        () async {
          called = true;
        },
      );
      expect(called, isTrue);
    });

    test('uses custom key extractor', () async {
      final middleware = RateLimit(
        RateLimitOptions(
          maxRequests: 2,
          windowMs: 60000,
          keyExtractor: (_) => 'custom-key',
        ),
        store,
      );

      await middleware.handle(
        TestContext.get('/', remoteIp: '192.168.1.1'),
        () async {},
      );
      await middleware.handle(
        TestContext.get('/', remoteIp: '192.168.1.2'),
        () async {},
      );

      var called = false;
      await middleware.handle(
        TestContext.get('/', remoteIp: '192.168.1.3'),
        () async {
          called = true;
        },
      );
      expect(called, isFalse);
    });

    test('calls onLimitReached callback', () async {
      RateLimitInfo? capturedInfo;
      final middleware = RateLimit(
        RateLimitOptions(
          maxRequests: 1,
          windowMs: 60000,
          onLimitReached: (ctx, info) => capturedInfo = info,
        ),
        store,
      );

      await middleware.handle(TestContext.get('/'), () async {});
      await middleware.handle(TestContext.get('/'), () async {});

      expect(capturedInfo, isNotNull);
      expect(capturedInfo!.isExceeded, isTrue);
    });

    test('resets after window expires', () async {
      final middleware = RateLimit(
        const RateLimitOptions(maxRequests: 2, windowMs: 50),
        store,
      );

      await middleware.handle(TestContext.get('/'), () async {});
      await middleware.handle(TestContext.get('/'), () async {});

      var called = false;
      await middleware.handle(TestContext.get('/'), () async {
        called = true;
      });
      expect(called, isFalse);

      await Future.delayed(const Duration(milliseconds: 60));

      called = false;
      await middleware.handle(TestContext.get('/'), () async {
        called = true;
      });
      expect(called, isTrue);
    });

    test('remaining count decreases correctly', () async {
      final middleware = RateLimit(
        const RateLimitOptions(maxRequests: 5, windowMs: 60000),
        store,
      );

      for (var i = 0; i < 4; i++) {
        final ctx = TestContext.get('/');
        await middleware.handle(ctx, () async {});
        expect(ctx.response.headers.value('x-ratelimit-remaining'), '${4 - i}');
      }
    });

    test('works with perSecond option', () async {
      final middleware = RateLimit(const RateLimitOptions.perSecond(2), store);

      await middleware.handle(TestContext.get('/'), () async {});
      await middleware.handle(TestContext.get('/'), () async {});

      var called = false;
      await middleware.handle(TestContext.get('/'), () async {
        called = true;
      });
      expect(called, isFalse);
    });

    test('works with perMinute option', () async {
      final middleware = RateLimit(const RateLimitOptions.perMinute(3), store);

      for (var i = 0; i < 3; i++) {
        var called = false;
        await middleware.handle(TestContext.get('/'), () async {
          called = true;
        });
        expect(called, isTrue);
      }

      var called = false;
      await middleware.handle(TestContext.get('/'), () async {
        called = true;
      });
      expect(called, isFalse);
    });

    test('exposes store for manual control', () async {
      final middleware = RateLimit(
        const RateLimitOptions(maxRequests: 2, windowMs: 60000),
        store,
      );

      await middleware.handle(TestContext.get('/'), () async {});
      await middleware.handle(TestContext.get('/'), () async {});

      var called = false;
      await middleware.handle(TestContext.get('/'), () async {
        called = true;
      });
      expect(called, isFalse);

      middleware.store.reset('127.0.0.1');

      called = false;
      await middleware.handle(TestContext.get('/'), () async {
        called = true;
      });
      expect(called, isTrue);
    });
  });
}
