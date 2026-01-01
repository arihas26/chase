# Testing

chase provides comprehensive testing utilities for unit and integration testing.

## Setup

```dart
import 'package:chase/chase.dart';
import 'package:chase/testing/testing.dart';
import 'package:test/test.dart';
```

## TestClient

TestClient starts your app and provides HTTP client methods:

```dart
void main() {
  late Chase app;
  late TestClient client;

  setUp(() async {
    app = Chase();
    app.get('/').handle((ctx) => 'Hello');
    app.post('/users').handle((ctx) async {
      final body = await ctx.req.json();
      return Response.created(body);
    });

    client = await TestClient.start(app);
  });

  tearDown(() => client.close());

  test('GET request', () async {
    final res = await client.get('/');
    expect(res.status, 200);
    expect(await res.body, 'Hello');
  });

  test('POST request', () async {
    final res = await client.post('/users',
      body: '{"name": "John"}',
      headers: {'content-type': 'application/json'},
    );
    expect(res.status, 201);
  });
}
```

## HTTP Methods

```dart
// GET
final res = await client.get('/users');

// POST
final res = await client.post('/users', body: jsonEncode(data));

// PUT
final res = await client.put('/users/1', body: jsonEncode(data));

// PATCH
final res = await client.patch('/users/1', body: jsonEncode(data));

// DELETE
final res = await client.delete('/users/1');

// Custom request
final res = await client.request('OPTIONS', '/users');
```

## Helper Extensions

```dart
// GET with auth
final res = await client.getWithAuth('/profile', 'my-token');
// Adds header: Authorization: Bearer my-token

// POST JSON
final res = await client.postJson('/users', {'name': 'John'});
// Sets content-type and encodes body

// POST JSON with auth
final res = await client.postJson('/users', {'name': 'John'}, token: 'secret');
```

## Matchers

### Status Matchers

```dart
expect(res, isOkResponse);           // 2xx
expect(res, isRedirectResponse);     // 3xx
expect(res, isClientErrorResponse);  // 4xx
expect(res, isServerErrorResponse);  // 5xx
expect(res, hasStatus(201));         // Exact status
```

### Header Matchers

```dart
expect(res, hasHeader('content-type'));
expect(res, hasHeader('content-type', 'application/json'));
expect(res, hasHeader('content-type', contains('json')));
expect(res, hasContentType('application/json'));
```

### JSON Matchers

```dart
final json = await res.json;
expect(json, hasJsonPath('user.name', 'John'));
expect(json, hasJsonPath('items', hasLength(3)));
expect(json, hasJsonPath('data.tags', contains('dart')));
```

### Cookie Matchers

```dart
expect(res, hasCookie('session'));
expect(res, hasCookie('token', 'abc123'));
```

## TestContext

For unit testing handlers and middleware without HTTP:

```dart
test('handler returns user', () async {
  final ctx = TestContext.get('/users/123');

  await myHandler(ctx);

  final response = ctx.response;
  expect(response.statusCode, 200);
  expect(response.body, contains('123'));
});

test('middleware sets header', () async {
  final ctx = TestContext.get('/');

  var nextCalled = false;
  await myMiddleware.handle(ctx, () async {
    nextCalled = true;
  });

  expect(nextCalled, isTrue);
  expect(ctx.response.headers['x-custom'], isNotNull);
});
```

### Creating Test Contexts

```dart
// GET request
final ctx = TestContext.get('/path');

// POST with body
final ctx = TestContext.post('/path', body: {'key': 'value'});

// With headers
final ctx = TestContext.get('/path', headers: {
  'Authorization': 'Bearer token',
});

// With query params
final ctx = TestContext.get('/search?q=dart');

// Custom
final ctx = TestContext.create(
  method: 'PATCH',
  path: '/users/1',
  body: {'name': 'Updated'},
);
```

## Integration Tests

```dart
void main() {
  late Chase app;
  late TestClient client;

  setUpAll(() async {
    app = Chase();
    app.use(Logger());
    app.use(RateLimit(limit: 100));

    app.routes('/api', (api) {
      api.get('/users').handle(listUsers);
      api.post('/users').handle(createUser);
    });

    client = await TestClient.start(app);
  });

  tearDownAll(() => client.close());

  group('Users API', () {
    test('list users', () async {
      final res = await client.get('/api/users');
      expect(res, isOkResponse);
      expect(await res.json, isList);
    });

    test('create user', () async {
      final res = await client.postJson('/api/users', {
        'name': 'John',
        'email': 'john@example.com',
      });
      expect(res, hasStatus(201));
      expect(await res.json, hasJsonPath('id', isNotNull));
    });

    test('rate limit', () async {
      // Make many requests quickly
      for (var i = 0; i < 110; i++) {
        await client.get('/api/users');
      }

      final res = await client.get('/api/users');
      expect(res, hasStatus(429));
    });
  });
}
```
