import 'package:chase/src/middleware/secure_headers/secure_headers.dart';
import 'package:chase/testing/testing.dart';
import 'package:test/test.dart';

void main() {
  group('ContentSecurityPolicy', () {
    test('builds empty CSP', () {
      final csp = ContentSecurityPolicy();
      expect(csp.isEmpty, isTrue);
      expect(csp.build(), isEmpty);
    });

    test('builds single directive', () {
      final csp = ContentSecurityPolicy()..defaultSrc(["'self'"]);
      expect(csp.build(), "default-src 'self'");
    });

    test('builds multiple directives', () {
      final csp = ContentSecurityPolicy()
        ..defaultSrc(["'self'"])
        ..scriptSrc(["'self'", 'https://cdn.example.com']);

      final result = csp.build();
      expect(result, contains("default-src 'self'"));
      expect(result, contains("script-src 'self' https://cdn.example.com"));
    });

    test('strict() creates restrictive CSP', () {
      final result = ContentSecurityPolicy.strict().build();
      expect(result, contains("default-src 'self'"));
      expect(result, contains("script-src 'self'"));
      expect(result, contains("object-src 'none'"));
    });

    test('permissive() creates development CSP', () {
      final result = ContentSecurityPolicy.permissive().build();
      expect(result, contains("'unsafe-inline'"));
      expect(result, contains("'unsafe-eval'"));
    });

    test('supports all common directives', () {
      final csp = ContentSecurityPolicy()
        ..defaultSrc(["'self'"])
        ..scriptSrc(["'self'"])
        ..styleSrc(["'self'"])
        ..imgSrc(["'self'", 'data:'])
        ..fontSrc(["'self'"])
        ..connectSrc(["'self'"])
        ..frameSrc(["'none'"])
        ..objectSrc(["'none'"])
        ..mediaSrc(["'self'"])
        ..baseUri(["'self'"])
        ..formAction(["'self'"])
        ..frameAncestors(["'none'"])
        ..reportUri('/csp-report');

      final result = csp.build();
      expect(result, contains('default-src'));
      expect(result, contains('script-src'));
      expect(result, contains('report-uri'));
    });

    test('custom directive', () {
      final csp = ContentSecurityPolicy()..directive('worker-src', ["'self'"]);
      expect(csp.build(), contains("worker-src 'self'"));
    });
  });

  group('StrictTransportSecurity', () {
    test('standard configuration', () {
      expect(
        StrictTransportSecurity.standard.build(),
        'max-age=31536000; includeSubDomains',
      );
    });

    test('preload configuration', () {
      expect(
        StrictTransportSecurity.forPreload.build(),
        'max-age=31536000; includeSubDomains; preload',
      );
    });

    test('custom max-age', () {
      expect(
        const StrictTransportSecurity(maxAge: 86400).build(),
        contains('max-age=86400'),
      );
    });

    test('without includeSubDomains', () {
      expect(
        const StrictTransportSecurity(includeSubDomains: false).build(),
        isNot(contains('includeSubDomains')),
      );
    });
  });

  group('SecureHeadersOptions', () {
    test('default options', () {
      const options = SecureHeadersOptions();
      expect(options.contentTypeOptions, 'nosniff');
      expect(options.frameOptions, XFrameOptions.sameOrigin);
      expect(options.hsts, isNull);
      expect(options.contentSecurityPolicy, isNull);
      expect(
        options.referrerPolicy,
        ReferrerPolicy.strictOriginWhenCrossOrigin,
      );
      expect(options.downloadOptions, 'noopen');
      expect(options.permittedCrossDomainPolicies, 'none');
    });

    test('minimal options', () {
      const options = SecureHeadersOptions.minimal();
      expect(options.contentTypeOptions, 'nosniff');
      expect(options.frameOptions, XFrameOptions.sameOrigin);
      expect(options.referrerPolicy, ReferrerPolicy.noReferrer);
      expect(options.downloadOptions, isNull);
    });

    test('strict options', () {
      final options = SecureHeadersOptions.strict();
      expect(options.frameOptions, XFrameOptions.deny);
      expect(options.hsts, isNotNull);
      expect(options.contentSecurityPolicy, isNotNull);
      expect(
        options.crossOriginEmbedderPolicy,
        CrossOriginEmbedderPolicy.requireCorp,
      );
    });
  });

  group('SecureHeaders middleware', () {
    test('sets default headers', () async {
      final ctx = TestContext.get('/');
      await const SecureHeaders().handle(ctx, () async {});

      expect(ctx.response.headers.value('x-content-type-options'), 'nosniff');
      expect(ctx.response.headers.value('x-frame-options'), 'SAMEORIGIN');
      expect(
        ctx.response.headers.value('referrer-policy'),
        'strict-origin-when-cross-origin',
      );
      expect(ctx.response.headers.value('x-download-options'), 'noopen');
      expect(
        ctx.response.headers.value('x-permitted-cross-domain-policies'),
        'none',
      );
    });

    test('does not set HSTS by default', () async {
      final ctx = TestContext.get('/');
      await const SecureHeaders().handle(ctx, () async {});
      expect(ctx.response.headers.value('strict-transport-security'), isNull);
    });

    test('does not set CSP by default', () async {
      final ctx = TestContext.get('/');
      await const SecureHeaders().handle(ctx, () async {});
      expect(ctx.response.headers.value('content-security-policy'), isNull);
    });

    test('sets X-Frame-Options to DENY', () async {
      final ctx = TestContext.get('/');
      await const SecureHeaders(
        SecureHeadersOptions(frameOptions: XFrameOptions.deny),
      ).handle(ctx, () async {});
      expect(ctx.response.headers.value('x-frame-options'), 'DENY');
    });

    test('sets HSTS header', () async {
      final ctx = TestContext.get('/');
      await const SecureHeaders(
        SecureHeadersOptions(hsts: StrictTransportSecurity.standard),
      ).handle(ctx, () async {});
      expect(
        ctx.response.headers.value('strict-transport-security'),
        contains('max-age=31536000'),
      );
    });

    test('sets Content-Security-Policy header', () async {
      final ctx = TestContext.get('/');
      await SecureHeaders(
        SecureHeadersOptions(
          contentSecurityPolicy: ContentSecurityPolicy()
            ..defaultSrc(["'self'"]),
        ),
      ).handle(ctx, () async {});
      expect(
        ctx.response.headers.value('content-security-policy'),
        "default-src 'self'",
      );
    });

    test('sets CSP in report-only mode', () async {
      final ctx = TestContext.get('/');
      await SecureHeaders(
        SecureHeadersOptions(
          contentSecurityPolicy: ContentSecurityPolicy()
            ..defaultSrc(["'self'"]),
          cspReportOnly: true,
        ),
      ).handle(ctx, () async {});

      expect(
        ctx.response.headers.value('content-security-policy-report-only'),
        "default-src 'self'",
      );
      expect(ctx.response.headers.value('content-security-policy'), isNull);
    });

    test('sets cross-origin headers', () async {
      final ctx = TestContext.get('/');
      await const SecureHeaders(
        SecureHeadersOptions(
          crossOriginEmbedderPolicy: CrossOriginEmbedderPolicy.requireCorp,
          crossOriginOpenerPolicy: CrossOriginOpenerPolicy.sameOrigin,
          crossOriginResourcePolicy: CrossOriginResourcePolicy.sameOrigin,
        ),
      ).handle(ctx, () async {});

      expect(
        ctx.response.headers.value('cross-origin-embedder-policy'),
        'require-corp',
      );
      expect(
        ctx.response.headers.value('cross-origin-opener-policy'),
        'same-origin',
      );
      expect(
        ctx.response.headers.value('cross-origin-resource-policy'),
        'same-origin',
      );
    });

    test('sets Permissions-Policy header', () async {
      final ctx = TestContext.get('/');
      await const SecureHeaders(
        SecureHeadersOptions(permissionsPolicy: 'camera=(), microphone=()'),
      ).handle(ctx, () async {});
      expect(
        ctx.response.headers.value('permissions-policy'),
        'camera=(), microphone=()',
      );
    });

    test('disables headers when set to null', () async {
      final ctx = TestContext.get('/');
      await const SecureHeaders(
        SecureHeadersOptions(
          contentTypeOptions: null,
          frameOptions: null,
          referrerPolicy: null,
          downloadOptions: null,
          permittedCrossDomainPolicies: null,
        ),
      ).handle(ctx, () async {});

      expect(ctx.response.headers.value('x-content-type-options'), isNull);
      expect(ctx.response.headers.value('x-frame-options'), isNull);
      expect(ctx.response.headers.value('referrer-policy'), isNull);
    });

    test('minimal configuration', () async {
      final ctx = TestContext.get('/');
      await const SecureHeaders(
        SecureHeadersOptions.minimal(),
      ).handle(ctx, () async {});

      expect(ctx.response.headers.value('x-content-type-options'), 'nosniff');
      expect(ctx.response.headers.value('x-frame-options'), 'SAMEORIGIN');
      expect(ctx.response.headers.value('referrer-policy'), 'no-referrer');
      expect(ctx.response.headers.value('x-download-options'), isNull);
    });

    test('strict configuration', () async {
      final ctx = TestContext.get('/');
      await SecureHeaders(
        SecureHeadersOptions.strict(),
      ).handle(ctx, () async {});

      expect(ctx.response.headers.value('x-content-type-options'), 'nosniff');
      expect(ctx.response.headers.value('x-frame-options'), 'DENY');
      expect(
        ctx.response.headers.value('strict-transport-security'),
        isNotNull,
      );
      expect(ctx.response.headers.value('content-security-policy'), isNotNull);
      expect(
        ctx.response.headers.value('cross-origin-embedder-policy'),
        'require-corp',
      );
    });

    test('all referrer policies', () async {
      for (final policy in ReferrerPolicy.values) {
        final ctx = TestContext.get('/');
        await SecureHeaders(
          SecureHeadersOptions(referrerPolicy: policy),
        ).handle(ctx, () async {});
        expect(ctx.response.headers.value('referrer-policy'), policy.value);
      }
    });
  });
}
