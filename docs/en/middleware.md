# Middleware

Middleware allows you to intercept and process requests before they reach handlers.

## Using Middleware

### Global Middleware

```dart
final app = Chase();

// Single middleware
app.use(Logger());

// Multiple middleware
app.useAll([
  ExceptionHandler(),
  Cors(),
  Compress(),
]);
```

### Route-Specific Middleware

```dart
app.get('/admin')
  .use(BearerAuth(token: 'secret'))
  .handle(adminHandler);

// Chain multiple
app.post('/upload')
  .use(RateLimit(limit: 10))
  .use(BodyLimit(maxSize: 10 * 1024 * 1024))
  .handle(uploadHandler);
```

### Group Middleware

```dart
final api = app.path('/api');
api.use(Logger());
api.use(RateLimit(limit: 100));

api.get('/users').handle(listUsers);  // Has Logger + RateLimit
```

## Built-in Middleware

### Authentication

| Middleware | Description |
|------------|-------------|
| `BasicAuth` | HTTP Basic authentication |
| `BearerAuth` | Bearer token authentication |
| `JwtAuth` | JWT authentication with claims |

```dart
// Basic Auth
app.use(BasicAuth(
  username: 'admin',
  password: 'secret',
));

// Bearer Auth
app.use(BearerAuth(
  token: 'my-api-token',
));

// JWT Auth
app.use(JwtAuth(
  secret: 'jwt-secret',
  algorithms: ['HS256'],
));
```

### Security

| Middleware | Description |
|------------|-------------|
| `Cors` | Cross-Origin Resource Sharing |
| `Csrf` | CSRF protection |
| `SecureHeaders` | Security headers (CSP, HSTS, etc.) |
| `RateLimit` | Request rate limiting |
| `BodyLimit` | Request body size limit |

```dart
// CORS
app.use(Cors(
  origins: ['https://example.com'],
  methods: ['GET', 'POST'],
  headers: ['Content-Type', 'Authorization'],
));

// Rate limiting
app.use(RateLimit(
  limit: 100,
  window: Duration(minutes: 1),
));

// Body size limit
app.use(BodyLimit(maxSize: 1024 * 1024));  // 1MB
```

### Performance

| Middleware | Description |
|------------|-------------|
| `Compress` | Gzip/Deflate compression |
| `CacheControl` | Cache-Control headers |
| `ETag` | Entity tags for caching |
| `Timeout` | Request timeout |

```dart
// Compression
app.use(Compress());

// Cache control
app.use(CacheControl(maxAge: Duration(hours: 1)));

// ETag
app.use(ETag());

// Timeout
app.use(Timeout(duration: Duration(seconds: 30)));
```

### Utilities

| Middleware | Description |
|------------|-------------|
| `Logger` | Request/response logging |
| `RequestId` | Unique request ID |
| `ExceptionHandler` | Error handling |
| `Session` | Session management |
| `I18n` | Internationalization |
| `Validator` | Request validation |
| `Proxy` | HTTP proxy |
| `StaticFileHandler` | Static file serving |

```dart
// Logger
app.use(Logger());

// Request ID
app.use(RequestId());

// Exception handler
app.use(ExceptionHandler());
```

## Custom Middleware

```dart
class TimingMiddleware implements Middleware {
  @override
  FutureOr<void> handle(Context ctx, NextFunction next) async {
    final stopwatch = Stopwatch()..start();

    await next();  // Call next middleware/handler

    print('${ctx.req.method} ${ctx.req.path} - ${stopwatch.elapsedMilliseconds}ms');
  }
}

app.use(TimingMiddleware());
```

### Middleware with Configuration

```dart
class RateLimitMiddleware implements Middleware {
  final int limit;
  final Duration window;
  final Map<String, List<DateTime>> _requests = {};

  RateLimitMiddleware({
    this.limit = 100,
    this.window = const Duration(minutes: 1),
  });

  @override
  FutureOr<void> handle(Context ctx, NextFunction next) async {
    final ip = ctx.req.ip;
    final now = DateTime.now();

    _requests[ip] = (_requests[ip] ?? [])
      .where((t) => now.difference(t) < window)
      .toList()
      ..add(now);

    if (_requests[ip]!.length > limit) {
      return Response.tooManyRequests({'error': 'Rate limit exceeded'});
    }

    await next();
  }
}
```

### Early Return from Middleware

```dart
class AuthMiddleware implements Middleware {
  @override
  FutureOr<void> handle(Context ctx, NextFunction next) async {
    final token = ctx.req.header('Authorization');

    if (token == null) {
      // Return early - handler won't be called
      ctx.res.json({'error': 'Unauthorized'}, status: 401);
      return;
    }

    final user = await validateToken(token);
    if (user == null) {
      ctx.res.json({'error': 'Invalid token'}, status: 401);
      return;
    }

    // Store user for handler to access
    ctx.set('user', user);

    await next();  // Continue to handler
  }
}
```

## Middleware Order

Middleware executes in the order it's added:

```dart
app.use(Logger());        // 1. First
app.use(Cors());          // 2. Second
app.use(RateLimit());     // 3. Third

// Request flow:
// Logger → Cors → RateLimit → Handler → RateLimit → Cors → Logger
```
