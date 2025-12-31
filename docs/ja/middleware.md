# ミドルウェア

ミドルウェアはリクエストがハンドラに到達する前に処理を挟むことができます。

## ミドルウェアの使用

### グローバルミドルウェア

```dart
final app = Chase();

// 単一のミドルウェア
app.use(Logger());

// 複数のミドルウェア
app.useAll([
  ExceptionHandler(),
  Cors(),
  Compress(),
]);
```

### ルート固有のミドルウェア

```dart
app.get('/admin')
  .use(BearerAuth(token: 'secret'))
  .handle(adminHandler);

// チェーンで複数適用
app.post('/upload')
  .use(RateLimit(limit: 10))
  .use(BodyLimit(maxSize: 10 * 1024 * 1024))
  .handle(uploadHandler);
```

### グループミドルウェア

```dart
final api = app.path('/api');
api.use(Logger());
api.use(RateLimit(limit: 100));

api.get('/users').handle(listUsers);  // Logger + RateLimit が適用
```

## 組み込みミドルウェア

### 認証

| ミドルウェア | 説明 |
|------------|------|
| `BasicAuth` | HTTP Basic 認証 |
| `BearerAuth` | Bearer トークン認証 |
| `JwtAuth` | JWT 認証 (クレーム付き) |

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

### セキュリティ

| ミドルウェア | 説明 |
|------------|------|
| `Cors` | Cross-Origin Resource Sharing |
| `Csrf` | CSRF 保護 |
| `SecureHeaders` | セキュリティヘッダー (CSP, HSTS等) |
| `RateLimit` | リクエストレート制限 |
| `BodyLimit` | リクエストボディサイズ制限 |

```dart
// CORS
app.use(Cors(
  origins: ['https://example.com'],
  methods: ['GET', 'POST'],
  headers: ['Content-Type', 'Authorization'],
));

// レート制限
app.use(RateLimit(
  limit: 100,
  window: Duration(minutes: 1),
));

// ボディサイズ制限
app.use(BodyLimit(maxSize: 1024 * 1024));  // 1MB
```

### パフォーマンス

| ミドルウェア | 説明 |
|------------|------|
| `Compress` | Gzip/Deflate 圧縮 |
| `CacheControl` | Cache-Control ヘッダー |
| `ETag` | キャッシュ用エンティティタグ |
| `Timeout` | リクエストタイムアウト |

```dart
// 圧縮
app.use(Compress());

// キャッシュ制御
app.use(CacheControl(maxAge: Duration(hours: 1)));

// ETag
app.use(ETag());

// タイムアウト
app.use(Timeout(duration: Duration(seconds: 30)));
```

### ユーティリティ

| ミドルウェア | 説明 |
|------------|------|
| `Logger` | リクエスト/レスポンスログ |
| `RequestId` | 一意のリクエストID |
| `ExceptionHandler` | エラーハンドリング |
| `Session` | セッション管理 |
| `I18n` | 国際化 |
| `Validator` | リクエストバリデーション |
| `Proxy` | HTTP プロキシ |
| `StaticFileHandler` | 静的ファイル配信 |

```dart
// Logger
app.use(Logger());

// Request ID
app.use(RequestId());

// 例外ハンドラ
app.use(ExceptionHandler());
```

## カスタムミドルウェア

```dart
class TimingMiddleware implements Middleware {
  @override
  FutureOr<void> handle(Context ctx, NextFunction next) async {
    final stopwatch = Stopwatch()..start();

    await next();  // 次のミドルウェア/ハンドラを呼び出す

    print('${ctx.req.method} ${ctx.req.path} - ${stopwatch.elapsedMilliseconds}ms');
  }
}

app.use(TimingMiddleware());
```

### 設定付きミドルウェア

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
      return Response.tooManyRequests({'error': 'レート制限を超えました'});
    }

    await next();
  }
}
```

### ミドルウェアからの早期リターン

```dart
class AuthMiddleware implements Middleware {
  @override
  FutureOr<void> handle(Context ctx, NextFunction next) async {
    final token = ctx.req.header('Authorization');

    if (token == null) {
      // 早期リターン - ハンドラは呼ばれない
      ctx.res.json({'error': '認証されていません'}, status: 401);
      return;
    }

    final user = await validateToken(token);
    if (user == null) {
      ctx.res.json({'error': '無効なトークン'}, status: 401);
      return;
    }

    // ハンドラでアクセスできるようにユーザーを保存
    ctx.set('user', user);

    await next();  // ハンドラへ続行
  }
}
```

## ミドルウェアの順序

ミドルウェアは追加された順序で実行されます:

```dart
app.use(Logger());        // 1. 最初
app.use(Cors());          // 2. 2番目
app.use(RateLimit());     // 3. 3番目

// リクエストフロー:
// Logger → Cors → RateLimit → Handler → RateLimit → Cors → Logger
```
