import 'dart:io';

import 'package:chase/src/core/context/context.dart';
import 'package:chase/src/core/middleware.dart';

/// Cache-Control HTTP header middleware.
///
/// Sets the Cache-Control header to control how browsers and CDNs cache responses.
/// The Cache-Control header is defined in RFC 7234 and is the primary mechanism
/// for HTTP caching.
///
/// Common directives:
/// - `max-age`: Maximum time a response is considered fresh (in seconds)
/// - `s-maxage`: Like max-age but only for shared caches (CDNs, proxies)
/// - `public`: Response may be cached by any cache
/// - `private`: Response is for a single user and shouldn't be cached by shared caches
/// - `no-cache`: Cache must revalidate with server before using cached response
/// - `no-store`: Don't cache the response at all (for sensitive data)
/// - `must-revalidate`: Cache must revalidate stale responses
/// - `immutable`: Response will never change (safe to cache indefinitely)
///
/// Security notes:
/// - Use `private` for user-specific data
/// - Use `no-store` for sensitive data (passwords, personal info)
/// - Use `public` only for truly public resources
/// - Set appropriate `max-age` values to balance freshness and performance
///
/// Example usage:
/// ```dart
/// // Static assets (long-term caching)
/// app.use(CacheControl.static(duration: Duration(days: 365)));
///
/// // API responses (short-term caching)
/// app.use(CacheControl.api(duration: Duration(minutes: 5)));
///
/// // No caching for sensitive data
/// app.use(CacheControl.noCache());
///
/// // Custom configuration
/// app.use(CacheControl(
///   maxAge: Duration(hours: 1),
///   public: true,
///   mustRevalidate: true,
/// ));
///
/// // Immutable static assets
/// app.use(CacheControl(
///   maxAge: Duration(days: 365),
///   public: true,
///   immutable: true,
/// ));
///
/// // Private user data with short cache
/// app.use(CacheControl(
///   maxAge: Duration(minutes: 5),
///   private: true,
///   mustRevalidate: true,
/// ));
/// ```
class CacheControl implements Middleware {
  /// Maximum time in seconds that a response is considered fresh.
  /// Both browsers and CDNs will use cached response within this time.
  final Duration? maxAge;

  /// Like max-age but only applies to shared caches (CDNs, proxies).
  /// Overrides max-age for shared caches.
  final Duration? sMaxAge;

  /// Response is intended for a single user.
  /// CDNs and shared caches should not cache this response.
  final bool private;

  /// Response may be cached by any cache (browsers, CDNs, proxies).
  /// This is the default for most cacheable responses.
  final bool public;

  /// Cache must revalidate with the server before using the cached response.
  /// The cached response can still be used if server says it's still valid (304).
  final bool noCache;

  /// Don't cache the response at all. Use for sensitive data.
  /// This is the strictest caching directive.
  final bool noStore;

  /// Cache must not use stale response without revalidating with server.
  final bool mustRevalidate;

  /// Like must-revalidate but only applies to shared caches.
  final bool proxyRevalidate;

  /// Response will never change. Safe to cache indefinitely.
  /// Useful for versioned/hashed static assets.
  final bool immutable;

  /// Time in seconds that cache may serve stale response while revalidating.
  /// Improves performance by allowing stale content during revalidation.
  final Duration? staleWhileRevalidate;

  /// Time in seconds that cache may serve stale response on error.
  /// Improves reliability by serving cached content when server is down.
  final Duration? staleIfError;

  /// Creates a CacheControl middleware with custom configuration.
  ///
  /// Note: `public` and `private` are mutually exclusive.
  /// If both are true, an assertion error will be thrown in debug mode.
  const CacheControl({
    this.maxAge,
    this.sMaxAge,
    this.private = false,
    this.public = false,
    this.noCache = false,
    this.noStore = false,
    this.mustRevalidate = false,
    this.proxyRevalidate = false,
    this.immutable = false,
    this.staleWhileRevalidate,
    this.staleIfError,
  }) : assert(
         !(public && private),
         'Cache-Control cannot be both public and private',
       );

  /// Creates a CacheControl for static assets with long-term caching.
  ///
  /// Sets:
  /// - `max-age` to the specified duration
  /// - `public` to true
  /// - `immutable` to true
  ///
  /// Example:
  /// ```dart
  /// app.use(CacheControl.static(duration: Duration(days: 365)));
  /// ```
  const CacheControl.static({required Duration duration})
    : maxAge = duration,
      sMaxAge = null,
      private = false,
      public = true,
      noCache = false,
      noStore = false,
      mustRevalidate = false,
      proxyRevalidate = false,
      immutable = true,
      staleWhileRevalidate = null,
      staleIfError = null;

  /// Creates a CacheControl for API responses with short-term caching.
  ///
  /// Sets:
  /// - `max-age` to the specified duration
  /// - `private` to true
  /// - `must-revalidate` to true
  ///
  /// Example:
  /// ```dart
  /// app.use(CacheControl.api(duration: Duration(minutes: 5)));
  /// ```
  const CacheControl.api({required Duration duration})
    : maxAge = duration,
      sMaxAge = null,
      private = true,
      public = false,
      noCache = false,
      noStore = false,
      mustRevalidate = true,
      proxyRevalidate = false,
      immutable = false,
      staleWhileRevalidate = null,
      staleIfError = null;

  /// Creates a CacheControl that prevents all caching.
  ///
  /// Sets:
  /// - `no-cache` to true
  /// - `no-store` to true
  /// - `must-revalidate` to true
  ///
  /// Use for sensitive data that should never be cached.
  ///
  /// Example:
  /// ```dart
  /// app.use(CacheControl.noCache());
  /// ```
  const CacheControl.noCache()
    : maxAge = null,
      sMaxAge = null,
      private = false,
      public = false,
      noCache = true,
      noStore = true,
      mustRevalidate = true,
      proxyRevalidate = false,
      immutable = false,
      staleWhileRevalidate = null,
      staleIfError = null;

  @override
  Future<void> handle(Context ctx, NextFunction next) async {
    final cacheControlValue = _buildCacheControlHeader();

    if (cacheControlValue.isNotEmpty) {
      ctx.res.headers.set(HttpHeaders.cacheControlHeader, cacheControlValue);
    }

    await next();
  }

  /// Builds the Cache-Control header value from the configured directives.
  String _buildCacheControlHeader() {
    final directives = <String>[];

    if (maxAge != null) {
      directives.add('max-age=${maxAge!.inSeconds}');
    }
    if (sMaxAge != null) {
      directives.add('s-maxage=${sMaxAge!.inSeconds}');
    }
    if (private) {
      directives.add('private');
    }
    if (public) {
      directives.add('public');
    }
    if (noCache) {
      directives.add('no-cache');
    }
    if (noStore) {
      directives.add('no-store');
    }
    if (mustRevalidate) {
      directives.add('must-revalidate');
    }
    if (proxyRevalidate) {
      directives.add('proxy-revalidate');
    }
    if (immutable) {
      directives.add('immutable');
    }
    if (staleWhileRevalidate != null) {
      directives.add(
        'stale-while-revalidate=${staleWhileRevalidate!.inSeconds}',
      );
    }
    if (staleIfError != null) {
      directives.add('stale-if-error=${staleIfError!.inSeconds}');
    }

    return directives.join(', ');
  }
}
