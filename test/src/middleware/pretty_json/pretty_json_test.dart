import 'package:chase/chase.dart';
import 'package:chase/testing/testing.dart';
import 'package:test/test.dart';

void main() {
  group('PrettyJson middleware', () {
    test('sets prettyJson flag on response', () async {
      final ctx = TestContext.get('/');
      const middleware = PrettyJson();

      await middleware.handle(ctx, () async {});

      expect(ctx.res.prettyJson, isTrue);
    });

    test('formats JSON output with indentation', () async {
      final ctx = TestContext.get('/');
      const middleware = PrettyJson();

      await middleware.handle(ctx, () async {
        await ctx.res.json({'name': 'John', 'age': 30});
      });

      final body = ctx.response.body;
      expect(body, contains('{\n'));
      expect(body, contains('  "name"'));
      expect(body, contains('  "age"'));
    });

    test('formats nested JSON correctly', () async {
      final ctx = TestContext.get('/');
      const middleware = PrettyJson();

      await middleware.handle(ctx, () async {
        await ctx.res.json({
          'user': {'name': 'John', 'email': 'john@example.com'},
          'posts': [
            {'id': 1, 'title': 'Hello'},
          ],
        });
      });

      final body = ctx.response.body;
      expect(body, contains('  "user"'));
      expect(body, contains('    "name"'));
      expect(body, contains('  "posts"'));
    });

    test('does not format when condition returns false', () async {
      final ctx = TestContext.get('/');
      final middleware = PrettyJson(
        condition: (ctx) => ctx.req.query('pretty') == 'true',
      );

      await middleware.handle(ctx, () async {
        await ctx.res.json({'name': 'John'});
      });

      final body = ctx.response.body;
      expect(body, '{"name":"John"}');
    });

    test('formats when condition returns true', () async {
      final ctx = TestContext.get('/?pretty=true');
      final middleware = PrettyJson(
        condition: (ctx) => ctx.req.query('pretty') == 'true',
      );

      await middleware.handle(ctx, () async {
        await ctx.res.json({'name': 'John'});
      });

      final body = ctx.response.body;
      expect(body, contains('{\n'));
      expect(body, contains('  "name"'));
    });

    test('works with list responses', () async {
      final ctx = TestContext.get('/');
      const middleware = PrettyJson();

      await middleware.handle(ctx, () async {
        await ctx.res.json([1, 2, 3]);
      });

      final body = ctx.response.body;
      expect(body, contains('[\n'));
      expect(body, contains('  1'));
    });
  });

  group('Response.prettyJson flag', () {
    test('defaults to false', () {
      final ctx = TestContext.get('/');
      expect(ctx.res.prettyJson, isFalse);
    });

    test('can be set directly', () {
      final ctx = TestContext.get('/');
      ctx.res.prettyJson = true;
      expect(ctx.res.prettyJson, isTrue);
    });
  });

  group('Integration with Response class', () {
    test('formats Response.ok with Map', () async {
      final ctx = TestContext.get('/');
      const middleware = PrettyJson();

      await middleware.handle(ctx, () async {});

      // Simulate what Chase does with Response
      final response = Response.ok().json({'message': 'Hello'});
      await response.writeTo(ctx.response, prettyJson: ctx.res.prettyJson);

      final body = ctx.response.body;
      expect(body, contains('{\n'));
      expect(body, contains('  "message"'));
    });

    test('formats Response with nested Map', () async {
      final ctx = TestContext.get('/');
      const middleware = PrettyJson();

      await middleware.handle(ctx, () async {});

      final response = Response.ok().json({
        'user': {'name': 'John'},
      });
      await response.writeTo(ctx.response, prettyJson: ctx.res.prettyJson);

      final body = ctx.response.body;
      expect(body, contains('  "user"'));
      expect(body, contains('    "name"'));
    });
  });
}
