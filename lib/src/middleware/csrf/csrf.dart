import 'dart:async';
import 'dart:io';

import 'package:chase/src/core/context/context.dart';
import 'package:chase/src/core/middleware.dart';
import 'package:zlogger/zlogger.dart';

/// Callback function for validating origin headers.
/// Returns true if the origin is valid, false otherwise.
typedef OriginValidator = bool Function(String origin, Context ctx);

/// Callback function for validating Sec-Fetch-Site headers.
/// Returns true if the sec-fetch-site value is valid, false otherwise.
typedef SecFetchSiteValidator = bool Function(String secFetchSite, Context ctx);

/// CSRF (Cross-Site Request Forgery) Protection middleware.
///
/// Protects against CSRF attacks by validating the Origin and Sec-Fetch-Site
/// headers for unsafe HTTP methods (POST, PUT, DELETE, PATCH).
///
/// CSRF attacks occur when a malicious site tricks a user's browser into making
/// unauthorized requests to your site. This middleware prevents such attacks by
/// checking that requests originate from trusted sources.
///
/// How it works:
/// 1. Safe methods (GET, HEAD, OPTIONS) are allowed without validation
/// 2. For unsafe methods (POST, PUT, DELETE, PATCH):
///    - Validates Origin header against allowed origins
///    - Falls back to Sec-Fetch-Site header validation
///    - Rejects requests missing both headers
/// 3. Only validates requests with form-like Content-Types to avoid
///    blocking legitimate API requests (JSON, XML, etc.)
///
/// Security notes:
/// - Always use HTTPS in production
/// - This is a defense-in-depth measure, not a complete CSRF solution
/// - For APIs, consider using token-based CSRF protection
/// - Modern browsers provide additional CSRF protection via SameSite cookies
///
/// Example usage:
/// ```dart
/// // Allow requests from a single origin
/// app.use(Csrf.origin('https://example.com'));
///
/// // Allow requests from multiple origins
/// app.use(Csrf.origins([
///   'https://example.com',
///   'https://www.example.com',
/// ]));
///
/// // Custom origin validation
/// app.use(Csrf.originValidator((origin, ctx) {
///   return origin.endsWith('.example.com');
/// }));
///
/// // Validate using Sec-Fetch-Site header
/// app.use(Csrf.secFetchSite('same-origin'));
///
/// // Allow same-origin and same-site
/// app.use(Csrf.secFetchSites(['same-origin', 'same-site']));
///
/// // Custom error message
/// app.use(Csrf.origin(
///   'https://example.com',
///   errorMessage: 'Invalid request origin',
/// ));
/// ```
class Csrf implements Middleware {
  static final _log = Log.named('Csrf');

  final OriginValidator? _originValidator;
  final SecFetchSiteValidator? _secFetchSiteValidator;

  /// Custom error message to return when CSRF validation fails.
  final String errorMessage;

  /// Creates a CSRF middleware with custom validators.
  ///
  /// At least one of [originValidator] or [secFetchSiteValidator] must be provided.
  const Csrf._({
    OriginValidator? originValidator,
    SecFetchSiteValidator? secFetchSiteValidator,
    this.errorMessage = 'Potential CSRF attack detected',
  }) : _originValidator = originValidator,
       _secFetchSiteValidator = secFetchSiteValidator,
       assert(
         originValidator != null || secFetchSiteValidator != null,
         'At least one validator must be provided',
       );

  /// Creates a CSRF middleware that validates against a single origin.
  ///
  /// Example:
  /// ```dart
  /// app.use(Csrf.origin('https://example.com'));
  /// ```
  factory Csrf.origin(
    String origin, {
    String errorMessage = 'Potential CSRF attack detected',
  }) {
    return Csrf._(
      originValidator: (o, _) => o == origin,
      errorMessage: errorMessage,
    );
  }

  /// Creates a CSRF middleware that validates against multiple origins.
  ///
  /// Example:
  /// ```dart
  /// app.use(Csrf.origins([
  ///   'https://example.com',
  ///   'https://www.example.com',
  /// ]));
  /// ```
  factory Csrf.origins(
    List<String> origins, {
    String errorMessage = 'Potential CSRF attack detected',
  }) {
    return Csrf._(
      originValidator: (o, _) => origins.contains(o),
      errorMessage: errorMessage,
    );
  }

  /// Creates a CSRF middleware with a custom origin validator function.
  ///
  /// Example:
  /// ```dart
  /// app.use(Csrf.originValidator((origin, ctx) {
  ///   return origin.endsWith('.example.com');
  /// }));
  /// ```
  factory Csrf.originValidator(
    OriginValidator validator, {
    String errorMessage = 'Potential CSRF attack detected',
  }) {
    return Csrf._(originValidator: validator, errorMessage: errorMessage);
  }

  /// Creates a CSRF middleware that validates against a single Sec-Fetch-Site value.
  ///
  /// Common values:
  /// - `same-origin`: Request from the same origin
  /// - `same-site`: Request from the same site (different subdomain)
  /// - `cross-site`: Request from a different site
  /// - `none`: Request initiated by the user (e.g., bookmark)
  ///
  /// Example:
  /// ```dart
  /// app.use(Csrf.secFetchSite('same-origin'));
  /// ```
  factory Csrf.secFetchSite(
    String secFetchSite, {
    String errorMessage = 'Potential CSRF attack detected',
  }) {
    return Csrf._(
      secFetchSiteValidator: (s, _) => s == secFetchSite,
      errorMessage: errorMessage,
    );
  }

  /// Creates a CSRF middleware that validates against multiple Sec-Fetch-Site values.
  ///
  /// Example:
  /// ```dart
  /// app.use(Csrf.secFetchSites(['same-origin', 'same-site']));
  /// ```
  factory Csrf.secFetchSites(
    List<String> secFetchSites, {
    String errorMessage = 'Potential CSRF attack detected',
  }) {
    return Csrf._(
      secFetchSiteValidator: (s, _) => secFetchSites.contains(s),
      errorMessage: errorMessage,
    );
  }

  /// Creates a CSRF middleware with a custom Sec-Fetch-Site validator function.
  ///
  /// Example:
  /// ```dart
  /// app.use(Csrf.secFetchSiteValidator((secFetchSite, ctx) {
  ///   return secFetchSite == 'same-origin' || secFetchSite == 'same-site';
  /// }));
  /// ```
  factory Csrf.secFetchSiteValidator(
    SecFetchSiteValidator validator, {
    String errorMessage = 'Potential CSRF attack detected',
  }) {
    return Csrf._(secFetchSiteValidator: validator, errorMessage: errorMessage);
  }

  /// HTTP methods that require CSRF validation.
  static const _unsafeMethods = {'POST', 'PUT', 'DELETE', 'PATCH'};

  /// Content-Types that can be submitted via HTML forms.
  /// These are the only content types that browsers can use for CSRF attacks.
  static const _formContentTypes = {
    'application/x-www-form-urlencoded',
    'multipart/form-data',
    'text/plain',
  };

  @override
  Future<void> handle(Context ctx, NextFunction next) async {
    // Safe methods (GET, HEAD, OPTIONS) don't need CSRF protection
    if (!_unsafeMethods.contains(ctx.req.method.toUpperCase())) {
      await next();
      return;
    }

    // Only validate form-like content types
    // JSON, XML, etc. are protected by CORS and can't be sent via forms
    final contentType = ctx.req.header('content-type');
    if (contentType != null && !_isFormContentType(contentType)) {
      await next();
      return;
    }

    // Validate Origin header (preferred method)
    if (_originValidator != null) {
      final originHeader = ctx.req.header('origin');
      if (originHeader != null) {
        if (_originValidator(originHeader, ctx)) {
          await next();
          return;
        } else {
          await _forbidden(ctx, 'Invalid origin');
          return;
        }
      }
    }

    // Fallback to Sec-Fetch-Site header validation
    if (_secFetchSiteValidator != null) {
      final secFetchSiteHeader = ctx.req.header('sec-fetch-site');
      if (secFetchSiteHeader != null) {
        if (_secFetchSiteValidator(secFetchSiteHeader, ctx)) {
          await next();
          return;
        } else {
          await _forbidden(ctx, 'Invalid sec-fetch-site');
          return;
        }
      }
    }

    // No valid headers found
    await _forbidden(ctx, 'Missing CSRF validation headers');
  }

  /// Checks if the Content-Type is a form-like type that can be used for CSRF.
  bool _isFormContentType(String contentType) {
    // Content-Type may include parameters like charset, so extract the media type
    final mediaType = contentType.split(';').first.trim().toLowerCase();
    return _formContentTypes.contains(mediaType);
  }

  /// Sends a 403 Forbidden response.
  Future<void> _forbidden(Context ctx, String details) async {
    _log.warn('CSRF validation failed: $details', {
      'request_id': ctx.get<String>('_requestId'),
      'method': ctx.req.method,
      'path': ctx.req.path,
      'ip': _safeGetIp(ctx),
      'origin': ctx.req.header('origin'),
      'sec_fetch_site': ctx.req.header('sec-fetch-site'),
    });

    await ctx.res.json({
      'error': errorMessage,
      'message': details,
    }, status: HttpStatus.forbidden);
  }

  /// Safely gets the remote IP address, returning null if not available.
  String? _safeGetIp(Context ctx) {
    try {
      return ctx.req.remoteAddress;
    } catch (_) {
      return null;
    }
  }
}
