# クイックスタート

このガイドで初めての chase アプリケーションを作成します。

## Hello World

```dart
import 'package:chase/chase.dart';

void main() async {
  final app = Chase();

  app.get('/').handle((ctx) => 'Hello, World!');

  await app.start(port: 6060);
  print('Server running on http://localhost:6060');
}
```

## JSON API

```dart
void main() async {
  final app = Chase();

  // ユーザー一覧
  app.get('/users').handle((ctx) {
    return [
      {'id': 1, 'name': 'Alice'},
      {'id': 2, 'name': 'Bob'},
    ];
  });

  // IDでユーザー取得
  app.get('/users/:id').handle((ctx) {
    final id = ctx.params['id'];
    return {'id': id, 'name': 'User $id'};
  });

  // ユーザー作成
  app.post('/users').handle((ctx) async {
    final body = await ctx.req.json();
    return Response.created({'id': 3, ...body});
  });

  // ユーザー更新
  app.put('/users/:id').handle((ctx) async {
    final id = ctx.params['id'];
    final body = await ctx.req.json();
    return {'id': id, ...body};
  });

  // ユーザー削除
  app.delete('/users/:id').handle((ctx) {
    return Response.noContent();
  });

  await app.start(port: 6060);
}
```

## ミドルウェアの追加

```dart
void main() async {
  final app = Chase();

  // グローバルミドルウェア
  app.use(Logger());
  app.use(Cors());
  app.use(ExceptionHandler());

  // ルート固有のミドルウェア
  app.get('/admin')
    .use(BearerAuth(token: 'secret'))
    .handle((ctx) => {'admin': true});

  app.get('/').handle((ctx) => 'Hello!');

  await app.start(port: 6060);
}
```

## ルートグループ

```dart
void main() async {
  final app = Chase();

  // API v1 ルート
  app.routes('/api/v1', (v1) {
    v1.use(Logger());

    v1.routes('/users', (users) {
      users.get('/').handle(listUsers);
      users.get('/:id').handle(getUser);
      users.post('/').handle(createUser);
    });

    v1.routes('/posts', (posts) {
      posts.get('/').handle(listPosts);
      posts.post('/').handle(createPost);
    });
  });

  await app.start(port: 6060);
}
```

## エラーハンドリング

```dart
void main() async {
  final app = Chase();

  app.use(ExceptionHandler());

  app.get('/users/:id').handle((ctx) {
    final id = ctx.params['id'];

    // エラーレスポンスを返す
    if (id == null) {
      return Response.badRequest({'error': 'IDが必要です'});
    }

    final user = findUser(id);
    if (user == null) {
      return Response.notFound({'error': 'ユーザーが見つかりません'});
    }

    return user;
  });

  await app.start(port: 6060);
}
```

## 次のステップ

- [ルーティング](/ja/routing.md)を詳しく学ぶ
- [ミドルウェア](/ja/middleware.md)のオプションを探る
- [リクエスト & レスポンス](/ja/request-response.md)の扱いを理解する
