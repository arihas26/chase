<p align="center">
  <img src="assets/chase-logo.png" alt="Chase Logo" width="400">
</p>

<p align="center">
  A fast, lightweight web framework for Dart.
</p>

<p align="center">
  <a href="https://dart.dev"><img src="https://img.shields.io/badge/Dart-3.10+-blue.svg" alt="Dart"></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT"></a>
</p>

<p align="center">
  <a href="../../README.md">English</a>
  <a href="docs/ja/README.md">日本語</a>
</p>

## Features

- 🚀 **Fast** - Trie-based router for optimal performance
- 🪶 **Lightweight** - Minimal dependencies, small footprint
- 🧩 **Middleware** - 18+ built-in middleware, easy to extend
- 🔌 **Plugin System** - Extend functionality with plugins
- 🌐 **Real-time** - WebSocket, SSE, and streaming support
- ✅ **Validation** - Schema-based request validation
- 🌍 **i18n** - Built-in internationalization
- 🧪 **Testing** - First-class testing utilities

## Performance

<p align="center">
  <img src="assets/benchmark-result.png" alt="Benchmark Results" width="600">
</p>

<p align="center">
  <a href="docs/en/benchmarks.md">View detailed benchmarks</a>
</p>

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Routing](#routing)
- [Middleware](#middleware)
- [Request & Response](#request--response)
- [Validation](#validation)
- [Route Groups](#route-groups)
- [WebSocket](#websocket)
- [Server-Sent Events](#server-sent-events)
- [Streaming](#streaming)
- [Static Files](#static-files)
- [Session](#session)
- [Internationalization](#internationalization)
- [Testing](#testing)
- [Plugins](#plugins)

## Installation

```yaml
dependencies:
  chase: ^0.1.0
```

## Quick Start

```dart
import 'package:chase/chase.dart';

void main() async {
  final app = Chase();

  // Simple string response
  app.get('/').handle((ctx) => 'Hello, World!');

  // JSON response (return Map directly)
  app.get('/hello/:name').handle((ctx) {
    final name = ctx.req.param('name');
    return {'message': 'Hello, $name!'};
  });

  // With status code (Response fluent API)
  app.post('/users').handle((ctx) async {
    final body = await ctx.req.json();
    return Response.created().json({'id': 1, ...body});
  });

  // Response object for full control
  app.get('/users/:id').handle((ctx) {
    return Response.ok().json({'id': ctx.req.param('id'), 'name': 'John'});
  });

  await app.start(port: 6060);
}
```

## Routing

### Basic Routes

```dart
final app = Chase();

// HTTP methods
app.get('/users').handle((ctx) => {'users': []});
app.post('/users').handle(createUser);
app.put('/users/:id').handle(updateUser);
app.patch('/users/:id').handle(patchUser);
app.delete('/users/:id').handle(deleteUser);
app.head('/users/:id').handle(checkUser);
app.options('/users').handle(corsHandler);

// Custom method
app.route('CUSTOM', '/any').handle((ctx) => 'Custom method');
```

### Route Parameters

```dart
// Single parameter
app.get('/users/:id').handle((ctx) {
  final id = ctx.req.param('id');
  return {'id': id};
});

// Multiple parameters
app.get('/users/:userId/posts/:postId').handle((ctx) {
  final userId = ctx.req.param('userId');
  final postId = ctx.req.param('postId');
  return {'userId': userId, 'postId': postId};
});

// Wildcard (catch-all)
app.get('/files/*path').handle((ctx) {
  final path = ctx.req.param('path');  // e.g., "images/photo.jpg"
  return 'File: $path';
});

// Optional parameter
app.get('/users/:id?').handle((ctx) {
  final id = ctx.req.param('id');  // null if not provided
  // Matches both /users and /users/123
});

// Optional with other parameters
app.get('/posts/:postId/comments/:commentId?').handle((ctx) {
  final postId = ctx.req.param('postId');      // Required
  final commentId = ctx.req.param('commentId'); // Optional
  // Matches /posts/1/comments and /posts/1/comments/2
});
```

### Query Parameters

```dart
app.get('/search').handle((ctx) {
  final query = ctx.req.query('q');           // Single value
  final tags = ctx.req.queryAll('tag');       // Multiple values
  final queries = ctx.req.queries;            // All as Map
  return {'query': query, 'tags': tags};
});
```

### Multiple Paths

Register the same handler for multiple paths:

```dart
// Same handler for multiple paths
app.get(['/hello', '/ja/hello']).handle((ctx) {
  return 'Hello!';
});

// Works with all HTTP methods
app.post(['/submit', '/api/submit']).handle(submitHandler);
app.put(['/update', '/api/update']).handle(updateHandler);

// With middleware
app.get(['/a', '/b', '/c'])
  .use(AuthMiddleware())
  .handle(handler);

// With path parameters
app.get(['/users/:id', '/members/:id']).handle((ctx) {
  final id = ctx.req.param('id');
  return {'id': id};
});

// all() and on() also support multiple paths
app.all(['/any', '/v1/any']).handle(anyHandler);
app.on(['GET', 'POST'], ['/form', '/api/form']).handle(formHandler);
```

## Middleware

### Using Middleware

```dart
// Global middleware
app.use(ExceptionHandler());
app.use(Logger());

// Multiple at once
app.useAll([Cors(), Compress()]);

// Route-specific
app.get('/admin')
  .use(BearerAuth(token: 'secret'))
  .handle(adminHandler);

// Chain multiple
app.post('/api/data')
  .use(RateLimit(limit: 100))
  .use(BodyLimit(maxSize: 1024 * 1024))
  .handle(dataHandler);
```

### Built-in Middleware

| Middleware | Description |
|------------|-------------|
| **Authentication** | |
| `BasicAuth` | HTTP Basic authentication |
| `BearerAuth` | Bearer token authentication |
| `JwtAuth` | JWT authentication with claims |
| **Security** | |
| `Cors` | Cross-Origin Resource Sharing |
| `Csrf` | CSRF protection with tokens |
| `SecureHeaders` | Security headers (CSP, HSTS, etc.) |
| `RateLimit` | Request rate limiting |
| `BodyLimit` | Request body size limit |
| `IpRestriction` | IP-based access control |
| **Performance** | |
| `Compress` | Gzip/Deflate compression |
| `CacheControl` | Cache-Control headers |
| `ETag` | Entity tag for caching |
| `Timeout` | Request timeout handling |
| `Timing` | Server-Timing headers for performance monitoring |
| **Utilities** | |
| `Logger` | Request/response logging |
| `RequestId` | Unique request ID generation |
| `ExceptionHandler` | Error handling |
| `Session` | Session management |
| `I18n` | Internationalization |
| `Validator` | Request validation |
| `Proxy` | HTTP proxy |
| `StaticFileHandler` | Static file serving |
| `PrettyJson` | Format JSON with indentation |
| `TrailingSlash` | Normalize trailing slashes (trim/append) |

### Custom Middleware

```dart
class TimingMiddleware implements Middleware {
  @override
  FutureOr<void> handle(Context ctx, NextFunction next) async {
    final sw = Stopwatch()..start();
    await next();
    print('${ctx.req.method} ${ctx.req.path} - ${sw.elapsedMilliseconds}ms');
  }
}

app.use(TimingMiddleware());
```

## Request & Response

### Request

```dart
app.post('/users').handle((ctx) async {
  // Body
  final json = await ctx.req.json();           // JSON body
  final text = await ctx.req.text();           // Raw text
  final form = await ctx.req.formData();       // Form data
  final multipart = await ctx.req.multipart(); // Multipart

  // Headers
  final contentType = ctx.req.header('content-type');
  final headers = ctx.req.headers;

  // Request info
  final method = ctx.req.method;
  final path = ctx.req.path;
  final url = ctx.req.url;

  return {'received': json};
});
```

#### Content Negotiation

```dart
app.get('/data').handle((ctx) {
  // Accept header negotiation
  final type = ctx.req.accepts(['json', 'html', 'xml'], defaultValue: 'json');

  if (type == 'html') {
    return Response.html('<h1>Data</h1>');
  }
  return {'data': 'value'};
});

// Language negotiation
final lang = ctx.req.acceptsLanguages(['en', 'ja', 'zh'], defaultValue: 'en');

// Encoding negotiation
final encoding = ctx.req.acceptsEncodings(['gzip', 'br'], defaultValue: 'identity');
```

#### Connection Info

```dart
app.get('/info').handle((ctx) {
  final info = ctx.req.connInfo;

  return {
    'remoteAddress': info.remote.address,  // Client IP
    'remotePort': info.remote.port,        // Client port
    'addressType': info.remote.addressType?.name,  // 'ipv4' or 'ipv6'
    'localPort': info.local.port,          // Server port
  };
});

// Shorthand accessors also available
final ip = ctx.req.ip;              // With X-Forwarded-For support
final addr = ctx.req.remoteAddress; // Direct connection IP
```

### Response

Chase supports multiple response styles - from simple return values to Response objects.

#### Simple Return Values (Recommended)

```dart
// String → text/plain
app.get('/text').handle((ctx) => 'Hello, World!');

// Map → application/json
app.get('/json').handle((ctx) => {'message': 'Hello'});

// List → application/json
app.get('/list').handle((ctx) => [1, 2, 3]);

// Response object → full control
app.get('/custom').handle((ctx) => Response.ok().json({'status': 'success'}));
```

#### Response Fluent API

```dart
// JSON response with status
app.post('/users').handle((ctx) => Response.created().json({'id': 1}));

// With custom headers (chainable)
app.get('/data').handle((ctx) {
  return Response.ok()
    .header('X-Custom', 'value')
    .json({'data': 'value'});
});

// HTML response
app.get('/html').handle((ctx) => Response.html('<h1>Hello</h1>'));

// Text response
app.get('/text').handle((ctx) => Response.text('Hello, World!'));

// Redirect
app.get('/old').handle((ctx) => Response.redirect('/new'));

// Not found
app.get('/missing').handle((ctx) => Response.notFound('Resource not found'));
```

#### Response Class

```dart
// Success responses (2xx)
Response.ok().text('Hello')             // 200 text
Response.ok().json({'data': value})     // 200 JSON
Response.created().json({'id': 1})      // 201
Response.noContent()                    // 204
Response.accepted().json({'status': 'pending'}) // 202

// Redirects (3xx)
Response.movedPermanently('/new')       // 301
Response.redirect('/temp')              // 302
Response.seeOther('/other')             // 303
Response.temporaryRedirect('/temp')     // 307
Response.permanentRedirect('/new')      // 308

// Client errors (4xx)
Response.badRequest().json({'error': 'Invalid'})   // 400
Response.unauthorized()                             // 401
Response.forbidden()                                // 403
Response.notFound().json({'error': 'Not found'})   // 404
Response.conflict()                                 // 409
Response.unprocessableEntity().json({'errors': []}) // 422
Response.tooManyRequests()                          // 429

// Server errors (5xx)
Response.internalServerError()          // 500
Response.badGateway()                   // 502
Response.serviceUnavailable()           // 503

// Convenience factories (return Response directly)
Response.json({'key': 'value'}, status: 201)
Response.text('Hello', status: 200)
Response.html('<h1>Hello</h1>')
```

#### Low-Level Access (ctx.res)

For advanced use cases, you can still access the underlying `HttpResponse`:

```dart
app.get('/low-level').handle((ctx) async {
  // Direct header access
  ctx.res.headers.set('X-Custom', 'value');
  
  // Cookies
  ctx.res.cookie('session', 'abc123', maxAge: Duration(hours: 24));
  ctx.res.deleteCookie('session');
  
  // Status code
  ctx.res.statusCode = 200;
  
  // Write directly
  ctx.res.write('Hello');
  await ctx.res.close();
});
```

## Validation

chase provides a powerful schema-based validation system.

### Schema Definition

```dart
final userSchema = Schema({
  'name': V.isString().required().min(2).max(50),
  'email': V.isString().required().email(),
  'age': V.isInt().min(0).max(150),
  'role': V.isString().oneOf(['admin', 'user', 'guest']),
  'tags': V.list().min(1).max(10),
  'active': V.isBool().defaultValue(true),
});
```

### Validator Middleware

```dart
app.post('/users')
  .use(Validator(body: userSchema))
  .handle((ctx) {
    // Access validated & transformed data
    final data = ctx.validatedBody!;
    return Response.created().json({'created': data});
  });
```

### Validate Query & Params

```dart
final querySchema = Schema({
  'page': V.isInt().defaultValue(1).min(1),
  'limit': V.isInt().defaultValue(20).max(100),
  'sort': V.isString().oneOf(['asc', 'desc']).defaultValue('desc'),
});

final paramsSchema = Schema({
  'id': V.isInt().required().min(1),
});

app.get('/users/:id/posts')
  .use(Validator(query: querySchema, params: paramsSchema))
  .handle((ctx) {
    final page = ctx.validatedQuery!['page'];
    final userId = ctx.validatedParams!['id'];
    // ...
  });
```

### Available Validators

```dart
// Type validators
V.isString()     // String validation
V.isInt()        // Integer (auto-parses strings)
V.isDouble()     // Double/number
V.isBool()       // Boolean (accepts "true", "1", etc.)
V.list()         // Array/List
V.map()          // Object/Map
V.any()          // Any type

// String rules
V.isString()
  .required()                    // Must not be null or empty
  .min(5)                        // Minimum length
  .max(100)                      // Maximum length
  .length(10)                    // Exact length
  .email()                       // Email format
  .url()                         // URL format
  .pattern(RegExp(r'^\d+$'))     // Custom regex
  .oneOf(['a', 'b', 'c'])        // Allowed values

// Number rules
V.isInt()
  .required()
  .min(0)                        // Minimum value
  .max(100)                      // Maximum value

// Custom validation
V.isString().custom(
  (value) => value.startsWith('A'),
  message: 'Must start with A',
)

// Default values
V.isString().defaultValue('guest')
```

### Manual Validation

```dart
final schema = Schema({
  'email': V.isString().required().email(),
});

final result = schema.validate({'email': 'invalid'});
if (!result.isValid) {
  for (final error in result.errors) {
    print('${error.field}: ${error.message}');
  }
}
```

## Route Groups

```dart
// Using path()
final api = app.path('/api');
api.use(BearerAuth(token: 'secret'));
api.get('/users').handle(getUsers);
api.post('/users').handle(createUser);

// Using routes() callback
app.routes('/api/v1', (v1) {
  v1.use(Logger());
  
  v1.routes('/users', (users) {
    users.get('/').handle(listUsers);
    users.get('/:id').handle(getUser);
    users.post('/').handle(createUser);
  });
});

// Nested groups
final admin = app.path('/admin');
admin.use(JwtAuth(secret: 'secret'));

final adminUsers = admin.path('/users');
adminUsers.get('/').handle(listAdminUsers);
```

## WebSocket

```dart
app.get('/ws').handle((ctx) async {
  final ws = await ctx.req.upgrade();
  
  ws.onMessage((message) {
    print('Received: $message');
    ws.send('Echo: $message');
  });
  
  ws.onClose((code, reason) {
    print('Closed: $code $reason');
  });
  
  ws.onError((error) {
    print('Error: $error');
  });
});
```

## Server-Sent Events

```dart
app.get('/events').handle((ctx) {
  return streamSSE(ctx, (stream) async {
    // Send events
    await stream.writeSSE(SSEMessage(
      data: '{"count": 1}',
      event: 'update',
    ));
    
    await stream.writeSSE(SSEMessage(
      data: '{"count": 2}',
      event: 'update',
      id: '2',
    ));
    
    // Real-time updates
    for (var i = 0; i < 10; i++) {
      await stream.sleep(Duration(seconds: 1));
      await stream.writeSSE(SSEMessage(
        data: DateTime.now().toIso8601String(),
      ));
    }
  });
});
```

## Streaming

Chase provides Hono-style streaming helpers that return `Response` objects.

### Text Streaming

```dart
app.get('/stream').handle((ctx) {
  return streamText(ctx, (stream) async {
    for (var i = 0; i < 10; i++) {
      await stream.writeln('Line $i');
      await stream.sleep(Duration(milliseconds: 100));
    }
  });
});
```

### Binary Streaming

```dart
app.get('/download').handle((ctx) {
  return stream(ctx, (s) async {
    final file = File('large-file.zip');
    await s.pipe(file.openRead());
  }, headers: {
    'content-disposition': 'attachment; filename="file.zip"',
  });
});
```

### Streaming with Abort Handling

```dart
app.get('/long-stream').handle((ctx) {
  return streamText(ctx, (stream) async {
    stream.onAbort(() {
      print('Client disconnected');
    });
    
    while (!stream.isClosed) {
      await stream.writeln(DateTime.now().toIso8601String());
      await stream.sleep(Duration(seconds: 1));
    }
  });
});
```

## Static Files

```dart
// Basic usage
app.staticFiles('/static', './public');

// With options
app.staticFiles('/assets', './public', StaticOptions(
  maxAge: Duration(days: 365),
  etag: true,
  index: ['index.html'],
  dotFiles: DotFiles.ignore,
));

// Or use middleware directly
app.get('/files/*path')
  .use(StaticFileHandler('./uploads'))
  .handle((ctx) => ctx.res.notFound());
```

## Session

```dart
// Add session middleware
app.use(Session(
  store: MemorySessionStore(),
  cookieName: 'session_id',
  maxAge: Duration(hours: 24),
));

// Use sessions
app.post('/login').handle((ctx) async {
  final body = await ctx.req.json();
  ctx.session['userId'] = body['userId'];
  ctx.session['loggedIn'] = true;
  return {'success': true};
});

app.get('/profile').handle((ctx) {
  if (ctx.session['loggedIn'] != true) {
    return Response.unauthorized().json({'error': 'Not logged in'});
  }
  return {'userId': ctx.session['userId']};
});

app.post('/logout').handle((ctx) async {
  await ctx.destroySession();
  return {'success': true};
});
```

## Internationalization

### Setup

```dart
// Load translations
final translations = I18nTranslations.fromMap({
  'en': {
    'greeting': 'Hello',
    'welcome': 'Welcome, {name}!',
  },
  'ja': {
    'greeting': 'こんにちは',
    'welcome': 'ようこそ、{name}さん！',
  },
});

// Add middleware
app.use(I18n(
  translations: translations,
  defaultLocale: 'en',
  supportedLocales: ['en', 'ja', 'ko'],
));
```

### Usage

```dart
app.get('/greeting').handle((ctx) {
  final t = ctx.t;  // Translation function
  
  return {
    'greeting': t('greeting'),
    'welcome': t('welcome', {'name': 'John'}),
    'locale': ctx.locale,
  };
});
```

### Locale Detection

Locale is detected in order:
1. Query parameter: `?lang=ja`
2. Accept-Language header
3. Default locale

```dart
// Force specific locale
app.get('/ja/greeting').handle((ctx) {
  ctx.setLocale('ja');
  return {'message': ctx.t('greeting')};
});
```

## Testing

chase provides comprehensive testing utilities.

### TestClient

```dart
import 'package:chase/chase.dart';
import 'package:chase/testing/testing.dart';
import 'package:test/test.dart';

void main() {
  late Chase app;
  late TestClient client;

  setUp(() async {
    app = Chase();
    app.get('/').handle((ctx) => 'Hello');
    app.post('/users').handle((ctx) async {
      final body = await ctx.req.json();
      return Response.created().json(body);
    });
    
    client = await TestClient.start(app);
  });

  tearDown(() => client.close());

  test('GET request', () async {
    final res = await client.get('/');
    expect(res, isOkResponse);
    expect(await res.body, 'Hello');
  });

  test('POST JSON', () async {
    final res = await client.postJson('/users', {'name': 'John'});
    expect(res, hasStatus(201));
    expect(await res.json, hasJsonPath('name', 'John'));
  });
}
```

### Custom Matchers

```dart
// Status matchers
expect(res, isOkResponse);           // 2xx
expect(res, isRedirectResponse);     // 3xx
expect(res, isClientErrorResponse);  // 4xx
expect(res, isServerErrorResponse);  // 5xx
expect(res, hasStatus(201));         // Exact status

// Header matchers
expect(res, hasHeader('content-type'));
expect(res, hasHeader('content-type', 'application/json'));
expect(res, hasHeader('content-type', contains('json')));
expect(res, hasContentType('application/json'));

// JSON matchers
final json = await res.json;
expect(json, hasJsonPath('user.name', 'John'));
expect(json, hasJsonPath('items', hasLength(3)));
expect(json, hasJsonPath('data.tags', ['a', 'b']));

// Cookie matchers
expect(res, hasCookie('session'));
expect(res, hasCookie('token', 'abc123'));
```

### TestClient Extensions

```dart
// Auth helper
final res = await client.getWithAuth('/profile', 'my-token');

// JSON POST helper
final res = await client.postJson('/users', {'name': 'John'});
final res = await client.postJson('/users', {'name': 'John'}, token: 'secret');
```

### Unit Testing with TestContext

```dart
test('middleware behavior', () async {
  final ctx = TestContext.get('/api/users', headers: {
    'Authorization': 'Bearer token123',
  });
  
  var nextCalled = false;
  await myMiddleware.handle(ctx, () async {
    nextCalled = true;
  });
  
  expect(nextCalled, isTrue);
  expect(ctx.res.statusCode, 200);
});
```

## Plugins

### Using Plugins

```dart
final app = Chase()
  ..plugin(HealthCheckPlugin())
  ..plugin(MetricsPlugin());
```

### Creating Plugins

```dart
class HealthCheckPlugin extends Plugin {
  @override
  String get name => 'health-check';

  @override
  void onInstall(Chase app) {
    app.get('/health').handle((ctx) {
      return {
        'status': 'healthy',
        'timestamp': DateTime.now().toIso8601String(),
      };
    });
  }

  @override
  Future<void> onStart(Chase app) async {
    print('Health check endpoint ready');
  }

  @override
  Future<void> onStop(Chase app) async {
    print('Shutting down health check');
  }
}
```

## Context Store

Share data between middleware and handlers:

```dart
// Middleware sets data
class AuthMiddleware implements Middleware {
  @override
  FutureOr<void> handle(Context ctx, NextFunction next) async {
    final user = await validateToken(ctx.req.header('Authorization'));
    ctx.set('user', user);
    ctx.set('requestId', generateId());
    await next();
  }
}

// Handler retrieves data
app.get('/profile').handle((ctx) {
  final user = ctx.get<User>('user');
  final requestId = ctx.get<String>('requestId');
  
  if (ctx.has('user')) {
    return {'user': user, 'requestId': requestId};
  }
  return Response.unauthorized().json({'error': 'Unauthorized'});
});
```

## Method Override

HTML forms only support GET and POST. Method Override allows forms to simulate PUT, PATCH, and DELETE requests.

```dart
// Enable method override (default: form field "_method")
final app = Chase()..methodOverride();

// Custom configuration
final app = Chase()
  ..methodOverride(
    form: '_method',            // Form field name (default)
    header: 'X-HTTP-Method',    // Header name
    query: '_method',           // Query parameter name
  );

// Now handles DELETE from form
app.delete('/posts/:id').handle((ctx) {
  return {'deleted': ctx.req.param('id')};
});
```

```html
<form action="/posts/123" method="POST">
  <input type="hidden" name="_method" value="DELETE" />
  <button type="submit">Delete</button>
</form>
```

## Server Configuration

```dart
// Development mode (prints routes)
final app = Chase(dev: true);

// Custom router
final app = Chase(router: TrieRouter());  // Default, trie-based (fast)
final app2 = Chase(router: RegexRouter()); // Regex-based (flexible)

// Start options
await app.start(port: 6060);
await app.start(host: '0.0.0.0', port: 8080);
await app.start(shared: true);  // Multi-isolate support

// Server info
print(app.isRunning);
print(app.server?.port);

// Graceful shutdown
await app.stop();
await app.stop(force: true);
```

## Convenience Setup

```dart
// Add common middleware stack
final app = Chase()..withDefaults();

// Equivalent to:
final app = Chase()
  ..use(ExceptionHandler())
  ..use(Logger());
```

## Examples

See the [example](example/) directory for more examples:

- [WebSocket](example/example_websocket.dart)
- [SSE](example/example_sse.dart)
- [Streaming](example/example_streaming.dart)
- [Rate Limiting](example/example_rate_limit.dart)
- [Session](example/example_session.dart)
- [ETag](example/example_etag.dart)
- [Timeout](example/example_timeout.dart)
- [Body Limit](example/example_body_limit.dart)
- [Secure Headers](example/example_secure_headers.dart)
- [Request ID](example/example_request_id.dart)

## License

MIT License - see [LICENSE](LICENSE) file for details.
