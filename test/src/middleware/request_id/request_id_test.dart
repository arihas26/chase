import 'package:chase/src/middleware/request_id/request_id.dart';
import 'package:chase/testing/testing.dart';
import 'package:test/test.dart';

void main() {
  group('RequestIdOptions', () {
    test('creates with default values', () {
      const options = RequestIdOptions();
      expect(options.headerName, 'X-Request-ID');
      expect(options.useExisting, isTrue);
      expect(options.setResponseHeader, isTrue);
      expect(options.generator, isNull);
    });

    test('creates with custom values', () {
      const options = RequestIdOptions(
        headerName: 'X-Correlation-ID',
        useExisting: false,
        setResponseHeader: false,
      );
      expect(options.headerName, 'X-Correlation-ID');
      expect(options.useExisting, isFalse);
      expect(options.setResponseHeader, isFalse);
    });

    test('alwaysNew sets useExisting to false', () {
      const options = RequestIdOptions.alwaysNew();
      expect(options.useExisting, isFalse);
      expect(options.setResponseHeader, isTrue);
    });

    test('withHeader sets custom header name', () {
      const options = RequestIdOptions.withHeader('X-Trace-ID');
      expect(options.headerName, 'X-Trace-ID');
      expect(options.useExisting, isTrue);
    });

    test('accepts custom generator', () {
      var counter = 0;
      final options = RequestIdOptions(generator: () => 'custom-${++counter}');
      expect(options.generator!(), 'custom-1');
      expect(options.generator!(), 'custom-2');
    });
  });

  group('RequestId middleware', () {
    test('generates a request ID when none exists', () async {
      final ctx = TestContext.get('/');
      await RequestId().handle(ctx, () async {});

      final requestId = ctx.get<String>('requestId');
      expect(requestId, isNotNull);
      expect(requestId, isNotEmpty);
    });

    test('generates UUID v4-like format', () async {
      final ctx = TestContext.get('/');
      await RequestId().handle(ctx, () async {});

      final requestId = ctx.get<String>('requestId');
      final uuidRegex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        caseSensitive: false,
      );
      expect(requestId, matches(uuidRegex));
    });

    test('uses existing request ID from header', () async {
      final ctx = TestContext.get('/', headers: {'x-request-id': 'existing-id-123'});
      await RequestId().handle(ctx, () async {});
      expect(ctx.get<String>('requestId'), 'existing-id-123');
    });

    test('generates new ID when useExisting is false', () async {
      final ctx = TestContext.get('/', headers: {'x-request-id': 'existing-id-123'});
      await RequestId(const RequestIdOptions.alwaysNew()).handle(ctx, () async {});
      expect(ctx.get<String>('requestId'), isNot('existing-id-123'));
    });

    test('adds request ID to response header', () async {
      final ctx = TestContext.get('/');
      await RequestId().handle(ctx, () async {});

      final requestId = ctx.get<String>('requestId');
      expect(ctx.response.headers.value('x-request-id'), requestId);
    });

    test('does not add response header when disabled', () async {
      final ctx = TestContext.get('/');
      await RequestId(const RequestIdOptions(setResponseHeader: false)).handle(ctx, () async {});
      expect(ctx.response.headers.value('x-request-id'), isNull);
    });

    test('uses custom header name', () async {
      final ctx = TestContext.get('/', headers: {'x-correlation-id': 'correlation-123'});
      await RequestId(const RequestIdOptions.withHeader('X-Correlation-ID')).handle(ctx, () async {});

      expect(ctx.get<String>('requestId'), 'correlation-123');
      expect(ctx.response.headers.value('x-correlation-id'), 'correlation-123');
    });

    test('uses custom generator', () async {
      var counter = 0;
      final ctx = TestContext.get('/');
      await RequestId(RequestIdOptions(generator: () => 'custom-${++counter}')).handle(ctx, () async {});
      expect(ctx.get<String>('requestId'), 'custom-1');
    });

    test('generates unique IDs for each request', () async {
      final middleware = RequestId();
      final ids = <String>{};

      for (var i = 0; i < 100; i++) {
        final ctx = TestContext.get('/');
        await middleware.handle(ctx, () async {});
        ids.add(ctx.get<String>('requestId')!);
      }

      expect(ids.length, 100);
    });

    test('stores requestId in context', () async {
      final ctx = TestContext.get('/');
      await RequestId().handle(ctx, () async {});
      expect(ctx.get<String>('requestId'), isNotNull);
    });

    test('works with default constructor', () async {
      final ctx = TestContext.get('/');
      await RequestId().handle(ctx, () async {});

      expect(ctx.get<String>('requestId'), isNotNull);
      expect(ctx.response.headers.value('x-request-id'), isNotNull);
    });

    test('custom generator overrides existing header when useExisting is false', () async {
      var counter = 0;
      final ctx = TestContext.get('/', headers: {'x-request-id': 'existing-id'});
      await RequestId(RequestIdOptions(
        useExisting: false,
        generator: () => 'generated-${++counter}',
      )).handle(ctx, () async {});

      expect(ctx.get<String>('requestId'), 'generated-1');
    });

    test('respects case-insensitive header matching', () async {
      final ctx = TestContext.get('/', headers: {'x-request-id': 'case-test-id'});
      await RequestId(const RequestIdOptions(headerName: 'X-REQUEST-ID')).handle(ctx, () async {});
      expect(ctx.get<String>('requestId'), 'case-test-id');
    });
  });
}
