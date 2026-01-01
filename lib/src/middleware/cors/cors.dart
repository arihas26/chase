import 'dart:async';
import 'dart:io';

import 'package:chase/src/core/context/context.dart';
import 'package:chase/src/core/middleware.dart';

/// Callback function for dynamic origin validation.
/// Returns true if the origin is allowed, false otherwise.
typedef OriginCallback = bool Function(String? origin);

/// Options for configuring CORS behavior.
class CorsOptions {
  /// List of allowed origins. If null or empty, defaults to '*' (all origins).
  /// Cannot be used together with [originCallback].
  final List<String>? origins;

  /// Callback for dynamic origin validation.
  /// Cannot be used together with [origins].
  final OriginCallback? originCallback;

  /// Whether to allow credentials (cookies, authorization headers, etc.).
  /// When true, the wildcard origin '*' cannot be used.
  final bool allowCredentials;

  /// List of allowed HTTP methods for preflight requests.
  /// Defaults to ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'].
  final List<String>? allowMethods;

  /// List of allowed headers for preflight requests.
  /// If null, mirrors the Access-Control-Request-Headers header from the preflight request.
  final List<String>? allowHeaders;

  /// List of headers that can be exposed to the client.
  final List<String>? exposeHeaders;

  /// Maximum age (in seconds) for caching preflight results.
  final Duration? maxAge;

  const CorsOptions({
    this.origins,
    this.originCallback,
    this.allowCredentials = false,
    this.allowMethods,
    this.allowHeaders,
    this.exposeHeaders,
    this.maxAge,
  }) : assert(
         origins == null || originCallback == null,
         'Cannot specify both origins and originCallback',
       );
}

/// CORS (Cross-Origin Resource Sharing) middleware.
///
/// Handles CORS headers for both preflight (OPTIONS) and actual requests.
/// Supports static origin lists, dynamic origin callbacks, and various security options.
class Cors implements Middleware {
  final CorsOptions options;

  /// Creates a CORS middleware with the given [options].
  ///
  /// Example:
  /// ```dart
  /// // Allow all origins
  /// app.use(Cors());
  ///
  /// // Allow specific origins
  /// app.use(Cors(CorsOptions(
  ///   origins: ['https://example.com'],
  ///   allowCredentials: true,
  /// )));
  ///
  /// // Dynamic origin validation
  /// app.use(Cors(CorsOptions(
  ///   originCallback: (origin) => origin?.endsWith('.example.com') ?? false,
  /// )));
  /// ```
  Cors([this.options = const CorsOptions()]);

  static const _defaultAllowMethods = [
    'GET',
    'POST',
    'PUT',
    'DELETE',
    'OPTIONS',
  ];

  @override
  FutureOr<void> handle(Context ctx, NextFunction next) async {
    final origin = ctx.req.header('origin');
    final resolvedOrigin = _resolveOrigin(origin);

    if (resolvedOrigin != null) {
      _setAllowOriginHeader(ctx, resolvedOrigin);
      _setCredentialsHeader(ctx);
      _setExposeHeadersHeader(ctx);
      _setVaryHeader(ctx, origin, resolvedOrigin);
    }

    if (_isPreflight(ctx, origin)) {
      _handlePreflight(ctx);
      return;
    }

    await next();
  }

  /// Checks if the request is a CORS preflight request.
  bool _isPreflight(Context ctx, String? origin) {
    return ctx.req.method == 'OPTIONS' &&
        origin != null &&
        ctx.req.header('access-control-request-method') != null;
  }

  /// Handles a CORS preflight request by setting appropriate headers and returning 204.
  void _handlePreflight(Context ctx) {
    _setAllowMethodsHeader(ctx);
    _setAllowHeadersHeader(ctx);
    _setMaxAgeHeader(ctx);

    ctx.res.statusCode = HttpStatus.noContent;
    ctx.res.close();
  }

  /// Sets the Access-Control-Allow-Origin header.
  void _setAllowOriginHeader(Context ctx, String origin) {
    ctx.res.headers.set(HttpHeaders.accessControlAllowOriginHeader, origin);
  }

  /// Sets the Access-Control-Allow-Credentials header if credentials are allowed.
  void _setCredentialsHeader(Context ctx) {
    if (options.allowCredentials) {
      ctx.res.headers.set(
        HttpHeaders.accessControlAllowCredentialsHeader,
        'true',
      );
    }
  }

  /// Sets the Access-Control-Expose-Headers header if expose headers are configured.
  void _setExposeHeadersHeader(Context ctx) {
    if (options.exposeHeaders != null && options.exposeHeaders!.isNotEmpty) {
      ctx.res.headers.set(
        HttpHeaders.accessControlExposeHeadersHeader,
        options.exposeHeaders!.join(', '),
      );
    }
  }

  /// Sets the Vary: Origin header to indicate that the response varies by origin.
  void _setVaryHeader(Context ctx, String? origin, String resolvedOrigin) {
    if (origin != null && resolvedOrigin != '*') {
      ctx.res.headers.add(HttpHeaders.varyHeader, 'Origin');
    }
  }

  /// Sets the Access-Control-Allow-Methods header for preflight requests.
  void _setAllowMethodsHeader(Context ctx) {
    final methods = options.allowMethods ?? _defaultAllowMethods;
    ctx.res.headers.set(
      HttpHeaders.accessControlAllowMethodsHeader,
      methods.join(', '),
    );
  }

  /// Sets the Access-Control-Allow-Headers header for preflight requests.
  void _setAllowHeadersHeader(Context ctx) {
    if (options.allowHeaders != null && options.allowHeaders!.isNotEmpty) {
      ctx.res.headers.set(
        HttpHeaders.accessControlAllowHeadersHeader,
        options.allowHeaders!.join(', '),
      );
    } else {
      final requestHeaders = ctx.req.header('access-control-request-headers');
      if (requestHeaders != null && requestHeaders.isNotEmpty) {
        ctx.res.headers.set(
          HttpHeaders.accessControlAllowHeadersHeader,
          requestHeaders,
        );
      }
    }
  }

  /// Sets the Access-Control-Max-Age header if configured.
  void _setMaxAgeHeader(Context ctx) {
    if (options.maxAge != null) {
      ctx.res.headers.set(
        HttpHeaders.accessControlMaxAgeHeader,
        options.maxAge!.inSeconds.toString(),
      );
    }
  }

  /// Resolves the allowed origin based on the configuration.
  ///
  /// Returns:
  /// - The origin if it's allowed
  /// - '*' if all origins are allowed (and credentials are not required)
  /// - null if the origin is not allowed
  String? _resolveOrigin(String? origin) {
    if (options.originCallback != null) {
      return options.originCallback!(origin) ? origin : null;
    }

    final origins = options.origins;
    if (origins != null && origins.isNotEmpty) {
      if (origin == null) return null;
      if (origins.contains(origin)) return origin;
      if (origins.contains('*')) return origin;

      return null;
    }

    if (options.allowCredentials) {
      return origin;
    }

    return '*';
  }
}
