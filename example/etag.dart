import 'dart:io';

import 'package:chase/chase.dart';

/// Example: ETag Middleware
///
/// This example demonstrates:
/// - Manual ETag handling with ctx.checkEtag()
/// - ETag generation using ETagHelper
/// - Version-based ETags
/// - Content-based ETags
/// - 304 Not Modified responses
///
/// Run: dart run bin/example_etag.dart
/// Test:
///   # First request (gets full response with ETag)
///   curl -i http://localhost:6060/api/data
///
///   # Second request with If-None-Match (gets 304)
///   curl -i -H 'If-None-Match: "`<etag-from-first-response>`"' http://localhost:6060/api/data
void main() async {
  final app = Chase();

  // Simulated data with version
  var dataVersion = 1;
  var data = {'items': ['apple', 'banana', 'cherry'], 'version': dataVersion};

  // Example 1: Version-based ETag
  // Use when you track data versions explicitly
  app.get('/api/data').handle((ctx) async {
    final etag = ETagHelper.fromVersion('v$dataVersion');

    // Check if client has current version
    if (await ctx.checkEtag(etag)) {
      return; // 304 Not Modified sent
    }

    await ctx.res.json(data);
  });

  // Example 2: Content-based ETag
  // ETag is computed from the response content
  app.get('/api/content').handle((ctx) async {
    final content = {'message': 'Hello, World!', 'timestamp': 'fixed'};
    final etag = ETagHelper.fromJson(content);

    if (await ctx.checkEtag(etag)) {
    }

    await ctx.res.json(content);
  });

  // Example 3: Weak ETag
  // For semantically equivalent content
  app.get('/api/weak').handle((ctx) async {
    final content = {'data': 'example'};
    final etag = ETagHelper.fromJson(content, weak: true);

    if (await ctx.checkEtag(etag)) {
    }

    await ctx.res.json(content);
  });

  // Example 4: Update data (invalidates ETag)
  app.post('/api/data').handle((ctx) async {
    dataVersion++;
    data = {
      'items': [...data['items'] as List, 'new-item-$dataVersion'],
      'version': dataVersion,
    };

    await ctx.res.json({
      'message': 'Data updated',
      'newVersion': dataVersion,
      'newEtag': ETagHelper.fromVersion('v$dataVersion'),
    });
  });

  // Example 5: Static content with ETag
  app.get('/static/config').handle((ctx) async {
    const config = {
      'apiVersion': '1.0',
      'features': ['feature1', 'feature2'],
      'maxItems': 100,
    };

    // For truly static content, you can use a fixed ETag
    const etag = '"config-v1"';

    if (await ctx.checkEtag(etag)) {
    }

    await ctx.res.json(config);
  });

  // Example 6: Using ETag with Last-Modified
  app.get('/api/resource').handle((ctx) async {
    final lastModified = DateTime(2024, 1, 15, 10, 30, 0);
    final content = {'id': 1, 'name': 'Resource'};
    final etag = ETagHelper.fromJson(content);

    // Set Last-Modified header
    ctx.res.headers.set('Last-Modified', HttpDate.format(lastModified));

    if (await ctx.checkEtag(etag)) {
    }

    await ctx.res.json(content);
  });

  // Example 7: Checking If-None-Match manually
  app.get('/api/manual').handle((ctx) async {
    final content = {'manual': 'example'};
    final etag = ETagHelper.fromJson(content);

    // Manual check
    if (ctx.etagMatches(etag)) {
      ctx.res.statusCode = 304;
      ctx.res.headers.set('ETag', etag);
      await ctx.res.close();
    }

    ctx.res.headers.set('ETag', etag);
    await ctx.res.json(content);
  });

  // Info endpoint
  app.get('/').handle((ctx) async {
    final html = '''
<!DOCTYPE html>
<html>
<head>
  <title>ETag Example</title>
  <style>
    body { font-family: Arial; max-width: 900px; margin: 50px auto; }
    table { width: 100%; border-collapse: collapse; margin: 20px 0; }
    th, td { padding: 12px; text-align: left; border: 1px solid #ddd; }
    th { background: #f4f4f4; }
    code { background: #f4f4f4; padding: 2px 6px; border-radius: 3px; }
    pre { background: #f4f4f4; padding: 15px; border-radius: 5px; overflow-x: auto; }
    .header { color: #3498db; font-weight: bold; }
  </style>
</head>
<body>
  <h1>ETag Middleware Example</h1>
  <p>ETags enable efficient caching by identifying resource versions.</p>

  <h2>How ETags Work</h2>
  <ol>
    <li>Client requests a resource</li>
    <li>Server responds with content and <code>ETag</code> header</li>
    <li>Client caches the response with the ETag</li>
    <li>On subsequent requests, client sends <code>If-None-Match: &lt;etag&gt;</code></li>
    <li>If ETag matches, server returns <code>304 Not Modified</code> (no body)</li>
    <li>If ETag differs, server returns new content with new ETag</li>
  </ol>

  <h2>Endpoints</h2>
  <table>
    <thead>
      <tr>
        <th>Endpoint</th>
        <th>ETag Type</th>
        <th>Description</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td>GET /api/data</td>
        <td>Version-based</td>
        <td>ETag changes when data version changes</td>
      </tr>
      <tr>
        <td>POST /api/data</td>
        <td>-</td>
        <td>Updates data (increments version)</td>
      </tr>
      <tr>
        <td>GET /api/content</td>
        <td>Content-based</td>
        <td>ETag computed from response body</td>
      </tr>
      <tr>
        <td>GET /api/weak</td>
        <td>Weak (W/"...")</td>
        <td>For semantically equivalent content</td>
      </tr>
      <tr>
        <td>GET /static/config</td>
        <td>Fixed</td>
        <td>Static content with fixed ETag</td>
      </tr>
      <tr>
        <td>GET /api/resource</td>
        <td>Content + Last-Modified</td>
        <td>Combined with Last-Modified header</td>
      </tr>
    </tbody>
  </table>

  <h2>Test Commands</h2>

  <h3>1. Get resource with ETag</h3>
  <pre><code>curl -i http://localhost:6060/api/data</code></pre>
  <p>Note the <code class="header">ETag</code> header in the response.</p>

  <h3>2. Conditional request (304 response)</h3>
  <pre><code>curl -i -H 'If-None-Match: "v1"' http://localhost:6060/api/data</code></pre>
  <p>Returns 304 if ETag matches (no response body).</p>

  <h3>3. Update data and get new ETag</h3>
  <pre><code># Update data
curl -X POST http://localhost:6060/api/data

# New request will have different ETag
curl -i http://localhost:6060/api/data</code></pre>

  <h3>4. Weak ETag example</h3>
  <pre><code>curl -i http://localhost:6060/api/weak</code></pre>
  <p>Returns <code>W/"..."</code> format ETag.</p>

  <h2>ETag Types</h2>
  <table>
    <thead>
      <tr>
        <th>Type</th>
        <th>Format</th>
        <th>Use Case</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td>Strong</td>
        <td><code>"abc123"</code></td>
        <td>Byte-for-byte identical content</td>
      </tr>
      <tr>
        <td>Weak</td>
        <td><code>W/"abc123"</code></td>
        <td>Semantically equivalent content</td>
      </tr>
    </tbody>
  </table>

  <h2>Benefits</h2>
  <ul>
    <li>Reduced bandwidth (304 responses have no body)</li>
    <li>Faster page loads for cached content</li>
    <li>Lower server load</li>
    <li>Works with CDNs and browser caches</li>
  </ul>
</body>
</html>
''';
    await ctx.res.html(html);
  });

  final port = 3000;
  print('ETag example server running on http://localhost:$port');
  print('');
  print('Open http://localhost:$port in your browser for documentation');
  print('');
  print('Example tests:');
  print('  # Get resource with ETag');
  print('  curl -i http://localhost:$port/api/data');
  print('');
  print('  # Conditional request (should return 304)');
  print('  curl -i -H \'If-None-Match: "v1"\' http://localhost:$port/api/data');

  await app.start(port: port);
}
