import 'dart:async';

import 'package:chase/src/core/context/context.dart';
import 'package:chase/src/core/middleware.dart';

export 'translation_loader.dart';

// -----------------------------------------------------------------------------
// Types
// -----------------------------------------------------------------------------

/// Translation messages type.
///
/// Structure: `{ 'locale': { 'key': 'translation' } }`
///
/// Example:
/// ```dart
/// {
///   'en': {
///     'greeting': 'Hello',
///     'items': {'one': '1 item', 'other': '{count} items'},
///   },
///   'ja': {
///     'greeting': 'こんにちは',
///     'items': {'other': '{count}個のアイテム'},
///   },
/// }
/// ```
typedef Translations = Map<String, Map<String, dynamic>>;

/// Function type for resolving locale from context.
typedef LocaleResolver = String? Function(Context ctx);

// -----------------------------------------------------------------------------
// I18n Middleware
// -----------------------------------------------------------------------------

/// Internationalization (i18n) middleware.
///
/// Provides translation support with:
/// - Multiple locale support
/// - Language detection from Accept-Language header, cookie, or query parameter
/// - Variable interpolation: `'Hello {name}'`
/// - Pluralization support: `{'one': '1 item', 'other': '{count} items'}`
/// - Fallback locale
///
/// ## Example
///
/// ```dart
/// final translations = {
///   'en': {
///     'greeting': 'Hello, {name}!',
///     'items': {'one': '1 item', 'other': '{count} items'},
///   },
///   'ja': {
///     'greeting': 'こんにちは、{name}さん！',
///     'items': {'other': '{count}個のアイテム'},
///   },
/// };
///
/// app.use(I18n(translations));
///
/// app.get('/').handle((ctx) async {
///   // Simple translation
///   final greeting = ctx.t('greeting', {'name': 'John'});
///
///   // Pluralization
///   final items = ctx.t('items', {'count': 5});
///
///   await ctx.res.json({'greeting': greeting, 'items': items});
/// });
/// ```
class I18n implements Middleware {
  /// Translation messages.
  final Translations translations;

  /// Default locale when detection fails.
  final String defaultLocale;

  /// Supported locales. If empty, all locales in translations are supported.
  final List<String> supportedLocales;

  /// Cookie name for locale override.
  final String? cookieName;

  /// Query parameter name for locale override.
  final String? queryParam;

  /// Custom locale resolver. Takes precedence over built-in detection.
  final LocaleResolver? localeResolver;

  /// Whether to detect locale from Accept-Language header.
  final bool detectFromHeader;

  /// Creates an I18n middleware.
  ///
  /// - [translations]: Translation messages map
  /// - [defaultLocale]: Fallback locale (default: 'en')
  /// - [supportedLocales]: List of supported locales (default: all in translations)
  /// - [cookieName]: Cookie name for locale override (default: 'locale')
  /// - [queryParam]: Query param for locale override (default: 'lang')
  /// - [localeResolver]: Custom locale resolver function
  /// - [detectFromHeader]: Whether to use Accept-Language header (default: true)
  const I18n(
    this.translations, {
    this.defaultLocale = 'en',
    this.supportedLocales = const [],
    this.cookieName = 'locale',
    this.queryParam = 'lang',
    this.localeResolver,
    this.detectFromHeader = true,
  });

  @override
  FutureOr<void> handle(Context ctx, NextFunction next) async {
    final locale = _detectLocale(ctx);
    final translator = Translator(
      translations: translations,
      locale: locale,
      fallbackLocale: defaultLocale,
    );

    ctx.set('_i18n_locale', locale);
    ctx.set('_i18n_translator', translator);

    return next();
  }

  /// Detects the locale from various sources.
  String _detectLocale(Context ctx) {
    final supported = supportedLocales.isEmpty
        ? translations.keys.toList()
        : supportedLocales;

    // 1. Custom resolver
    if (localeResolver != null) {
      final resolved = localeResolver!(ctx);
      if (resolved != null && supported.contains(resolved)) {
        return resolved;
      }
    }

    // 2. Query parameter
    if (queryParam != null) {
      final queryLocale = ctx.req.query<String>(queryParam!);
      if (queryLocale != null && supported.contains(queryLocale)) {
        return queryLocale;
      }
    }

    // 3. Cookie
    if (cookieName != null) {
      final cookieLocale = ctx.req.cookie(cookieName!);
      if (cookieLocale != null && supported.contains(cookieLocale)) {
        return cookieLocale;
      }
    }

    // 4. Accept-Language header
    if (detectFromHeader) {
      final headerLocale = _parseAcceptLanguage(ctx, supported);
      if (headerLocale != null) {
        return headerLocale;
      }
    }

    // 5. Default
    return defaultLocale;
  }

  /// Parses Accept-Language header and returns best matching locale.
  String? _parseAcceptLanguage(Context ctx, List<String> supported) {
    final header = ctx.req.header('accept-language');
    if (header == null || header.isEmpty) return null;

    final locales = _parseAcceptLanguageHeader(header);

    for (final locale in locales) {
      // Exact match
      if (supported.contains(locale)) {
        return locale;
      }
      // Language-only match (e.g., 'en-US' -> 'en')
      final lang = locale.split('-').first;
      if (supported.contains(lang)) {
        return lang;
      }
    }

    return null;
  }

  /// Parses Accept-Language header into sorted list of locales.
  List<String> _parseAcceptLanguageHeader(String header) {
    final entries = <_LocaleEntry>[];

    for (final part in header.split(',')) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;

      final segments = trimmed.split(';');
      final locale = segments.first.trim();
      var quality = 1.0;

      if (segments.length > 1) {
        final qPart = segments[1].trim();
        if (qPart.startsWith('q=')) {
          quality = double.tryParse(qPart.substring(2)) ?? 1.0;
        }
      }

      entries.add(_LocaleEntry(locale, quality));
    }

    // Sort by quality descending
    entries.sort((a, b) => b.quality.compareTo(a.quality));

    return entries.map((e) => e.locale).toList();
  }
}

class _LocaleEntry {
  final String locale;
  final double quality;

  _LocaleEntry(this.locale, this.quality);
}

// -----------------------------------------------------------------------------
// Translator
// -----------------------------------------------------------------------------

/// Translator class for performing translations.
class Translator {
  final Translations translations;
  final String locale;
  final String fallbackLocale;

  const Translator({
    required this.translations,
    required this.locale,
    required this.fallbackLocale,
  });

  /// Translates a key with optional parameters.
  ///
  /// Supports:
  /// - Variable interpolation: `'Hello {name}'` with `{'name': 'John'}`
  /// - Pluralization: `{'one': '1 item', 'other': '{count} items'}` with `{'count': 5}`
  ///
  /// Returns the key itself if no translation is found.
  String translate(String key, [Map<String, dynamic>? params]) {
    final value = _lookup(key);
    if (value == null) return key;

    // Handle pluralization
    if (value is Map<String, dynamic>) {
      return _pluralize(value, params);
    }

    // Handle string interpolation
    if (value is String) {
      return _interpolate(value, params);
    }

    return key;
  }

  /// Looks up a translation value by key.
  dynamic _lookup(String key) {
    // Try current locale
    final localeMessages = translations[locale];
    if (localeMessages != null) {
      final value = _getNestedValue(localeMessages, key);
      if (value != null) return value;
    }

    // Try fallback locale
    if (locale != fallbackLocale) {
      final fallbackMessages = translations[fallbackLocale];
      if (fallbackMessages != null) {
        final value = _getNestedValue(fallbackMessages, key);
        if (value != null) return value;
      }
    }

    return null;
  }

  /// Gets a nested value using dot notation.
  ///
  /// Example: `'errors.validation.required'` -> `messages['errors']['validation']['required']`
  dynamic _getNestedValue(Map<String, dynamic> map, String key) {
    final parts = key.split('.');
    dynamic current = map;

    for (final part in parts) {
      if (current is! Map<String, dynamic>) return null;
      current = current[part];
      if (current == null) return null;
    }

    return current;
  }

  /// Handles pluralization.
  String _pluralize(Map<String, dynamic> pluralMap, Map<String, dynamic>? params) {
    final count = params?['count'];
    final n = count is num ? count.toInt() : 0;

    String? template;

    // Simple plural rules (can be extended for more complex rules)
    if (n == 0 && pluralMap.containsKey('zero')) {
      template = pluralMap['zero'] as String?;
    } else if (n == 1 && pluralMap.containsKey('one')) {
      template = pluralMap['one'] as String?;
    } else if (n == 2 && pluralMap.containsKey('two')) {
      template = pluralMap['two'] as String?;
    } else if (pluralMap.containsKey('few') && n >= 3 && n <= 10) {
      template = pluralMap['few'] as String?;
    } else if (pluralMap.containsKey('many') && n > 10) {
      template = pluralMap['many'] as String?;
    }

    // Fallback to 'other'
    template ??= pluralMap['other'] as String?;

    if (template == null) return '';

    return _interpolate(template, params);
  }

  /// Interpolates variables in a string.
  String _interpolate(String template, Map<String, dynamic>? params) {
    if (params == null || params.isEmpty) return template;

    var result = template;
    for (final entry in params.entries) {
      result = result.replaceAll('{${entry.key}}', entry.value.toString());
    }

    return result;
  }
}

// -----------------------------------------------------------------------------
// Context Extension
// -----------------------------------------------------------------------------

/// Extension on Context for i18n access.
extension I18nContextExtension on Context {
  /// Gets the current locale.
  String get locale => get<String>('_i18n_locale') ?? 'en';

  /// Gets the translator instance.
  Translator? get _translator => get<Translator>('_i18n_translator');

  /// Translates a key with optional parameters.
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Simple translation
  /// ctx.t('greeting'); // 'Hello'
  ///
  /// // With variables
  /// ctx.t('welcome', {'name': 'John'}); // 'Welcome, John!'
  ///
  /// // Pluralization
  /// ctx.t('items', {'count': 1}); // '1 item'
  /// ctx.t('items', {'count': 5}); // '5 items'
  ///
  /// // Nested keys
  /// ctx.t('errors.validation.required'); // 'This field is required'
  /// ```
  String t(String key, [Map<String, dynamic>? params]) {
    final translator = _translator;
    if (translator == null) {
      // No i18n middleware, return key
      return key;
    }
    return translator.translate(key, params);
  }
}
