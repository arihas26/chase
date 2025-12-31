import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

import 'i18n.dart';

// -----------------------------------------------------------------------------
// Translation Loader
// -----------------------------------------------------------------------------

/// Loads translations from files.
///
/// Supports JSON and YAML formats with automatic detection based on file extension.
///
/// ## Example
///
/// ```dart
/// // Load from a directory (auto-detects files)
/// final translations = await TranslationLoader.fromDirectory('locales');
///
/// // Load specific files
/// final translations = await TranslationLoader.fromFiles({
///   'en': 'locales/en.json',
///   'ja': 'locales/ja.yaml',
/// });
///
/// // Use with I18n middleware
/// app.use(I18n(translations));
/// ```
class TranslationLoader {
  TranslationLoader._();

  /// Loads translations from a directory.
  ///
  /// Scans for `.json`, `.yaml`, and `.yml` files.
  /// The filename (without extension) is used as the locale code.
  ///
  /// Example directory structure:
  /// ```
  /// locales/
  ///   en.json      → locale: 'en'
  ///   ja.yaml      → locale: 'ja'
  ///   zh-CN.json   → locale: 'zh-CN'
  /// ```
  ///
  /// Throws [FileSystemException] if the directory doesn't exist.
  static Future<Translations> fromDirectory(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      throw FileSystemException('Directory not found', path);
    }

    final translations = <String, Map<String, dynamic>>{};
    final supportedExtensions = ['.json', '.yaml', '.yml'];

    await for (final entity in dir.list()) {
      if (entity is! File) continue;

      final filename = entity.uri.pathSegments.last;
      final ext = _getExtension(filename);

      if (!supportedExtensions.contains(ext)) continue;

      final locale = _getLocaleFromFilename(filename);
      final content = await _loadFile(entity.path);

      if (content != null) {
        translations[locale] = content;
      }
    }

    return translations;
  }

  /// Loads translations from specific files.
  ///
  /// The map key is the locale code, and the value is the file path.
  ///
  /// ```dart
  /// final translations = await TranslationLoader.fromFiles({
  ///   'en': 'locales/en.json',
  ///   'ja': 'locales/ja.yaml',
  ///   'es': 'locales/spanish.json',
  /// });
  /// ```
  static Future<Translations> fromFiles(Map<String, String> files) async {
    final translations = <String, Map<String, dynamic>>{};

    for (final entry in files.entries) {
      final locale = entry.key;
      final path = entry.value;
      final content = await _loadFile(path);

      if (content != null) {
        translations[locale] = content;
      }
    }

    return translations;
  }

  /// Loads a single translation file.
  ///
  /// Automatically detects format based on file extension.
  static Future<Map<String, dynamic>?> fromFile(String path) async {
    return _loadFile(path);
  }

  /// Loads translations synchronously from a directory.
  ///
  /// Useful for initialization before the server starts.
  static Translations fromDirectorySync(String path) {
    final dir = Directory(path);
    if (!dir.existsSync()) {
      throw FileSystemException('Directory not found', path);
    }

    final translations = <String, Map<String, dynamic>>{};
    final supportedExtensions = ['.json', '.yaml', '.yml'];

    for (final entity in dir.listSync()) {
      if (entity is! File) continue;

      final filename = entity.uri.pathSegments.last;
      final ext = _getExtension(filename);

      if (!supportedExtensions.contains(ext)) continue;

      final locale = _getLocaleFromFilename(filename);
      final content = _loadFileSync(entity.path);

      if (content != null) {
        translations[locale] = content;
      }
    }

    return translations;
  }

  /// Loads translations synchronously from specific files.
  static Translations fromFilesSync(Map<String, String> files) {
    final translations = <String, Map<String, dynamic>>{};

    for (final entry in files.entries) {
      final locale = entry.key;
      final path = entry.value;
      final content = _loadFileSync(path);

      if (content != null) {
        translations[locale] = content;
      }
    }

    return translations;
  }

  /// Loads a single translation file synchronously.
  static Map<String, dynamic>? fromFileSync(String path) {
    return _loadFileSync(path);
  }

  // ---------------------------------------------------------------------------
  // Private Helpers
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>?> _loadFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return null;
    }

    final content = await file.readAsString();
    return _parseContent(content, path);
  }

  static Map<String, dynamic>? _loadFileSync(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      return null;
    }

    final content = file.readAsStringSync();
    return _parseContent(content, path);
  }

  static Map<String, dynamic>? _parseContent(String content, String path) {
    final ext = _getExtension(path);

    try {
      if (ext == '.json') {
        return _parseJson(content);
      } else if (ext == '.yaml' || ext == '.yml') {
        return _parseYaml(content);
      }
    } catch (e) {
      throw FormatException('Failed to parse translation file: $path', e);
    }

    return null;
  }

  static Map<String, dynamic> _parseJson(String content) {
    final decoded = jsonDecode(content);
    return _convertToStringDynamicMap(decoded);
  }

  static Map<String, dynamic> _parseYaml(String content) {
    final decoded = loadYaml(content);
    return _convertToStringDynamicMap(decoded);
  }

  /// Converts YAML/JSON maps to `Map<String, dynamic>` recursively.
  static Map<String, dynamic> _convertToStringDynamicMap(dynamic value) {
    if (value is Map) {
      return value.map((key, val) {
        if (val is Map) {
          return MapEntry(key.toString(), _convertToStringDynamicMap(val));
        } else if (val is List) {
          return MapEntry(key.toString(), _convertList(val));
        }
        return MapEntry(key.toString(), val);
      });
    }
    return {};
  }

  static List<dynamic> _convertList(List<dynamic> list) {
    return list.map((item) {
      if (item is Map) {
        return _convertToStringDynamicMap(item);
      } else if (item is List) {
        return _convertList(item);
      }
      return item;
    }).toList();
  }

  static String _getExtension(String path) {
    final lastDot = path.lastIndexOf('.');
    if (lastDot == -1) return '';
    return path.substring(lastDot).toLowerCase();
  }

  static String _getLocaleFromFilename(String filename) {
    final lastDot = filename.lastIndexOf('.');
    if (lastDot == -1) return filename;
    return filename.substring(0, lastDot);
  }
}

// -----------------------------------------------------------------------------
// I18n Extension for File Loading
// -----------------------------------------------------------------------------

/// Extension on I18n for convenient file-based initialization.
extension I18nFileLoader on I18n {
  /// Creates an I18n middleware from a translations directory.
  ///
  /// ```dart
  /// // Async loading
  /// final i18n = await I18n.loadFromDirectory('locales');
  /// app.use(i18n);
  ///
  /// // Or sync loading
  /// app.use(I18n.fromDirectory('locales'));
  /// ```
  static Future<I18n> loadFromDirectory(
    String path, {
    String defaultLocale = 'en',
    List<String> supportedLocales = const [],
    String? cookieName = 'locale',
    String? queryParam = 'lang',
    LocaleResolver? localeResolver,
    bool detectFromHeader = true,
  }) async {
    final translations = await TranslationLoader.fromDirectory(path);
    return I18n(
      translations,
      defaultLocale: defaultLocale,
      supportedLocales: supportedLocales,
      cookieName: cookieName,
      queryParam: queryParam,
      localeResolver: localeResolver,
      detectFromHeader: detectFromHeader,
    );
  }

  /// Creates an I18n middleware from a translations directory (sync).
  static I18n fromDirectory(
    String path, {
    String defaultLocale = 'en',
    List<String> supportedLocales = const [],
    String? cookieName = 'locale',
    String? queryParam = 'lang',
    LocaleResolver? localeResolver,
    bool detectFromHeader = true,
  }) {
    final translations = TranslationLoader.fromDirectorySync(path);
    return I18n(
      translations,
      defaultLocale: defaultLocale,
      supportedLocales: supportedLocales,
      cookieName: cookieName,
      queryParam: queryParam,
      localeResolver: localeResolver,
      detectFromHeader: detectFromHeader,
    );
  }

  /// Creates an I18n middleware from specific translation files.
  ///
  /// ```dart
  /// final i18n = await I18n.loadFromFiles({
  ///   'en': 'locales/en.json',
  ///   'ja': 'locales/ja.yaml',
  /// });
  /// app.use(i18n);
  /// ```
  static Future<I18n> loadFromFiles(
    Map<String, String> files, {
    String defaultLocale = 'en',
    List<String> supportedLocales = const [],
    String? cookieName = 'locale',
    String? queryParam = 'lang',
    LocaleResolver? localeResolver,
    bool detectFromHeader = true,
  }) async {
    final translations = await TranslationLoader.fromFiles(files);
    return I18n(
      translations,
      defaultLocale: defaultLocale,
      supportedLocales: supportedLocales,
      cookieName: cookieName,
      queryParam: queryParam,
      localeResolver: localeResolver,
      detectFromHeader: detectFromHeader,
    );
  }

  /// Creates an I18n middleware from specific translation files (sync).
  static I18n fromFiles(
    Map<String, String> files, {
    String defaultLocale = 'en',
    List<String> supportedLocales = const [],
    String? cookieName = 'locale',
    String? queryParam = 'lang',
    LocaleResolver? localeResolver,
    bool detectFromHeader = true,
  }) {
    final translations = TranslationLoader.fromFilesSync(files);
    return I18n(
      translations,
      defaultLocale: defaultLocale,
      supportedLocales: supportedLocales,
      cookieName: cookieName,
      queryParam: queryParam,
      localeResolver: localeResolver,
      detectFromHeader: detectFromHeader,
    );
  }
}
