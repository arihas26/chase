import 'dart:io';

import 'package:chase/chase.dart';

/// Example: Timeout Middleware
///
/// This example demonstrates:
/// - Global request timeout
/// - Route-specific timeouts
/// - Custom timeout handlers
/// - Timeout presets
///
/// Run: dart run bin/example_timeout.dart
/// Test:
///   # Fast endpoint (should succeed)
///   curl -i http://localhost:6060/fast
///
///   # Slow endpoint (should timeout)
///   curl -i http://localhost:6060/slow
void main() async {
  final app = Chase();

  // Example 1: Global timeout of 30 seconds
  app.use(const Timeout());

  // Example 2: Fast endpoint (completes before timeout)
  app.get('/fast').handle((ctx) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return Response.ok().json({
      'message': 'Fast response',
      'duration_ms': 100,
    });
  });

  // Example 3: Endpoint that will timeout
  app.get('/slow')
      .use(const Timeout(TimeoutOptions(duration: Duration(seconds: 2))))
      .handle((ctx) async {
    // This takes longer than the 2-second timeout
    await Future.delayed(const Duration(seconds: 5));
    return Response.ok().json({'message': 'This will never be sent'});
  });

  // Example 4: Short timeout preset
  app.get('/quick')
      .use(const Timeout(TimeoutOptions.short)) // 5 seconds
      .handle((ctx) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return Response.ok().json({'message': 'Quick response'});
  });

  // Example 5: Long timeout for heavy operations
  app.post('/process')
      .use(const Timeout(TimeoutOptions.long)) // 120 seconds
      .handle((ctx) async {
    // Simulate heavy processing
    await Future.delayed(const Duration(seconds: 2));
    return Response.ok().json({'message': 'Processing complete'});
  });

  // Example 6: Custom timeout handler
  app.get('/custom-timeout')
      .use(Timeout(TimeoutOptions(
        duration: const Duration(seconds: 1),
        onTimeout: (ctx) async {
          ctx.res.statusCode = HttpStatus.serviceUnavailable;
          await ctx.res.json({
            'error': 'Custom timeout response',
            'suggestion': 'Please try again later',
            'support': 'support@example.com',
          });
        },
      )))
      .handle((ctx) async {
    await Future.delayed(const Duration(seconds: 3));
    return Response.ok().json({'message': 'Never reached'});
  });

  // Example 7: Gateway timeout status
  app.get('/gateway')
      .use(const Timeout(TimeoutOptions(
        duration: Duration(seconds: 2),
        statusCode: HttpStatus.gatewayTimeout,
        errorMessage: 'Upstream server took too long',
      )))
      .handle((ctx) async {
    await Future.delayed(const Duration(seconds: 5));
    return Response.ok().json({'data': 'from upstream'});
  });

  // Example 8: Include duration in error
  app.get('/debug')
      .use(const Timeout(TimeoutOptions(
        duration: Duration(seconds: 1),
        includeDuration: true,
      )))
      .handle((ctx) async {
    await Future.delayed(const Duration(seconds: 3));
    return Response.ok().json({'debug': true});
  });

  // Example 9: Variable processing time
  app.get('/variable').handle((ctx) async {
    final delay = DateTime.now().second % 3; // 0, 1, or 2 seconds
    await Future.delayed(Duration(seconds: delay));
    return Response.ok().json({
      'message': 'Variable delay response',
      'delay_seconds': delay,
    });
  });

  // Example 10: Using deadline in handler
  app.get('/deadline')
      .use(const Timeout(TimeoutOptions(duration: Duration(seconds: 5))))
      .handle((ctx) async {
    // Set deadline for internal use
    ctx.setDeadline(DateTime.now().add(const Duration(seconds: 5)));

    // Check deadline during processing
    for (var i = 0; i < 3; i++) {
      if (ctx.isExpired) {
        return Response.ok().json({'error': 'Deadline exceeded during processing'});
      }

      await Future.delayed(const Duration(seconds: 1));
    }

    return Response.ok().json({
      'message': 'Completed before deadline',
      'remaining_ms': ctx.remainingTime?.inMilliseconds,
    });
  });

  // Info endpoint
  app.get('/').handle((ctx) async {
    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <title>Timeout Example</title>
  <style>
    body { font-family: Arial; max-width: 900px; margin: 50px auto; }
    table { width: 100%; border-collapse: collapse; margin: 20px 0; }
    th, td { padding: 12px; text-align: left; border: 1px solid #ddd; }
    th { background: #f4f4f4; }
    code { background: #f4f4f4; padding: 2px 6px; border-radius: 3px; }
    pre { background: #f4f4f4; padding: 15px; border-radius: 5px; overflow-x: auto; }
    .timeout { color: #e74c3c; font-weight: bold; }
    .success { color: #27ae60; }
  </style>
</head>
<body>
  <h1>Timeout Middleware Example</h1>
  <p>This middleware enforces a maximum duration for request processing.</p>

  <h2>Endpoints</h2>
  <table>
    <thead>
      <tr>
        <th>Endpoint</th>
        <th>Timeout</th>
        <th>Behavior</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td>GET /fast</td>
        <td>30s (global)</td>
        <td class="success">Completes in 100ms</td>
      </tr>
      <tr>
        <td>GET /slow</td>
        <td class="timeout">2s</td>
        <td>Takes 5s, will timeout</td>
      </tr>
      <tr>
        <td>GET /quick</td>
        <td>5s (short preset)</td>
        <td class="success">Completes in 500ms</td>
      </tr>
      <tr>
        <td>POST /process</td>
        <td>120s (long preset)</td>
        <td class="success">Heavy processing</td>
      </tr>
      <tr>
        <td>GET /custom-timeout</td>
        <td class="timeout">1s</td>
        <td>Custom error response</td>
      </tr>
      <tr>
        <td>GET /gateway</td>
        <td class="timeout">2s</td>
        <td>504 Gateway Timeout</td>
      </tr>
      <tr>
        <td>GET /debug</td>
        <td class="timeout">1s</td>
        <td>Includes duration in error</td>
      </tr>
      <tr>
        <td>GET /variable</td>
        <td>30s (global)</td>
        <td>Random 0-2s delay</td>
      </tr>
      <tr>
        <td>GET /deadline</td>
        <td>5s</td>
        <td>Uses deadline internally</td>
      </tr>
    </tbody>
  </table>

  <h2>Test Commands</h2>

  <h3>1. Fast endpoint (should succeed)</h3>
  <pre><code>curl -i http://localhost:6060/fast</code></pre>

  <h3>2. Slow endpoint (should timeout)</h3>
  <pre><code>curl -i http://localhost:6060/slow</code></pre>

  <h3>3. Custom timeout response</h3>
  <pre><code>curl -i http://localhost:6060/custom-timeout</code></pre>

  <h3>4. Gateway timeout</h3>
  <pre><code>curl -i http://localhost:6060/gateway</code></pre>

  <h3>5. Debug mode with duration</h3>
  <pre><code>curl -i http://localhost:6060/debug</code></pre>

  <h2>Timeout Presets</h2>
  <table>
    <thead>
      <tr>
        <th>Preset</th>
        <th>Duration</th>
        <th>Use Case</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td><code>TimeoutOptions.short</code></td>
        <td>5 seconds</td>
        <td>Quick API calls</td>
      </tr>
      <tr>
        <td><code>TimeoutOptions.medium</code></td>
        <td>30 seconds</td>
        <td>Default operations</td>
      </tr>
      <tr>
        <td><code>TimeoutOptions.long</code></td>
        <td>120 seconds</td>
        <td>Heavy processing, uploads</td>
      </tr>
    </tbody>
  </table>

  <h2>Status Codes</h2>
  <ul>
    <li><strong>503 Service Unavailable</strong> (default): Server is overloaded</li>
    <li><strong>504 Gateway Timeout</strong>: Upstream server timeout</li>
    <li><strong>408 Request Timeout</strong>: Client took too long</li>
  </ul>
</body>
</html>
''';
    return Response.ok().html(htmlContent);
  });

  final port = 3000;
  print('Timeout example server running on http://localhost:$port');
  print('');
  print('Open http://localhost:$port in your browser for documentation');
  print('');
  print('Example tests:');
  print('  # Fast endpoint (should succeed)');
  print('  curl -i http://localhost:$port/fast');
  print('');
  print('  # Slow endpoint (should timeout with 503)');
  print('  curl -i http://localhost:$port/slow');

  await app.start(port: port);
}
