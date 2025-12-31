import 'package:chase/chase.dart';
import 'package:chase/testing/testing.dart';
import 'package:test/test.dart';

void main() {
  final translations = <String, Map<String, dynamic>>{
    'en': {
      'greeting': 'Hello',
      'welcome': 'Welcome, {name}!',
      'items': {
        'zero': 'No items',
        'one': '1 item',
        'other': '{count} items',
      },
      'nested': {
        'deep': {
          'key': 'Nested value',
        },
      },
      'errors': {
        'required': 'This field is required',
        'minLength': 'Minimum {min} characters',
      },
    },
    'ja': {
      'greeting': 'こんにちは',
      'welcome': 'ようこそ、{name}さん！',
      'items': {
        'other': '{count}個のアイテム',
      },
      'nested': {
        'deep': {
          'key': 'ネストされた値',
        },
      },
    },
    'es': {
      'greeting': 'Hola',
    },
  };

  group('Translator', () {
    test('translates simple key', () {
      final translator = Translator(
        translations: translations,
        locale: 'en',
        fallbackLocale: 'en',
      );

      expect(translator.translate('greeting'), 'Hello');
    });

    test('returns key when not found', () {
      final translator = Translator(
        translations: translations,
        locale: 'en',
        fallbackLocale: 'en',
      );

      expect(translator.translate('nonexistent'), 'nonexistent');
    });

    test('interpolates variables', () {
      final translator = Translator(
        translations: translations,
        locale: 'en',
        fallbackLocale: 'en',
      );

      expect(
        translator.translate('welcome', {'name': 'John'}),
        'Welcome, John!',
      );
    });

    test('handles multiple variables', () {
      final translator = Translator(
        translations: translations,
        locale: 'en',
        fallbackLocale: 'en',
      );

      expect(
        translator.translate('errors.minLength', {'min': 8}),
        'Minimum 8 characters',
      );
    });

    test('handles nested keys with dot notation', () {
      final translator = Translator(
        translations: translations,
        locale: 'en',
        fallbackLocale: 'en',
      );

      expect(translator.translate('nested.deep.key'), 'Nested value');
      expect(translator.translate('errors.required'), 'This field is required');
    });

    test('handles pluralization - zero', () {
      final translator = Translator(
        translations: translations,
        locale: 'en',
        fallbackLocale: 'en',
      );

      expect(translator.translate('items', {'count': 0}), 'No items');
    });

    test('handles pluralization - one', () {
      final translator = Translator(
        translations: translations,
        locale: 'en',
        fallbackLocale: 'en',
      );

      expect(translator.translate('items', {'count': 1}), '1 item');
    });

    test('handles pluralization - other', () {
      final translator = Translator(
        translations: translations,
        locale: 'en',
        fallbackLocale: 'en',
      );

      expect(translator.translate('items', {'count': 5}), '5 items');
      expect(translator.translate('items', {'count': 100}), '100 items');
    });

    test('falls back to other for missing plural forms', () {
      final translator = Translator(
        translations: translations,
        locale: 'ja',
        fallbackLocale: 'en',
      );

      // Japanese only has 'other' form
      expect(translator.translate('items', {'count': 0}), '0個のアイテム');
      expect(translator.translate('items', {'count': 1}), '1個のアイテム');
      expect(translator.translate('items', {'count': 5}), '5個のアイテム');
    });

    test('uses fallback locale when key missing', () {
      final translator = Translator(
        translations: translations,
        locale: 'es',
        fallbackLocale: 'en',
      );

      // Spanish has greeting but not welcome
      expect(translator.translate('greeting'), 'Hola');
      expect(translator.translate('welcome', {'name': 'Juan'}), 'Welcome, Juan!');
    });

    test('translates in different locales', () {
      final enTranslator = Translator(
        translations: translations,
        locale: 'en',
        fallbackLocale: 'en',
      );
      final jaTranslator = Translator(
        translations: translations,
        locale: 'ja',
        fallbackLocale: 'en',
      );

      expect(enTranslator.translate('greeting'), 'Hello');
      expect(jaTranslator.translate('greeting'), 'こんにちは');

      expect(
        enTranslator.translate('welcome', {'name': 'John'}),
        'Welcome, John!',
      );
      expect(
        jaTranslator.translate('welcome', {'name': '太郎'}),
        'ようこそ、太郎さん！',
      );
    });
  });

  group('I18n Middleware', () {
    test('detects locale from query parameter', () async {
      final ctx = TestContext.get('/?lang=ja');

      await I18n(translations).handle(ctx, () async {});

      expect(ctx.locale, 'ja');
      expect(ctx.t('greeting'), 'こんにちは');
    });

    test('detects locale from cookie', () async {
      final ctx = TestContext.get('/', headers: {'cookie': 'locale=ja'});

      await I18n(translations).handle(ctx, () async {});

      expect(ctx.locale, 'ja');
      expect(ctx.t('greeting'), 'こんにちは');
    });

    test('detects locale from Accept-Language header', () async {
      final ctx = TestContext.get('/', headers: {'accept-language': 'ja-JP,ja;q=0.9,en;q=0.8'});

      await I18n(translations).handle(ctx, () async {});

      expect(ctx.locale, 'ja');
    });

    test('handles Accept-Language with quality values', () async {
      // Prefers Spanish over Japanese based on quality
      final ctx = TestContext.get('/', headers: {'accept-language': 'ja;q=0.8,es;q=0.9'});

      await I18n(translations).handle(ctx, () async {});

      expect(ctx.locale, 'es');
    });

    test('falls back to language code from Accept-Language', () async {
      // en-US should match 'en'
      final ctx = TestContext.get('/', headers: {'accept-language': 'en-US'});

      await I18n(translations).handle(ctx, () async {});

      expect(ctx.locale, 'en');
    });

    test('uses default locale when no match', () async {
      final ctx = TestContext.get('/', headers: {'accept-language': 'fr-FR'});

      await I18n(translations, defaultLocale: 'en').handle(ctx, () async {});

      expect(ctx.locale, 'en');
    });

    test('query parameter takes precedence over cookie', () async {
      final ctx = TestContext.get('/?lang=en', headers: {'cookie': 'locale=ja'});

      await I18n(translations).handle(ctx, () async {});

      expect(ctx.locale, 'en');
    });

    test('cookie takes precedence over Accept-Language', () async {
      final ctx = TestContext.get(
        '/',
        headers: {
          'cookie': 'locale=ja',
          'accept-language': 'en-US',
        },
      );

      await I18n(translations).handle(ctx, () async {});

      expect(ctx.locale, 'ja');
    });

    test('custom locale resolver takes highest precedence', () async {
      final ctx = TestContext.get('/?lang=en', headers: {'cookie': 'locale=ja'});

      await I18n(
        translations,
        localeResolver: (_) => 'es',
      ).handle(ctx, () async {});

      expect(ctx.locale, 'es');
    });

    test('respects supported locales', () async {
      final ctx = TestContext.get('/?lang=es');

      await I18n(
        translations,
        supportedLocales: ['en', 'ja'], // es not supported
        defaultLocale: 'en',
      ).handle(ctx, () async {});

      expect(ctx.locale, 'en'); // Falls back to default
    });

    test('custom cookie name works', () async {
      final ctx = TestContext.get('/', headers: {'cookie': 'lang=ja'});

      await I18n(translations, cookieName: 'lang').handle(ctx, () async {});

      expect(ctx.locale, 'ja');
    });

    test('custom query param works', () async {
      final ctx = TestContext.get('/?locale=ja');

      await I18n(translations, queryParam: 'locale').handle(ctx, () async {});

      expect(ctx.locale, 'ja');
    });

    test('disabling header detection works', () async {
      final ctx = TestContext.get('/', headers: {'accept-language': 'ja'});

      await I18n(
        translations,
        detectFromHeader: false,
        defaultLocale: 'en',
      ).handle(ctx, () async {});

      expect(ctx.locale, 'en');
    });

    test('disabling cookie detection works', () async {
      final ctx = TestContext.get('/', headers: {'cookie': 'locale=ja'});

      await I18n(
        translations,
        cookieName: null, // Disable cookie detection
        defaultLocale: 'en',
      ).handle(ctx, () async {});

      expect(ctx.locale, 'en');
    });

    test('disabling query param detection works', () async {
      final ctx = TestContext.get('/?lang=ja');

      await I18n(
        translations,
        queryParam: null, // Disable query param detection
        defaultLocale: 'en',
      ).handle(ctx, () async {});

      expect(ctx.locale, 'en');
    });
  });

  group('Context Extension', () {
    test('ctx.t translates correctly', () async {
      final ctx = TestContext.get('/');

      await I18n(translations).handle(ctx, () async {});

      expect(ctx.t('greeting'), 'Hello');
      expect(ctx.t('welcome', {'name': 'World'}), 'Welcome, World!');
    });

    test('ctx.locale returns current locale', () async {
      final ctx = TestContext.get('/?lang=ja');

      await I18n(translations).handle(ctx, () async {});

      expect(ctx.locale, 'ja');
    });

    test('ctx.t returns key when no middleware', () {
      final ctx = TestContext.get('/');

      // No I18n middleware used
      expect(ctx.t('greeting'), 'greeting');
    });

    test('ctx.locale returns en when no middleware', () {
      final ctx = TestContext.get('/');

      expect(ctx.locale, 'en');
    });
  });

  group('Integration', () {
    late Chase app;
    late TestClient client;

    setUp(() async {
      app = Chase();
      app.use(I18n(translations));

      app.get('/greeting').handle((ctx) async {
        await ctx.res.json({'message': ctx.t('greeting')});
      });

      app.get('/welcome').handle((ctx) async {
        final name = ctx.req.query('name') ?? 'Guest';
        await ctx.res.json({'message': ctx.t('welcome', {'name': name})});
      });

      app.get('/items').handle((ctx) async {
        final count = ctx.req.query<int>('count') ?? 0;
        await ctx.res.json({'message': ctx.t('items', {'count': count})});
      });

      app.get('/locale').handle((ctx) async {
        await ctx.res.json({'locale': ctx.locale});
      });

      client = await TestClient.start(app);
    });

    tearDown(() async {
      await client.close();
    });

    test('translates based on Accept-Language', () async {
      final res = await client.get(
        '/greeting',
        headers: {'accept-language': 'ja'},
      );

      expect(res, isOkResponse);
      expect(await res.json, hasJsonPath('message', 'こんにちは'));
    });

    test('translates based on query parameter', () async {
      final res = await client.get('/greeting?lang=ja');

      expect(res, isOkResponse);
      expect(await res.json, hasJsonPath('message', 'こんにちは'));
    });

    test('interpolates variables', () async {
      final res = await client.get('/welcome?name=Alice&lang=en');

      expect(res, isOkResponse);
      expect(await res.json, hasJsonPath('message', 'Welcome, Alice!'));
    });

    test('handles pluralization', () async {
      final res0 = await client.get('/items?count=0&lang=en');
      expect(await res0.json, hasJsonPath('message', 'No items'));

      final res1 = await client.get('/items?count=1&lang=en');
      expect(await res1.json, hasJsonPath('message', '1 item'));

      final res5 = await client.get('/items?count=5&lang=en');
      expect(await res5.json, hasJsonPath('message', '5 items'));
    });

    test('returns current locale', () async {
      final res = await client.get('/locale?lang=ja');

      expect(await res.json, hasJsonPath('locale', 'ja'));
    });
  });
}
