# ルーティング

chase は Trie ベースルーターで O(k) のルートマッチングを実現しています。

## 基本ルート

```dart
final app = Chase();

// HTTPメソッド
app.get('/users').handle(listUsers);
app.post('/users').handle(createUser);
app.put('/users/:id').handle(updateUser);
app.patch('/users/:id').handle(patchUser);
app.delete('/users/:id').handle(deleteUser);
app.head('/users').handle(headUsers);
app.options('/users').handle(optionsUsers);

// 全メソッド
app.route('/any', 'GET').handle(handler);
```

## ルートパラメータ

### 名前付きパラメータ

```dart
app.get('/users/:id').handle((ctx) {
  final id = ctx.params['id'];
  return {'id': id};
});

// 複数パラメータ
app.get('/users/:userId/posts/:postId').handle((ctx) {
  final userId = ctx.params['userId'];
  final postId = ctx.params['postId'];
  return {'userId': userId, 'postId': postId};
});
```

### ワイルドカードパラメータ

```dart
// /files/any/path/here にマッチ
app.get('/files/*path').handle((ctx) {
  final path = ctx.params['path'];  // "any/path/here"
  return {'path': path};
});
```

## ルートグループ

### path() を使う

```dart
final api = app.path('/api');
api.use(Logger());

api.get('/users').handle(listUsers);     // GET /api/users
api.post('/users').handle(createUser);   // POST /api/users
```

### routes() を使う

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

### ネストしたグループ

```dart
final admin = app.path('/admin');
admin.use(JwtAuth(secret: 'admin-secret'));

final adminUsers = admin.path('/users');
adminUsers.get('/').handle(listAdminUsers);     // GET /admin/users
adminUsers.delete('/:id').handle(deleteUser);   // DELETE /admin/users/:id

final adminPosts = admin.path('/posts');
adminPosts.get('/').handle(listAdminPosts);     // GET /admin/posts
```

## ルート固有のミドルウェア

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

## ルーターオプション

chase には2つのルーター実装があります:

### TrieRouter (デフォルト)

パス深度 k で O(k) マッチングの Trie ベースルーター:

```dart
final app = Chase();  // デフォルトで TrieRouter を使用
// または明示的に:
final app = Chase(router: TrieRouter());
```

### RegexRouter

複雑なパターン用の正規表現ベースルーター:

```dart
final app = Chase(router: RegexRouter());

// カスタム正規表現パターン
app.get('/users/:id(\\d+)').handle((ctx) {
  // id は数値であることが保証される
  final id = int.parse(ctx.params['id']!);
  return {'id': id};
});
```

## ルートの表示

開発モードを有効にして登録されたルートを確認:

```dart
final app = Chase(dev: true);

app.get('/users').handle(listUsers);
app.post('/users').handle(createUser);

await app.start(port: 6060);
// 表示:
// GET /users
// POST /users
```

または手動で printRoutes() を呼び出す:

```dart
app.printRoutes();
```
