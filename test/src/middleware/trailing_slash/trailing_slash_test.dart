import 'dart:io';

import 'package:chase/chase.dart';
import 'package:chase/testing/testing.dart';
import 'package:test/test.dart';

void main() {
  group('trimTrailingSlash', () {
    test('redirects path with trailing slash', () async {
      final ctx = TestContext.get('/about/');
      final middleware = trimTrailingSlash();

      await middleware.handle(ctx, () async {});

      expect(ctx.response.statusCode, HttpStatus.movedPermanently);
      expect(ctx.response.headers.value('location'), '/about');
    });

    test('does not redirect path without trailing slash', () async {
      final ctx = TestContext.get('/about');
      var nextCalled = false;
      final middleware = trimTrailingSlash();

      await middleware.handle(ctx, () async {
        nextCalled = true;
      });

      expect(nextCalled, isTrue);
      expect(ctx.response.headers.value('location'), isNull);
    });

    test('does not redirect root path', () async {
      final ctx = TestContext.get('/');
      var nextCalled = false;
      final middleware = trimTrailingSlash();

      await middleware.handle(ctx, () async {
        nextCalled = true;
      });

      expect(nextCalled, isTrue);
      expect(ctx.response.headers.value('location'), isNull);
    });

    test('preserves query string', () async {
      final ctx = TestContext.get('/search/?q=hello&page=1');
      final middleware = trimTrailingSlash();

      await middleware.handle(ctx, () async {});

      expect(ctx.response.headers.value('location'), '/search?q=hello&page=1');
    });

    test('uses custom redirect status', () async {
      final ctx = TestContext.get('/about/');
      final middleware = trimTrailingSlash(redirectStatus: HttpStatus.found);

      await middleware.handle(ctx, () async {});

      expect(ctx.response.statusCode, HttpStatus.found);
    });

    test('only applies to GET requests', () async {
      final ctx = TestContext.post('/about/');
      var nextCalled = false;
      final middleware = trimTrailingSlash();

      await middleware.handle(ctx, () async {
        nextCalled = true;
      });

      expect(nextCalled, isTrue);
      expect(ctx.response.headers.value('location'), isNull);
    });

    // Note: HEAD requests are also handled but TestContext doesn't support HEAD
  });

  group('appendTrailingSlash', () {
    test('redirects path without trailing slash', () async {
      final ctx = TestContext.get('/about');
      final middleware = appendTrailingSlash();

      await middleware.handle(ctx, () async {});

      expect(ctx.response.statusCode, HttpStatus.movedPermanently);
      expect(ctx.response.headers.value('location'), '/about/');
    });

    test('does not redirect path with trailing slash', () async {
      final ctx = TestContext.get('/about/');
      var nextCalled = false;
      final middleware = appendTrailingSlash();

      await middleware.handle(ctx, () async {
        nextCalled = true;
      });

      expect(nextCalled, isTrue);
      expect(ctx.response.headers.value('location'), isNull);
    });

    test('does not redirect root path', () async {
      final ctx = TestContext.get('/');
      var nextCalled = false;
      final middleware = appendTrailingSlash();

      await middleware.handle(ctx, () async {
        nextCalled = true;
      });

      expect(nextCalled, isTrue);
      expect(ctx.response.headers.value('location'), isNull);
    });

    test('preserves query string', () async {
      final ctx = TestContext.get('/search?q=hello&page=1');
      final middleware = appendTrailingSlash();

      await middleware.handle(ctx, () async {});

      expect(ctx.response.headers.value('location'), '/search/?q=hello&page=1');
    });

    test('uses custom redirect status', () async {
      final ctx = TestContext.get('/about');
      final middleware = appendTrailingSlash(redirectStatus: HttpStatus.found);

      await middleware.handle(ctx, () async {});

      expect(ctx.response.statusCode, HttpStatus.found);
    });

    test('only applies to GET requests', () async {
      final ctx = TestContext.post('/about');
      var nextCalled = false;
      final middleware = appendTrailingSlash();

      await middleware.handle(ctx, () async {
        nextCalled = true;
      });

      expect(nextCalled, isTrue);
      expect(ctx.response.headers.value('location'), isNull);
    });
  });

  group('TrailingSlash class', () {
    test('trim static method', () async {
      final ctx = TestContext.get('/about/');
      final middleware = TrailingSlash.trim();

      await middleware.handle(ctx, () async {});

      expect(ctx.response.headers.value('location'), '/about');
    });

    test('append static method', () async {
      final ctx = TestContext.get('/about');
      final middleware = TrailingSlash.append();

      await middleware.handle(ctx, () async {});

      expect(ctx.response.headers.value('location'), '/about/');
    });

    test('constructor with trim mode', () async {
      final ctx = TestContext.get('/about/');
      const middleware = TrailingSlash(mode: TrailingSlashMode.trim);

      await middleware.handle(ctx, () async {});

      expect(ctx.response.headers.value('location'), '/about');
    });

    test('constructor with append mode', () async {
      final ctx = TestContext.get('/about');
      const middleware = TrailingSlash(mode: TrailingSlashMode.append);

      await middleware.handle(ctx, () async {});

      expect(ctx.response.headers.value('location'), '/about/');
    });
  });

  group('nested paths', () {
    test('trims trailing slash from nested path', () async {
      final ctx = TestContext.get('/api/v1/users/');
      final middleware = trimTrailingSlash();

      await middleware.handle(ctx, () async {});

      expect(ctx.response.headers.value('location'), '/api/v1/users');
    });

    test('appends trailing slash to nested path', () async {
      final ctx = TestContext.get('/api/v1/users');
      final middleware = appendTrailingSlash();

      await middleware.handle(ctx, () async {});

      expect(ctx.response.headers.value('location'), '/api/v1/users/');
    });
  });
}
