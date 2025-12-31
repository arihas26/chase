import 'dart:io';

import 'package:chase/chase.dart';
import 'package:chase/testing/testing.dart';
import 'package:test/test.dart';

void main() {
  group('Csrf.origin', () {
    test('allows request with matching origin', () async {
      final ctx = TestContext.post('/', headers: {
        'origin': 'https://example.com',
        'content-type': 'application/x-www-form-urlencoded',
      });

      var called = false;
      await buildMiddlewareChain([Csrf.origin('https://example.com')], (_) async {
        called = true;
      })(ctx);

      expect(called, isTrue);
      expect(ctx.response.statusCode, 200);
    });

    test('rejects request with non-matching origin', () async {
      final ctx = TestContext.post('/', headers: {
        'origin': 'https://evil.com',
        'content-type': 'application/x-www-form-urlencoded',
      });

      var called = false;
      await buildMiddlewareChain([Csrf.origin('https://example.com')], (_) async {
        called = true;
      })(ctx);

      expect(called, isFalse);
      expect(ctx.response.statusCode, HttpStatus.forbidden);
      expect(ctx.response.body, contains('Potential CSRF attack detected'));
    });

    test('uses custom error message', () async {
      final ctx = TestContext.post('/', headers: {
        'origin': 'https://evil.com',
        'content-type': 'application/x-www-form-urlencoded',
      });

      await buildMiddlewareChain([
        Csrf.origin('https://example.com', errorMessage: 'Custom error'),
      ], (_) async {})(ctx);

      expect(ctx.response.body, contains('Custom error'));
    });
  });

  group('Csrf.origins', () {
    test('allows request from any allowed origin', () async {
      final origins = ['https://example.com', 'https://www.example.com'];

      for (final origin in origins) {
        final ctx = TestContext.post('/', headers: {
          'origin': origin,
          'content-type': 'application/x-www-form-urlencoded',
        });

        var called = false;
        await buildMiddlewareChain([Csrf.origins(origins)], (_) async {
          called = true;
        })(ctx);

        expect(called, isTrue, reason: 'Failed for: $origin');
      }
    });

    test('rejects request from non-allowed origin', () async {
      final ctx = TestContext.post('/', headers: {
        'origin': 'https://evil.com',
        'content-type': 'application/x-www-form-urlencoded',
      });

      var called = false;
      await buildMiddlewareChain([
        Csrf.origins(['https://example.com']),
      ], (_) async {
        called = true;
      })(ctx);

      expect(called, isFalse);
      expect(ctx.response.statusCode, HttpStatus.forbidden);
    });
  });

  group('Csrf.originValidator', () {
    test('uses custom validator function', () async {
      final ctx = TestContext.post('/', headers: {
        'origin': 'https://sub.example.com',
        'content-type': 'application/x-www-form-urlencoded',
      });

      var called = false;
      await buildMiddlewareChain([
        Csrf.originValidator((o, _) => o.endsWith('.example.com')),
      ], (_) async {
        called = true;
      })(ctx);

      expect(called, isTrue);
    });

    test('rejects when validator returns false', () async {
      final ctx = TestContext.post('/', headers: {
        'origin': 'https://evil.com',
        'content-type': 'application/x-www-form-urlencoded',
      });

      var called = false;
      await buildMiddlewareChain([
        Csrf.originValidator((o, _) => o.endsWith('.example.com')),
      ], (_) async {
        called = true;
      })(ctx);

      expect(called, isFalse);
      expect(ctx.response.statusCode, HttpStatus.forbidden);
    });
  });

  group('Csrf.secFetchSite', () {
    test('allows request with matching sec-fetch-site', () async {
      final ctx = TestContext.post('/', headers: {
        'sec-fetch-site': 'same-origin',
        'content-type': 'application/x-www-form-urlencoded',
      });

      var called = false;
      await buildMiddlewareChain([Csrf.secFetchSite('same-origin')], (_) async {
        called = true;
      })(ctx);

      expect(called, isTrue);
    });

    test('rejects request with non-matching sec-fetch-site', () async {
      final ctx = TestContext.post('/', headers: {
        'sec-fetch-site': 'cross-site',
        'content-type': 'application/x-www-form-urlencoded',
      });

      var called = false;
      await buildMiddlewareChain([Csrf.secFetchSite('same-origin')], (_) async {
        called = true;
      })(ctx);

      expect(called, isFalse);
      expect(ctx.response.statusCode, HttpStatus.forbidden);
    });
  });

  group('Csrf.secFetchSites', () {
    test('allows request from any allowed sec-fetch-site', () async {
      final ctx = TestContext.post('/', headers: {
        'sec-fetch-site': 'same-site',
        'content-type': 'application/x-www-form-urlencoded',
      });

      var called = false;
      await buildMiddlewareChain([
        Csrf.secFetchSites(['same-origin', 'same-site']),
      ], (_) async {
        called = true;
      })(ctx);

      expect(called, isTrue);
    });

    test('rejects request from non-allowed sec-fetch-site', () async {
      final ctx = TestContext.post('/', headers: {
        'sec-fetch-site': 'cross-site',
        'content-type': 'application/x-www-form-urlencoded',
      });

      var called = false;
      await buildMiddlewareChain([
        Csrf.secFetchSites(['same-origin', 'same-site']),
      ], (_) async {
        called = true;
      })(ctx);

      expect(called, isFalse);
      expect(ctx.response.statusCode, HttpStatus.forbidden);
    });
  });

  group('HTTP methods', () {
    test('allows safe methods without validation', () async {
      for (final method in ['GET', 'HEAD', 'OPTIONS']) {
        final ctx = TestContext.create(method, '/', headers: {
          'content-type': 'application/x-www-form-urlencoded',
        });

        var called = false;
        await buildMiddlewareChain([Csrf.origin('https://example.com')], (_) async {
          called = true;
        })(ctx);

        expect(called, isTrue, reason: 'Failed for: $method');
      }
    });

    test('validates unsafe methods', () async {
      for (final method in ['POST', 'PUT', 'DELETE', 'PATCH']) {
        final ctx = TestContext.create(method, '/', headers: {
          'content-type': 'application/x-www-form-urlencoded',
        });

        var called = false;
        await buildMiddlewareChain([Csrf.origin('https://example.com')], (_) async {
          called = true;
        })(ctx);

        expect(called, isFalse, reason: 'Failed for: $method');
        expect(ctx.response.statusCode, HttpStatus.forbidden);
      }
    });
  });

  group('Content-Type filtering', () {
    test('validates form content types', () async {
      final formTypes = [
        'application/x-www-form-urlencoded',
        'multipart/form-data',
        'text/plain',
      ];

      for (final ct in formTypes) {
        final ctx = TestContext.post('/', headers: {'content-type': ct});
        await buildMiddlewareChain([Csrf.origin('https://example.com')], (_) async {})(ctx);
        expect(ctx.response.statusCode, HttpStatus.forbidden, reason: 'Should validate: $ct');
      }
    });

    test('skips validation for non-form content types', () async {
      final nonFormTypes = ['application/json', 'application/xml', 'text/xml'];

      for (final ct in nonFormTypes) {
        final ctx = TestContext.post('/', headers: {'content-type': ct});

        var called = false;
        await buildMiddlewareChain([Csrf.origin('https://example.com')], (_) async {
          called = true;
        })(ctx);

        expect(called, isTrue, reason: 'Should skip: $ct');
      }
    });

    test('validates when content-type is missing', () async {
      final ctx = TestContext.post('/');
      await buildMiddlewareChain([Csrf.origin('https://example.com')], (_) async {})(ctx);
      expect(ctx.response.statusCode, HttpStatus.forbidden);
    });
  });

  group('Header validation fallback', () {
    test('prefers origin header over sec-fetch-site', () async {
      final ctx = TestContext.post('/', headers: {
        'origin': 'https://example.com',
        'sec-fetch-site': 'cross-site',
        'content-type': 'application/x-www-form-urlencoded',
      });

      var called = false;
      await buildMiddlewareChain([Csrf.origin('https://example.com')], (_) async {
        called = true;
      })(ctx);

      expect(called, isTrue);
    });

    test('rejects when both headers are missing', () async {
      final ctx = TestContext.post('/', headers: {
        'content-type': 'application/x-www-form-urlencoded',
      });

      await buildMiddlewareChain([Csrf.origin('https://example.com')], (_) async {})(ctx);

      expect(ctx.response.statusCode, HttpStatus.forbidden);
      expect(ctx.response.body, contains('Missing CSRF validation headers'));
    });
  });

  group('Edge cases', () {
    test('handles case-sensitive origin matching', () async {
      final ctx = TestContext.post('/', headers: {
        'origin': 'https://Example.com',
        'content-type': 'application/x-www-form-urlencoded',
      });

      var called = false;
      await buildMiddlewareChain([Csrf.origin('https://example.com')], (_) async {
        called = true;
      })(ctx);

      expect(called, isFalse);
    });

    test('handles content-type case insensitively', () async {
      final ctx = TestContext.post('/', headers: {
        'content-type': 'APPLICATION/X-WWW-FORM-URLENCODED',
      });

      await buildMiddlewareChain([Csrf.origin('https://example.com')], (_) async {})(ctx);
      expect(ctx.response.statusCode, HttpStatus.forbidden);
    });

    test('handles method case insensitively', () async {
      final ctx = TestContext.create('post', '/', headers: {
        'content-type': 'application/x-www-form-urlencoded',
      });

      await buildMiddlewareChain([Csrf.origin('https://example.com')], (_) async {})(ctx);
      expect(ctx.response.statusCode, HttpStatus.forbidden);
    });
  });
}
