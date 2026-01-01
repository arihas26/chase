import 'package:chase/chase.dart';
import 'package:test/test.dart';

void main() {
  late RegexRouter router;
  late Handler handler;
  late Handler postHandler;
  late Handler staticHandler;

  setUp(() {
    router = RegexRouter();
    handler = (Context c) => c;
    postHandler = (Context c) => c;
    staticHandler = (Context c) => c;
  });

  group('Basic Routing', () {
    test('returns null when route is missing', () {
      expect(router.match('GET', '/missing'), isNull);
    });

    test('matches the root path', () {
      router.add('GET', '/', handler);

      expect(router.match('GET', '/')?.handler, same(handler));
    });

    test('matches static routes', () {
      router.add('GET', '/users/me', handler);

      expect(router.match('GET', '/users/me')?.handler, same(handler));
    });

    test('matches parameter routes and extracts params', () {
      router.add('GET', '/users/:id', handler);

      final RouteMatch? match = router.match('GET', '/users/123');

      expect(match?.handler, same(handler));
      expect(match?.params, {'id': '123'});
    });

    test('matches multiple parameters', () {
      router.add('GET', '/users/:userId/posts/:postId', handler);

      final match = router.match('GET', '/users/1/posts/2');

      expect(match?.params, {'userId': '1', 'postId': '2'});
    });
  });

  group('Wildcard Routes', () {
    test('matches wildcard routes and captures remaining segments', () {
      router.add('GET', '/assets/*path', handler);

      final match = router.match('GET', '/assets/images/icon.png');

      expect(match?.params, {'path': 'images/icon.png'});
    });

    test('matches empty wildcard', () {
      router.add('GET', '/files/*path', handler);

      final match = router.match('GET', '/files/');

      expect(match?.params, {'path': ''});
    });
  });

  group('Custom Regex Patterns', () {
    test('matches numeric parameter with custom pattern', () {
      router.add('GET', r'/users/:id(\d+)', handler);

      final match = router.match('GET', '/users/123');

      expect(match?.handler, same(handler));
      expect(match?.params, {'id': '123'});
    });

    test('rejects non-numeric for numeric pattern', () {
      router.add('GET', r'/users/:id(\d+)', handler);

      final match = router.match('GET', '/users/abc');

      expect(match, isNull);
    });

    test('matches alphanumeric pattern', () {
      router.add('GET', r'/posts/:slug([a-z0-9-]+)', handler);

      final match = router.match('GET', '/posts/hello-world-123');

      expect(match?.params, {'slug': 'hello-world-123'});
    });

    test('matches uuid pattern', () {
      router.add(
        'GET',
        r'/items/:id([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})',
        handler,
      );

      final match = router.match(
        'GET',
        '/items/550e8400-e29b-41d4-a716-446655440000',
      );

      expect(match?.params, {'id': '550e8400-e29b-41d4-a716-446655440000'});
    });

    test('rejects invalid uuid', () {
      router.add(
        'GET',
        r'/items/:id([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})',
        handler,
      );

      final match = router.match('GET', '/items/not-a-uuid');

      expect(match, isNull);
    });
  });

  group('Route Priority', () {
    test('first registered route wins for same pattern', () {
      router.add('GET', '/users/:id', handler);
      router.add('GET', '/users/:name', staticHandler);

      final match = router.match('GET', '/users/123');

      expect(match?.handler, same(handler));
    });

    test('static route before parameter route wins if registered first', () {
      router.add('GET', '/users/me', staticHandler);
      router.add('GET', '/users/:id', handler);

      final match = router.match('GET', '/users/me');

      expect(match?.handler, same(staticHandler));
    });
  });

  group('HTTP Methods', () {
    test('keeps methods isolated', () {
      router.add('GET', '/users/:id', handler);
      router.add('POST', '/users/:id', postHandler);

      expect(router.match('GET', '/users/1')?.handler, same(handler));
      expect(router.match('POST', '/users/1')?.handler, same(postHandler));
    });

    test('returns null for unregistered method', () {
      router.add('GET', '/users', handler);

      expect(router.match('POST', '/users'), isNull);
    });
  });

  group('Complex Patterns', () {
    test('matches parameter and wildcard together', () {
      router.add('GET', '/files/:id/*rest', handler);

      final match = router.match('GET', '/files/1/a/b.txt');

      expect(match?.params, {'id': '1', 'rest': 'a/b.txt'});
    });

    test('multi parameters and wildcard together', () {
      router.add('GET', '/a/:p1/b/:p2/*rest', handler);

      final match = router.match('GET', '/a/one/b/two/c/d/e');

      expect(match?.params, {'p1': 'one', 'p2': 'two', 'rest': 'c/d/e'});
    });

    test('custom pattern with wildcard', () {
      router.add('GET', r'/api/:version(\d+)/*path', handler);

      final match = router.match('GET', '/api/2/users/123');

      expect(match?.params, {'version': '2', 'path': 'users/123'});
    });
  });

  group('Edge Cases', () {
    test('params are unmodifiable', () {
      router.add('GET', '/users/:id', handler);

      final match = router.match('GET', '/users/1');

      expect(() => match?.params['id'] = '2', throwsUnsupportedError);
    });

    test('escapes special regex characters in static segments', () {
      router.add('GET', '/api/v1.0/users', handler);

      expect(router.match('GET', '/api/v1.0/users')?.handler, same(handler));
      expect(router.match('GET', '/api/v1X0/users'), isNull);
    });

    test('matches path with special characters', () {
      router.add('GET', '/search/:query', handler);

      final match = router.match('GET', '/search/hello%20world');

      expect(match?.params, {'query': 'hello%20world'});
    });
  });

  group('Optional Parameters', () {
    test('matches optional parameter when provided', () {
      router.add('GET', '/users/:id?', handler);

      final match = router.match('GET', '/users/123');

      expect(match?.handler, same(handler));
      expect(match?.params, {'id': '123'});
    });

    test('matches optional parameter when omitted', () {
      router.add('GET', '/users/:id?', handler);

      final match = router.match('GET', '/users');

      expect(match?.handler, same(handler));
      expect(match?.params, isEmpty);
    });

    test('matches optional parameter at end of path', () {
      router.add('GET', '/api/users/:id?', handler);

      expect(router.match('GET', '/api/users')?.handler, same(handler));
      expect(router.match('GET', '/api/users/456')?.params, {'id': '456'});
    });

    test('optional parameter with static prefix', () {
      router.add('GET', '/posts/:postId/comments/:commentId?', handler);

      final withComment = router.match('GET', '/posts/1/comments/2');
      expect(withComment?.params, {'postId': '1', 'commentId': '2'});

      final withoutComment = router.match('GET', '/posts/1/comments');
      expect(withoutComment?.params, {'postId': '1'});
    });

    test('optional parameter with custom regex pattern', () {
      router.add('GET', r'/users/:id(\d+)?', handler);

      expect(router.match('GET', '/users/123')?.params, {'id': '123'});
      expect(router.match('GET', '/users')?.handler, same(handler));
      expect(router.match('GET', '/users/abc'), isNull);
    });

    test('static route before optional parameter route', () {
      router.add('GET', '/users/me', staticHandler);
      router.add('GET', '/users/:id?', handler);

      expect(router.match('GET', '/users/me')?.handler, same(staticHandler));
      expect(router.match('GET', '/users/123')?.handler, same(handler));
      expect(router.match('GET', '/users')?.handler, same(handler));
    });
  });
}
