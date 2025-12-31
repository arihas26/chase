import 'dart:convert';
import 'dart:io';

import 'package:chase/chase.dart';
import 'package:test/test.dart';

void main() {
  group('Cookie Utilities', () {
    group('signCookieValue / verifySignedCookieValue', () {
      test('signs and verifies a cookie value', () {
        const value = 'user123';
        const secret = 'my-secret-key';

        final signed = signCookieValue(value, secret);
        expect(signed, contains('.'));
        expect(signed, startsWith('user123.'));

        final verified = verifySignedCookieValue(signed, secret);
        expect(verified, equals(value));
      });

      test('returns null for invalid signature', () {
        const secret = 'my-secret-key';
        final signed = signCookieValue('user123', secret);

        // Tamper with the value
        final tampered = 'user456${signed.substring(signed.indexOf('.'))}';
        final verified = verifySignedCookieValue(tampered, secret);

        expect(verified, isNull);
      });

      test('returns null for wrong secret', () {
        final signed = signCookieValue('user123', 'secret1');
        final verified = verifySignedCookieValue(signed, 'secret2');

        expect(verified, isNull);
      });

      test('returns null for missing signature', () {
        final verified = verifySignedCookieValue('user123', 'secret');
        expect(verified, isNull);
      });

      test('handles values containing dots', () {
        const value = 'user.name.with.dots';
        const secret = 'secret';

        final signed = signCookieValue(value, secret);
        final verified = verifySignedCookieValue(signed, secret);

        expect(verified, equals(value));
      });
    });

    group('parseCookieHeader', () {
      test('parses simple cookie header', () {
        final result = parseCookieHeader('session=abc');
        expect(result, {'session': 'abc'});
      });

      test('parses multiple cookies', () {
        final result = parseCookieHeader('session=abc; theme=dark; lang=en');
        expect(result, {'session': 'abc', 'theme': 'dark', 'lang': 'en'});
      });

      test('handles empty header', () {
        expect(parseCookieHeader(null), isEmpty);
        expect(parseCookieHeader(''), isEmpty);
      });

      test('handles URI-encoded values', () {
        final result = parseCookieHeader('name=hello%20world');
        expect(result['name'], 'hello world');
      });

      test('handles invalid encoding gracefully', () {
        final result = parseCookieHeader('name=%ZZ');
        expect(result['name'], '%ZZ');
      });

      test('ignores malformed entries', () {
        final result = parseCookieHeader('valid=yes; invalid; =nokey');
        expect(result, {'valid': 'yes'});
      });
    });

    group('formatSetCookie', () {
      test('formats basic cookie', () {
        final result = formatSetCookie('session', 'abc123');
        expect(result, contains('session=abc123'));
        expect(result, contains('HttpOnly'));
      });

      test('includes maxAge', () {
        final result = formatSetCookie('session', 'abc',
            maxAge: const Duration(hours: 1));
        expect(result, contains('Max-Age=3600'));
      });

      test('includes expires', () {
        final expires = DateTime.utc(2025, 1, 15, 12, 0, 0);
        final result = formatSetCookie('session', 'abc', expires: expires);
        expect(result, contains('Expires='));
      });

      test('includes domain and path', () {
        final result =
            formatSetCookie('session', 'abc', domain: '.example.com', path: '/api');
        expect(result, contains('Domain=.example.com'));
        expect(result, contains('Path=/api'));
      });

      test('includes secure flag', () {
        final result = formatSetCookie('session', 'abc', secure: true);
        expect(result, contains('Secure'));
      });

      test('includes sameSite', () {
        expect(
            formatSetCookie('s', 'v', sameSite: SameSite.lax), contains('SameSite=Lax'));
        expect(formatSetCookie('s', 'v', sameSite: SameSite.strict),
            contains('SameSite=Strict'));
        expect(formatSetCookie('s', 'v', sameSite: SameSite.none),
            contains('SameSite=None'));
      });

      test('includes partitioned flag', () {
        final result = formatSetCookie('session', 'abc', partitioned: true);
        expect(result, contains('Partitioned'));
      });

      test('applies __Secure- prefix', () {
        final result =
            formatSetCookie('session', 'abc', prefix: CookiePrefix.secure);
        expect(result, startsWith('__Secure-session='));
        expect(result, contains('Secure'));
      });

      test('applies __Host- prefix with required attributes', () {
        final result =
            formatSetCookie('session', 'abc', prefix: CookiePrefix.host);
        expect(result, startsWith('__Host-session='));
        expect(result, contains('Path=/'));
        expect(result, contains('Secure'));
        // __Host- prefix should not include Domain
        expect(result, isNot(contains('Domain=')));
      });

      test('URI-encodes cookie value', () {
        final result = formatSetCookie('name', 'hello world');
        expect(result, contains('name=hello%20world'));
      });
    });

    group('JSON Cookie helpers', () {
      test('encodeCookieJson encodes objects', () {
        final encoded = encodeCookieJson({'theme': 'dark', 'lang': 'en'});
        expect(encoded, isNotEmpty);
        expect(encoded, isNot(contains('{')));
      });

      test('decodeCookieJson decodes objects', () {
        final encoded = encodeCookieJson({'theme': 'dark', 'lang': 'en'});
        final decoded = decodeCookieJson<Map<String, dynamic>>(encoded);
        expect(decoded, {'theme': 'dark', 'lang': 'en'});
      });

      test('decodeCookieJson returns null for invalid input', () {
        expect(decodeCookieJson<Map<String, dynamic>>('not-base64!!!'), isNull);
      });

      test('handles arrays', () {
        final encoded = encodeCookieJson([1, 2, 3]);
        final decoded = decodeCookieJson<List<dynamic>>(encoded);
        expect(decoded, [1, 2, 3]);
      });

      test('handles null', () {
        final encoded = encodeCookieJson(null);
        final decoded = decodeCookieJson<Object?>(encoded);
        expect(decoded, isNull);
      });
    });

    group('CookieDuration', () {
      test('has correct durations', () {
        expect(CookieDuration.session, isNull);
        expect(CookieDuration.hour, const Duration(hours: 1));
        expect(CookieDuration.day, const Duration(days: 1));
        expect(CookieDuration.week, const Duration(days: 7));
        expect(CookieDuration.month, const Duration(days: 30));
        expect(CookieDuration.year, const Duration(days: 365));
      });
    });
  });

  group('Response Cookie Methods', () {
    test('req.cookie and req.cookies parse Cookie header', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      server.listen((req) async {
        final ctx = Context(req, req.response);
        await ctx.res.json({
          'session': ctx.req.cookie('session'),
          'all': ctx.req.cookies,
        });
      });

      final client = HttpClient();
      addTearDown(client.close);

      final request = await client.getUrl(
        Uri.parse('http://localhost:${server.port}/'),
      );
      request.headers.set(HttpHeaders.cookieHeader, 'session=abc; theme=dark');

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body) as Map<String, dynamic>;

      expect(decoded['session'], 'abc');
      expect(decoded['all'], {'session': 'abc', 'theme': 'dark'});
    });

    test('ctx.res.cookie sets Set-Cookie header with options', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      server.listen((req) async {
        final ctx = Context(req, req.response);
        ctx.res.cookie(
          'session',
          'abc',
          path: '/',
          sameSite: SameSite.lax,
        );
        await ctx.res.text('ok');
      });

      final client = HttpClient();
      addTearDown(client.close);

      final request =
          await client.getUrl(Uri.parse('http://localhost:${server.port}/'));
      final response = await request.close();
      await response.drain();

      final setCookie = response.headers.value(HttpHeaders.setCookieHeader);
      expect(setCookie, isNotNull);
      expect(setCookie, contains('session=abc'));
      expect(setCookie, contains('Path=/'));
      expect(setCookie, contains('HttpOnly'));
      expect(setCookie, contains('SameSite=Lax'));
    });

    test('Max-Age and Expires are both set', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      server.listen((req) async {
        final ctx = Context(req, req.response);
        ctx.res.cookie(
          'session',
          'abc',
          maxAge: const Duration(minutes: 1),
          expires: DateTime.now().add(const Duration(days: 7)),
        );
        await ctx.res.text('ok');
      });

      final client = HttpClient();
      addTearDown(client.close);

      final request =
          await client.getUrl(Uri.parse('http://localhost:${server.port}/'));
      final response = await request.close();
      await response.drain();

      final setCookie = response.headers.value(HttpHeaders.setCookieHeader);
      expect(setCookie, isNotNull);
      expect(setCookie, contains('Max-Age=60'));
      expect(setCookie, contains('Expires='));
    });

    test('ctx.res.deleteCookie sets expired Set-Cookie header', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      server.listen((req) async {
        final ctx = Context(req, req.response);
        ctx.res.deleteCookie('session', path: '/');
        await ctx.res.text('ok');
      });

      final client = HttpClient();
      addTearDown(client.close);

      final request =
          await client.getUrl(Uri.parse('http://localhost:${server.port}/'));
      final response = await request.close();
      await response.drain();

      final setCookie = response.headers.value(HttpHeaders.setCookieHeader);
      expect(setCookie, isNotNull);
      expect(setCookie, contains('session='));
      expect(setCookie, contains('Max-Age=0'));
      expect(setCookie, contains('Expires='));
      expect(setCookie, contains('Path=/'));
    });

    test('ctx.res.signedCookie sets signed cookie', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      const secret = 'test-secret';

      server.listen((req) async {
        final ctx = Context(req, req.response);
        ctx.res.signedCookie('userId', '12345', secret);
        await ctx.res.text('ok');
      });

      final client = HttpClient();
      addTearDown(client.close);

      final request =
          await client.getUrl(Uri.parse('http://localhost:${server.port}/'));
      final response = await request.close();
      await response.drain();

      final setCookie = response.headers.value(HttpHeaders.setCookieHeader);
      expect(setCookie, isNotNull);
      expect(setCookie, contains('userId='));
      expect(setCookie, contains('.'));
    });

    test('ctx.res.jsonCookie sets JSON-encoded cookie', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      server.listen((req) async {
        final ctx = Context(req, req.response);
        ctx.res.jsonCookie('prefs', {'theme': 'dark', 'lang': 'en'});
        await ctx.res.text('ok');
      });

      final client = HttpClient();
      addTearDown(client.close);

      final request =
          await client.getUrl(Uri.parse('http://localhost:${server.port}/'));
      final response = await request.close();
      await response.drain();

      final setCookie = response.headers.value(HttpHeaders.setCookieHeader);
      expect(setCookie, isNotNull);
      expect(setCookie, contains('prefs='));
    });
  });

  group('Request Cookie Methods', () {
    test('req.signedCookie verifies and returns value', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      const secret = 'test-secret';
      final signedValue = signCookieValue('12345', secret);

      server.listen((req) async {
        final ctx = Context(req, req.response);
        final userId = ctx.req.signedCookie('userId', secret);
        await ctx.res.json({'userId': userId});
      });

      final client = HttpClient();
      addTearDown(client.close);

      final request =
          await client.getUrl(Uri.parse('http://localhost:${server.port}/'));
      request.headers.set(HttpHeaders.cookieHeader, 'userId=$signedValue');

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body) as Map<String, dynamic>;

      expect(decoded['userId'], '12345');
    });

    test('req.signedCookie returns null for tampered value', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      const secret = 'test-secret';

      server.listen((req) async {
        final ctx = Context(req, req.response);
        final userId = ctx.req.signedCookie('userId', secret);
        await ctx.res.json({'userId': userId});
      });

      final client = HttpClient();
      addTearDown(client.close);

      final request =
          await client.getUrl(Uri.parse('http://localhost:${server.port}/'));
      request.headers
          .set(HttpHeaders.cookieHeader, 'userId=tampered.invalidsig');

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body) as Map<String, dynamic>;

      expect(decoded['userId'], isNull);
    });

    test('req.jsonCookie decodes JSON value', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      final encodedPrefs = encodeCookieJson({'theme': 'dark', 'lang': 'en'});

      server.listen((req) async {
        final ctx = Context(req, req.response);
        final prefs = ctx.req.jsonCookie<Map<String, dynamic>>('prefs');
        await ctx.res.json({'prefs': prefs});
      });

      final client = HttpClient();
      addTearDown(client.close);

      final request =
          await client.getUrl(Uri.parse('http://localhost:${server.port}/'));
      request.headers.set(HttpHeaders.cookieHeader, 'prefs=$encodedPrefs');

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body) as Map<String, dynamic>;

      expect(decoded['prefs'], {'theme': 'dark', 'lang': 'en'});
    });

    test('req.signedJsonCookie verifies and decodes', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      const secret = 'test-secret';
      final encodedValue = encodeCookieJson({'userId': 123, 'role': 'admin'});
      final signedValue = signCookieValue(encodedValue, secret);

      server.listen((req) async {
        final ctx = Context(req, req.response);
        final session =
            ctx.req.signedJsonCookie<Map<String, dynamic>>('session', secret);
        await ctx.res.json({'session': session});
      });

      final client = HttpClient();
      addTearDown(client.close);

      final request =
          await client.getUrl(Uri.parse('http://localhost:${server.port}/'));
      request.headers.set(HttpHeaders.cookieHeader, 'session=$signedValue');

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body) as Map<String, dynamic>;

      expect(decoded['session'], {'userId': 123, 'role': 'admin'});
    });
  });
}
