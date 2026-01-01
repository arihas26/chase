# Routing

chase uses a trie-based router for optimal performance with O(k) route matching.

## Basic Routes

```dart
final app = Chase();

// HTTP methods
app.get('/users').handle(listUsers);
app.post('/users').handle(createUser);
app.put('/users/:id').handle(updateUser);
app.patch('/users/:id').handle(patchUser);
app.delete('/users/:id').handle(deleteUser);
app.head('/users').handle(headUsers);
app.options('/users').handle(optionsUsers);

// All methods
app.route('/any', 'GET').handle(handler);
```

## Route Parameters

### Named Parameters

```dart
app.get('/users/:id').handle((ctx) {
  final id = ctx.params['id'];
  return {'id': id};
});

// Multiple parameters
app.get('/users/:userId/posts/:postId').handle((ctx) {
  final userId = ctx.params['userId'];
  final postId = ctx.params['postId'];
  return {'userId': userId, 'postId': postId};
});
```

### Wildcard Parameters

```dart
// Matches /files/any/path/here
app.get('/files/*path').handle((ctx) {
  final path = ctx.params['path'];  // "any/path/here"
  return {'path': path};
});
```

## Route Groups

### Using path()

```dart
final api = app.path('/api');
api.use(Logger());

api.get('/users').handle(listUsers);     // GET /api/users
api.post('/users').handle(createUser);   // POST /api/users
```

### Using routes()

```dart
app.routes('/api/v1', (v1) {
  v1.use(BearerAuth(token: 'secret'));

  v1.routes('/users', (users) {
    users.get('/').handle(listUsers);      // GET /api/v1/users
    users.get('/:id').handle(getUser);     // GET /api/v1/users/:id
    users.post('/').handle(createUser);    // POST /api/v1/users
    users.put('/:id').handle(updateUser);  // PUT /api/v1/users/:id
  });
});
```

### Nested Groups

```dart
final admin = app.path('/admin');
admin.use(JwtAuth(secret: 'admin-secret'));

final adminUsers = admin.path('/users');
adminUsers.get('/').handle(listAdminUsers);     // GET /admin/users
adminUsers.delete('/:id').handle(deleteUser);   // DELETE /admin/users/:id

final adminPosts = admin.path('/posts');
adminPosts.get('/').handle(listAdminPosts);     // GET /admin/posts
```

## Route-Specific Middleware

```dart
app.get('/public').handle(publicHandler);

app.get('/protected')
  .use(BearerAuth(token: 'secret'))
  .handle(protectedHandler);

app.post('/users')
  .use(RateLimit(limit: 10))
  .use(BodyLimit(maxSize: 1024 * 1024))
  .handle(createUser);
```

## Router Options

chase includes two router implementations:

### TrieRouter (Default)

Trie-based router with O(k) matching where k is path depth:

```dart
final app = Chase();  // Uses TrieRouter by default
// or explicitly:
final app = Chase(router: TrieRouter());
```

### RegexRouter

Regex-based router for complex patterns:

```dart
final app = Chase(router: RegexRouter());

// Custom regex patterns
app.get('/users/:id(\\d+)').handle((ctx) {
  // id is guaranteed to be numeric
  final id = int.parse(ctx.params['id']!);
  return {'id': id};
});
```

## Printing Routes

Enable development mode to see registered routes:

```dart
final app = Chase(dev: true);

app.get('/users').handle(listUsers);
app.post('/users').handle(createUser);

await app.start(port: 6060);
// Prints:
// GET /users
// POST /users
```

Or call printRoutes() manually:

```dart
app.printRoutes();
```
