# コンテキスト

`Context` オブジェクトはリクエスト、レスポンス、共有データへのアクセスを提供します。

## 概要

```dart
app.get('/example').handle((ctx) {
  // リクエストアクセス
  final method = ctx.req.method;
  final path = ctx.req.path;

  // ルートパラメータ
  final id = ctx.params['id'];

  // レスポンス (命令型スタイル)
  ctx.res.json({'message': 'Hello'});

  // または値を返す
  return {'message': 'Hello'};
});
```

## プロパティ

| プロパティ | 型 | 説明 |
|----------|------|------|
| `req` | `Request` | HTTP リクエストラッパー |
| `res` | `Response` | HTTP レスポンスラッパー |
| `params` | `Map<String, String>?` | ルートパラメータ |

## コンテキストストア

ミドルウェアとハンドラ間でデータを共有:

```dart
// ミドルウェアでデータを保存
class AuthMiddleware implements Middleware {
  @override
  FutureOr<void> handle(Context ctx, NextFunction next) async {
    final user = await validateToken(ctx.req.header('Authorization'));
    ctx.set('user', user);
    ctx.set('requestId', generateId());
    await next();
  }
}

// ハンドラでデータを取得
app.get('/profile').handle((ctx) {
  final user = ctx.get<User>('user');
  final requestId = ctx.get<String>('requestId');

  if (ctx.has('user')) {
    return {'user': user, 'requestId': requestId};
  }

  return Response.unauthorized();
});
```

### ストアメソッド

```dart
// 値を設定
ctx.set('key', value);

// 値を取得 (型付き)
final user = ctx.get<User>('user');
final count = ctx.get<int>('count');

// キーが存在するか確認
if (ctx.has('user')) {
  // ...
}
```

## セッション

Session ミドルウェア使用時:

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

## 国際化

I18n ミドルウェア使用時:

```dart
app.use(I18n(translations: translations));

app.get('/greeting').handle((ctx) {
  // 翻訳関数
  final greeting = ctx.t('greeting');
  final welcome = ctx.t('welcome', {'name': 'John'});

  // 現在のロケール
  final locale = ctx.locale;

  // ロケールを変更
  ctx.setLocale('ja');

  return {'greeting': greeting, 'locale': locale};
});
```

## バリデーション

Validator ミドルウェア使用時:

```dart
app.post('/users')
  .use(Validator(body: userSchema))
  .handle((ctx) {
    // バリデーション済みデータにアクセス
    final body = ctx.validatedBody!;
    final query = ctx.validatedQuery;
    final params = ctx.validatedParams;

    return Response.created(body);
  });
```
