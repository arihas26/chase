import 'dart:io';

import 'package:chase/chase.dart';
import 'package:chase/testing/testing.dart';
import 'package:test/test.dart';

void main() {
  test('sets Access-Control-Allow-Origin for simple requests', () async {
    final ctx = TestContext.get(
      '/',
      headers: {'origin': 'https://example.com'},
    );
    await buildMiddlewareChain([Cors()], (_) async {})(ctx);
    expect(ctx.response.headers.value('access-control-allow-origin'), '*');
  });

  test('echoes origin when credentials are allowed', () async {
    final ctx = TestContext.get(
      '/',
      headers: {'origin': 'https://example.com'},
    );
    await buildMiddlewareChain([
      Cors(const CorsOptions(allowCredentials: true)),
    ], (_) async {})(ctx);

    expect(
      ctx.response.headers.value('access-control-allow-origin'),
      'https://example.com',
    );
    expect(
      ctx.response.headers.value('access-control-allow-credentials'),
      'true',
    );
    expect(ctx.response.headers.value('vary'), 'Origin');
  });

  test('handles preflight requests', () async {
    final ctx = TestContext.create(
      'OPTIONS',
      '/',
      headers: {
        'origin': 'https://example.com',
        'access-control-request-method': 'POST',
        'access-control-request-headers': 'X-Test',
      },
    );

    var called = false;
    await buildMiddlewareChain(
      [Cors(const CorsOptions(maxAge: Duration(hours: 1)))],
      (_) async {
        called = true;
      },
    )(ctx);

    expect(called, isFalse);
    expect(ctx.response.statusCode, HttpStatus.noContent);
    expect(
      ctx.response.headers.value('access-control-allow-methods'),
      contains('POST'),
    );
    expect(
      ctx.response.headers.value('access-control-allow-headers'),
      'X-Test',
    );
    expect(ctx.response.headers.value('access-control-max-age'), '3600');
    // Note: Response is returned and will be closed by Chase's _sendResponse
  });

  group('Origin validation', () {
    test('allows specific origin when in allowed list', () async {
      final ctx = TestContext.get(
        '/',
        headers: {'origin': 'https://example.com'},
      );
      await buildMiddlewareChain([
        Cors(
          const CorsOptions(
            origins: ['https://example.com', 'https://test.com'],
          ),
        ),
      ], (_) async {})(ctx);
      expect(
        ctx.response.headers.value('access-control-allow-origin'),
        'https://example.com',
      );
    });

    test('rejects origin not in allowed list', () async {
      final ctx = TestContext.get('/', headers: {'origin': 'https://evil.com'});
      await buildMiddlewareChain([
        Cors(const CorsOptions(origins: ['https://example.com'])),
      ], (_) async {})(ctx);
      expect(ctx.response.headers.value('access-control-allow-origin'), isNull);
    });

    test('allows any origin when wildcard in list', () async {
      final ctx = TestContext.get(
        '/',
        headers: {'origin': 'https://any-domain.com'},
      );
      await buildMiddlewareChain([
        Cors(const CorsOptions(origins: ['*'])),
      ], (_) async {})(ctx);
      expect(
        ctx.response.headers.value('access-control-allow-origin'),
        'https://any-domain.com',
      );
    });

    test('uses callback for dynamic origin validation', () async {
      final ctx = TestContext.get(
        '/',
        headers: {'origin': 'https://sub.example.com'},
      );
      await buildMiddlewareChain([
        Cors(
          CorsOptions(
            originCallback: (o) => o?.endsWith('.example.com') ?? false,
          ),
        ),
      ], (_) async {})(ctx);
      expect(
        ctx.response.headers.value('access-control-allow-origin'),
        'https://sub.example.com',
      );
    });

    test('callback rejects invalid origin', () async {
      final ctx = TestContext.get('/', headers: {'origin': 'https://evil.com'});
      await buildMiddlewareChain([
        Cors(
          CorsOptions(
            originCallback: (o) => o?.endsWith('.example.com') ?? false,
          ),
        ),
      ], (_) async {})(ctx);
      expect(ctx.response.headers.value('access-control-allow-origin'), isNull);
    });
  });

  group('Headers configuration', () {
    test('sets expose headers when configured', () async {
      final ctx = TestContext.get(
        '/',
        headers: {'origin': 'https://example.com'},
      );
      await buildMiddlewareChain([
        Cors(
          const CorsOptions(exposeHeaders: ['X-Total-Count', 'X-Page-Number']),
        ),
      ], (_) async {})(ctx);
      expect(
        ctx.response.headers.value('access-control-expose-headers'),
        'X-Total-Count, X-Page-Number',
      );
    });

    test('allows custom methods in preflight', () async {
      final ctx = TestContext.create(
        'OPTIONS',
        '/',
        headers: {
          'origin': 'https://example.com',
          'access-control-request-method': 'DELETE',
        },
      );
      await buildMiddlewareChain([
        Cors(
          const CorsOptions(allowMethods: ['GET', 'POST', 'DELETE', 'PATCH']),
        ),
      ], (_) async {})(ctx);
      expect(
        ctx.response.headers.value('access-control-allow-methods'),
        'GET, POST, DELETE, PATCH',
      );
    });

    test('allows custom headers in preflight', () async {
      final ctx = TestContext.create(
        'OPTIONS',
        '/',
        headers: {
          'origin': 'https://example.com',
          'access-control-request-method': 'POST',
        },
      );
      await buildMiddlewareChain([
        Cors(
          const CorsOptions(
            allowHeaders: ['Content-Type', 'Authorization', 'X-Custom'],
          ),
        ),
      ], (_) async {})(ctx);
      expect(
        ctx.response.headers.value('access-control-allow-headers'),
        'Content-Type, Authorization, X-Custom',
      );
    });

    test('mirrors request headers when no allow headers configured', () async {
      final ctx = TestContext.create(
        'OPTIONS',
        '/',
        headers: {
          'origin': 'https://example.com',
          'access-control-request-method': 'POST',
          'access-control-request-headers': 'X-Custom-Header, X-Another',
        },
      );
      await buildMiddlewareChain([Cors()], (_) async {})(ctx);
      expect(
        ctx.response.headers.value('access-control-allow-headers'),
        'X-Custom-Header, X-Another',
      );
    });
  });

  group('Security', () {
    test('does not set Vary header when using wildcard', () async {
      final ctx = TestContext.get(
        '/',
        headers: {'origin': 'https://example.com'},
      );
      await buildMiddlewareChain([Cors()], (_) async {})(ctx);
      expect(ctx.response.headers.value('vary'), isNull);
    });

    test('sets Vary header when using specific origin', () async {
      final ctx = TestContext.get(
        '/',
        headers: {'origin': 'https://example.com'},
      );
      await buildMiddlewareChain([
        Cors(const CorsOptions(origins: ['https://example.com'])),
      ], (_) async {})(ctx);
      expect(ctx.response.headers.value('vary'), 'Origin');
    });

    test('handles requests without origin header', () async {
      final ctx = TestContext.get('/');
      await buildMiddlewareChain([Cors()], (_) async {})(ctx);
      expect(ctx.response.headers.value('access-control-allow-origin'), '*');
    });
  });

  group('Non-preflight requests', () {
    test('calls next handler for non-OPTIONS requests', () async {
      final ctx = TestContext.get(
        '/',
        headers: {'origin': 'https://example.com'},
      );

      var called = false;
      await buildMiddlewareChain([Cors()], (_) async {
        called = true;
      })(ctx);

      expect(called, isTrue);
      expect(ctx.response.isClosed, isFalse);
    });

    test('calls next handler for OPTIONS without preflight headers', () async {
      final ctx = TestContext.create(
        'OPTIONS',
        '/',
        headers: {'origin': 'https://example.com'},
      );

      var called = false;
      await buildMiddlewareChain([Cors()], (_) async {
        called = true;
      })(ctx);

      expect(called, isTrue);
      expect(ctx.response.isClosed, isFalse);
    });
  });

  group('Edge cases', () {
    test('handles empty origins list as wildcard', () async {
      final ctx = TestContext.get(
        '/',
        headers: {'origin': 'https://example.com'},
      );
      await buildMiddlewareChain([
        Cors(const CorsOptions(origins: [])),
      ], (_) async {})(ctx);
      expect(ctx.response.headers.value('access-control-allow-origin'), '*');
    });

    test('max age duration converts to seconds correctly', () async {
      final ctx = TestContext.create(
        'OPTIONS',
        '/',
        headers: {
          'origin': 'https://example.com',
          'access-control-request-method': 'POST',
        },
      );
      await buildMiddlewareChain([
        Cors(const CorsOptions(maxAge: Duration(days: 1))),
      ], (_) async {})(ctx);
      expect(ctx.response.headers.value('access-control-max-age'), '86400');
    });

    test('allows credentials without explicit origins echoes origin', () async {
      final ctx = TestContext.get(
        '/',
        headers: {'origin': 'https://example.com'},
      );
      await buildMiddlewareChain([
        Cors(const CorsOptions(allowCredentials: true)),
      ], (_) async {})(ctx);

      expect(
        ctx.response.headers.value('access-control-allow-origin'),
        'https://example.com',
      );
      expect(
        ctx.response.headers.value('access-control-allow-credentials'),
        'true',
      );
    });
  });
}
