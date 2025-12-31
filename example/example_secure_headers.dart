import 'package:chase/chase.dart';

/// Example: Security Headers Middleware
///
/// This example demonstrates:
/// - Default security headers
/// - Strict security configuration
/// - Custom Content-Security-Policy
/// - HSTS configuration
/// - Cross-origin policies
///
/// Run: dart run bin/example_secure_headers.dart
/// Test:
///   curl -i http://localhost:6060/
void main() async {
  final app = Chase();

  // Example 1: Default security headers
  // Includes: X-Content-Type-Options, X-Frame-Options, Referrer-Policy, etc.
  app.use(const SecureHeaders());

  // Simple endpoint to check headers
  app.get('/').handle((ctx) async {
    await ctx.res.json({
      'message': 'Check response headers for security settings',
      'headers': {
        'X-Content-Type-Options': 'nosniff',
        'X-Frame-Options': 'SAMEORIGIN',
        'Referrer-Policy': 'strict-origin-when-cross-origin',
        'X-Download-Options': 'noopen',
        'X-Permitted-Cross-Domain-Policies': 'none',
      },
    });
  });

  // Example 2: Minimal security (for development)
  app.routes('/dev', (dev) {
    dev.use(const SecureHeaders(SecureHeadersOptions.minimal()));

    dev.get('/info').handle((ctx) async {
      await ctx.res.json({
        'mode': 'development',
        'note': 'Minimal security headers applied',
      });
    });
  });

  // Example 3: Strict security (for production)
  app.routes('/secure', (secure) {
    secure.use(SecureHeaders(SecureHeadersOptions.strict()));

    secure.get('/data').handle((ctx) async {
      await ctx.res.json({
        'mode': 'production',
        'note': 'Strict security headers applied',
        'headers': [
          'X-Frame-Options: DENY',
          'Strict-Transport-Security enabled',
          'Content-Security-Policy enabled',
          'Cross-Origin policies enabled',
        ],
      });
    });
  });

  // Example 4: Custom CSP configuration
  app.routes('/api', (api) {
    api.use(SecureHeaders(SecureHeadersOptions(
      contentSecurityPolicy: ContentSecurityPolicy()
        ..defaultSrc(["'self'"])
        ..scriptSrc(["'self'", 'https://cdn.example.com'])
        ..styleSrc(["'self'", "'unsafe-inline'"])
        ..imgSrc(["'self'", 'data:', 'https:'])
        ..connectSrc(["'self'", 'https://api.example.com'])
        ..fontSrc(["'self'", 'https://fonts.googleapis.com'])
        ..frameSrc(["'none'"])
        ..objectSrc(["'none'"]),
    )));

    api.get('/users').handle((ctx) async {
      await ctx.res.json({'users': [], 'csp': 'Custom CSP applied'});
    });
  });

  // Example 5: CSP Report-Only mode (for testing)
  app.routes('/test-csp', (test) {
    test.use(SecureHeaders(SecureHeadersOptions(
      contentSecurityPolicy: ContentSecurityPolicy.strict(),
      cspReportOnly: true, // Won't block, just report
    )));

    test.get('/page').handle((ctx) async {
      await ctx.res.html('''
<!DOCTYPE html>
<html>
<head>
  <title>CSP Test</title>
  <script>console.log("inline script - would be blocked in enforcing mode")</script>
</head>
<body>
  <h1>CSP Report-Only Mode</h1>
  <p>Check browser console for CSP violation reports.</p>
</body>
</html>
''');
    });
  });

  // Example 6: HSTS configuration
  app.routes('/hsts', (hsts) {
    hsts.use(const SecureHeaders(SecureHeadersOptions(
      hsts: StrictTransportSecurity(
        maxAge: 31536000, // 1 year
        includeSubDomains: true,
        preload: false,
      ),
    )));

    hsts.get('/info').handle((ctx) async {
      await ctx.res.json({
        'hsts': 'enabled',
        'maxAge': '1 year',
        'includeSubDomains': true,
        'note': 'Only enable HSTS with proper HTTPS setup',
      });
    });
  });

  // Example 7: Cross-origin isolation
  app.routes('/isolated', (isolated) {
    isolated.use(const SecureHeaders(SecureHeadersOptions(
      crossOriginEmbedderPolicy: CrossOriginEmbedderPolicy.requireCorp,
      crossOriginOpenerPolicy: CrossOriginOpenerPolicy.sameOrigin,
      crossOriginResourcePolicy: CrossOriginResourcePolicy.sameOrigin,
    )));

    isolated.get('/status').handle((ctx) async {
      await ctx.res.json({
        'crossOriginIsolated': true,
        'note': 'Required for SharedArrayBuffer and high-resolution timers',
      });
    });
  });

  // Example 8: Custom Permissions-Policy
  app.routes('/restricted', (restricted) {
    restricted.use(const SecureHeaders(SecureHeadersOptions(
      permissionsPolicy: 'camera=(), microphone=(), geolocation=(self), payment=()',
    )));

    restricted.get('/features').handle((ctx) async {
      await ctx.res.json({
        'permissions': {
          'camera': 'disabled',
          'microphone': 'disabled',
          'geolocation': 'self only',
          'payment': 'disabled',
        },
      });
    });
  });

  // Info endpoint
  app.get('/info').handle((ctx) async {
    final html = '''
<!DOCTYPE html>
<html>
<head>
  <title>Secure Headers Example</title>
  <style>
    body { font-family: Arial; max-width: 900px; margin: 50px auto; }
    table { width: 100%; border-collapse: collapse; margin: 20px 0; }
    th, td { padding: 12px; text-align: left; border: 1px solid #ddd; }
    th { background: #f4f4f4; }
    code { background: #f4f4f4; padding: 2px 6px; border-radius: 3px; }
    pre { background: #f4f4f4; padding: 15px; border-radius: 5px; overflow-x: auto; }
    .header { color: #27ae60; font-weight: bold; }
    .warning { color: #e67e22; }
  </style>
</head>
<body>
  <h1>Security Headers Middleware</h1>
  <p>This middleware adds security-related HTTP headers to protect against common vulnerabilities.</p>

  <h2>Endpoints</h2>
  <table>
    <thead>
      <tr>
        <th>Endpoint</th>
        <th>Configuration</th>
        <th>Description</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td>GET /</td>
        <td>Default</td>
        <td>Standard security headers</td>
      </tr>
      <tr>
        <td>GET /dev/info</td>
        <td>Minimal</td>
        <td>Development configuration</td>
      </tr>
      <tr>
        <td>GET /secure/data</td>
        <td>Strict</td>
        <td>Production configuration</td>
      </tr>
      <tr>
        <td>GET /api/users</td>
        <td>Custom CSP</td>
        <td>Content-Security-Policy</td>
      </tr>
      <tr>
        <td>GET /test-csp/page</td>
        <td>CSP Report-Only</td>
        <td>Testing CSP without blocking</td>
      </tr>
      <tr>
        <td>GET /hsts/info</td>
        <td>HSTS</td>
        <td>Strict-Transport-Security</td>
      </tr>
      <tr>
        <td>GET /isolated/status</td>
        <td>Cross-Origin</td>
        <td>Cross-origin isolation</td>
      </tr>
      <tr>
        <td>GET /restricted/features</td>
        <td>Permissions</td>
        <td>Permissions-Policy</td>
      </tr>
    </tbody>
  </table>

  <h2>Security Headers Overview</h2>
  <table>
    <thead>
      <tr>
        <th>Header</th>
        <th>Purpose</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td class="header">X-Content-Type-Options</td>
        <td>Prevents MIME type sniffing</td>
      </tr>
      <tr>
        <td class="header">X-Frame-Options</td>
        <td>Prevents clickjacking attacks</td>
      </tr>
      <tr>
        <td class="header">Strict-Transport-Security</td>
        <td>Forces HTTPS connections</td>
      </tr>
      <tr>
        <td class="header">Content-Security-Policy</td>
        <td>Controls resource loading (XSS protection)</td>
      </tr>
      <tr>
        <td class="header">Referrer-Policy</td>
        <td>Controls referrer information leakage</td>
      </tr>
      <tr>
        <td class="header">Permissions-Policy</td>
        <td>Controls browser feature access</td>
      </tr>
      <tr>
        <td class="header">Cross-Origin-*-Policy</td>
        <td>Controls cross-origin behavior</td>
      </tr>
    </tbody>
  </table>

  <h2>Test Commands</h2>
  <pre><code># Check default headers
curl -i http://localhost:6060/

# Check strict headers
curl -i http://localhost:6060/secure/data

# Check CSP header
curl -i http://localhost:6060/api/users

# Check HSTS header
curl -i http://localhost:6060/hsts/info</code></pre>

  <h2 class="warning">Important Notes</h2>
  <ul>
    <li><strong>HSTS:</strong> Only enable with proper HTTPS configuration</li>
    <li><strong>CSP:</strong> Test in report-only mode before enforcing</li>
    <li><strong>Cross-Origin Isolation:</strong> May break third-party resources</li>
  </ul>
</body>
</html>
''';
    await ctx.res.html(html);
  });

  final port = 3000;
  print('Secure Headers example server running on http://localhost:$port');
  print('');
  print('Open http://localhost:$port/info in your browser for documentation');
  print('');
  print('Example tests:');
  print('  curl -i http://localhost:$port/');
  print('  curl -i http://localhost:$port/secure/data');

  await app.start(port: port);
}
