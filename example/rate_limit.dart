import 'package:chase/chase.dart';

/// Example: Rate Limiting
///
/// This example demonstrates:
/// - Global rate limiting
/// - Route-specific rate limits
/// - Different window configurations (per second, minute, hour)
/// - Custom key extraction
/// - Rate limit headers
/// - Custom error messages
/// - Callback on limit exceeded
///
/// Run: dart run bin/example_rate_limit.dart
/// Test:
///   # Make requests (first few should succeed)
///   curl -i http://localhost:6060/api/data
///
///   # Keep making requests to see rate limit in action
///   for i in {1..10}; do curl -i http://localhost:6060/api/data; done
void main() async {
  final app = Chase();

  // Example 1: Global rate limit (applies to all routes)
  // 100 requests per minute for all clients
  app.use(RateLimit(const RateLimitOptions.perMinute(100)));

  // Example 2: Strict limit for login endpoint (prevent brute force)
  app.post('/login')
      .use(RateLimit(const RateLimitOptions(
        maxRequests: 5,
        windowMs: 900000, // 15 minutes
        errorMessage: 'Too many login attempts. Please try again in 15 minutes.',
      )))
      .handle((ctx) async {
    return Response.json({'message': 'Login endpoint'});
  });

  // Example 3: API endpoint with per-second limit
  app.get('/api/data')
      .use(RateLimit(const RateLimitOptions.perSecond(5)))
      .handle((ctx) async {
    return Response.json({
      'data': 'This endpoint allows 5 requests per second',
      'timestamp': DateTime.now().toIso8601String(),
    });
  });

  // Example 4: High-volume endpoint with per-hour limit
  app.get('/api/batch')
      .use(RateLimit(const RateLimitOptions.perHour(1000)))
      .handle((ctx) async {
    return Response.json({'message': 'Batch processing endpoint'});
  });

  // Example 5: Custom key extraction by API key header
  app.routes('/api/v1', (api) {
    api.use(RateLimit(RateLimitOptions(
      maxRequests: 100,
      windowMs: 60000, // 1 minute
      keyExtractor: (ctx) {
        final apiKey = ctx.req.header('X-API-Key');
        if (apiKey != null) {
          return 'apikey:$apiKey';
        }
        // Fall back to IP if no API key
        return ctx.req.remoteAddress;
      },
    )));

    api.get('/users').handle((ctx) async {
      return Response.json({'users': [], 'limit': '100/min per API key'});
    });

    api.get('/products').handle((ctx) async {
      return Response.json({'products': [], 'limit': '100/min per API key'});
    });
  });

  // Example 6: Rate limit with callback for logging/alerting
  app.post('/api/expensive')
      .use(RateLimit(RateLimitOptions(
        maxRequests: 3,
        windowMs: 60000,
        onLimitReached: (ctx, info) {
          print('Rate limit exceeded for ${info.key}');
          print('  Requests: ${info.requestCount}/${info.maxRequests}');
          print('  Reset in: ${info.resetInMs}ms');
        },
      )))
      .handle((ctx) async {
    return Response.json({'message': 'Expensive operation completed'});
  });

  // Example 7: Rate limit without headers (hide limit info)
  app.get('/api/secure')
      .use(RateLimit(const RateLimitOptions(
        maxRequests: 10,
        windowMs: 60000,
        includeHeaders: false,
        errorMessage: 'Request limit exceeded',
      )))
      .handle((ctx) async {
    return Response.json({'status': 'ok'});
  });

  // Example 8: Per-user rate limiting (requires auth middleware first)
  app.routes('/user', (user) {
    // Simulate user ID extraction (in real app, this would come from auth)
    user.use(RateLimit(RateLimitOptions(
      maxRequests: 50,
      windowMs: 60000,
      keyExtractor: (ctx) {
        // In a real app, get user ID from auth context
        final userId = ctx.req.header('X-User-ID') ?? 'anonymous';
        return 'user:$userId';
      },
    )));

    user.get('/profile').handle((ctx) async {
      return Response.json({'profile': 'User profile data'});
    });

    user.post('/update').handle((ctx) async {
      return Response.json({'message': 'Profile updated'});
    });
  });

  // Info endpoint showing all routes and their limits
  app.get('/').handle((ctx) async {
    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <title>Rate Limit Example</title>
  <style>
    body { font-family: Arial; max-width: 900px; margin: 50px auto; }
    table { width: 100%; border-collapse: collapse; margin: 20px 0; }
    th, td { padding: 12px; text-align: left; border: 1px solid #ddd; }
    th { background: #f4f4f4; }
    code { background: #f4f4f4; padding: 2px 6px; border-radius: 3px; }
    .limit { color: #e67e22; font-weight: bold; }
    .endpoint { color: #2980b9; }
    pre { background: #f4f4f4; padding: 15px; border-radius: 5px; overflow-x: auto; }
  </style>
</head>
<body>
  <h1>Rate Limit Middleware Examples</h1>
  <p>This server demonstrates various rate limiting configurations.</p>

  <h2>Configured Endpoints</h2>
  <table>
    <thead>
      <tr>
        <th>Endpoint</th>
        <th>Limit</th>
        <th>Window</th>
        <th>Key</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td class="endpoint">Global (all routes)</td>
        <td class="limit">100 req</td>
        <td>1 minute</td>
        <td>IP address</td>
      </tr>
      <tr>
        <td class="endpoint">POST /login</td>
        <td class="limit">5 req</td>
        <td>15 minutes</td>
        <td>IP address</td>
      </tr>
      <tr>
        <td class="endpoint">GET /api/data</td>
        <td class="limit">5 req</td>
        <td>1 second</td>
        <td>IP address</td>
      </tr>
      <tr>
        <td class="endpoint">GET /api/batch</td>
        <td class="limit">1000 req</td>
        <td>1 hour</td>
        <td>IP address</td>
      </tr>
      <tr>
        <td class="endpoint">GET /api/v1/*</td>
        <td class="limit">100 req</td>
        <td>1 minute</td>
        <td>API Key or IP</td>
      </tr>
      <tr>
        <td class="endpoint">POST /api/expensive</td>
        <td class="limit">3 req</td>
        <td>1 minute</td>
        <td>IP address</td>
      </tr>
      <tr>
        <td class="endpoint">GET /api/secure</td>
        <td class="limit">10 req</td>
        <td>1 minute</td>
        <td>IP (no headers)</td>
      </tr>
      <tr>
        <td class="endpoint">/user/*</td>
        <td class="limit">50 req</td>
        <td>1 minute</td>
        <td>X-User-ID header</td>
      </tr>
    </tbody>
  </table>

  <h2>Rate Limit Headers</h2>
  <p>Responses include the following headers (unless disabled):</p>
  <table>
    <thead>
      <tr>
        <th>Header</th>
        <th>Description</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td><code>X-RateLimit-Limit</code></td>
        <td>Maximum requests allowed per window</td>
      </tr>
      <tr>
        <td><code>X-RateLimit-Remaining</code></td>
        <td>Remaining requests in current window</td>
      </tr>
      <tr>
        <td><code>X-RateLimit-Reset</code></td>
        <td>Unix timestamp when the window resets</td>
      </tr>
      <tr>
        <td><code>Retry-After</code></td>
        <td>Seconds until next request allowed (429 only)</td>
      </tr>
    </tbody>
  </table>

  <h2>Test Commands</h2>

  <h3>1. Check rate limit headers</h3>
  <pre><code>curl -i http://localhost:6060/api/data</code></pre>

  <h3>2. Test rate limit (5 requests/second)</h3>
  <pre><code>for i in {1..10}; do
  echo "Request \$i:"
  curl -s -w "Status: %{http_code}\\n" http://localhost:6060/api/data
  echo ""
done</code></pre>

  <h3>3. Test with API key</h3>
  <pre><code>curl -i -H "X-API-Key: my-key-123" http://localhost:6060/api/v1/users</code></pre>

  <h3>4. Test login rate limit</h3>
  <pre><code>for i in {1..7}; do
  echo "Attempt \$i:"
  curl -s -X POST -w "Status: %{http_code}\\n" http://localhost:6060/login
  echo ""
done</code></pre>

  <h3>5. Test expensive endpoint (with logging)</h3>
  <pre><code>for i in {1..5}; do
  curl -s -X POST http://localhost:6060/api/expensive
  echo ""
done</code></pre>

  <h2>Expected Responses</h2>
  <ul>
    <li>Within limit: <strong>200 OK</strong> with JSON response and rate limit headers</li>
    <li>Exceeds limit: <strong>429 Too Many Requests</strong> with error message and Retry-After header</li>
  </ul>

  <h2>Best Practices</h2>
  <ul>
    <li>Use stricter limits for sensitive endpoints (login, password reset)</li>
    <li>Use API keys for authenticated access to track per-user limits</li>
    <li>Consider using a distributed store (Redis) for multi-instance deployments</li>
    <li>Monitor rate limit events for potential abuse detection</li>
    <li>Set appropriate limits based on your API's expected usage patterns</li>
  </ul>
</body>
</html>
''';

    return Response.html(htmlContent);
  });

  final port = 3000;
  print('Rate Limit example server running on http://localhost:$port');
  print('');
  print('Open http://localhost:$port in your browser for documentation');
  print('');
  print('Example tests:');
  print('  # Check rate limit headers');
  print('  curl -i http://localhost:$port/api/data');
  print('');
  print('  # Test rate limit (5 req/sec)');
  print('  for i in {1..10}; do curl -s http://localhost:$port/api/data; echo ""; done');

  await app.start(port: port);
}
