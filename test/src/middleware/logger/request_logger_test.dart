import 'package:zlogger/zlogger.dart';
import 'package:chase/src/middleware/logger/request_logger.dart';
import 'package:chase/testing/testing.dart';
import 'package:test/test.dart';

/// Test logger that captures log records.
class TestLogger implements Logger {
  final List<LogRecord> records = [];

  void log(LogRecord record) {
    records.add(record);
  }

  @override
  void debug(String message, [Map<String, dynamic>? fields]) {
    log(LogRecord(
      level: LogLevel.debug,
      message: message,
      timestamp: DateTime.now(),
      fields: fields ?? {},
    ));
  }

  @override
  void info(String message, [Map<String, dynamic>? fields]) {
    log(LogRecord(
      level: LogLevel.info,
      message: message,
      timestamp: DateTime.now(),
      fields: fields ?? {},
    ));
  }

  @override
  void warn(String message, [Map<String, dynamic>? fields]) {
    log(LogRecord(
      level: LogLevel.warn,
      message: message,
      timestamp: DateTime.now(),
      fields: fields ?? {},
    ));
  }

  @override
  void error(
    String message, [
    Map<String, dynamic>? fields,
    Object? error,
    StackTrace? stackTrace,
  ]) {
    log(LogRecord(
      level: LogLevel.error,
      message: message,
      timestamp: DateTime.now(),
      fields: fields ?? {},
      error: error,
      stackTrace: stackTrace,
    ));
  }

  @override
  Logger withFields(Map<String, dynamic> fields) => this;

  void clear() => records.clear();

  LogRecord? get lastRecord => records.isNotEmpty ? records.last : null;
}

void main() {
  late TestLogger testLogger;

  setUp(() {
    testLogger = TestLogger();
    LogConfig.global = testLogger;
  });

  tearDown(() {
    LogConfig.global = DefaultLogger();
  });

  group('RequestLogger', () {
    group('defaults', () {
      test('creates with default values', () {
        final logger = RequestLogger();
        expect(logger.requestIdHeader, 'X-Request-ID');
        expect(logger.useExistingRequestId, isTrue);
        expect(logger.setResponseHeader, isTrue);
        expect(logger.minLevel, LogLevel.info);
        expect(logger.skip, isNull);
        expect(logger.includeIp, isTrue);
        expect(logger.includeUserAgent, isFalse);
        expect(logger.slowThreshold, const Duration(seconds: 1));
      });

      test('creates with custom values', () {
        final logger = RequestLogger(
          requestIdHeader: 'X-Correlation-ID',
          useExistingRequestId: false,
          setResponseHeader: false,
          minLevel: LogLevel.warn,
          includeUserAgent: true,
          slowThreshold: const Duration(milliseconds: 500),
        );
        expect(logger.requestIdHeader, 'X-Correlation-ID');
        expect(logger.useExistingRequestId, isFalse);
        expect(logger.setResponseHeader, isFalse);
        expect(logger.minLevel, LogLevel.warn);
        expect(logger.includeUserAgent, isTrue);
        expect(logger.slowThreshold, const Duration(milliseconds: 500));
      });
    });

    group('request ID', () {
      test('generates request ID and stores in context', () async {
        final ctx = TestContext.get('/');

        await RequestLogger().handle(ctx, () async {});

        final requestId = ctx.get<String>('_requestId');
        expect(requestId, isNotNull);
        expect(requestId, matches(RegExp(r'^[a-f0-9-]{36}$')));
      });

      test('sets request ID in response header', () async {
        final ctx = TestContext.get('/');

        await RequestLogger().handle(ctx, () async {});

        expect(ctx.res.headers.value('X-Request-ID'), isNotNull);
      });

      test('uses custom header name', () async {
        final ctx = TestContext.get('/');

        await RequestLogger(requestIdHeader: 'X-Correlation-ID')
            .handle(ctx, () async {});

        expect(ctx.res.headers.value('X-Correlation-ID'), isNotNull);
      });

      test('uses existing request ID from header', () async {
        final ctx = TestContext.get(
          '/',
          headers: {'X-Request-ID': 'existing-id-123'},
        );

        await RequestLogger().handle(ctx, () async {});

        expect(ctx.get<String>('_requestId'), 'existing-id-123');
      });

      test('generates new ID when useExistingRequestId is false', () async {
        final ctx = TestContext.get(
          '/',
          headers: {'X-Request-ID': 'existing-id-123'},
        );

        await RequestLogger(useExistingRequestId: false)
            .handle(ctx, () async {});

        expect(ctx.get<String>('_requestId'), isNot('existing-id-123'));
      });

      test('uses custom ID generator', () async {
        var counter = 0;
        final ctx = TestContext.get('/');

        await RequestLogger(idGenerator: () => 'custom-${++counter}')
            .handle(ctx, () async {});

        expect(ctx.get<String>('_requestId'), 'custom-1');
      });

      test('does not set response header when disabled', () async {
        final ctx = TestContext.get('/');

        await RequestLogger(setResponseHeader: false).handle(ctx, () async {});

        expect(ctx.res.headers.value('X-Request-ID'), isNull);
      });
    });

    group('log context', () {
      test('includes request_id in log fields', () async {
        final ctx = TestContext.get('/');

        await RequestLogger().handle(ctx, () async {});

        expect(testLogger.lastRecord!.fields['request_id'], isNotNull);
      });

      test('includes custom fields from fieldsBuilder', () async {
        final ctx = TestContext.get('/');
        ctx.set('tenant', 'acme');

        await RequestLogger(
          fieldsBuilder: (ctx) => {'tenant': ctx.get<String>('tenant')},
        ).handle(ctx, () async {});

        expect(testLogger.lastRecord!.fields['tenant'], 'acme');
      });
    });

    group('request logging', () {
      test('calls next handler', () async {
        var nextCalled = false;
        final ctx = TestContext.get('/');

        await RequestLogger().handle(ctx, () async {
          nextCalled = true;
        });

        expect(nextCalled, isTrue);
      });

      test('logs request with method and path', () async {
        final ctx = TestContext.get('/api/users');
        ctx.res.statusCode = 200;

        await RequestLogger().handle(ctx, () async {});

        expect(testLogger.lastRecord, isNotNull);
        expect(testLogger.lastRecord!.message, 'GET /api/users');
        expect(testLogger.lastRecord!.level, LogLevel.info);
      });

      test('includes status and duration in fields', () async {
        final ctx = TestContext.get('/api/users');
        ctx.res.statusCode = 200;

        await RequestLogger().handle(ctx, () async {});

        final fields = testLogger.lastRecord!.fields;
        expect(fields['status'], 200);
        expect(fields['duration_ms'], isA<int>());
      });

      test('sets info level for 2xx responses', () async {
        final ctx = TestContext.get('/');
        ctx.res.statusCode = 201;

        await RequestLogger().handle(ctx, () async {});

        expect(testLogger.lastRecord!.level, LogLevel.info);
      });

      test('sets warn level for 4xx responses', () async {
        final ctx = TestContext.get('/');
        ctx.res.statusCode = 404;

        await RequestLogger().handle(ctx, () async {});

        expect(testLogger.lastRecord!.level, LogLevel.warn);
      });

      test('sets error level for 5xx responses', () async {
        final ctx = TestContext.get('/');
        ctx.res.statusCode = 500;

        await RequestLogger().handle(ctx, () async {});

        expect(testLogger.lastRecord!.level, LogLevel.error);
      });

      test('sets warn level for slow requests', () async {
        final logger = RequestLogger(
          slowThreshold: const Duration(milliseconds: 10),
        );

        final ctx = TestContext.get('/');
        ctx.res.statusCode = 200;

        await logger.handle(ctx, () async {
          await Future.delayed(const Duration(milliseconds: 20));
        });

        expect(testLogger.lastRecord!.level, LogLevel.warn);
      });

      test('skips logging when skip returns true', () async {
        final logger = RequestLogger(
          skip: (ctx) => ctx.req.path == '/health',
        );

        final ctx = TestContext.get('/health');

        await logger.handle(ctx, () async {});

        expect(testLogger.records, isEmpty);
      });

      test('still sets request ID even when skip returns true', () async {
        final logger = RequestLogger(
          skip: (ctx) => ctx.req.path == '/health',
        );

        final ctx = TestContext.get('/health');

        await logger.handle(ctx, () async {});

        expect(ctx.get<String>('_requestId'), isNotNull);
      });

      test('logs when skip returns false', () async {
        final logger = RequestLogger(
          skip: (ctx) => ctx.req.path == '/health',
        );

        final ctx = TestContext.get('/api/users');

        await logger.handle(ctx, () async {});

        expect(testLogger.records, isNotEmpty);
      });

      test('respects minLevel filter', () async {
        final logger = RequestLogger(minLevel: LogLevel.warn);

        final ctx = TestContext.get('/');
        ctx.res.statusCode = 200;

        await logger.handle(ctx, () async {});

        // info level should be filtered out when minLevel is warn
        expect(testLogger.records, isEmpty);
      });

      test('logs warn and above when minLevel is warn', () async {
        final logger = RequestLogger(minLevel: LogLevel.warn);

        final ctx = TestContext.get('/');
        ctx.res.statusCode = 404;

        await logger.handle(ctx, () async {});

        expect(testLogger.records, isNotEmpty);
        expect(testLogger.lastRecord!.level, LogLevel.warn);
      });

      test('captures error on exception', () async {
        final ctx = TestContext.get('/');

        try {
          await RequestLogger().handle(ctx, () async {
            throw Exception('Test error');
          });
        } catch (_) {}

        expect(testLogger.lastRecord, isNotNull);
        expect(testLogger.lastRecord!.level, LogLevel.error);
        expect(testLogger.lastRecord!.error, isNotNull);
      });

      test('rethrows exception after logging', () async {
        final ctx = TestContext.get('/');

        expect(
          () => RequestLogger().handle(ctx, () async {
            throw Exception('Test error');
          }),
          throwsException,
        );
      });

      test('includes IP when configured', () async {
        final logger = RequestLogger(includeIp: true);

        final ctx = TestContext.get('/', remoteIp: '10.0.0.1');

        await logger.handle(ctx, () async {});

        expect(testLogger.lastRecord!.fields['ip'], '10.0.0.1');
      });

      test('excludes IP when configured', () async {
        final logger = RequestLogger(includeIp: false);

        final ctx = TestContext.get('/', remoteIp: '10.0.0.1');

        await logger.handle(ctx, () async {});

        expect(testLogger.lastRecord!.fields.containsKey('ip'), isFalse);
      });

      test('includes User-Agent when configured', () async {
        final logger = RequestLogger(includeUserAgent: true);

        final ctx = TestContext.get(
          '/',
          headers: {'user-agent': 'TestAgent/1.0'},
        );

        await logger.handle(ctx, () async {});

        expect(testLogger.lastRecord!.fields['user_agent'], 'TestAgent/1.0');
      });

      test('excludes User-Agent by default', () async {
        final ctx = TestContext.get(
          '/',
          headers: {'user-agent': 'TestAgent/1.0'},
        );

        await RequestLogger().handle(ctx, () async {});

        expect(
            testLogger.lastRecord!.fields.containsKey('user_agent'), isFalse);
      });

      test('includes query string in fields', () async {
        final ctx = TestContext.get('/search?q=test&page=1');

        await RequestLogger().handle(ctx, () async {});

        expect(testLogger.lastRecord!.fields['query'], 'q=test&page=1');
      });

      test('measures duration correctly', () async {
        final ctx = TestContext.get('/');

        await RequestLogger().handle(ctx, () async {
          await Future.delayed(const Duration(milliseconds: 50));
        });

        expect(
          testLogger.lastRecord!.fields['duration_ms'],
          greaterThanOrEqualTo(50),
        );
      });

      test('uses named logger when name is provided', () async {
        final logger = RequestLogger(name: 'HTTP');

        final ctx = TestContext.get('/');

        await logger.handle(ctx, () async {});

        expect(testLogger.lastRecord!.fields['logger'], 'HTTP');
      });
    });
  });
}
