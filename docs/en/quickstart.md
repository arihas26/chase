# Quick Start

This guide will help you create your first chase application.

## Hello World

```dart
import 'package:chase/chase.dart';

void main() async {
  final app = Chase();

  app.get('/').handle((ctx) => 'Hello, World!');

  await app.start(port: 6060);
  print('Server running on http://localhost:6060');
}
```

## JSON API

```dart
void main() async {
  final app = Chase();

  // List users
  app.get('/users').handle((ctx) {
    return [
      {'id': 1, 'name': 'Alice'},
      {'id': 2, 'name': 'Bob'},
    ];
  });

  // Get user by ID
  app.get('/users/:id').handle((ctx) {
    final id = ctx.params['id'];
    return {'id': id, 'name': 'User $id'};
  });

  // Create user
  app.post('/users').handle((ctx) async {
    final body = await ctx.req.json();
    return Response.created({'id': 3, ...body});
  });

  // Update user
  app.put('/users/:id').handle((ctx) async {
    final id = ctx.params['id'];
    final body = await ctx.req.json();
    return {'id': id, ...body};
  });

  // Delete user
  app.delete('/users/:id').handle((ctx) {
    return Response.noContent();
  });

  await app.start(port: 6060);
}
```

## Adding Middleware

```dart
void main() async {
  final app = Chase();

  // Global middleware
  app.use(Logger());
  app.use(Cors());
  app.use(ExceptionHandler());

  // Route-specific middleware
  app.get('/admin')
    .use(BearerAuth(token: 'secret'))
    .handle((ctx) => {'admin': true});

  app.get('/').handle((ctx) => 'Hello!');

  await app.start(port: 6060);
}
```

## Route Groups

```dart
void main() async {
  final app = Chase();

  // API v1 routes
  app.routes('/api/v1', (v1) {
    v1.use(Logger());

    v1.routes('/users', (users) {
      users.get('/').handle(listUsers);
      users.get('/:id').handle(getUser);
      users.post('/').handle(createUser);
    });

    v1.routes('/posts', (posts) {
      posts.get('/').handle(listPosts);
      posts.post('/').handle(createPost);
    });
  });

  await app.start(port: 6060);
}
```

## Error Handling

```dart
void main() async {
  final app = Chase();

  app.use(ExceptionHandler());

  app.get('/users/:id').handle((ctx) {
    final id = ctx.params['id'];

    // Return error responses
    if (id == null) {
      return Response.badRequest({'error': 'ID is required'});
    }

    final user = findUser(id);
    if (user == null) {
      return Response.notFound({'error': 'User not found'});
    }

    return user;
  });

  await app.start(port: 6060);
}
```

## Next Steps

- Learn about [Routing](routing.md) in depth
- Explore [Middleware](middleware.md) options
- Understand [Request & Response](request-response.md) handling
