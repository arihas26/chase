import 'package:chase/chase.dart';

/// Example: Request Body Size Limiting
///
/// This example demonstrates:
/// - Global body size limits
/// - Route-specific limits
/// - Different size configurations (bytes, KB, MB)
/// - Custom error messages
/// - Handling of file uploads
///
/// Run: dart run bin/example_body_limit.dart
/// Test:
///   # Small request (should succeed)
///   curl -X POST http://localhost:6060/api/data \
///     -H "Content-Type: application/json" \
///     -H "Content-Length: 100" \
///     -d '{"test":"data"}'
///
///   # Large request (should fail)
///   curl -X POST http://localhost:6060/api/data \
///     -H "Content-Type: application/json" \
///     -H "Content-Length: 2000000" \
///     -d '{"large":"data"}'
void main() async {
  final app = Chase();

  // Example 1: Global body limit (applies to all routes)
  // Set a reasonable default limit for all requests
  app.use(BodyLimit(const BodyLimitOptions.mb(5)));

  // Example 2: Small limit for API endpoints
  app.post('/api/data').use(BodyLimit(const BodyLimitOptions.kb(100))).handle((
    ctx,
  ) async {
    // This route only accepts requests up to 100KB
    final body = await ctx.req.json();
    return Response.json({'message': 'Data received', 'data': body});
  });

  // Example 3: Larger limit for file uploads
  app.post('/upload').use(BodyLimit(const BodyLimitOptions.mb(100))).handle((
    ctx,
  ) async {
    // This route accepts files up to 100MB
    return Response.json({'message': 'File upload endpoint ready'});
  });

  // Example 4: Custom error message
  app
      .post('/strict')
      .use(
        BodyLimit(
          const BodyLimitOptions(
            maxSize: 1024, // 1KB
            errorMessage: 'This endpoint has a strict 1KB limit',
          ),
        ),
      )
      .handle((ctx) async {
        final body = await ctx.req.json();
        return Response.json({'received': body});
      });

  // Example 5: Generic error without size details
  app
      .post('/secure')
      .use(
        BodyLimit(
          const BodyLimitOptions(
            maxSize: 2048,
            includeLimit: false, // Don't reveal size limits
          ),
        ),
      )
      .handle((ctx) async {
        return Response.json({'status': 'ok'});
      });

  // Example 6: Very small limit for metadata endpoints
  app
      .post('/metadata')
      .use(
        BodyLimit(
          const BodyLimitOptions(
            maxSize: 512, // 512 bytes
            errorMessage: 'Metadata must be under 512 bytes',
          ),
        ),
      )
      .handle((ctx) async {
        final metadata = await ctx.req.json();
        return Response.json({'metadata': metadata});
      });

  // Example 7: Multiple size limits in nested routes
  app.routes('/api/v1', (api) {
    // Default 10KB for all v1 endpoints
    api.use(BodyLimit(const BodyLimitOptions.kb(10)));

    api.post('/users').handle((ctx) async {
      // Inherits the 10KB limit
      final user = await ctx.req.json();
      return Response.json({'user': user, 'limit': '10KB'});
    });

    // Override with larger limit for specific endpoint
    api.post('/posts').use(BodyLimit(const BodyLimitOptions.kb(50))).handle((
      ctx,
    ) async {
      final post = await ctx.req.json();
      return Response.json({'post': post, 'limit': '50KB'});
    });
  });

  // Example 8: No limit route (for demonstration - not recommended in production)
  app.post('/unlimited').handle((ctx) async {
    // No BodyLimit middleware, will use global limit or no limit
    return Response.json({'message': 'This route uses the global 5MB limit'});
  });

  // Info endpoint showing all routes and their limits
  app.get('/').handle((ctx) async {
    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <title>Body Limit Example</title>
  <style>
    body { font-family: Arial; max-width: 900px; margin: 50px auto; }
    table { width: 100%; border-collapse: collapse; margin: 20px 0; }
    th, td { padding: 12px; text-align: left; border: 1px solid #ddd; }
    th { background: #f4f4f4; }
    code { background: #f4f4f4; padding: 2px 6px; border-radius: 3px; }
    .limit { color: #e67e22; font-weight: bold; }
    .endpoint { color: #2980b9; }
  </style>
</head>
<body>
  <h1>Body Limit Middleware Examples</h1>
  <p>This server demonstrates various body size limit configurations.</p>

  <h2>Configured Endpoints</h2>
  <table>
    <thead>
      <tr>
        <th>Endpoint</th>
        <th>Limit</th>
        <th>Description</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td class="endpoint">POST /api/data</td>
        <td class="limit">100 KB</td>
        <td>Small limit for API data</td>
      </tr>
      <tr>
        <td class="endpoint">POST /upload</td>
        <td class="limit">100 MB</td>
        <td>Large limit for file uploads</td>
      </tr>
      <tr>
        <td class="endpoint">POST /strict</td>
        <td class="limit">1 KB</td>
        <td>Very strict limit with custom message</td>
      </tr>
      <tr>
        <td class="endpoint">POST /secure</td>
        <td class="limit">2 KB</td>
        <td>Generic error (size not revealed)</td>
      </tr>
      <tr>
        <td class="endpoint">POST /metadata</td>
        <td class="limit">512 bytes</td>
        <td>Tiny limit for metadata only</td>
      </tr>
      <tr>
        <td class="endpoint">POST /api/v1/users</td>
        <td class="limit">10 KB</td>
        <td>API v1 default limit</td>
      </tr>
      <tr>
        <td class="endpoint">POST /api/v1/posts</td>
        <td class="limit">50 KB</td>
        <td>Override for posts endpoint</td>
      </tr>
      <tr>
        <td class="endpoint">POST /unlimited</td>
        <td class="limit">5 MB (global)</td>
        <td>Uses global default limit</td>
      </tr>
    </tbody>
  </table>

  <h2>Test Commands</h2>
  <p>Try these curl commands to test different scenarios:</p>

  <h3>1. Small request (should succeed)</h3>
  <pre><code>curl -X POST http://localhost:6060/api/data \\
  -H "Content-Type: application/json" \\
  -d '{"message":"Hello"}'</code></pre>

  <h3>2. Large request (should fail with 413)</h3>
  <pre><code>curl -X POST http://localhost:6060/api/data \\
  -H "Content-Type: application/json" \\
  -H "Content-Length: 200000" \\
  -d '{"large":"data"}'</code></pre>

  <h3>3. Test strict endpoint</h3>
  <pre><code>curl -X POST http://localhost:6060/strict \\
  -H "Content-Type: application/json" \\
  -d '{"tiny":"data"}'</code></pre>

  <h3>4. Test metadata endpoint (very small limit)</h3>
  <pre><code>curl -X POST http://localhost:6060/metadata \\
  -H "Content-Type: application/json" \\
  -d '{"id":1,"tags":["a","b"]}'</code></pre>

  <h2>Expected Behaviors</h2>
  <ul>
    <li>Requests within limits: <strong>200 OK</strong> with JSON response</li>
    <li>Requests exceeding limits: <strong>413 Payload Too Large</strong> with error message</li>
    <li>Requests without Content-Length: Passed through (global limit applies)</li>
  </ul>

  <h2>Security Best Practices</h2>
  <ul>
    <li>Always set appropriate limits based on expected data sizes</li>
    <li>Use smaller limits for sensitive endpoints</li>
    <li>Use larger limits only when necessary (file uploads, etc.)</li>
    <li>Consider using <code>includeLimit: false</code> for security-sensitive routes</li>
    <li>Monitor and log rejected requests for potential attacks</li>
  </ul>
</body>
</html>
''';

    return Response.html(htmlContent);
  });

  final port = 3000;
  print('🚀 Body Limit example server running on http://localhost:$port');
  print('');
  print('Open http://localhost:$port in your browser for documentation');
  print('');
  print('Example tests:');
  print('  # Small request (should succeed)');
  print(
    '  curl -X POST http://localhost:$port/api/data -H "Content-Type: application/json" -d \'{"test":"data"}\'',
  );
  print('');
  print('  # Large request (should fail)');
  print(
    '  curl -X POST http://localhost:$port/api/data -H "Content-Type: application/json" -H "Content-Length: 200000" -d \'{"large":"data"}\'',
  );

  await app.start(port: port);
}
