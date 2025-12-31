# chase

> A fast, lightweight web framework for Dart inspired by [Hono](https://hono.dev/).

## Features

- **Fast** - Trie-based router for optimal performance
- **Lightweight** - Minimal dependencies, small footprint
- **Flexible Response** - Return strings, maps, or Response objects
- **Middleware** - 18+ built-in middleware, easy to extend
- **Plugin System** - Extend functionality with plugins
- **Real-time** - WebSocket, SSE, and streaming support
- **Validation** - Schema-based request validation
- **i18n** - Built-in internationalization
- **Testing** - First-class testing utilities

## Quick Example

```dart
import 'package:chase/chase.dart';

void main() async {
  final app = Chase();

  // Simple string response
  app.get('/').handle((ctx) => 'Hello, World!');

  // JSON response (auto-serialized)
  app.get('/users/:id').handle((ctx) {
    return {'id': ctx.params['id'], 'name': 'John'};
  });

  // Response object for full control
  app.post('/users').handle((ctx) async {
    final body = await ctx.req.json();
    return Response.created({'id': 1, ...body});
  });

  // Error responses
  app.get('/protected').handle((ctx) {
    if (!isAuthorized(ctx)) {
      return Response.unauthorized({'error': 'Auth required'});
    }
    return {'secret': 'data'};
  });

  await app.start(port: 6060);
}
```

## Why chase?

### Simple & Intuitive API

```dart
// Just return what you want to send
app.get('/text').handle((ctx) => 'Hello');
app.get('/json').handle((ctx) => {'message': 'Hello'});
app.get('/list').handle((ctx) => [1, 2, 3]);
```

### Powerful Middleware

```dart
app.use(Logger());
app.use(Cors());
app.use(RateLimit(limit: 100));

app.get('/admin')
  .use(JwtAuth(secret: 'secret'))
  .handle(adminHandler);
```

### Built for Performance

chase uses a trie-based router for O(k) route matching (where k is the path depth), making it significantly faster than linear route matching.

## Getting Started

Check out the [Installation](installation.md) and [Quick Start](quickstart.md) guides to begin.
