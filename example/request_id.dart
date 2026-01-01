import 'dart:async';

import 'package:chase/chase.dart';

/// Example: Request ID Middleware
///
/// This example demonstrates:
/// - Automatic request ID generation
/// - Using existing request IDs from upstream
/// - Custom header names
/// - Custom ID generators
/// - Accessing request ID in handlers
///
/// Run: dart run bin/example_request_id.dart
/// Test:
///   # Get auto-generated request ID
///   curl -i http://localhost:6060/api/data
///
///   # Send existing request ID
///   curl -i -H "X-Request-ID: my-custom-id" http://localhost:6060/api/data
void main() async {
  final app = Chase();

  // Example 1: Basic request ID middleware
  // Generates UUID v4 for each request, respects existing X-Request-ID header
  app.use(RequestId());

  // Example 2: Logging with request ID
  app.use(_LoggingMiddleware());

  // Example 3: Simple endpoint showing request ID
  app.get('/api/data').handle((ctx) async {
    final requestId = ctx.get<String>('requestId');
    await ctx.res.json({
      'requestId': requestId,
      'message': 'Your request has been processed',
      'timestamp': DateTime.now().toIso8601String(),
    });
  });

  // Example 4: Custom correlation ID header
  app.routes('/v2', (v2) {
    v2.use(RequestId(const RequestIdOptions.withHeader('X-Correlation-ID')));

    v2.get('/users').handle((ctx) async {
      final correlationId = ctx.get<String>('requestId');
      await ctx.res.json({
        'correlationId': correlationId,
        'users': [],
      });
    });
  });

  // Example 5: Always generate new ID (ignore incoming headers)
  app.routes('/internal', (internal) {
    internal.use(RequestId(const RequestIdOptions.alwaysNew()));

    internal.get('/status').handle((ctx) async {
      await ctx.res.json({
        'requestId': ctx.get<String>('requestId'),
        'status': 'healthy',
      });
    });
  });

  // Example 6: Custom ID generator with timestamp prefix
  app.routes('/custom', (custom) {
    var counter = 0;
    custom.use(RequestId(RequestIdOptions(
      generator: () {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        return 'req-$timestamp-${++counter}';
      },
    )));

    custom.get('/order').handle((ctx) async {
      await ctx.res.json({
        'requestId': ctx.get<String>('requestId'),
        'order': 'Sample order',
      });
    });
  });

  // Example 7: Using context store for other data
  app.get('/context-demo').handle((ctx) async {
    // Request ID is already set by middleware
    final requestId = ctx.get<String>('requestId');

    // You can store additional data
    ctx.set('processedAt', DateTime.now());
    ctx.set('userId', 12345);

    await ctx.res.json({
      'requestId': requestId,
      'processedAt': ctx.get<DateTime>('processedAt')?.toIso8601String(),
      'userId': ctx.get<int>('userId'),
      'hasUserId': ctx.get('userId') != null,
    });
  });

  // Info endpoint
  app.get('/').handle((ctx) async {
    final html = '''
<!DOCTYPE html>
<html>
<head>
  <title>Request ID Example</title>
  <style>
    body { font-family: Arial; max-width: 900px; margin: 50px auto; }
    table { width: 100%; border-collapse: collapse; margin: 20px 0; }
    th, td { padding: 12px; text-align: left; border: 1px solid #ddd; }
    th { background: #f4f4f4; }
    code { background: #f4f4f4; padding: 2px 6px; border-radius: 3px; }
    pre { background: #f4f4f4; padding: 15px; border-radius: 5px; overflow-x: auto; }
    .header { color: #e67e22; font-weight: bold; }
  </style>
</head>
<body>
  <h1>Request ID Middleware Example</h1>
  <p>This server demonstrates request ID generation and tracking.</p>

  <h2>Endpoints</h2>
  <table>
    <thead>
      <tr>
        <th>Endpoint</th>
        <th>Header</th>
        <th>Behavior</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td>GET /api/data</td>
        <td class="header">X-Request-ID</td>
        <td>Uses existing or generates UUID v4</td>
      </tr>
      <tr>
        <td>GET /v2/users</td>
        <td class="header">X-Correlation-ID</td>
        <td>Custom header name</td>
      </tr>
      <tr>
        <td>GET /internal/status</td>
        <td class="header">X-Request-ID</td>
        <td>Always generates new ID</td>
      </tr>
      <tr>
        <td>GET /custom/order</td>
        <td class="header">X-Request-ID</td>
        <td>Custom generator (timestamp-based)</td>
      </tr>
      <tr>
        <td>GET /context-demo</td>
        <td class="header">X-Request-ID</td>
        <td>Demonstrates context store</td>
      </tr>
    </tbody>
  </table>

  <h2>Test Commands</h2>

  <h3>1. Auto-generated request ID</h3>
  <pre><code>curl -i http://localhost:6060/api/data</code></pre>

  <h3>2. With existing request ID</h3>
  <pre><code>curl -i -H "X-Request-ID: my-trace-123" http://localhost:6060/api/data</code></pre>

  <h3>3. Custom correlation header</h3>
  <pre><code>curl -i -H "X-Correlation-ID: corr-456" http://localhost:6060/v2/users</code></pre>

  <h3>4. Always new ID (ignores header)</h3>
  <pre><code>curl -i -H "X-Request-ID: will-be-ignored" http://localhost:6060/internal/status</code></pre>

  <h3>5. Custom generator format</h3>
  <pre><code>curl -i http://localhost:6060/custom/order</code></pre>

  <h2>Response Headers</h2>
  <p>Each response includes the request ID in the header:</p>
  <pre><code>X-Request-ID: a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d</code></pre>

  <h2>Use Cases</h2>
  <ul>
    <li><strong>Logging</strong>: Correlate all log entries for a single request</li>
    <li><strong>Debugging</strong>: Track requests through your system</li>
    <li><strong>Distributed Tracing</strong>: Pass IDs between microservices</li>
    <li><strong>Support</strong>: Reference specific requests in error reports</li>
  </ul>
</body>
</html>
''';
    await ctx.res.html(html);
  });

  final port = 3000;
  print('Request ID example server running on http://localhost:$port');
  print('');
  print('Open http://localhost:$port in your browser for documentation');
  print('');
  print('Example tests:');
  print('  # Auto-generated ID');
  print('  curl -i http://localhost:$port/api/data');
  print('');
  print('  # With existing ID');
  print('  curl -i -H "X-Request-ID: my-custom-id" http://localhost:$port/api/data');

  await app.start(port: port);
}

/// Simple logging middleware that logs request/response with request ID.
class _LoggingMiddleware implements Middleware {
  @override
  FutureOr<void> handle(Context ctx, NextFunction next) async {
    final requestId = ctx.get<String>('requestId');
    final startTime = DateTime.now();

    print('[$requestId] --> ${ctx.req.method} ${ctx.req.uri.path}');

    await next();

    final duration = DateTime.now().difference(startTime).inMilliseconds;
    print('[$requestId] <-- ${ctx.res.statusCode} (${duration}ms)');
  }
}
