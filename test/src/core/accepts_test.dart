import 'package:chase/chase.dart';
import 'package:chase/testing/testing.dart';
import 'package:test/test.dart';

void main() {
  group('accepts', () {
    group('Accept header', () {
      test('matches exact mime type', () {
        final ctx = TestContext.get('/', headers: {
          'accept': 'application/json',
        });

        final result = ctx.req.accepts(['json', 'html'], defaultValue: 'html');
        expect(result, 'json');
      });

      test('matches shorthand type', () {
        final ctx = TestContext.get('/', headers: {
          'accept': 'text/html',
        });

        final result = ctx.req.accepts(['json', 'html'], defaultValue: 'json');
        expect(result, 'html');
      });

      test('respects quality values', () {
        final ctx = TestContext.get('/', headers: {
          'accept': 'text/html;q=0.9, application/json;q=1.0',
        });

        final result = ctx.req.accepts(['json', 'html'], defaultValue: 'text');
        expect(result, 'json');
      });

      test('returns default when no match', () {
        final ctx = TestContext.get('/', headers: {
          'accept': 'image/png',
        });

        final result = ctx.req.accepts(['json', 'html'], defaultValue: 'json');
        expect(result, 'json');
      });

      test('returns default when no Accept header', () {
        final ctx = TestContext.get('/');

        final result = ctx.req.accepts(['json', 'html'], defaultValue: 'json');
        expect(result, 'json');
      });

      test('handles wildcard */*', () {
        final ctx = TestContext.get('/', headers: {
          'accept': '*/*',
        });

        final result = ctx.req.accepts(['json', 'html'], defaultValue: 'text');
        expect(result, 'json'); // Returns first supported
      });

      test('handles partial wildcard text/*', () {
        final ctx = TestContext.get('/', headers: {
          'accept': 'text/*',
        });

        final result = ctx.req.accepts(['json', 'html'], defaultValue: 'xml');
        expect(result, 'html'); // text/html matches text/*
      });

      test('handles multiple accept values', () {
        final ctx = TestContext.get('/', headers: {
          'accept': 'text/plain, application/json, text/html',
        });

        final result = ctx.req.accepts(['html', 'json'], defaultValue: 'text');
        expect(result, 'json'); // First match in order of header
      });

      test('supports full mime type in supported list', () {
        final ctx = TestContext.get('/', headers: {
          'accept': 'application/json',
        });

        final result = ctx.req.accepts(
          ['application/json', 'text/html'],
          defaultValue: 'text/plain',
        );
        expect(result, 'application/json');
      });
    });

    group('Accept-Language header', () {
      test('matches language', () {
        final ctx = TestContext.get('/', headers: {
          'accept-language': 'ja,en;q=0.9',
        });

        final result = ctx.req.acceptsLanguages(
          ['en', 'ja', 'zh'],
          defaultValue: 'en',
        );
        expect(result, 'ja');
      });

      test('respects quality values', () {
        final ctx = TestContext.get('/', headers: {
          'accept-language': 'en;q=0.8, ja;q=0.9, zh;q=0.7',
        });

        final result = ctx.req.acceptsLanguages(
          ['en', 'ja', 'zh'],
          defaultValue: 'en',
        );
        expect(result, 'ja');
      });

      test('returns default when no match', () {
        final ctx = TestContext.get('/', headers: {
          'accept-language': 'fr,de',
        });

        final result = ctx.req.acceptsLanguages(
          ['en', 'ja'],
          defaultValue: 'en',
        );
        expect(result, 'en');
      });

      test('handles wildcard', () {
        final ctx = TestContext.get('/', headers: {
          'accept-language': '*',
        });

        final result = ctx.req.acceptsLanguages(
          ['en', 'ja'],
          defaultValue: 'zh',
        );
        expect(result, 'en'); // First supported
      });
    });

    group('Accept-Encoding header', () {
      test('matches encoding', () {
        final ctx = TestContext.get('/', headers: {
          'accept-encoding': 'gzip, deflate, br',
        });

        final result = ctx.req.acceptsEncodings(
          ['gzip', 'deflate'],
          defaultValue: 'identity',
        );
        expect(result, 'gzip');
      });

      test('respects quality values', () {
        final ctx = TestContext.get('/', headers: {
          'accept-encoding': 'gzip;q=0.5, br;q=1.0',
        });

        final result = ctx.req.acceptsEncodings(
          ['gzip', 'br'],
          defaultValue: 'identity',
        );
        expect(result, 'br');
      });

      test('returns default when no match', () {
        final ctx = TestContext.get('/', headers: {
          'accept-encoding': 'br',
        });

        final result = ctx.req.acceptsEncodings(
          ['gzip', 'deflate'],
          defaultValue: 'identity',
        );
        expect(result, 'identity');
      });
    });

    group('Accept-Charset header', () {
      test('matches charset', () {
        final ctx = TestContext.get('/', headers: {
          'accept-charset': 'utf-8, iso-8859-1;q=0.5',
        });

        final result = ctx.req.acceptsCharsets(
          ['utf-8', 'iso-8859-1'],
          defaultValue: 'utf-8',
        );
        expect(result, 'utf-8');
      });
    });

    group('edge cases', () {
      test('handles empty Accept header', () {
        final ctx = TestContext.get('/', headers: {
          'accept': '',
        });

        final result = ctx.req.accepts(['json'], defaultValue: 'json');
        expect(result, 'json');
      });

      test('handles malformed quality value', () {
        final ctx = TestContext.get('/', headers: {
          'accept': 'application/json;q=invalid',
        });

        final result = ctx.req.accepts(['json'], defaultValue: 'html');
        expect(result, 'json'); // Should still match, quality defaults to 1.0
      });

      test('case insensitive matching', () {
        final ctx = TestContext.get('/', headers: {
          'accept': 'APPLICATION/JSON',
        });

        final result = ctx.req.accepts(['json'], defaultValue: 'html');
        expect(result, 'json');
      });

      test('handles spaces in header', () {
        final ctx = TestContext.get('/', headers: {
          'accept': '  application/json  ,  text/html  ',
        });

        final result = ctx.req.accepts(['html', 'json'], defaultValue: 'text');
        expect(result, 'json');
      });
    });
  });
}
