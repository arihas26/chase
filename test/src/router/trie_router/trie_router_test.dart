import 'package:chase/chase.dart';
import 'package:test/test.dart';

void main() {
  late TrieRouter router;
  late Handler handler;
  late Handler postHandler;
  late Handler staticHandler;
  late Handler wildcardHandler;

  setUp(() {
    router = TrieRouter();
    handler = (Context c) => c;
    postHandler = (Context c) => c;
    staticHandler = (Context c) => c;
    wildcardHandler = (Context c) => c;
  });

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

  test('matches wildcard routes and captures remaining segments', () {
    router.add('GET', '/assets/*path', handler);

    final match = router.match('GET', '/assets/images/icon.png');

    expect(match?.params, {'path': 'images/icon.png'});
  });

  test('rejects wildcard that is not the last segment', () {
    expect(
      () => router.add('GET', '/assets/*path/images', handler),
      throwsArgumentError,
    );
  });

  test('prefers static over parameter routes', () {
    router.add('GET', '/users/:id', handler);
    router.add('GET', '/users/me', staticHandler);

    final match = router.match('GET', '/users/me');

    expect(match?.handler, same(staticHandler));
  });

  test('prefers parameter over wildcard routes', () {
    router.add('GET', '/users/:id', handler);
    router.add('GET', '/users/*rest', wildcardHandler);

    final match = router.match('GET', '/users/1');

    expect(match?.handler, same(handler));
  });

  test('backs off to parameter when static branch fails deeper', () {
    router.add('GET', '/users/:id/profile', handler);
    router.add('GET', '/users/me', (Context c) => c);

    final match = router.match('GET', '/users/me/profile');

    expect(match?.params, {'id': 'me'});
  });

  test('matches parameter and wildcard together', () {
    router.add('GET', '/files/:id/*rest', handler);

    final match = router.match('GET', '/files/1/a/b.txt');

    expect(match?.params, {'id': '1', 'rest': 'a/b.txt'});
  });

  test('keeps methods isolated', () {
    router.add('GET', '/users/:id', handler);
    router.add('POST', '/users/:id', postHandler);

    expect(router.match('GET', '/users/1')?.handler, same(handler));
    expect(router.match('POST', '/users/1')?.handler, same(postHandler));
  });

  test('params are unmodifiable', () {
    router.add('GET', '/users/:id', handler);

    final match = router.match('GET', '/users/1');

    expect(() => match?.params['id'] = '2', throwsUnsupportedError);
  });

  test('multi parameters and wildcard together', () {
    router.add('GET', '/a/:p1/b/:p2/*rest', handler);

    final match = router.match('GET', '/a/one/b/two/c/d/e');

    expect(match?.params, {'p1': 'one', 'p2': 'two', 'rest': 'c/d/e'});
  });

  group('optional parameters', () {
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

    test('prefers static over optional parameter', () {
      router.add('GET', '/users/:id?', handler);
      router.add('GET', '/users/me', staticHandler);

      expect(router.match('GET', '/users/me')?.handler, same(staticHandler));
      expect(router.match('GET', '/users/123')?.handler, same(handler));
      expect(router.match('GET', '/users')?.handler, same(handler));
    });
  });
}
