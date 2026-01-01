import 'dart:io';

import 'package:chase/chase.dart';

/// Example: Session Middleware
///
/// This example demonstrates:
/// - Cookie-based session management
/// - Session data persistence
/// - Session destruction and regeneration
/// - Secure session options
///
/// Run: dart run bin/example_session.dart
/// Test:
///   # Set session data
///   curl -c cookies.txt http://localhost:6060/login?username=alice
///
///   # Get session data
///   curl -b cookies.txt http://localhost:6060/profile
///
///   # Logout
///   curl -b cookies.txt -c cookies.txt http://localhost:6060/logout
void main() async {
  final app = Chase();

  // Create a session store
  final store = MemorySessionStore(
    cleanupInterval: const Duration(minutes: 5),
  );

  // Add session middleware globally
  app.use(Session(store));

  // Example 1: Login - set session data
  app.get('/login').handle((ctx) async {
    final username = ctx.req.query('username');
    if (username == null || username.isEmpty) {
      await ctx.res.json({
        'error': 'Username required',
        'usage': '/login?username=yourname',
      }, status: HttpStatus.badRequest);
    }

    // Store user data in session
    ctx.session.set('username', username);
    ctx.session.set('loginTime', DateTime.now().toIso8601String());
    ctx.session.set('visits', 0);

    await ctx.res.json({
      'message': 'Logged in successfully',
      'sessionId': '${ctx.session.id.substring(0, 8)}...',
      'username': username,
    });
  });

  // Example 2: Profile - read session data
  app.get('/profile').handle((ctx) async {
    final username = ctx.session.get<String>('username');
    if (username == null) {
      await ctx.res.json({
        'error': 'Not logged in',
        'hint': 'Visit /login?username=yourname first',
      }, status: HttpStatus.unauthorized);
    }

    // Increment visit counter
    final visits = (ctx.session.get<int>('visits') ?? 0) + 1;
    ctx.session.set('visits', visits);

    await ctx.res.json({
      'username': username,
      'loginTime': ctx.session.get<String>('loginTime'),
      'visits': visits,
      'isNew': ctx.session.isNew,
    });
  });

  // Example 3: Logout - destroy session
  app.get('/logout').handle((ctx) async {
    final username = ctx.session.get<String>('username');
    if (username == null) {
      await ctx.res.json({'message': 'Already logged out'});
    }

    ctx.destroySession();

    await ctx.res.json({
      'message': 'Logged out successfully',
      'previousUser': username,
    });
  });

  // Example 4: Security - regenerate session ID
  app.get('/secure-action').handle((ctx) async {
    final username = ctx.session.get<String>('username');
    if (username == null) {
      await ctx.res.json({
        'error': 'Not logged in',
      }, status: HttpStatus.unauthorized);
    }

    // Regenerate session ID to prevent session fixation
    // Data is preserved, but ID changes
    final oldId = ctx.session.id.substring(0, 8);
    ctx.regenerateSession();
    final newId = ctx.session.id.substring(0, 8);

    await ctx.res.json({
      'message': 'Session regenerated',
      'oldIdPrefix': '$oldId...',
      'newIdPrefix': '$newId...',
      'username': ctx.session.get<String>('username'),
    });
  });

  // Example 5: Session info
  app.get('/session-info').handle((ctx) async {
    await ctx.res.json({
      'sessionId': '${ctx.session.id.substring(0, 8)}...',
      'isNew': ctx.session.isNew,
      'isModified': ctx.session.isModified,
      'lastAccess': ctx.session.lastAccess.toIso8601String(),
      'data': ctx.session.data,
    });
  });

  // Example 6: Clear specific data
  app.get('/clear-visits').handle((ctx) async {
    ctx.session.remove('visits');
    await ctx.res.json({
      'message': 'Visits counter cleared',
      'data': ctx.session.data,
    });
  });

  // Example 7: Admin - view store stats
  app.get('/admin/sessions').handle((ctx) async {
    await ctx.res.json({
      'activeSessions': store.length,
    });
  });

  // Example 8: Shopping cart simulation
  app.get('/cart').handle((ctx) async {
    final cart = ctx.session.get<List<dynamic>>('cart') ?? [];
    await ctx.res.json({
      'items': cart,
      'itemCount': cart.length,
    });
  });

  app.get('/cart/add').handle((ctx) async {
    final item = ctx.req.query('item');
    if (item == null) {
      await ctx.res.json({
        'error': 'Item required',
        'usage': '/cart/add?item=apple',
      }, status: HttpStatus.badRequest);
      return;
    }

    final cart = List<String>.from(ctx.session.get<List<dynamic>>('cart') ?? []);
    cart.add(item);
    ctx.session.set('cart', cart);

    await ctx.res.json({
      'message': 'Added to cart',
      'item': item,
      'itemCount': cart.length,
    });
  });

  app.get('/cart/clear').handle((ctx) async {
    ctx.session.remove('cart');
    await ctx.res.json({
      'message': 'Cart cleared',
    });
  });

  // Info endpoint
  app.get('/').handle((ctx) async {
    final html = '''
<!DOCTYPE html>
<html>
<head>
  <title>Session Example</title>
  <style>
    body { font-family: Arial; max-width: 900px; margin: 50px auto; }
    table { width: 100%; border-collapse: collapse; margin: 20px 0; }
    th, td { padding: 12px; text-align: left; border: 1px solid #ddd; }
    th { background: #f4f4f4; }
    code { background: #f4f4f4; padding: 2px 6px; border-radius: 3px; }
    pre { background: #f4f4f4; padding: 15px; border-radius: 5px; overflow-x: auto; }
    .secure { color: #27ae60; }
    .auth { color: #e74c3c; }
  </style>
</head>
<body>
  <h1>Session Middleware Example</h1>
  <p>This middleware provides cookie-based session management with pluggable storage backends.</p>

  <h2>Endpoints</h2>
  <table>
    <thead>
      <tr>
        <th>Endpoint</th>
        <th>Description</th>
        <th>Auth Required</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td>GET /login?username=...</td>
        <td>Login and create session</td>
        <td>No</td>
      </tr>
      <tr>
        <td>GET /profile</td>
        <td>View session data</td>
        <td class="auth">Yes</td>
      </tr>
      <tr>
        <td>GET /logout</td>
        <td>Destroy session</td>
        <td>No</td>
      </tr>
      <tr>
        <td>GET /secure-action</td>
        <td>Regenerate session ID</td>
        <td class="auth">Yes</td>
      </tr>
      <tr>
        <td>GET /session-info</td>
        <td>View session metadata</td>
        <td>No</td>
      </tr>
      <tr>
        <td>GET /clear-visits</td>
        <td>Remove visits counter</td>
        <td>No</td>
      </tr>
      <tr>
        <td>GET /admin/sessions</td>
        <td>View active session count</td>
        <td>No</td>
      </tr>
      <tr>
        <td>GET /cart</td>
        <td>View shopping cart</td>
        <td>No</td>
      </tr>
      <tr>
        <td>GET /cart/add?item=...</td>
        <td>Add item to cart</td>
        <td>No</td>
      </tr>
      <tr>
        <td>GET /cart/clear</td>
        <td>Clear shopping cart</td>
        <td>No</td>
      </tr>
    </tbody>
  </table>

  <h2>Test Commands</h2>

  <h3>1. Login</h3>
  <pre><code># Save session cookie
curl -c cookies.txt http://localhost:6060/login?username=alice</code></pre>

  <h3>2. View profile (use saved cookie)</h3>
  <pre><code>curl -b cookies.txt http://localhost:6060/profile</code></pre>

  <h3>3. Add items to cart</h3>
  <pre><code>curl -b cookies.txt http://localhost:6060/cart/add?item=apple
curl -b cookies.txt http://localhost:6060/cart/add?item=banana
curl -b cookies.txt http://localhost:6060/cart</code></pre>

  <h3>4. Regenerate session ID (security)</h3>
  <pre><code># Session ID changes but data preserved
curl -b cookies.txt -c cookies.txt http://localhost:6060/secure-action
curl -b cookies.txt http://localhost:6060/profile</code></pre>

  <h3>5. Logout</h3>
  <pre><code>curl -b cookies.txt -c cookies.txt http://localhost:6060/logout
curl -b cookies.txt http://localhost:6060/profile  # Should show not logged in</code></pre>

  <h2>Session Options</h2>
  <table>
    <thead>
      <tr>
        <th>Preset</th>
        <th>Cookie Secure</th>
        <th>SameSite</th>
        <th>Max Age</th>
        <th>Use Case</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td><code>SessionOptions()</code></td>
        <td>false</td>
        <td>Lax</td>
        <td>24h</td>
        <td>Development</td>
      </tr>
      <tr>
        <td><code>SessionOptions.secure()</code></td>
        <td class="secure">true</td>
        <td class="secure">Strict</td>
        <td>24h</td>
        <td>Production (HTTPS)</td>
      </tr>
      <tr>
        <td><code>SessionOptions.shortLived()</code></td>
        <td>false</td>
        <td>Lax</td>
        <td>30min</td>
        <td>Sensitive operations</td>
      </tr>
    </tbody>
  </table>

  <h2>Security Features</h2>
  <ul>
    <li><strong>HttpOnly cookies</strong>: Prevents XSS access to session ID</li>
    <li><strong>Secure cookies</strong>: HTTPS-only in secure mode</li>
    <li><strong>SameSite policy</strong>: CSRF protection</li>
    <li><strong>Session regeneration</strong>: Prevents session fixation</li>
    <li><strong>Automatic cleanup</strong>: Expired sessions are removed</li>
  </ul>

  <h2>Storage Backends</h2>
  <ul>
    <li><strong>MemorySessionStore</strong>: Development, single-instance</li>
    <li><strong>Custom SessionStore</strong>: Implement for Redis, database, etc.</li>
  </ul>
</body>
</html>
''';
    await ctx.res.html(html);
  });

  final port = 3000;
  print('Session example server running on http://localhost:$port');
  print('');
  print('Open http://localhost:$port in your browser for documentation');
  print('');
  print('Quick test:');
  print('  # Login');
  print('  curl -c cookies.txt http://localhost:$port/login?username=alice');
  print('');
  print('  # View profile');
  print('  curl -b cookies.txt http://localhost:$port/profile');
  print('');
  print('  # Logout');
  print('  curl -b cookies.txt -c cookies.txt http://localhost:$port/logout');

  await app.start(port: port);
}
