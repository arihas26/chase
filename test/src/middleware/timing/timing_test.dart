import 'package:chase/chase.dart';
import 'package:chase/testing/testing.dart';
import 'package:test/test.dart';

void main() {
  group('Timing', () {
    group('basic functionality', () {
      test('adds Server-Timing header with total time', () async {
        final ctx = TestContext.get('/');
        final middleware = Timing();

        await middleware.handle(ctx, () async {
          await Future.delayed(Duration(milliseconds: 10));
        });

        final header = ctx.response.headers.value('Server-Timing');
        expect(header, isNotNull);
        expect(header, contains('total'));
        expect(header, contains('dur='));
        expect(header, contains('desc="Total Response Time"'));
      });

      test('respects total=false option', () async {
        final ctx = TestContext.get('/');
        final middleware = Timing(total: false);

        await middleware.handle(ctx, () async {});

        final header = ctx.response.headers.value('Server-Timing');
        expect(header, isNull);
      });

      test('uses custom totalDescription', () async {
        final ctx = TestContext.get('/');
        final middleware = Timing(totalDescription: 'Request Duration');

        await middleware.handle(ctx, () async {});

        final header = ctx.response.headers.value('Server-Timing');
        expect(header, contains('desc="Request Duration"'));
      });
    });

    group('startTime/endTime', () {
      test('measures duration between start and end', () async {
        final ctx = TestContext.get('/');
        final middleware = Timing(total: false);

        await middleware.handle(ctx, () async {
          startTime(ctx, 'operation');
          await Future.delayed(Duration(milliseconds: 10));
          endTime(ctx, 'operation');
        });

        final header = ctx.response.headers.value('Server-Timing');
        expect(header, isNotNull);
        expect(header, contains('operation'));
        expect(header, contains('dur='));
      });

      test('supports description in startTime', () async {
        final ctx = TestContext.get('/');
        final middleware = Timing(total: false);

        await middleware.handle(ctx, () async {
          startTime(ctx, 'db', description: 'Database query');
          endTime(ctx, 'db');
        });

        final header = ctx.response.headers.value('Server-Timing');
        expect(header, contains('desc="Database query"'));
      });

      test('handles multiple timers', () async {
        final ctx = TestContext.get('/');
        final middleware = Timing(total: false);

        await middleware.handle(ctx, () async {
          startTime(ctx, 'db');
          startTime(ctx, 'cache');
          endTime(ctx, 'cache');
          endTime(ctx, 'db');
        });

        final header = ctx.response.headers.value('Server-Timing');
        expect(header, contains('db'));
        expect(header, contains('cache'));
      });

      test('auto-ends unfinished timers when autoEnd=true', () async {
        final ctx = TestContext.get('/');
        final middleware = Timing(total: false, autoEnd: true);

        await middleware.handle(ctx, () async {
          startTime(ctx, 'unfinished');
          // Don't call endTime
        });

        final header = ctx.response.headers.value('Server-Timing');
        expect(header, contains('unfinished'));
      });
    });

    group('setMetric', () {
      test('adds metric with duration', () async {
        final ctx = TestContext.get('/');
        final middleware = Timing(total: false);

        await middleware.handle(ctx, () async {
          setMetric(ctx, 'custom', duration: 42.5);
        });

        final header = ctx.response.headers.value('Server-Timing');
        expect(header, contains('custom'));
        expect(header, contains('dur=42.50'));
      });

      test('adds metric with description', () async {
        final ctx = TestContext.get('/');
        final middleware = Timing(total: false);

        await middleware.handle(ctx, () async {
          setMetric(ctx, 'cache', desc: 'Cache lookup');
        });

        final header = ctx.response.headers.value('Server-Timing');
        expect(header, contains('desc="Cache lookup"'));
      });

      test('adds metric with value', () async {
        final ctx = TestContext.get('/');
        final middleware = Timing(total: false);

        await middleware.handle(ctx, () async {
          setMetric(ctx, 'region', value: 'us-west-1');
        });

        final header = ctx.response.headers.value('Server-Timing');
        expect(header, contains('region'));
        expect(header, contains('value="us-west-1"'));
      });

      test('adds metric with all options', () async {
        final ctx = TestContext.get('/');
        final middleware = Timing(total: false);

        await middleware.handle(ctx, () async {
          setMetric(ctx, 'db', duration: 25.0, desc: 'Database');
        });

        final header = ctx.response.headers.value('Server-Timing');
        expect(header, contains('db'));
        expect(header, contains('dur=25.00'));
        expect(header, contains('desc="Database"'));
      });
    });

    group('timeAsync', () {
      test('measures async operation', () async {
        final ctx = TestContext.get('/');
        final middleware = Timing(total: false);

        await middleware.handle(ctx, () async {
          final result = await timeAsync(ctx, 'fetch', () async {
            await Future.delayed(Duration(milliseconds: 5));
            return 'data';
          });
          expect(result, 'data');
        });

        final header = ctx.response.headers.value('Server-Timing');
        expect(header, contains('fetch'));
        expect(header, contains('dur='));
      });

      test('records metric even on exception', () async {
        final ctx = TestContext.get('/');
        final middleware = Timing(total: false);

        await middleware.handle(ctx, () async {
          try {
            await timeAsync(ctx, 'failing', () async {
              throw Exception('error');
            });
          } catch (_) {}
        });

        final header = ctx.response.headers.value('Server-Timing');
        expect(header, contains('failing'));
      });
    });

    group('enabled option', () {
      test('skips timing when enabled returns false', () async {
        final ctx = TestContext.get('/');
        final middleware = Timing(enabled: (_) => false);

        await middleware.handle(ctx, () async {
          setMetric(ctx, 'test', duration: 10.0);
        });

        final header = ctx.response.headers.value('Server-Timing');
        expect(header, isNull);
      });

      test('applies timing when enabled returns true', () async {
        final ctx = TestContext.get('/');
        final middleware = Timing(enabled: (_) => true);

        await middleware.handle(ctx, () async {});

        final header = ctx.response.headers.value('Server-Timing');
        expect(header, isNotNull);
      });
    });

    group('crossOrigin option', () {
      test('sets Timing-Allow-Origin header', () async {
        final ctx = TestContext.get('/');
        final middleware = Timing(crossOrigin: '*');

        await middleware.handle(ctx, () async {});

        final header = ctx.response.headers.value('Timing-Allow-Origin');
        expect(header, '*');
      });

      test('does not set header when null', () async {
        final ctx = TestContext.get('/');
        final middleware = Timing();

        await middleware.handle(ctx, () async {});

        final header = ctx.response.headers.value('Timing-Allow-Origin');
        expect(header, isNull);
      });
    });

    group('timing function', () {
      test('creates middleware via function', () async {
        final ctx = TestContext.get('/');
        final middleware = timing(totalDescription: 'Custom');

        await middleware.handle(ctx, () async {});

        final header = ctx.response.headers.value('Server-Timing');
        expect(header, contains('desc="Custom"'));
      });
    });

    group('header format', () {
      test('escapes quotes in description', () async {
        final ctx = TestContext.get('/');
        final middleware = Timing(total: false);

        await middleware.handle(ctx, () async {
          setMetric(ctx, 'test', desc: 'Say "hello"');
        });

        final header = ctx.response.headers.value('Server-Timing');
        expect(header, contains(r'desc="Say \"hello\""'));
      });

      test('combines multiple metrics with comma', () async {
        final ctx = TestContext.get('/');
        final middleware = Timing(total: false);

        await middleware.handle(ctx, () async {
          setMetric(ctx, 'a', duration: 1.0);
          setMetric(ctx, 'b', duration: 2.0);
        });

        final header = ctx.response.headers.value('Server-Timing');
        expect(header, contains('a;dur=1.00'));
        expect(header, contains('b;dur=2.00'));
        expect(header, contains(', '));
      });
    });
  });
}
