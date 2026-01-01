<p align="center">
  <img src="/chase/assets/chase-logo.png" alt="Chase Logo" width="400">
</p>

<p align="center">
  Dart用の高速で軽量なWebフレームワーク
</p>

<p align="center">
  <a href="https://dart.dev"><img src="https://img.shields.io/badge/Dart-3.10+-blue.svg" alt="Dart"></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT"></a>
</p>

<p align="center">
  <a href="../../README.md">English</a>
  <a href="docs/ja/README.md">日本語</a>
</p>

## 特徴

- 🚀 **高速** - Trieベースルーターで最適なパフォーマンス
- 🪶 **軽量** - 最小限の依存関係、小さなフットプリント
- 🧩 **ミドルウェア** - 18以上の組み込みミドルウェア、拡張も簡単
- 🔌 **プラグインシステム** - プラグインで機能を拡張
- 🌐 **リアルタイム** - WebSocket、SSE、ストリーミング対応
- ✅ **バリデーション** - スキーマベースのリクエストバリデーション
- 🌍 **多言語対応** - 組み込みのi18nサポート
- 🧪 **テスト** - ファーストクラスのテストユーティリティ

## パフォーマンス
<p align="center">
  <img src="/chase/assets/benchmark-result.png" alt="Benchmark Results" width="600">
</p>

<p align="center">

| Test         | chase  | dart:io | Shelf  | Dart Frog | chase vs dart:io |
|--------------|--------|---------|--------|-----------|------------------|
| Plain Text   | 72,187 | 72,391  | 42,206 | 41,006    | 99.7%            |
| JSON         | 66,233 | 68,908  | 38,863 | 38,135    | 96.1%            |
| Route Params | 65,681 | 60,256  | 36,721 | 36,695    | 109%             |
| Query Params | 63,154 | 65,237  | 36,534 | 35,483    | 96.8%            |
| Large JSON   | 8,053  | 8,110   | 7,812  | 7,643     | 99.3%            |
| Middleware   | 63,308 | 71,117  | 37,937 | 37,093    | 89.0%            |

</p>

## 目次

- [インストール](#インストール)
- [クイックスタート](#クイックスタート)
- [ルーティング](#ルーティング)
- [ミドルウェア](#ミドルウェア)
- [リクエスト & レスポンス](#リクエスト--レスポンス)
- [バリデーション](#バリデーション)
- [ルートグループ](#ルートグループ)
- [WebSocket](#websocket)
- [Server-Sent Events](#server-sent-events)
- [ストリーミング](#ストリーミング)
- [静的ファイル](#静的ファイル)
- [セッション](#セッション)
- [多言語対応](#多言語対応)
- [テスト](#テスト)
- [プラグイン](#プラグイン)

## インストール

```yaml
dependencies:
  chase: ^0.1.0
```

## クイックスタート

```dart
import 'package:chase/chase.dart';

void main() async {
  final app = Chase();

  // シンプルな文字列レスポンス
  app.get('/').handle((ctx) => 'Hello, World!');

  // JSONレスポンス（Map/Listは自動シリアライズ）
  app.get('/hello/:name').handle((ctx) {
    final name = ctx.req.param('name');
    return {'message': 'Hello, $name!'};
  });

  // ステータスコード指定（Response fluent API）
  app.post('/users').handle((ctx) async {
    final body = await ctx.req.json();
    return Response.created().json({'id': 1, ...body as Map});
  });

  // 完全な制御のためのResponseオブジェクト
  app.get('/users/:id').handle((ctx) {
    return Response.ok().json({'id': ctx.req.param('id'), 'name': 'John'});
  });

  await app.start(port: 6060);
}
```

## ルーティング

### 基本ルート

```dart
final app = Chase();

// HTTPメソッド
app.get('/users').handle((ctx) => {'users': []});
app.post('/users').handle(createUser);
app.put('/users/:id').handle(updateUser);
app.patch('/users/:id').handle(patchUser);
app.delete('/users/:id').handle(deleteUser);
app.head('/users/:id').handle(checkUser);
app.options('/users').handle(corsHandler);

// カスタムメソッド
app.route('CUSTOM', '/any').handle((ctx) => 'Custom method');
```

### ルートパラメータ

```dart
// 単一パラメータ
app.get('/users/:id').handle((ctx) {
  final id = ctx.req.param('id');
  return {'id': id};
});

// 複数パラメータ
app.get('/users/:userId/posts/:postId').handle((ctx) {
  final userId = ctx.req.param('userId');
  final postId = ctx.req.param('postId');
  return {'userId': userId, 'postId': postId};
});

// ワイルドカード（キャッチオール）
app.get('/files/*path').handle((ctx) {
  final path = ctx.req.param('path');  // 例: "images/photo.jpg"
  return 'File: $path';
});

// オプショナルパラメータ
app.get('/users/:id?').handle((ctx) {
  final id = ctx.req.param('id');  // 未指定の場合はnull
  // /users と /users/123 の両方にマッチ
});

// 他のパラメータと組み合わせ
app.get('/posts/:postId/comments/:commentId?').handle((ctx) {
  final postId = ctx.req.param('postId');      // 必須
  final commentId = ctx.req.param('commentId'); // オプショナル
  // /posts/1/comments と /posts/1/comments/2 にマッチ
});
```

### クエリパラメータ

```dart
app.get('/search').handle((ctx) {
  final query = ctx.req.query('q');           // 単一値
  final tags = ctx.req.queryAll('tag');       // 複数値
  final queries = ctx.req.queries;            // 全てをMapで取得
  return {'query': query, 'tags': tags};
});
```

### 複数パス

同一ハンドラを複数パスに登録:

```dart
// 複数パスに同じハンドラを登録
app.get(['/hello', '/ja/hello']).handle((ctx) {
  return 'Hello!';
});

// 全HTTPメソッドで使用可能
app.post(['/submit', '/api/submit']).handle(submitHandler);
app.put(['/update', '/api/update']).handle(updateHandler);

// ミドルウェアと組み合わせ
app.get(['/a', '/b', '/c'])
  .use(AuthMiddleware())
  .handle(handler);

// パスパラメータも使用可能
app.get(['/users/:id', '/members/:id']).handle((ctx) {
  final id = ctx.req.param('id');
  return {'id': id};
});

// all() と on() も複数パスをサポート
app.all(['/any', '/v1/any']).handle(anyHandler);
app.on(['GET', 'POST'], ['/form', '/api/form']).handle(formHandler);
```

## ミドルウェア

### ミドルウェアの使用

```dart
// グローバルミドルウェア
app.use(ExceptionHandler());
app.use(Logger());

// 複数を一度に
app.useAll([Cors(), Compress()]);

// ルート固有
app.get('/admin')
  .use(BearerAuth(token: 'secret'))
  .handle(adminHandler);

// チェーン
app.post('/api/data')
  .use(RateLimit(limit: 100))
  .use(BodyLimit(maxSize: 1024 * 1024))
  .handle(dataHandler);
```

### 組み込みミドルウェア

| ミドルウェア | 説明 |
|------------|-------------|
| **認証** | |
| `BasicAuth` | HTTP Basic認証 |
| `BearerAuth` | Bearerトークン認証 |
| `JwtAuth` | JWTクレーム付き認証 |
| **セキュリティ** | |
| `Cors` | Cross-Origin Resource Sharing |
| `Csrf` | CSRFトークン保護 |
| `SecureHeaders` | セキュリティヘッダー（CSP、HSTSなど） |
| `RateLimit` | リクエストレート制限 |
| `BodyLimit` | リクエストボディサイズ制限 |
| `IpRestriction` | IPアドレスベースのアクセス制御 |
| **パフォーマンス** | |
| `Compress` | Gzip/Deflate圧縮 |
| `CacheControl` | Cache-Controlヘッダー |
| `ETag` | キャッシュ用エンティティタグ |
| `Timeout` | リクエストタイムアウト処理 |
| `Timing` | Server-Timingヘッダーでパフォーマンス計測 |
| **ユーティリティ** | |
| `Logger` | リクエスト/レスポンスログ |
| `RequestId` | ユニークリクエストID生成 |
| `ExceptionHandler` | エラーハンドリング |
| `Session` | セッション管理 |
| `I18n` | 多言語対応 |
| `Validator` | リクエストバリデーション |
| `Proxy` | HTTPプロキシ |
| `StaticFileHandler` | 静的ファイル配信 |
| `PrettyJson` | JSON整形出力 |
| `TrailingSlash` | 末尾スラッシュ正規化（削除/追加） |

### カスタムミドルウェア

```dart
class TimingMiddleware implements Middleware {
  @override
  FutureOr<void> handle(Context ctx, NextFunction next) async {
    final sw = Stopwatch()..start();
    await next();
    print('${ctx.req.method} ${ctx.req.path} - ${sw.elapsedMilliseconds}ms');
  }
}

app.use(TimingMiddleware());
```

## リクエスト & レスポンス

### リクエスト

```dart
app.post('/users').handle((ctx) async {
  // ボディ
  final json = await ctx.req.json();           // JSONボディ
  final text = await ctx.req.text();           // 生テキスト
  final form = await ctx.req.formData();       // フォームデータ
  final multipart = await ctx.req.multipart(); // マルチパート

  // ヘッダー
  final contentType = ctx.req.header('content-type');
  final headers = ctx.req.headers;

  // リクエスト情報
  final method = ctx.req.method;
  final path = ctx.req.path;
  final url = ctx.req.url;

  return {'received': json};
});
```

#### コンテンツネゴシエーション

```dart
app.get('/data').handle((ctx) {
  // Acceptヘッダーによるネゴシエーション
  final type = ctx.req.accepts(['json', 'html', 'xml'], defaultValue: 'json');

  if (type == 'html') {
    return Response.html('<h1>Data</h1>');
  }
  return {'data': 'value'};
});

// 言語ネゴシエーション
final lang = ctx.req.acceptsLanguages(['en', 'ja', 'zh'], defaultValue: 'en');

// エンコーディングネゴシエーション
final encoding = ctx.req.acceptsEncodings(['gzip', 'br'], defaultValue: 'identity');
```

#### 接続情報

```dart
app.get('/info').handle((ctx) {
  final info = ctx.req.connInfo;

  return {
    'remoteAddress': info.remote.address,  // クライアントIP
    'remotePort': info.remote.port,        // クライアントポート
    'addressType': info.remote.addressType?.name,  // 'ipv4' または 'ipv6'
    'localPort': info.local.port,          // サーバーポート
  };
});

// ショートカットアクセサも利用可能
final ip = ctx.req.ip;              // X-Forwarded-For対応
final addr = ctx.req.remoteAddress; // 直接接続IP
```

### レスポンス

Chaseはシンプルな戻り値から完全なResponseオブジェクトまで、複数のレスポンススタイルをサポートしています。

#### 戻り値（推奨）

```dart
// String → text/plain
app.get('/text').handle((ctx) => 'Hello, World!');

// Map → application/json
app.get('/json').handle((ctx) => {'message': 'Hello'});

// List → application/json
app.get('/list').handle((ctx) => [1, 2, 3]);

// Responseオブジェクト → 完全な制御
app.get('/custom').handle((ctx) => Response.ok().json({'status': 'success'}));
```

#### Responseクラス

```dart
// 成功レスポンス（2xx）
Response.ok().text('Hello')             // 200 text
Response.ok().json({'data': value})     // 200 JSON
Response.created().json({'id': 1})      // 201
Response.noContent()                    // 204
Response.accepted().json({'status': 'pending'}) // 202

// リダイレクト（3xx）
Response.movedPermanently('/new')       // 301
Response.redirect('/temp')              // 302
Response.seeOther('/other')             // 303
Response.temporaryRedirect('/temp')     // 307
Response.permanentRedirect('/new')      // 308

// クライアントエラー（4xx）
Response.badRequest().json({'error': 'Invalid'})   // 400
Response.unauthorized()                             // 401
Response.forbidden()                                // 403
Response.notFound().json({'error': 'Not found'})   // 404
Response.conflict()                                 // 409
Response.unprocessableEntity().json({'errors': []}) // 422
Response.tooManyRequests()                          // 429

// サーバーエラー（5xx）
Response.internalServerError()          // 500
Response.badGateway()                   // 502
Response.serviceUnavailable()           // 503

// 便利なファクトリ（直接Responseを返す）
Response.json({'key': 'value'}, status: 201)
Response.text('Hello', status: 200)
Response.html('<h1>Hello</h1>')
```

#### 低レベルアクセス（ctx.res）

高度なユースケース向けに、`HttpResponse`に直接アクセスできます：

```dart
app.get('/low-level').handle((ctx) async {
  // ヘッダー直接アクセス
  ctx.res.headers.set('X-Custom', 'value');

  // Cookie
  ctx.res.cookie('session', 'abc123', maxAge: Duration(hours: 24));
  ctx.res.deleteCookie('session');

  // ステータスコード
  ctx.res.statusCode = 200;

  // 直接書き込み
  ctx.res.write('Hello');
  await ctx.res.close();
});
```

## バリデーション

chaseはパワフルなスキーマベースのバリデーションシステムを提供します。

### スキーマ定義

```dart
final userSchema = Schema({
  'name': V.isString().required().min(2).max(50),
  'email': V.isString().required().email(),
  'age': V.isInt().min(0).max(150),
  'role': V.isString().oneOf(['admin', 'user', 'guest']),
  'tags': V.list().min(1).max(10),
  'active': V.isBool().defaultValue(true),
});
```

### Validatorミドルウェア

```dart
app.post('/users')
  .use(Validator(body: userSchema))
  .handle((ctx) {
    // バリデート済み＆変換済みデータにアクセス
    final data = ctx.validatedBody!;
    return Response.created().json({'created': data});
  });
```

### クエリ＆パラメータのバリデーション

```dart
final querySchema = Schema({
  'page': V.isInt().defaultValue(1).min(1),
  'limit': V.isInt().defaultValue(20).max(100),
  'sort': V.isString().oneOf(['asc', 'desc']).defaultValue('desc'),
});

final paramsSchema = Schema({
  'id': V.isInt().required().min(1),
});

app.get('/users/:id/posts')
  .use(Validator(query: querySchema, params: paramsSchema))
  .handle((ctx) {
    final page = ctx.validatedQuery!['page'];
    final userId = ctx.validatedParams!['id'];
    // ...
  });
```

### 利用可能なバリデータ

```dart
// 型バリデータ
V.isString()     // 文字列バリデーション
V.isInt()        // 整数（文字列を自動パース）
V.isDouble()     // Double/数値
V.isBool()       // Boolean（"true"、"1"などを受け入れ）
V.list()         // Array/List
V.map()          // Object/Map
V.any()          // 任意の型

// 文字列ルール
V.isString()
  .required()                    // nullまたは空でないこと
  .min(5)                        // 最小長
  .max(100)                      // 最大長
  .length(10)                    // 正確な長さ
  .email()                       // メール形式
  .url()                         // URL形式
  .pattern(RegExp(r'^\d+$'))     // カスタム正規表現
  .oneOf(['a', 'b', 'c'])        // 許可値

// 数値ルール
V.isInt()
  .required()
  .min(0)                        // 最小値
  .max(100)                      // 最大値

// カスタムバリデーション
V.isString().custom(
  (value) => value.startsWith('A'),
  message: 'Aで始まる必要があります',
)

// デフォルト値
V.isString().defaultValue('guest')
```

### 手動バリデーション

```dart
final schema = Schema({
  'email': V.isString().required().email(),
});

final result = schema.validate({'email': 'invalid'});
if (!result.isValid) {
  for (final error in result.errors) {
    print('${error.field}: ${error.message}');
  }
}
```

## ルートグループ

```dart
// path()を使用
final api = app.path('/api');
api.use(BearerAuth(token: 'secret'));
api.get('/users').handle(getUsers);
api.post('/users').handle(createUser);

// routes()コールバックを使用
app.routes('/api/v1', (v1) {
  v1.use(Logger());

  v1.routes('/users', (users) {
    users.get('/').handle(listUsers);
    users.get('/:id').handle(getUser);
    users.post('/').handle(createUser);
  });
});

// ネストしたグループ
final admin = app.path('/admin');
admin.use(JwtAuth(secret: 'secret'));

final adminUsers = admin.path('/users');
adminUsers.get('/').handle(listAdminUsers);
```

## WebSocket

```dart
app.get('/ws').handle((ctx) async {
  final ws = await ctx.req.upgrade();

  ws.onMessage((message) {
    print('Received: $message');
    ws.send('Echo: $message');
  });

  ws.onClose((code, reason) {
    print('Closed: $code $reason');
  });

  ws.onError((error) {
    print('Error: $error');
  });
});
```

## Server-Sent Events

```dart
app.get('/events').handle((ctx) {
  return streamSSE(ctx, (stream) async {
    // イベント送信
    await stream.writeSSE(SSEMessage(
      data: '{"count": 1}',
      event: 'update',
    ));

    await stream.writeSSE(SSEMessage(
      data: '{"count": 2}',
      event: 'update',
      id: '2',
    ));

    // リアルタイム更新
    for (var i = 0; i < 10; i++) {
      await stream.sleep(Duration(seconds: 1));
      await stream.writeSSE(SSEMessage(
        data: DateTime.now().toIso8601String(),
      ));
    }
  });
});
```

## ストリーミング

### テキストストリーミング

```dart
app.get('/stream').handle((ctx) {
  return streamText(ctx, (stream) async {
    for (var i = 0; i < 10; i++) {
      await stream.writeln('Line $i');
      await stream.sleep(Duration(milliseconds: 100));
    }
  });
});
```

### バイナリストリーミング

```dart
app.get('/download').handle((ctx) {
  return stream(ctx, (s) async {
    final file = File('large-file.zip');
    await s.pipe(file.openRead());
  }, headers: {
    'content-disposition': 'attachment; filename="file.zip"',
  });
});
```

## 静的ファイル

```dart
// 基本的な使用法
app.staticFiles('/static', './public');

// オプション付き
app.staticFiles('/assets', './public', StaticOptions(
  maxAge: Duration(days: 365),
  etag: true,
  index: ['index.html'],
  dotFiles: DotFiles.ignore,
));

// またはミドルウェアを直接使用
app.get('/files/*path')
  .use(StaticFileHandler('./uploads'))
  .handle((ctx) => Response.notFound());
```

## セッション

```dart
// セッションミドルウェアを追加
app.use(Session(
  store: MemorySessionStore(),
  cookieName: 'session_id',
  maxAge: Duration(hours: 24),
));

// セッションの使用
app.post('/login').handle((ctx) async {
  final body = await ctx.req.json();
  ctx.session['userId'] = body['userId'];
  ctx.session['loggedIn'] = true;
  return {'success': true};
});

app.get('/profile').handle((ctx) {
  if (ctx.session['loggedIn'] != true) {
    return Response.unauthorized().json({'error': 'ログインしていません'});
  }
  return {'userId': ctx.session['userId']};
});

app.post('/logout').handle((ctx) async {
  await ctx.destroySession();
  return {'success': true};
});
```

## 多言語対応

### セットアップ

```dart
// 翻訳を読み込み
final translations = I18nTranslations.fromMap({
  'en': {
    'greeting': 'Hello',
    'welcome': 'Welcome, {name}!',
  },
  'ja': {
    'greeting': 'こんにちは',
    'welcome': 'ようこそ、{name}さん！',
  },
});

// ミドルウェアを追加
app.use(I18n(
  translations: translations,
  defaultLocale: 'en',
  supportedLocales: ['en', 'ja', 'ko'],
));
```

### 使用方法

```dart
app.get('/greeting').handle((ctx) {
  final t = ctx.t;  // 翻訳関数

  return {
    'greeting': t('greeting'),
    'welcome': t('welcome', {'name': 'John'}),
    'locale': ctx.locale,
  };
});
```

### ロケール検出

ロケールは以下の順序で検出されます：
1. クエリパラメータ: `?lang=ja`
2. Accept-Languageヘッダー
3. デフォルトロケール

```dart
// 特定のロケールを強制
app.get('/ja/greeting').handle((ctx) {
  ctx.setLocale('ja');
  return {'message': ctx.t('greeting')};
});
```

## テスト

chaseは包括的なテストユーティリティを提供します。

### TestClient

```dart
import 'package:chase/chase.dart';
import 'package:chase/testing/testing.dart';
import 'package:test/test.dart';

void main() {
  late Chase app;
  late TestClient client;

  setUp(() async {
    app = Chase();
    app.get('/').handle((ctx) => 'Hello');
    app.post('/users').handle((ctx) async {
      final body = await ctx.req.json();
      return Response.created().json(body);
    });

    client = await TestClient.start(app);
  });

  tearDown(() => client.close());

  test('GETリクエスト', () async {
    final res = await client.get('/');
    expect(res, isOkResponse);
    expect(await res.body, 'Hello');
  });

  test('POST JSON', () async {
    final res = await client.postJson('/users', {'name': 'John'});
    expect(res, hasStatus(201));
    expect(await res.json, hasJsonPath('name', 'John'));
  });
}
```

### カスタムマッチャー

```dart
// ステータスマッチャー
expect(res, isOkResponse);           // 2xx
expect(res, isRedirectResponse);     // 3xx
expect(res, isClientErrorResponse);  // 4xx
expect(res, isServerErrorResponse);  // 5xx
expect(res, hasStatus(201));         // 正確なステータス

// ヘッダーマッチャー
expect(res, hasHeader('content-type'));
expect(res, hasHeader('content-type', 'application/json'));
expect(res, hasHeader('content-type', contains('json')));
expect(res, hasContentType('application/json'));

// JSONマッチャー
final json = await res.json;
expect(json, hasJsonPath('user.name', 'John'));
expect(json, hasJsonPath('items', hasLength(3)));
expect(json, hasJsonPath('data.tags', ['a', 'b']));

// Cookieマッチャー
expect(res, hasCookie('session'));
expect(res, hasCookie('token', 'abc123'));
```

### TestClient拡張

```dart
// 認証ヘルパー
final res = await client.getWithAuth('/profile', 'my-token');

// JSON POSTヘルパー
final res = await client.postJson('/users', {'name': 'John'});
final res = await client.postJson('/users', {'name': 'John'}, token: 'secret');
```

### TestContextを使ったユニットテスト

```dart
test('ミドルウェアの動作', () async {
  final ctx = TestContext.get('/api/users', headers: {
    'Authorization': 'Bearer token123',
  });

  var nextCalled = false;
  await myMiddleware.handle(ctx, () async {
    nextCalled = true;
  });

  expect(nextCalled, isTrue);
  expect(ctx.res.statusCode, 200);
});
```

## プラグイン

### プラグインの使用

```dart
final app = Chase()
  ..plugin(HealthCheckPlugin())
  ..plugin(MetricsPlugin());
```

### プラグインの作成

```dart
class HealthCheckPlugin extends Plugin {
  @override
  String get name => 'health-check';

  @override
  void onInstall(Chase app) {
    app.get('/health').handle((ctx) {
      return {
        'status': 'healthy',
        'timestamp': DateTime.now().toIso8601String(),
      };
    });
  }

  @override
  Future<void> onStart(Chase app) async {
    print('Health check endpoint ready');
  }

  @override
  Future<void> onStop(Chase app) async {
    print('Shutting down health check');
  }
}
```

## コンテキストストア

ミドルウェアとハンドラ間でデータを共有：

```dart
// ミドルウェアがデータを設定
class AuthMiddleware implements Middleware {
  @override
  FutureOr<void> handle(Context ctx, NextFunction next) async {
    final user = await validateToken(ctx.req.header('Authorization'));
    ctx.set('user', user);
    ctx.set('requestId', generateId());
    await next();
  }
}

// ハンドラがデータを取得
app.get('/profile').handle((ctx) {
  final user = ctx.get<User>('user');
  final requestId = ctx.get<String>('requestId');

  if (ctx.has('user')) {
    ctx.res.json({'user': user, 'requestId': requestId});
  }
});
```

## メソッドオーバーライド

HTMLフォームはGETとPOSTのみサポートしています。メソッドオーバーライドを使用すると、フォームからPUT、PATCH、DELETEリクエストをシミュレートできます。

```dart
// メソッドオーバーライドを有効化（デフォルト：フォームフィールド "_method"）
final app = Chase()..methodOverride();

// カスタム設定
final app = Chase()
  ..methodOverride(
    form: '_method',            // フォームフィールド名（デフォルト）
    header: 'X-HTTP-Method',    // ヘッダー名
    query: '_method',           // クエリパラメータ名
  );

// フォームからのDELETEを処理
app.delete('/posts/:id').handle((ctx) {
  return {'deleted': ctx.req.param('id')};
});
```

```html
<form action="/posts/123" method="POST">
  <input type="hidden" name="_method" value="DELETE" />
  <button type="submit">削除</button>
</form>
```

## サーバー設定

```dart
// 開発モード（ルートを出力）
final app = Chase(dev: true);

// カスタムルーター
final app = Chase(router: TrieRouter());  // デフォルト、Trieベース（高速）
final app2 = Chase(router: RegexRouter()); // 正規表現ベース（柔軟）

// 起動オプション
await app.start(port: 6060);
await app.start(host: '0.0.0.0', port: 8080);
await app.start(shared: true);  // マルチIsolateサポート

// サーバー情報
print(app.isRunning);
print(app.server?.port);

// グレースフルシャットダウン
await app.stop();
await app.stop(force: true);
```

## 便利なセットアップ

```dart
// 共通ミドルウェアスタックを追加
final app = Chase()..withDefaults();

// 以下と同等：
final app = Chase()
  ..use(ExceptionHandler())
  ..use(Logger());
```

## サンプル

[example](../../example/)ディレクトリでより多くの例をご覧ください：

- [WebSocket](../../example/example_websocket.dart)
- [SSE](../../example/example_sse.dart)
- [Streaming](../../example/example_streaming.dart)
- [Rate Limiting](../../example/example_rate_limit.dart)
- [Session](../../example/example_session.dart)
- [ETag](../../example/example_etag.dart)
- [Timeout](../../example/example_timeout.dart)
- [Body Limit](../../example/example_body_limit.dart)
- [Secure Headers](../../example/example_secure_headers.dart)
- [Request ID](../../example/example_request_id.dart)

## ライセンス

MITライセンス - 詳細は[LICENSE](../../LICENSE)ファイルをご覧ください。
