import 'dart:async';

import 'package:chase/src/core/context/context.dart';
import 'package:chase/src/core/middleware.dart';

/// Options for X-Frame-Options header.
enum XFrameOptions {
  /// Prevents any domain from framing the content.
  deny('DENY'),

  /// Allows only the same origin to frame the content.
  sameOrigin('SAMEORIGIN');

  final String value;
  const XFrameOptions(this.value);
}

/// Options for Referrer-Policy header.
enum ReferrerPolicy {
  /// No referrer information is sent.
  noReferrer('no-referrer'),

  /// No referrer for cross-origin requests.
  noReferrerWhenDowngrade('no-referrer-when-downgrade'),

  /// Only send origin (not full URL).
  origin('origin'),

  /// Send origin for cross-origin, full URL for same-origin.
  originWhenCrossOrigin('origin-when-cross-origin'),

  /// Only send referrer for same-origin requests.
  sameOrigin('same-origin'),

  /// Send origin for same security level, nothing for downgrade.
  strictOrigin('strict-origin'),

  /// Default behavior with strict security.
  strictOriginWhenCrossOrigin('strict-origin-when-cross-origin'),

  /// Send full URL (not recommended).
  unsafeUrl('unsafe-url');

  final String value;
  const ReferrerPolicy(this.value);
}

/// Options for Cross-Origin-Embedder-Policy header.
enum CrossOriginEmbedderPolicy {
  /// No restrictions.
  unsafeNone('unsafe-none'),

  /// Requires CORP or CORS for cross-origin resources.
  requireCorp('require-corp'),

  /// Credentialless mode for cross-origin resources.
  credentialless('credentialless');

  final String value;
  const CrossOriginEmbedderPolicy(this.value);
}

/// Options for Cross-Origin-Opener-Policy header.
enum CrossOriginOpenerPolicy {
  /// No restrictions.
  unsafeNone('unsafe-none'),

  /// Same origin only.
  sameOrigin('same-origin'),

  /// Same origin, allow popups.
  sameOriginAllowPopups('same-origin-allow-popups');

  final String value;
  const CrossOriginOpenerPolicy(this.value);
}

/// Options for Cross-Origin-Resource-Policy header.
enum CrossOriginResourcePolicy {
  /// Allow cross-origin requests.
  crossOrigin('cross-origin'),

  /// Same origin only.
  sameOrigin('same-origin'),

  /// Same site only.
  sameSite('same-site');

  final String value;
  const CrossOriginResourcePolicy(this.value);
}

/// Configuration for Content-Security-Policy header.
class ContentSecurityPolicy {
  final Map<String, List<String>> _directives = {};

  /// Creates an empty CSP configuration.
  ContentSecurityPolicy();

  /// Creates a basic CSP that only allows same-origin resources.
  factory ContentSecurityPolicy.strict() {
    return ContentSecurityPolicy()
      ..defaultSrc(["'self'"])
      ..scriptSrc(["'self'"])
      ..styleSrc(["'self'"])
      ..imgSrc(["'self'"])
      ..fontSrc(["'self'"])
      ..connectSrc(["'self'"])
      ..frameSrc(["'none'"])
      ..objectSrc(["'none'"])
      ..baseUri(["'self'"]);
  }

  /// Creates a permissive CSP (for development).
  factory ContentSecurityPolicy.permissive() {
    return ContentSecurityPolicy()..defaultSrc(["'self'", "'unsafe-inline'", "'unsafe-eval'", 'https:', 'data:']);
  }

  /// Sets the default-src directive.
  ContentSecurityPolicy defaultSrc(List<String> sources) {
    _directives['default-src'] = sources;
    return this;
  }

  /// Sets the script-src directive.
  ContentSecurityPolicy scriptSrc(List<String> sources) {
    _directives['script-src'] = sources;
    return this;
  }

  /// Sets the style-src directive.
  ContentSecurityPolicy styleSrc(List<String> sources) {
    _directives['style-src'] = sources;
    return this;
  }

  /// Sets the img-src directive.
  ContentSecurityPolicy imgSrc(List<String> sources) {
    _directives['img-src'] = sources;
    return this;
  }

  /// Sets the font-src directive.
  ContentSecurityPolicy fontSrc(List<String> sources) {
    _directives['font-src'] = sources;
    return this;
  }

  /// Sets the connect-src directive.
  ContentSecurityPolicy connectSrc(List<String> sources) {
    _directives['connect-src'] = sources;
    return this;
  }

  /// Sets the frame-src directive.
  ContentSecurityPolicy frameSrc(List<String> sources) {
    _directives['frame-src'] = sources;
    return this;
  }

  /// Sets the object-src directive.
  ContentSecurityPolicy objectSrc(List<String> sources) {
    _directives['object-src'] = sources;
    return this;
  }

  /// Sets the media-src directive.
  ContentSecurityPolicy mediaSrc(List<String> sources) {
    _directives['media-src'] = sources;
    return this;
  }

  /// Sets the base-uri directive.
  ContentSecurityPolicy baseUri(List<String> sources) {
    _directives['base-uri'] = sources;
    return this;
  }

  /// Sets the form-action directive.
  ContentSecurityPolicy formAction(List<String> sources) {
    _directives['form-action'] = sources;
    return this;
  }

  /// Sets the frame-ancestors directive.
  ContentSecurityPolicy frameAncestors(List<String> sources) {
    _directives['frame-ancestors'] = sources;
    return this;
  }

  /// Sets the report-uri directive.
  ContentSecurityPolicy reportUri(String uri) {
    _directives['report-uri'] = [uri];
    return this;
  }

  /// Sets a custom directive.
  ContentSecurityPolicy directive(String name, List<String> values) {
    _directives[name] = values;
    return this;
  }

  /// Builds the CSP header value.
  String build() {
    return _directives.entries.map((e) => '${e.key} ${e.value.join(' ')}').join('; ');
  }

  /// Whether the CSP has any directives.
  bool get isEmpty => _directives.isEmpty;
}

/// Configuration for Strict-Transport-Security (HSTS) header.
class StrictTransportSecurity {
  /// Max age in seconds.
  final int maxAge;

  /// Include subdomains.
  final bool includeSubDomains;

  /// Allow preloading.
  final bool preload;

  const StrictTransportSecurity({
    this.maxAge = 31536000, // 1 year
    this.includeSubDomains = true,
    this.preload = false,
  });

  /// Standard HSTS with 1 year max-age.
  static const standard = StrictTransportSecurity();

  /// HSTS suitable for preload submission.
  static const forPreload = StrictTransportSecurity(
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true,
  );

  /// Builds the HSTS header value.
  String build() {
    final parts = ['max-age=$maxAge'];
    if (includeSubDomains) parts.add('includeSubDomains');
    if (preload) parts.add('preload');
    return parts.join('; ');
  }
}

/// Options for configuring security headers.
class SecureHeadersOptions {
  /// X-Content-Type-Options header value.
  ///
  /// Set to 'nosniff' to prevent MIME type sniffing.
  /// Set to null to disable.
  ///
  /// Default: 'nosniff'
  final String? contentTypeOptions;

  /// X-Frame-Options header value.
  ///
  /// Controls whether the page can be embedded in frames.
  /// Set to null to disable (use CSP frame-ancestors instead).
  ///
  /// Default: XFrameOptions.sameOrigin
  final XFrameOptions? frameOptions;

  /// Strict-Transport-Security (HSTS) configuration.
  ///
  /// Forces HTTPS connections. Only enable in production with HTTPS.
  /// Set to null to disable.
  ///
  /// Default: null (disabled)
  final StrictTransportSecurity? hsts;

  /// Content-Security-Policy configuration.
  ///
  /// Controls which resources the browser is allowed to load.
  /// Set to null to disable.
  ///
  /// Default: null (disabled)
  final ContentSecurityPolicy? contentSecurityPolicy;

  /// Whether to use Content-Security-Policy-Report-Only instead.
  ///
  /// When true, violations are reported but not enforced.
  ///
  /// Default: false
  final bool cspReportOnly;

  /// Referrer-Policy header value.
  ///
  /// Controls how much referrer information is sent.
  ///
  /// Default: ReferrerPolicy.strictOriginWhenCrossOrigin
  final ReferrerPolicy? referrerPolicy;

  /// Permissions-Policy header value.
  ///
  /// Controls which browser features are allowed.
  /// Set to null to disable.
  ///
  /// Default: null (disabled)
  final String? permissionsPolicy;

  /// Cross-Origin-Embedder-Policy header value.
  ///
  /// Set to null to disable.
  ///
  /// Default: null (disabled)
  final CrossOriginEmbedderPolicy? crossOriginEmbedderPolicy;

  /// Cross-Origin-Opener-Policy header value.
  ///
  /// Set to null to disable.
  ///
  /// Default: null (disabled)
  final CrossOriginOpenerPolicy? crossOriginOpenerPolicy;

  /// Cross-Origin-Resource-Policy header value.
  ///
  /// Set to null to disable.
  ///
  /// Default: null (disabled)
  final CrossOriginResourcePolicy? crossOriginResourcePolicy;

  /// X-Download-Options header value (IE-specific).
  ///
  /// Set to 'noopen' to prevent IE from executing downloads.
  /// Set to null to disable.
  ///
  /// Default: 'noopen'
  final String? downloadOptions;

  /// X-Permitted-Cross-Domain-Policies header value.
  ///
  /// Controls Adobe Flash and PDF cross-domain requests.
  /// Set to null to disable.
  ///
  /// Default: 'none'
  final String? permittedCrossDomainPolicies;

  /// Creates secure headers options with the specified configuration.
  const SecureHeadersOptions({
    this.contentTypeOptions = 'nosniff',
    this.frameOptions = XFrameOptions.sameOrigin,
    this.hsts,
    this.contentSecurityPolicy,
    this.cspReportOnly = false,
    this.referrerPolicy = ReferrerPolicy.strictOriginWhenCrossOrigin,
    this.permissionsPolicy,
    this.crossOriginEmbedderPolicy,
    this.crossOriginOpenerPolicy,
    this.crossOriginResourcePolicy,
    this.downloadOptions = 'noopen',
    this.permittedCrossDomainPolicies = 'none',
  });

  /// Creates a minimal configuration with essential security headers.
  const SecureHeadersOptions.minimal()
      : contentTypeOptions = 'nosniff',
        frameOptions = XFrameOptions.sameOrigin,
        hsts = null,
        contentSecurityPolicy = null,
        cspReportOnly = false,
        referrerPolicy = ReferrerPolicy.noReferrer,
        permissionsPolicy = null,
        crossOriginEmbedderPolicy = null,
        crossOriginOpenerPolicy = null,
        crossOriginResourcePolicy = null,
        downloadOptions = null,
        permittedCrossDomainPolicies = null;

  /// Creates a strict configuration with all security headers enabled.
  factory SecureHeadersOptions.strict() {
    return SecureHeadersOptions(
      contentTypeOptions: 'nosniff',
      frameOptions: XFrameOptions.deny,
      hsts: StrictTransportSecurity.standard,
      contentSecurityPolicy: ContentSecurityPolicy.strict(),
      referrerPolicy: ReferrerPolicy.noReferrer,
      crossOriginEmbedderPolicy: CrossOriginEmbedderPolicy.requireCorp,
      crossOriginOpenerPolicy: CrossOriginOpenerPolicy.sameOrigin,
      crossOriginResourcePolicy: CrossOriginResourcePolicy.sameOrigin,
      downloadOptions: 'noopen',
      permittedCrossDomainPolicies: 'none',
    );
  }
}

/// Middleware that adds security-related HTTP headers to responses.
///
/// This middleware helps protect your application against common web
/// vulnerabilities by setting appropriate security headers.
///
/// Headers that can be configured:
/// - **X-Content-Type-Options**: Prevents MIME type sniffing
/// - **X-Frame-Options**: Prevents clickjacking attacks
/// - **Strict-Transport-Security**: Forces HTTPS connections
/// - **Content-Security-Policy**: Controls resource loading
/// - **Referrer-Policy**: Controls referrer information
/// - **Permissions-Policy**: Controls browser features
/// - **Cross-Origin-*-Policy**: Controls cross-origin behavior
/// - **X-Download-Options**: Prevents IE from executing downloads
/// - **X-Permitted-Cross-Domain-Policies**: Controls Adobe cross-domain
///
/// Example usage:
/// ```dart
/// // Basic usage with sensible defaults
/// app.use(SecureHeaders());
///
/// // Minimal headers only
/// app.use(SecureHeaders(const SecureHeadersOptions.minimal()));
///
/// // Strict security (for production)
/// app.use(SecureHeaders(SecureHeadersOptions.strict()));
///
/// // Custom configuration
/// app.use(SecureHeaders(SecureHeadersOptions(
///   frameOptions: XFrameOptions.deny,
///   hsts: StrictTransportSecurity(maxAge: 86400),
///   contentSecurityPolicy: ContentSecurityPolicy()
///     ..defaultSrc(["'self'"])
///     ..scriptSrc(["'self'", 'https://cdn.example.com']),
/// )));
///
/// // With CSP report-only mode for testing
/// app.use(SecureHeaders(SecureHeadersOptions(
///   contentSecurityPolicy: ContentSecurityPolicy.strict(),
///   cspReportOnly: true,
/// )));
/// ```
///
/// Note: Some headers (like HSTS) should only be enabled in production
/// with proper HTTPS configuration.
class SecureHeaders implements Middleware {
  final SecureHeadersOptions options;

  /// Creates a SecureHeaders middleware with the given [options].
  ///
  /// If no options are provided, uses sensible defaults:
  /// - X-Content-Type-Options: nosniff
  /// - X-Frame-Options: SAMEORIGIN
  /// - Referrer-Policy: strict-origin-when-cross-origin
  /// - X-Download-Options: noopen
  /// - X-Permitted-Cross-Domain-Policies: none
  const SecureHeaders([this.options = const SecureHeadersOptions()]);

  @override
  FutureOr<void> handle(Context ctx, NextFunction next) async {
    // X-Content-Type-Options
    if (options.contentTypeOptions != null) {
      ctx.res.headers.set('X-Content-Type-Options', options.contentTypeOptions!);
    }

    // X-Frame-Options
    if (options.frameOptions != null) {
      ctx.res.headers.set('X-Frame-Options', options.frameOptions!.value);
    }

    // Strict-Transport-Security
    if (options.hsts != null) {
      ctx.res.headers.set('Strict-Transport-Security', options.hsts!.build());
    }

    // Content-Security-Policy
    if (options.contentSecurityPolicy != null && !options.contentSecurityPolicy!.isEmpty) {
      final headerName = options.cspReportOnly ? 'Content-Security-Policy-Report-Only' : 'Content-Security-Policy';
      ctx.res.headers.set(headerName, options.contentSecurityPolicy!.build());
    }

    // Referrer-Policy
    if (options.referrerPolicy != null) {
      ctx.res.headers.set('Referrer-Policy', options.referrerPolicy!.value);
    }

    // Permissions-Policy
    if (options.permissionsPolicy != null) {
      ctx.res.headers.set('Permissions-Policy', options.permissionsPolicy!);
    }

    // Cross-Origin-Embedder-Policy
    if (options.crossOriginEmbedderPolicy != null) {
      ctx.res.headers.set('Cross-Origin-Embedder-Policy', options.crossOriginEmbedderPolicy!.value);
    }

    // Cross-Origin-Opener-Policy
    if (options.crossOriginOpenerPolicy != null) {
      ctx.res.headers.set('Cross-Origin-Opener-Policy', options.crossOriginOpenerPolicy!.value);
    }

    // Cross-Origin-Resource-Policy
    if (options.crossOriginResourcePolicy != null) {
      ctx.res.headers.set('Cross-Origin-Resource-Policy', options.crossOriginResourcePolicy!.value);
    }

    // X-Download-Options
    if (options.downloadOptions != null) {
      ctx.res.headers.set('X-Download-Options', options.downloadOptions!);
    }

    // X-Permitted-Cross-Domain-Policies
    if (options.permittedCrossDomainPolicies != null) {
      ctx.res.headers.set('X-Permitted-Cross-Domain-Policies', options.permittedCrossDomainPolicies!);
    }

    await next();
  }
}
