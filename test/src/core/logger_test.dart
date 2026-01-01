import 'package:chase/chase.dart';
import 'package:chase/testing/testing.dart';
import 'package:test/test.dart';

void main() {
  group('LogLevel', () {
    test('has correct order', () {
      expect(LogLevel.debug.index, lessThan(LogLevel.info.index));
      expect(LogLevel.info.index, lessThan(LogLevel.warn.index));
      expect(LogLevel.warn.index, lessThan(LogLevel.error.index));
    });
  });

  group('LogRecord', () {
    test('toJson includes all fields', () {
      final record = LogRecord(
        timestamp: DateTime(2025, 1, 1, 12, 0, 0),
        level: LogLevel.info,
        message: 'Test message',
        fields: {'userId': 123, 'action': 'login'},
      );

      final json = record.toJson();

      expect(json['time'], '2025-01-01T12:00:00.000');
      expect(json['level'], 'info');
      expect(json['msg'], 'Test message');
      expect(json['userId'], 123);
      expect(json['action'], 'login');
    });

    test('toJson includes error when present', () {
      final record = LogRecord(
        timestamp: DateTime(2025, 1, 1),
        level: LogLevel.error,
        message: 'Error occurred',
        error: Exception('Test error'),
      );

      final json = record.toJson();

      expect(json['error'], contains('Test error'));
    });
  });

  group('DefaultLogger', () {
    test('logs at or above minLevel', () {
      final logs = <LogRecord>[];
      final logger = DefaultLogger(
        minLevel: LogLevel.info,
        handler: logs.add,
      );

      logger.debug('debug message');
      logger.info('info message');
      logger.warn('warn message');

      expect(logs.length, 2);
      expect(logs[0].level, LogLevel.info);
      expect(logs[1].level, LogLevel.warn);
    });

    test('includes fields in log record', () {
      final logs = <LogRecord>[];
      final logger = DefaultLogger(handler: logs.add);

      logger.info('message', {'key': 'value'});

      expect(logs.single.fields['key'], 'value');
    });

    test('withFields creates child logger with default fields', () {
      final logs = <LogRecord>[];
      final logger = DefaultLogger(handler: logs.add);
      final childLogger = logger.withFields({'service': 'auth'});

      childLogger.info('login attempt', {'userId': 123});

      expect(logs.single.fields['service'], 'auth');
      expect(logs.single.fields['userId'], 123);
    });

    test('error includes error and stackTrace', () {
      final logs = <LogRecord>[];
      final logger = DefaultLogger(handler: logs.add);

      try {
        throw Exception('Test error');
      } catch (e, st) {
        logger.error('failed', {'operation': 'test'}, e, st);
      }

      expect(logs.single.error, isA<Exception>());
      expect(logs.single.stackTrace, isNotNull);
      expect(logs.single.fields['operation'], 'test');
    });
  });

  group('NullLogger', () {
    test('does nothing', () {
      const logger = NullLogger();

      // These should not throw
      logger.debug('message');
      logger.info('message');
      logger.warn('message');
      logger.error('message');
    });

    test('withFields returns self', () {
      const logger = NullLogger();
      final child = logger.withFields({'key': 'value'});

      expect(child, same(logger));
    });
  });

  group('ChaseLoggerConfig', () {
    tearDown(() {
      // Reset global logger after each test
      ChaseLoggerConfig.global = const DefaultLogger();
    });

    test('global logger can be set and retrieved', () {
      final logs = <LogRecord>[];
      final customLogger = DefaultLogger(handler: logs.add);

      ChaseLoggerConfig.global = customLogger;
      ChaseLoggerConfig.global.info('test');

      expect(logs.length, 1);
    });
  });

  group('Chase.log', () {
    late Chase app;

    setUp(() {
      app = Chase();
    });

    tearDown(() {
      ChaseLoggerConfig.global = const DefaultLogger();
    });

    test('returns global logger', () {
      final logs = <LogRecord>[];
      app.logger = DefaultLogger(handler: logs.add);

      app.log.info('app started');

      expect(logs.length, 1);
      expect(logs.single.message, 'app started');
    });

    test('logger setter updates global logger', () {
      final logs = <LogRecord>[];
      final customLogger = DefaultLogger(handler: logs.add);

      app.logger = customLogger;

      expect(ChaseLoggerConfig.global, same(customLogger));
    });
  });

  group('Context.log', () {
    late Chase app;
    late TestClient client;

    setUp(() {
      app = Chase();
      ChaseLoggerConfig.global = const DefaultLogger();
    });

    tearDown(() async {
      await client.close();
      ChaseLoggerConfig.global = const DefaultLogger();
    });

    test('returns logger from global config', () async {
      final logs = <LogRecord>[];
      app.logger = DefaultLogger(handler: logs.add);

      app.get('/test').handle((ctx) {
        ctx.log.info('handler called');
        ctx.res.text('ok');
      });

      client = await TestClient.start(app);
      await client.get('/test');

      expect(logs.length, 1);
      expect(logs.single.message, 'handler called');
    });

    test('includes request_id when available', () async {
      final logs = <LogRecord>[];
      app.logger = DefaultLogger(handler: logs.add);

      app.use(RequestId());
      app.get('/test').handle((ctx) {
        ctx.log.info('with request id');
        ctx.res.text('ok');
      });

      client = await TestClient.start(app);
      await client.get('/test');

      expect(logs.length, 1);
      expect(logs.single.fields['request_id'], isNotNull);
    });

    test('caches logger instance', () async {
      app.get('/test').handle((ctx) {
        final log1 = ctx.log;
        final log2 = ctx.log;
        expect(log1, same(log2));
        ctx.res.text('ok');
      });

      client = await TestClient.start(app);
      await client.get('/test');
    });
  });
}
