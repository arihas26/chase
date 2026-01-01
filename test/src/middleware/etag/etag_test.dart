import 'dart:typed_data';

import 'package:chase/src/middleware/etag/etag.dart';
import 'package:chase/testing/testing.dart';
import 'package:test/test.dart';

void main() {
  group('ETagOptions', () {
    test('default options', () {
      const options = ETagOptions();
      expect(options.weak, isFalse);
      expect(options.generator, isNull);
    });

    test('weak option', () {
      const options = ETagOptions.weak();
      expect(options.weak, isTrue);
    });

    test('custom generator', () {
      final options = ETagOptions(
        generator: (content) => 'custom-${content.length}',
      );
      expect(options.generator!(Uint8List.fromList([1, 2, 3])), 'custom-3');
    });
  });

  group('ETagHelper', () {
    test('fromBytes generates strong ETag', () {
      final etag = ETagHelper.fromBytes(Uint8List.fromList([1, 2, 3]));
      expect(etag, startsWith('"'));
      expect(etag, endsWith('"'));
      expect(etag, isNot(startsWith('W/')));
    });

    test('fromBytes generates weak ETag', () {
      final etag = ETagHelper.fromBytes(
        Uint8List.fromList([1, 2, 3]),
        weak: true,
      );
      expect(etag, startsWith('W/"'));
      expect(etag, endsWith('"'));
    });

    test('fromString generates consistent ETag', () {
      final etag1 = ETagHelper.fromString('hello');
      final etag2 = ETagHelper.fromString('hello');
      expect(etag1, etag2);
    });

    test('fromString generates different ETags for different content', () {
      final etag1 = ETagHelper.fromString('hello');
      final etag2 = ETagHelper.fromString('world');
      expect(etag1, isNot(etag2));
    });

    test('fromJson generates ETag from JSON', () {
      final etag = ETagHelper.fromJson({'key': 'value'});
      expect(etag, startsWith('"'));
      expect(etag, endsWith('"'));
    });

    test('fromVersion creates simple ETag', () {
      expect(ETagHelper.fromVersion('v1.0.0'), '"v1.0.0"');
    });

    test('fromVersion weak', () {
      expect(ETagHelper.fromVersion('v1.0.0', weak: true), 'W/"v1.0.0"');
    });

    test('equals with identical ETags', () {
      expect(ETagHelper.equals('"abc"', '"abc"'), isTrue);
    });

    test('equals ignores weak prefix in weak comparison', () {
      expect(ETagHelper.equals('"abc"', 'W/"abc"'), isTrue);
      expect(ETagHelper.equals('W/"abc"', 'W/"abc"'), isTrue);
    });

    test('equals fails for different values', () {
      expect(ETagHelper.equals('"abc"', '"xyz"'), isFalse);
    });

    test('strong comparison requires both strong', () {
      expect(
        ETagHelper.equals('"abc"', '"abc"', strongComparison: true),
        isTrue,
      );
      expect(
        ETagHelper.equals('W/"abc"', '"abc"', strongComparison: true),
        isFalse,
      );
      expect(
        ETagHelper.equals('"abc"', 'W/"abc"', strongComparison: true),
        isFalse,
      );
    });
  });

  group('ETag middleware', () {
    test('generateEtag creates strong ETag by default', () {
      const middleware = ETag();
      final etag = middleware.generateEtagFromString('hello');
      expect(etag, startsWith('"'));
      expect(etag, isNot(startsWith('W/')));
    });

    test('generateEtag creates weak ETag when configured', () {
      const middleware = ETag(ETagOptions.weak());
      final etag = middleware.generateEtagFromString('hello');
      expect(etag, startsWith('W/"'));
    });

    test('generateEtag uses custom generator', () {
      final middleware = ETag(
        ETagOptions(generator: (content) => 'custom-hash'),
      );
      expect(middleware.generateEtagFromString('hello'), '"custom-hash"');
    });

    test('generateEtag consistent for same content', () {
      const middleware = ETag();
      expect(
        middleware.generateEtagFromString('hello'),
        middleware.generateEtagFromString('hello'),
      );
    });
  });

  group('ETag context extension', () {
    test('ifNoneMatch returns empty list when no header', () {
      final ctx = TestContext.get('/');
      expect(ctx.ifNoneMatch, isEmpty);
    });

    test('ifNoneMatch parses single value', () {
      final ctx = TestContext.get('/', headers: {'if-none-match': '"abc123"'});
      expect(ctx.ifNoneMatch, ['"abc123"']);
    });

    test('ifNoneMatch parses multiple values', () {
      final ctx = TestContext.get(
        '/',
        headers: {'if-none-match': '"abc", "def", "ghi"'},
      );
      expect(ctx.ifNoneMatch, ['"abc"', '"def"', '"ghi"']);
    });

    test('ifMatch returns empty list when no header', () {
      final ctx = TestContext.get('/');
      expect(ctx.ifMatch, isEmpty);
    });

    test('etagMatches returns false when no If-None-Match header', () {
      final ctx = TestContext.get('/');
      expect(ctx.etagMatches('"abc"'), isFalse);
    });

    test('etagMatches returns true for matching ETag', () {
      final ctx = TestContext.get('/', headers: {'if-none-match': '"abc123"'});
      expect(ctx.etagMatches('"abc123"'), isTrue);
    });

    test('etagMatches handles weak ETags', () {
      final ctx = TestContext.get(
        '/',
        headers: {'if-none-match': 'W/"abc123"'},
      );
      expect(ctx.etagMatches('"abc123"'), isTrue);
      expect(ctx.etagMatches('W/"abc123"'), isTrue);
    });

    test('etagMatches returns true for wildcard', () {
      final ctx = TestContext.get('/', headers: {'if-none-match': '*'});
      expect(ctx.etagMatches('"anything"'), isTrue);
    });

    test('etagMatches returns false for non-matching ETag', () {
      final ctx = TestContext.get('/', headers: {'if-none-match': '"abc123"'});
      expect(ctx.etagMatches('"xyz789"'), isFalse);
    });

    test('checkEtag sets header and returns false when no match', () async {
      final ctx = TestContext.get('/');
      final result = await ctx.checkEtag('"abc123"');

      expect(result, isFalse);
      expect(ctx.response.headers.value('etag'), '"abc123"');
      expect(ctx.response.isClosed, isFalse);
    });

    test('checkEtag returns true and sends 304 when matches', () async {
      final ctx = TestContext.get('/', headers: {'if-none-match': '"abc123"'});
      final result = await ctx.checkEtag('"abc123"');

      expect(result, isTrue);
      expect(ctx.response.statusCode, 304);
      expect(ctx.response.isClosed, isTrue);
      expect(ctx.response.headers.value('etag'), '"abc123"');
    });

    test('checkEtag matches with multiple If-None-Match values', () async {
      final ctx = TestContext.get(
        '/',
        headers: {'if-none-match': '"old", "abc123", "other"'},
      );
      final result = await ctx.checkEtag('"abc123"');

      expect(result, isTrue);
      expect(ctx.response.statusCode, 304);
    });
  });

  group('ETagCheckResult', () {
    test('creates with values', () {
      const result = ETagCheckResult(etag: '"abc"', matches: true);
      expect(result.etag, '"abc"');
      expect(result.matches, isTrue);
    });
  });
}
