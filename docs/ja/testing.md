# テスト

chase はユニットテストと統合テストのための包括的なテストユーティリティを提供します。

## セットアップ

```dart
import 'package:chase/chase.dart';
import 'package:chase/testing/testing.dart';
import 'package:test/test.dart';
```

## TestClient

TestClient はアプリを起動し、HTTP クライアントメソッドを提供します:

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

  test('GET リクエスト', () async {
    final res = await client.get('/');
    expect(res.status, 200);
    expect(await res.body, 'Hello');
  });

  test('POST リクエスト', () async {
    final res = await client.post('/users',
      body: '{"name": "John"}',
      headers: {'content-type': 'application/json'},
    );
    expect(res.status, 201);
  });
}
```

## HTTP メソッド

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

// カスタムリクエスト
final res = await client.request('OPTIONS', '/users');
```

## ヘルパー拡張

```dart
// 認証付きGET
final res = await client.getWithAuth('/profile', 'my-token');
// ヘッダー追加: Authorization: Bearer my-token

// JSON POST
final res = await client.postJson('/users', {'name': 'John'});
// content-type を設定し、ボディをエンコード

// 認証付き JSON POST
final res = await client.postJson('/users', {'name': 'John'}, token: 'secret');
```

## マッチャー

### ステータスマッチャー

```dart
expect(res, isOkResponse);           // 2xx
expect(res, isRedirectResponse);     // 3xx
expect(res, isClientErrorResponse);  // 4xx
expect(res, isServerErrorResponse);  // 5xx
expect(res, hasStatus(201));         // 正確なステータス
```

### ヘッダーマッチャー

```dart
expect(res, hasHeader('content-type'));
expect(res, hasHeader('content-type', 'application/json'));
expect(res, hasHeader('content-type', contains('json')));
expect(res, hasContentType('application/json'));
```

### JSON マッチャー

```dart
final json = await res.json;
expect(json, hasJsonPath('user.name', 'John'));
expect(json, hasJsonPath('items', hasLength(3)));
expect(json, hasJsonPath('data.tags', contains('dart')));
```

### クッキーマッチャー

```dart
expect(res, hasCookie('session'));
expect(res, hasCookie('token', 'abc123'));
```

## TestContext

HTTP なしでハンドラやミドルウェアをユニットテスト:

```dart
test('ハンドラがユーザーを返す', () async {
  final ctx = TestContext.get('/users/123');

  await myHandler(ctx);

  final response = ctx.response;
  expect(response.statusCode, 200);
  expect(response.body, contains('123'));
});

test('ミドルウェアがヘッダーを設定', () async {
  final ctx = TestContext.get('/');

  var nextCalled = false;
  await myMiddleware.handle(ctx, () async {
    nextCalled = true;
  });

  expect(nextCalled, isTrue);
  expect(ctx.response.headers['x-custom'], isNotNull);
});
```

### テストコンテキストの作成

```dart
// GET リクエスト
final ctx = TestContext.get('/path');

// ボディ付き POST
final ctx = TestContext.post('/path', body: {'key': 'value'});

// ヘッダー付き
final ctx = TestContext.get('/path', headers: {
  'Authorization': 'Bearer token',
});

// クエリパラメータ付き
final ctx = TestContext.get('/search?q=dart');

// カスタム
final ctx = TestContext.create(
  method: 'PATCH',
  path: '/users/1',
  body: {'name': 'Updated'},
);
```

## 統合テスト

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
    test('ユーザー一覧', () async {
      final res = await client.get('/api/users');
      expect(res, isOkResponse);
      expect(await res.json, isList);
    });

    test('ユーザー作成', () async {
      final res = await client.postJson('/api/users', {
        'name': 'John',
        'email': 'john@example.com',
      });
      expect(res, hasStatus(201));
      expect(await res.json, hasJsonPath('id', isNotNull));
    });

    test('レート制限', () async {
      // 大量のリクエストを素早く送信
      for (var i = 0; i < 110; i++) {
        await client.get('/api/users');
      }

      final res = await client.get('/api/users');
      expect(res, hasStatus(429));
    });
  });
}
```
