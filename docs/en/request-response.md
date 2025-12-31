# Request & Response

chase provides flexible ways to handle HTTP requests and responses.

## Response Styles

chase supports three response styles. Choose what works best for your use case.

### 1. Return Values (Recommended)

The simplest approach - just return what you want to send:

```dart
// String → text/plain
app.get('/text').handle((ctx) => 'Hello, World!');

// Map → application/json
app.get('/json').handle((ctx) => {'message': 'Hello'});

// List → application/json
app.get('/list').handle((ctx) => [1, 2, 3]);

// Other types → toString()
app.get('/number').handle((ctx) => 42);  // "42"
```

### 2. Response Class

For full control over status codes and headers:

```dart
app.get('/user/:id').handle((ctx) {
  final user = findUser(ctx.params['id']);

  if (user == null) {
    return Response.notFound({'error': 'User not found'});
  }

  return Response.ok(user);
});

app.post('/users').handle((ctx) async {
  final body = await ctx.req.json();
  final user = createUser(body);
  return Response.created(user);
});
```

### 3. Imperative Style (ctx.res)

Traditional approach using context methods:

```dart
app.get('/legacy').handle((ctx) {
  ctx.res.json({'message': 'Hello'});
});
```

## Response Class Reference

### Success Responses (2xx)

```dart
Response.ok(body)                   // 200 OK
Response.ok({'data': value})        // 200 with JSON
Response.created(body)              // 201 Created
Response.accepted(body)             // 202 Accepted
Response.noContent()                // 204 No Content
```

### Redirect Responses (3xx)

```dart
Response.movedPermanently('/new')   // 301 Moved Permanently
Response.found('/temp')             // 302 Found
Response.seeOther('/other')         // 303 See Other
Response.temporaryRedirect('/temp') // 307 Temporary Redirect
Response.permanentRedirect('/new')  // 308 Permanent Redirect
```

### Client Error Responses (4xx)

```dart
Response.badRequest(body)           // 400 Bad Request
Response.unauthorized(body)         // 401 Unauthorized
Response.forbidden(body)            // 403 Forbidden
Response.notFound(body)             // 404 Not Found
Response.methodNotAllowed(body)     // 405 Method Not Allowed
Response.conflict(body)             // 409 Conflict
Response.unprocessableEntity(body)  // 422 Unprocessable Entity
Response.tooManyRequests(body)      // 429 Too Many Requests
```

### Server Error Responses (5xx)

```dart
Response.internalServerError(body)  // 500 Internal Server Error
Response.badGateway(body)           // 502 Bad Gateway
Response.serviceUnavailable(body)   // 503 Service Unavailable
```

### Convenience Constructors

```dart
// JSON with custom status
Response.json({'key': 'value'}, status: 201)

// Text with custom status
Response.text('Hello', status: 200)

// HTML response
Response.html('<h1>Hello</h1>')

// Custom response
Response(
  418,
  body: {'message': "I'm a teapot"},
  headers: {'x-custom': 'value'},
)
```

## Request Object

### Body Parsing

```dart
app.post('/data').handle((ctx) async {
  // JSON body
  final json = await ctx.req.json();

  // Raw text
  final text = await ctx.req.text();

  // Form data
  final form = await ctx.req.formData();

  // Multipart (file uploads)
  final parts = await ctx.req.multipart();
  for (final part in parts) {
    if (part.isFile) {
      final bytes = await part.readBytes();
      // Save file...
    }
  }

  return {'received': true};
});
```

### Headers

```dart
app.get('/headers').handle((ctx) {
  // Single header
  final contentType = ctx.req.header('content-type');
  final auth = ctx.req.header('authorization');

  // All headers
  final headers = ctx.req.headers;

  return {'contentType': contentType};
});
```

### Query Parameters

```dart
// GET /search?q=dart&tag=web&tag=api
app.get('/search').handle((ctx) {
  // Single value
  final query = ctx.req.query('q');  // "dart"

  // Multiple values
  final tags = ctx.req.queryAll('tag');  // ["web", "api"]

  // All as Map
  final all = ctx.req.queries;

  return {'query': query, 'tags': tags};
});
```

### Route Parameters

```dart
// GET /users/123/posts/456
app.get('/users/:userId/posts/:postId').handle((ctx) {
  final userId = ctx.params['userId'];   // "123"
  final postId = ctx.params['postId'];   // "456"

  return {'userId': userId, 'postId': postId};
});

// Wildcard
app.get('/files/*path').handle((ctx) {
  final path = ctx.params['path'];  // "images/photo.jpg"
  return {'path': path};
});
```

### Request Info

```dart
app.all('/info').handle((ctx) {
  return {
    'method': ctx.req.method,     // "GET", "POST", etc.
    'path': ctx.req.path,         // "/info"
    'url': ctx.req.url.toString(),
  };
});
```

## Response Headers & Cookies

```dart
app.get('/custom').handle((ctx) {
  // Set headers (before sending response)
  ctx.res.headers.set('X-Custom', 'value');
  ctx.res.headers.set('X-Request-Id', generateId());

  // Set cookies
  ctx.res.cookie('session', 'abc123', maxAge: Duration(hours: 24));
  ctx.res.cookie('prefs', 'dark', httpOnly: false);

  // Delete cookie
  ctx.res.deleteCookie('old-cookie');

  return {'success': true};
});
```

## Priority

If you use both `ctx.res` methods and return a value, the first one wins:

```dart
app.get('/priority').handle((ctx) {
  ctx.res.text('First');  // ← This is sent
  return 'Second';        // ← This is ignored
});
```

This allows you to use `ctx.res` for early returns while still using return values for the main response.
