import 'dart:io';

import 'package:chase/chase.dart';
import 'package:test/test.dart';

void main() {
  final fixturesPath = 'test/src/middleware/i18n/fixtures/locales';

  group('TranslationLoader', () {
    group('fromDirectory', () {
      test('loads all translation files from directory', () async {
        final translations = await TranslationLoader.fromDirectory(fixturesPath);

        expect(translations.keys, containsAll(['en', 'ja']));
      });

      test('loads JSON files correctly', () async {
        final translations = await TranslationLoader.fromDirectory(fixturesPath);

        expect(translations['en']!['greeting'], 'Hello');
        expect(translations['en']!['welcome'], 'Welcome, {name}!');
      });

      test('loads YAML files correctly', () async {
        final translations = await TranslationLoader.fromDirectory(fixturesPath);

        expect(translations['ja']!['greeting'], 'こんにちは');
        expect(translations['ja']!['welcome'], 'ようこそ、{name}さん！');
      });

      test('loads nested keys correctly', () async {
        final translations = await TranslationLoader.fromDirectory(fixturesPath);

        final enNested = translations['en']!['nested'] as Map<String, dynamic>;
        final enDeep = enNested['deep'] as Map<String, dynamic>;
        expect(enDeep['key'], 'Nested value');

        final jaNested = translations['ja']!['nested'] as Map<String, dynamic>;
        final jaDeep = jaNested['deep'] as Map<String, dynamic>;
        expect(jaDeep['key'], 'ネストされた値');
      });

      test('loads pluralization rules', () async {
        final translations = await TranslationLoader.fromDirectory(fixturesPath);

        final enItems = translations['en']!['items'] as Map<String, dynamic>;
        expect(enItems['zero'], 'No items');
        expect(enItems['one'], '1 item');
        expect(enItems['other'], '{count} items');

        final jaItems = translations['ja']!['items'] as Map<String, dynamic>;
        expect(jaItems['other'], '{count}個のアイテム');
      });

      test('throws on non-existent directory', () async {
        expect(
          () => TranslationLoader.fromDirectory('nonexistent'),
          throwsA(isA<FileSystemException>()),
        );
      });
    });

    group('fromDirectorySync', () {
      test('loads all translation files synchronously', () {
        final translations = TranslationLoader.fromDirectorySync(fixturesPath);

        expect(translations.keys, containsAll(['en', 'ja']));
        expect(translations['en']!['greeting'], 'Hello');
        expect(translations['ja']!['greeting'], 'こんにちは');
      });

      test('throws on non-existent directory', () {
        expect(
          () => TranslationLoader.fromDirectorySync('nonexistent'),
          throwsA(isA<FileSystemException>()),
        );
      });
    });

    group('fromFiles', () {
      test('loads specific files with custom locale keys', () async {
        final translations = await TranslationLoader.fromFiles({
          'english': '$fixturesPath/en.json',
          'japanese': '$fixturesPath/ja.yaml',
        });

        expect(translations.keys, containsAll(['english', 'japanese']));
        expect(translations['english']!['greeting'], 'Hello');
        expect(translations['japanese']!['greeting'], 'こんにちは');
      });

      test('skips non-existent files', () async {
        final translations = await TranslationLoader.fromFiles({
          'en': '$fixturesPath/en.json',
          'fr': '$fixturesPath/fr.json', // doesn't exist
        });

        expect(translations.keys, contains('en'));
        expect(translations.keys, isNot(contains('fr')));
      });
    });

    group('fromFilesSync', () {
      test('loads specific files synchronously', () {
        final translations = TranslationLoader.fromFilesSync({
          'en': '$fixturesPath/en.json',
          'ja': '$fixturesPath/ja.yaml',
        });

        expect(translations['en']!['greeting'], 'Hello');
        expect(translations['ja']!['greeting'], 'こんにちは');
      });
    });

    group('fromFile', () {
      test('loads a single JSON file', () async {
        final content = await TranslationLoader.fromFile('$fixturesPath/en.json');

        expect(content, isNotNull);
        expect(content!['greeting'], 'Hello');
      });

      test('loads a single YAML file', () async {
        final content = await TranslationLoader.fromFile('$fixturesPath/ja.yaml');

        expect(content, isNotNull);
        expect(content!['greeting'], 'こんにちは');
      });

      test('returns null for non-existent file', () async {
        final content = await TranslationLoader.fromFile('nonexistent.json');
        expect(content, isNull);
      });
    });

    group('fromFileSync', () {
      test('loads a single file synchronously', () {
        final content = TranslationLoader.fromFileSync('$fixturesPath/en.json');

        expect(content, isNotNull);
        expect(content!['greeting'], 'Hello');
      });

      test('returns null for non-existent file', () {
        final content = TranslationLoader.fromFileSync('nonexistent.json');
        expect(content, isNull);
      });
    });
  });

  group('I18nFileLoader extension', () {
    group('fromDirectory', () {
      test('creates I18n middleware from directory', () {
        final i18n = I18nFileLoader.fromDirectory(fixturesPath);

        expect(i18n, isA<I18n>());
        expect(i18n.translations.keys, containsAll(['en', 'ja']));
      });

      test('accepts custom options', () {
        final i18n = I18nFileLoader.fromDirectory(
          fixturesPath,
          defaultLocale: 'ja',
          cookieName: 'lang',
          queryParam: 'locale',
        );

        expect(i18n.defaultLocale, 'ja');
        expect(i18n.cookieName, 'lang');
        expect(i18n.queryParam, 'locale');
      });
    });

    group('loadFromDirectory', () {
      test('creates I18n middleware asynchronously', () async {
        final i18n = await I18nFileLoader.loadFromDirectory(fixturesPath);

        expect(i18n, isA<I18n>());
        expect(i18n.translations.keys, containsAll(['en', 'ja']));
      });
    });

    group('fromFiles', () {
      test('creates I18n middleware from specific files', () {
        final i18n = I18nFileLoader.fromFiles({
          'en': '$fixturesPath/en.json',
          'ja': '$fixturesPath/ja.yaml',
        });

        expect(i18n, isA<I18n>());
        expect(i18n.translations['en']!['greeting'], 'Hello');
        expect(i18n.translations['ja']!['greeting'], 'こんにちは');
      });
    });

    group('loadFromFiles', () {
      test('creates I18n middleware asynchronously from files', () async {
        final i18n = await I18nFileLoader.loadFromFiles({
          'en': '$fixturesPath/en.json',
          'ja': '$fixturesPath/ja.yaml',
        });

        expect(i18n, isA<I18n>());
        expect(i18n.translations.keys, containsAll(['en', 'ja']));
      });
    });
  });

  group('Integration with I18n middleware', () {
    test('works end-to-end with file-loaded translations', () {
      final i18n = I18nFileLoader.fromDirectory(fixturesPath);

      // Create a translator directly to test
      final translator = Translator(
        translations: i18n.translations,
        locale: 'en',
        fallbackLocale: 'en',
      );

      expect(translator.translate('greeting'), 'Hello');
      expect(translator.translate('welcome', {'name': 'World'}), 'Welcome, World!');
      expect(translator.translate('items', {'count': 5}), '5 items');
    });

    test('Japanese translations work correctly', () {
      final i18n = I18nFileLoader.fromDirectory(fixturesPath);

      final translator = Translator(
        translations: i18n.translations,
        locale: 'ja',
        fallbackLocale: 'en',
      );

      expect(translator.translate('greeting'), 'こんにちは');
      expect(translator.translate('welcome', {'name': '太郎'}), 'ようこそ、太郎さん！');
      expect(translator.translate('items', {'count': 3}), '3個のアイテム');
    });

    test('falls back to default locale for missing keys', () {
      final i18n = I18nFileLoader.fromDirectory(fixturesPath);

      final translator = Translator(
        translations: i18n.translations,
        locale: 'ja',
        fallbackLocale: 'en',
      );

      // Japanese has 'items.other' but not 'items.zero'
      // Should fall back to English
      expect(translator.translate('items', {'count': 0}), '0個のアイテム');
    });
  });
}
