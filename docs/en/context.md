# Context

The `Context` object provides access to request, response, and shared data.

## Overview

```dart
app.get('/example').handle((ctx) {
  // Request access
  final method = ctx.req.method;
  final path = ctx.req.path;

  // Route parameters
  final id = ctx.params['id'];

  // Response (imperative style)
  ctx.res.json({'message': 'Hello'});

  // Or return a value
  return {'message': 'Hello'};
});
```

## Properties

| Property | Type | Description |
|----------|------|-------------|
| `req` | `Request` | HTTP request wrapper |
| `res` | `Response` | HTTP response wrapper |
| `params` | `Map<String, String>?` | Route parameters |

## Context Store

Share data between middleware and handlers:

```dart
// Middleware stores data
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

  return Response.unauthorized();
});
```

### Store Methods

```dart
// Set a value
ctx.set('key', value);

// Get a value (typed)
final user = ctx.get<User>('user');
final count = ctx.get<int>('count');

// Check if key exists
if (ctx.has('user')) {
  // ...
}
```

## Session

When using Session middleware:

```dart
app.use(Session(store: MemorySessionStore()));

app.post('/login').handle((ctx) async {
  ctx.session['userId'] = 123;
  ctx.session['loggedIn'] = true;
  return {'success': true};
});

app.get('/profile').handle((ctx) {
  if (ctx.session['loggedIn'] != true) {
    return Response.unauthorized();
  }
  return {'userId': ctx.session['userId']};
});

app.post('/logout').handle((ctx) async {
  await ctx.destroySession();
  return {'success': true};
});
```

## Internationalization

When using I18n middleware:

```dart
app.use(I18n(translations: translations));

app.get('/greeting').handle((ctx) {
  // Translation function
  final greeting = ctx.t('greeting');
  final welcome = ctx.t('welcome', {'name': 'John'});

  // Current locale
  final locale = ctx.locale;

  // Change locale
  ctx.setLocale('ja');

  return {'greeting': greeting, 'locale': locale};
});
```

## Validation

When using Validator middleware:

```dart
app.post('/users')
  .use(Validator(body: userSchema))
  .handle((ctx) {
    // Access validated data
    final body = ctx.validatedBody!;
    final query = ctx.validatedQuery;
    final params = ctx.validatedParams;

    return Response.created(body);
  });
```
