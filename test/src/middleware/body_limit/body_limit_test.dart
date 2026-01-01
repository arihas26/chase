import 'dart:io';

import 'package:chase/src/middleware/body_limit/body_limit.dart';
import 'package:chase/testing/testing.dart';
import 'package:test/test.dart';

void main() {
  group('BodyLimitOptions', () {
    test('creates with default values', () {
      const options = BodyLimitOptions();
      expect(options.maxSize, 1048576); // 1MB
      expect(options.errorMessage, isNull);
      expect(options.includeLimit, isTrue);
    });

    test('creates with custom maxSize', () {
      const options = BodyLimitOptions(maxSize: 2048);
      expect(options.maxSize, 2048);
    });

    test('creates with kilobytes', () {
      const options = BodyLimitOptions.kb(500);
      expect(options.maxSize, 512000); // 500KB
      expect(options.includeLimit, isTrue);
    });

    test('creates with megabytes', () {
      const options = BodyLimitOptions.mb(10);
      expect(options.maxSize, 10485760); // 10MB
      expect(options.includeLimit, isTrue);
    });

    test('creates with custom error message', () {
      const options = BodyLimitOptions(
        maxSize: 1024,
        errorMessage: 'Custom error',
      );
      expect(options.errorMessage, 'Custom error');
    });

    test('creates with includeLimit false', () {
      const options = BodyLimitOptions(maxSize: 1024, includeLimit: false);
      expect(options.includeLimit, isFalse);
    });

    test('kb constructor with custom options', () {
      const options = BodyLimitOptions.kb(
        100,
        errorMessage: 'Too large',
        includeLimit: false,
      );
      expect(options.maxSize, 102400); // 100KB
      expect(options.errorMessage, 'Too large');
      expect(options.includeLimit, isFalse);
    });

    test('mb constructor with custom options', () {
      const options = BodyLimitOptions.mb(
        5,
        errorMessage: 'File too big',
        includeLimit: false,
      );
      expect(options.maxSize, 5242880); // 5MB
      expect(options.errorMessage, 'File too big');
      expect(options.includeLimit, isFalse);
    });
  });

  group('BodyLimit middleware', () {
    test('allows requests with no Content-Length header', () async {
      final ctx = TestContext.create('GET', '/', contentLength: -1);
      var called = false;
      await BodyLimit(const BodyLimitOptions(maxSize: 1024)).handle(
        ctx,
        () async {
          called = true;
        },
      );
      expect(called, isTrue);
      expect(ctx.response.isClosed, isFalse);
    });

    test('allows requests with zero Content-Length', () async {
      final ctx = TestContext.create('GET', '/', contentLength: 0);
      var called = false;
      await BodyLimit(const BodyLimitOptions(maxSize: 1024)).handle(
        ctx,
        () async {
          called = true;
        },
      );
      expect(called, isTrue);
      expect(ctx.response.isClosed, isFalse);
    });

    test('allows requests below the size limit', () async {
      final ctx = TestContext.create('POST', '/', contentLength: 512);
      var called = false;
      await BodyLimit(const BodyLimitOptions(maxSize: 1024)).handle(
        ctx,
        () async {
          called = true;
        },
      );
      expect(called, isTrue);
      expect(ctx.response.isClosed, isFalse);
    });

    test('allows requests equal to the size limit', () async {
      final ctx = TestContext.create('POST', '/', contentLength: 1024);
      var called = false;
      await BodyLimit(const BodyLimitOptions(maxSize: 1024)).handle(
        ctx,
        () async {
          called = true;
        },
      );
      expect(called, isTrue);
      expect(ctx.response.isClosed, isFalse);
    });

    test('rejects requests exceeding the size limit', () async {
      final ctx = TestContext.create('POST', '/', contentLength: 2048);
      var called = false;
      await BodyLimit(const BodyLimitOptions(maxSize: 1024)).handle(
        ctx,
        () async {
          called = true;
        },
      );
      expect(called, isFalse);
      expect(ctx.response.statusCode, HttpStatus.requestEntityTooLarge);
      expect(ctx.response.isClosed, isTrue);
      expect(ctx.response.body, contains('too large'));
    });

    test('rejects with default error message including sizes', () async {
      final ctx = TestContext.create('POST', '/', contentLength: 2048);
      await BodyLimit(
        const BodyLimitOptions(maxSize: 1024),
      ).handle(ctx, () async {});
      expect(ctx.response.body, contains('too large'));
      expect(ctx.response.body, contains('Maximum size:'));
      expect(ctx.response.body, contains('received:'));
    });

    test('rejects with custom error message', () async {
      final ctx = TestContext.create('POST', '/', contentLength: 2048);
      await BodyLimit(
        const BodyLimitOptions(
          maxSize: 1024,
          errorMessage: 'Custom error: body too large',
        ),
      ).handle(ctx, () async {});
      expect(ctx.response.body, 'Custom error: body too large');
    });

    test('rejects with generic message when includeLimit is false', () async {
      final ctx = TestContext.create('POST', '/', contentLength: 2048);
      await BodyLimit(
        const BodyLimitOptions(maxSize: 1024, includeLimit: false),
      ).handle(ctx, () async {});
      expect(ctx.response.body, 'Request body too large');
      expect(ctx.response.body, isNot(contains('Maximum size:')));
    });

    test('formats bytes correctly in error message', () async {
      final ctx = TestContext.create('POST', '/', contentLength: 512);
      await BodyLimit(
        const BodyLimitOptions(maxSize: 256),
      ).handle(ctx, () async {});
      expect(ctx.response.body, contains('256 bytes'));
      expect(ctx.response.body, contains('512 bytes'));
    });

    test('formats kilobytes correctly in error message', () async {
      final ctx = TestContext.create('POST', '/', contentLength: 2048);
      await BodyLimit(const BodyLimitOptions.kb(1)).handle(ctx, () async {});
      expect(ctx.response.body, contains('KB'));
    });

    test('formats megabytes correctly in error message', () async {
      final ctx = TestContext.create('POST', '/', contentLength: 2097152);
      await BodyLimit(const BodyLimitOptions.mb(1)).handle(ctx, () async {});
      expect(ctx.response.body, contains('MB'));
    });

    test('works with default constructor', () async {
      final ctx = TestContext.create('POST', '/', contentLength: 512);
      var called = false;
      await BodyLimit().handle(ctx, () async {
        called = true;
      });
      expect(called, isTrue);
    });

    test('rejects when exceeding default limit', () async {
      final ctx = TestContext.create('POST', '/', contentLength: 2097152);
      var called = false;
      await BodyLimit().handle(ctx, () async {
        called = true;
      });
      expect(called, isFalse);
      expect(ctx.response.statusCode, HttpStatus.requestEntityTooLarge);
    });

    test('kb constructor creates correct limit', () async {
      final ctx = TestContext.create('POST', '/', contentLength: 512000);
      var called = false;
      await BodyLimit(const BodyLimitOptions.kb(500)).handle(ctx, () async {
        called = true;
      });
      expect(called, isTrue);
    });

    test('mb constructor creates correct limit', () async {
      final ctx = TestContext.create('POST', '/', contentLength: 5242880);
      var called = false;
      await BodyLimit(const BodyLimitOptions.mb(5)).handle(ctx, () async {
        called = true;
      });
      expect(called, isTrue);
    });

    test('handles edge case at exactly 1024 bytes boundary', () async {
      final ctx = TestContext.create('POST', '/', contentLength: 1024);
      var called = false;
      await BodyLimit(const BodyLimitOptions(maxSize: 1024)).handle(
        ctx,
        () async {
          called = true;
        },
      );
      expect(called, isTrue);
    });

    test('handles edge case at exactly 1MB boundary', () async {
      final ctx = TestContext.create('POST', '/', contentLength: 1048576);
      var called = false;
      await BodyLimit(const BodyLimitOptions.mb(1)).handle(ctx, () async {
        called = true;
      });
      expect(called, isTrue);
    });

    test('rejects just over the boundary', () async {
      final ctx = TestContext.create('POST', '/', contentLength: 1025);
      var called = false;
      await BodyLimit(const BodyLimitOptions(maxSize: 1024)).handle(
        ctx,
        () async {
          called = true;
        },
      );
      expect(called, isFalse);
      expect(ctx.response.statusCode, HttpStatus.requestEntityTooLarge);
    });
  });
}
