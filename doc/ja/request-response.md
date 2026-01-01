# リクエスト & レスポンス

chase は HTTP リクエストとレスポンスを柔軟に扱えます。

## レスポンススタイル

chase は3つのレスポンススタイルをサポート。用途に合わせて選択してください。

### 1. 戻り値 (推奨)

最もシンプル - 送りたいものをそのまま返すだけ:

```dart
// String → text/plain
app.get('/text').handle((ctx) => 'Hello, World!');

// Map → application/json
app.get('/json').handle((ctx) => {'message': 'Hello'});

// List → application/json
app.get('/list').handle((ctx) => [1, 2, 3]);

// その他の型 → toString()
app.get('/number').handle((ctx) => 42);  // "42"
```

### 2. Response クラス

ステータスコードやヘッダーを完全制御:

```dart
app.get('/user/:id').handle((ctx) {
  final user = findUser(ctx.params['id']);

  if (user == null) {
    return Response.notFound({'error': 'ユーザーが見つかりません'});
  }

  return Response.ok(user);
});

app.post('/users').handle((ctx) async {
  final body = await ctx.req.json();
  final user = createUser(body);
  return Response.created(user);
});
```

### 3. 命令型スタイル (ctx.res)

従来のコンテキストメソッドを使うアプローチ:

```dart
app.get('/legacy').handle((ctx) {
  ctx.res.json({'message': 'Hello'});
});
```

## Response クラス リファレンス

### 成功レスポンス (2xx)

```dart
Response.ok(body)                   // 200 OK
Response.ok({'data': value})        // 200 JSON付き
Response.created(body)              // 201 Created
Response.accepted(body)             // 202 Accepted
Response.noContent()                // 204 No Content
```

### リダイレクトレスポンス (3xx)

```dart
Response.movedPermanently('/new')   // 301 Moved Permanently
Response.found('/temp')             // 302 Found
Response.seeOther('/other')         // 303 See Other
Response.temporaryRedirect('/temp') // 307 Temporary Redirect
Response.permanentRedirect('/new')  // 308 Permanent Redirect
```

### クライアントエラーレスポンス (4xx)

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

### サーバーエラーレスポンス (5xx)

```dart
Response.internalServerError(body)  // 500 Internal Server Error
Response.badGateway(body)           // 502 Bad Gateway
Response.serviceUnavailable(body)   // 503 Service Unavailable
```

### 便利なコンストラクタ

```dart
// カスタムステータスのJSON
Response.json({'key': 'value'}, status: 201)

// カスタムステータスのテキスト
Response.text('Hello', status: 200)

// HTMLレスポンス
Response.html('<h1>Hello</h1>')

// カスタムレスポンス
Response(
  418,
  body: {'message': "I'm a teapot"},
  headers: {'x-custom': 'value'},
)
```

## Request オブジェクト

### ボディのパース

```dart
app.post('/data').handle((ctx) async {
  // JSONボディ
  final json = await ctx.req.json();

  // 生テキスト
  final text = await ctx.req.text();

  // フォームデータ
  final form = await ctx.req.formData();

  // マルチパート (ファイルアップロード)
  final parts = await ctx.req.multipart();
  for (final part in parts) {
    if (part.isFile) {
      final bytes = await part.readBytes();
      // ファイルを保存...
    }
  }

  return {'received': true};
});
```

### ヘッダー

```dart
app.get('/headers').handle((ctx) {
  // 単一ヘッダー
  final contentType = ctx.req.header('content-type');
  final auth = ctx.req.header('authorization');

  // 全ヘッダー
  final headers = ctx.req.headers;

  return {'contentType': contentType};
});
```

### クエリパラメータ

```dart
// GET /search?q=dart&tag=web&tag=api
app.get('/search').handle((ctx) {
  // 単一値
  final query = ctx.req.query('q');  // "dart"

  // 複数値
  final tags = ctx.req.queryAll('tag');  // ["web", "api"]

  // 全てをMapで
  final all = ctx.req.queries;

  return {'query': query, 'tags': tags};
});
```

### ルートパラメータ

```dart
// GET /users/123/posts/456
app.get('/users/:userId/posts/:postId').handle((ctx) {
  final userId = ctx.params['userId'];   // "123"
  final postId = ctx.params['postId'];   // "456"

  return {'userId': userId, 'postId': postId};
});

// ワイルドカード
app.get('/files/*path').handle((ctx) {
  final path = ctx.params['path'];  // "images/photo.jpg"
  return {'path': path};
});
```

### リクエスト情報

```dart
app.all('/info').handle((ctx) {
  return {
    'method': ctx.req.method,     // "GET", "POST", etc.
    'path': ctx.req.path,         // "/info"
    'url': ctx.req.url.toString(),
  };
});
```

## レスポンスヘッダー & クッキー

```dart
app.get('/custom').handle((ctx) {
  // ヘッダーを設定 (レスポンス送信前に)
  ctx.res.headers.set('X-Custom', 'value');
  ctx.res.headers.set('X-Request-Id', generateId());

  // クッキーを設定
  ctx.res.cookie('session', 'abc123', maxAge: Duration(hours: 24));
  ctx.res.cookie('prefs', 'dark', httpOnly: false);

  // クッキーを削除
  ctx.res.deleteCookie('old-cookie');

  return {'success': true};
});
```

## 優先順位

`ctx.res` メソッドと戻り値の両方を使った場合、最初の方が優先:

```dart
app.get('/priority').handle((ctx) {
  ctx.res.text('First');  // ← これが送信される
  return 'Second';        // ← これは無視される
});
```

これにより、早期リターンには `ctx.res` を使い、メインレスポンスには戻り値を使えます。
