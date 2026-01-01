import 'package:chase/src/core/logger.dart';
import 'package:chase/src/middleware/logger/logger.dart';
import 'package:chase/testing/testing.dart';
import 'package:test/test.dart';

void main() {
  group('LogLevel', () {
    test('has correct order', () {
      expect(LogLevel.debug.index, 0);
      expect(LogLevel.info.index, 1);
      expect(LogLevel.warn.index, 2);
      expect(LogLevel.error.index, 3);
    });
  });

  group('LogEntry', () {
    test('toJson returns correct structure', () {
      final entry = LogEntry(
        timestamp: DateTime.parse('2024-01-15T10:30:00Z'),
        method: 'GET',
        path: '/api/users',
        query: 'page=1',
        status: 200,
        duration: const Duration(milliseconds: 45),
        requestId: 'req-123',
        ip: '192.168.1.1',
        userAgent: 'TestClient/1.0',
        level: LogLevel.info,
      );

      final json = entry.toJson();
      expect(json['timestamp'], '2024-01-15T10:30:00.000Z');
      expect(json['method'], 'GET');
      expect(json['path'], '/api/users');
      expect(json['query'], 'page=1');
      expect(json['status'], 200);
      expect(json['duration_ms'], 45);
      expect(json['request_id'], 'req-123');
      expect(json['ip'], '192.168.1.1');
      expect(json['user_agent'], 'TestClient/1.0');
      expect(json['level'], 'info');
    });

    test('toJson excludes null fields', () {
      final entry = LogEntry(
        timestamp: DateTime.parse('2024-01-15T10:30:00Z'),
        method: 'GET',
        path: '/api/users',
        status: 200,
        duration: const Duration(milliseconds: 45),
        level: LogLevel.info,
      );

      final json = entry.toJson();
      expect(json.containsKey('query'), isFalse);
      expect(json.containsKey('request_id'), isFalse);
      expect(json.containsKey('ip'), isFalse);
      expect(json.containsKey('user_agent'), isFalse);
      expect(json.containsKey('message'), isFalse);
      expect(json.containsKey('error'), isFalse);
    });

    test('toJson excludes empty query', () {
      final entry = LogEntry(
        timestamp: DateTime.parse('2024-01-15T10:30:00Z'),
        method: 'GET',
        path: '/api/users',
        query: '',
        status: 200,
        duration: const Duration(milliseconds: 45),
        level: LogLevel.info,
      );

      final json = entry.toJson();
      expect(json.containsKey('query'), isFalse);
    });

    test('toJson includes error when present', () {
      final entry = LogEntry(
        timestamp: DateTime.parse('2024-01-15T10:30:00Z'),
        method: 'GET',
        path: '/api/users',
        status: 500,
        duration: const Duration(milliseconds: 45),
        level: LogLevel.error,
        error: Exception('Something went wrong'),
      );

      final json = entry.toJson();
      expect(json['error'], contains('Something went wrong'));
    });

    test('toText formats correctly', () {
      final entry = LogEntry(
        timestamp: DateTime.parse('2024-01-15T10:30:00Z'),
        method: 'GET',
        path: '/api/users',
        query: 'page=1',
        status: 200,
        duration: const Duration(milliseconds: 45),
        requestId: 'req-123',
        level: LogLevel.info,
      );

      final text = entry.toText();
      expect(text, contains('2024-01-15'));
      expect(text, contains('[INFO]'));
      expect(text, contains('GET /api/users?page=1'));
      expect(text, contains('200'));
      expect(text, contains('45ms'));
      expect(text, contains('req_id=req-123'));
    });

    test('toText excludes query when empty', () {
      final entry = LogEntry(
        timestamp: DateTime.parse('2024-01-15T10:30:00Z'),
        method: 'GET',
        path: '/api/users',
        status: 200,
        duration: const Duration(milliseconds: 45),
        level: LogLevel.info,
      );

      final text = entry.toText();
      expect(text, contains('GET /api/users 200'));
      expect(text, isNot(contains('?')));
    });
  });

  group('Logger defaults', () {
    test('creates with default values', () {
      const logger = Logger();
      expect(logger.level, LogLevel.info);
      expect(logger.json, isFalse);
      expect(logger.onLog, isNull);
      expect(logger.skip, isNull);
      expect(logger.includeRequestId, isTrue);
      expect(logger.includeIp, isTrue);
      expect(logger.includeUserAgent, isFalse);
      expect(logger.slowThreshold, const Duration(seconds: 1));
      expect(logger.colored, isTrue);
    });

    test('creates with custom values', () {
      final logger = Logger(
        level: LogLevel.warn,
        json: true,
        includeUserAgent: true,
        slowThreshold: const Duration(milliseconds: 500),
        colored: false,
      );
      expect(logger.level, LogLevel.warn);
      expect(logger.json, isTrue);
      expect(logger.includeUserAgent, isTrue);
      expect(logger.slowThreshold, const Duration(milliseconds: 500));
      expect(logger.colored, isFalse);
    });
  });

  group('Logger middleware', () {
    test('calls next handler', () async {
      var nextCalled = false;
      final ctx = TestContext.get('/');

      await Logger(onLog: (_) {}).handle(ctx, () async {
        nextCalled = true;
      });

      expect(nextCalled, isTrue);
    });

    test('captures log entry with onLog callback', () async {
      LogEntry? capturedEntry;
      final logger = Logger(onLog: (entry) => capturedEntry = entry);

      final ctx = TestContext.get('/api/users');
      ctx.res.statusCode = 200;

      await logger.handle(ctx, () async {});

      expect(capturedEntry, isNotNull);
      expect(capturedEntry!.method, 'GET');
      expect(capturedEntry!.path, '/api/users');
      expect(capturedEntry!.status, 200);
      expect(capturedEntry!.level, LogLevel.info);
    });

    test('sets info level for 2xx responses', () async {
      LogEntry? capturedEntry;
      final logger = Logger(onLog: (entry) => capturedEntry = entry);

      final ctx = TestContext.get('/');
      ctx.res.statusCode = 201;

      await logger.handle(ctx, () async {});

      expect(capturedEntry!.level, LogLevel.info);
    });

    test('sets warn level for 4xx responses', () async {
      LogEntry? capturedEntry;
      final logger = Logger(onLog: (entry) => capturedEntry = entry);

      final ctx = TestContext.get('/');
      ctx.res.statusCode = 404;

      await logger.handle(ctx, () async {});

      expect(capturedEntry!.level, LogLevel.warn);
    });

    test('sets error level for 5xx responses', () async {
      LogEntry? capturedEntry;
      final logger = Logger(onLog: (entry) => capturedEntry = entry);

      final ctx = TestContext.get('/');
      ctx.res.statusCode = 500;

      await logger.handle(ctx, () async {});

      expect(capturedEntry!.level, LogLevel.error);
    });

    test('sets warn level for slow requests', () async {
      LogEntry? capturedEntry;
      final logger = Logger(
        onLog: (entry) => capturedEntry = entry,
        slowThreshold: const Duration(milliseconds: 10),
      );

      final ctx = TestContext.get('/');
      ctx.res.statusCode = 200;

      await logger.handle(ctx, () async {
        await Future.delayed(const Duration(milliseconds: 20));
      });

      expect(capturedEntry!.level, LogLevel.warn);
    });

    test('skips logging when skip returns true', () async {
      LogEntry? capturedEntry;
      final logger = Logger(
        onLog: (entry) => capturedEntry = entry,
        skip: (ctx) => ctx.req.path == '/health',
      );

      final ctx = TestContext.get('/health');

      await logger.handle(ctx, () async {});

      expect(capturedEntry, isNull);
    });

    test('logs when skip returns false', () async {
      LogEntry? capturedEntry;
      final logger = Logger(
        onLog: (entry) => capturedEntry = entry,
        skip: (ctx) => ctx.req.path == '/health',
      );

      final ctx = TestContext.get('/api/users');

      await logger.handle(ctx, () async {});

      expect(capturedEntry, isNotNull);
    });

    test('respects log level filter', () async {
      LogEntry? capturedEntry;
      final logger = Logger(
        level: LogLevel.warn,
        onLog: (entry) => capturedEntry = entry,
      );

      final ctx = TestContext.get('/');
      ctx.res.statusCode = 200;

      await logger.handle(ctx, () async {});

      // info level should be filtered out when level is warn
      expect(capturedEntry, isNull);
    });

    test('logs warn and above when level is warn', () async {
      LogEntry? capturedEntry;
      final logger = Logger(
        level: LogLevel.warn,
        onLog: (entry) => capturedEntry = entry,
      );

      final ctx = TestContext.get('/');
      ctx.res.statusCode = 404;

      await logger.handle(ctx, () async {});

      expect(capturedEntry, isNotNull);
      expect(capturedEntry!.level, LogLevel.warn);
    });

    test('captures error on exception', () async {
      LogEntry? capturedEntry;
      final logger = Logger(onLog: (entry) => capturedEntry = entry);

      final ctx = TestContext.get('/');

      try {
        await logger.handle(ctx, () async {
          throw Exception('Test error');
        });
      } catch (_) {}

      expect(capturedEntry, isNotNull);
      expect(capturedEntry!.level, LogLevel.error);
      expect(capturedEntry!.error, isNotNull);
    });

    test('rethrows exception after logging', () async {
      final logger = Logger(onLog: (_) {});

      final ctx = TestContext.get('/');

      expect(
        () => logger.handle(ctx, () async {
          throw Exception('Test error');
        }),
        throwsException,
      );
    });

    test('includes IP when configured', () async {
      LogEntry? capturedEntry;
      final logger = Logger(
        includeIp: true,
        onLog: (entry) => capturedEntry = entry,
      );

      final ctx = TestContext.get('/', remoteIp: '10.0.0.1');

      await logger.handle(ctx, () async {});

      expect(capturedEntry!.ip, '10.0.0.1');
    });

    test('excludes IP when configured', () async {
      LogEntry? capturedEntry;
      final logger = Logger(
        includeIp: false,
        onLog: (entry) => capturedEntry = entry,
      );

      final ctx = TestContext.get('/', remoteIp: '10.0.0.1');

      await logger.handle(ctx, () async {});

      expect(capturedEntry!.ip, isNull);
    });

    test('includes User-Agent when configured', () async {
      LogEntry? capturedEntry;
      final logger = Logger(
        includeUserAgent: true,
        onLog: (entry) => capturedEntry = entry,
      );

      final ctx = TestContext.get(
        '/',
        headers: {'user-agent': 'TestAgent/1.0'},
      );

      await logger.handle(ctx, () async {});

      expect(capturedEntry!.userAgent, 'TestAgent/1.0');
    });

    test('excludes User-Agent by default', () async {
      LogEntry? capturedEntry;
      final logger = Logger(onLog: (entry) => capturedEntry = entry);

      final ctx = TestContext.get(
        '/',
        headers: {'user-agent': 'TestAgent/1.0'},
      );

      await logger.handle(ctx, () async {});

      expect(capturedEntry!.userAgent, isNull);
    });

    test('captures query string', () async {
      LogEntry? capturedEntry;
      final logger = Logger(onLog: (entry) => capturedEntry = entry);

      final ctx = TestContext.get('/search?q=test&page=1');

      await logger.handle(ctx, () async {});

      expect(capturedEntry!.query, 'q=test&page=1');
    });

    test('measures duration correctly', () async {
      LogEntry? capturedEntry;
      final logger = Logger(onLog: (entry) => capturedEntry = entry);

      final ctx = TestContext.get('/');

      await logger.handle(ctx, () async {
        await Future.delayed(const Duration(milliseconds: 50));
      });

      expect(capturedEntry!.duration.inMilliseconds, greaterThanOrEqualTo(50));
    });

    test('includes requestId from context', () async {
      LogEntry? capturedEntry;
      final logger = Logger(
        includeRequestId: true,
        onLog: (entry) => capturedEntry = entry,
      );

      final ctx = TestContext.get('/');
      ctx.set('requestId', 'test-request-id-123');

      await logger.handle(ctx, () async {});

      expect(capturedEntry!.requestId, 'test-request-id-123');
    });

    test('excludes requestId when configured', () async {
      LogEntry? capturedEntry;
      final logger = Logger(
        includeRequestId: false,
        onLog: (entry) => capturedEntry = entry,
      );

      final ctx = TestContext.get('/');
      ctx.set('requestId', 'test-request-id-123');

      await logger.handle(ctx, () async {});

      expect(capturedEntry!.requestId, isNull);
    });

    test('works with default constructor', () async {
      var nextCalled = false;
      final ctx = TestContext.get('/');

      // Use onLog to suppress output during test
      await Logger(onLog: (_) {}).handle(ctx, () async {
        nextCalled = true;
      });

      expect(nextCalled, isTrue);
    });
  });
}
