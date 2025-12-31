# chase

> [Hono](https://hono.dev/)にインスパイアされた、Dart用の高速で軽量なWebフレームワーク

## 特徴

- **高速** - Trieベースルーターで最適なパフォーマンス
- **軽量** - 最小限の依存関係、小さなフットプリント
- **柔軟なレスポンス** - 文字列、Map、Responseオブジェクトを返せる
- **ミドルウェア** - 18以上の組み込みミドルウェア、拡張も簡単
- **プラグインシステム** - プラグインで機能を拡張
- **リアルタイム** - WebSocket、SSE、ストリーミング対応
- **バリデーション** - スキーマベースのリクエストバリデーション
- **多言語対応** - 組み込みのi18nサポート
- **テスト** - ファーストクラスのテストユーティリティ

## クイック例

```dart
import 'package:chase/chase.dart';

void main() async {
  final app = Chase();

  // シンプルな文字列レスポンス
  app.get('/').handle((ctx) => 'Hello, World!');

  // JSONレスポンス（自動シリアライズ）
  app.get('/users/:id').handle((ctx) {
    return {'id': ctx.params['id'], 'name': 'John'};
  });

  // 完全な制御のためのResponseオブジェクト
  app.post('/users').handle((ctx) async {
    final body = await ctx.req.json();
    return Response.created({'id': 1, ...body});
  });

  // エラーレスポンス
  app.get('/protected').handle((ctx) {
    if (!isAuthorized(ctx)) {
      return Response.unauthorized({'error': '認証が必要です'});
    }
    return {'secret': 'data'};
  });

  await app.start(port: 6060);
}
```

## なぜchase？

### シンプルで直感的なAPI

```dart
// 送りたいものをそのまま返すだけ
app.get('/text').handle((ctx) => 'Hello');
app.get('/json').handle((ctx) => {'message': 'Hello'});
app.get('/list').handle((ctx) => [1, 2, 3]);
```

### パワフルなミドルウェア

```dart
app.use(Logger());
app.use(Cors());
app.use(RateLimit(limit: 100));

app.get('/admin')
  .use(JwtAuth(secret: 'secret'))
  .handle(adminHandler);
```

### パフォーマンス重視

chaseはTrieベースルーターでO(k)のルートマッチング（kはパスの深さ）を実現。線形マッチングよりも大幅に高速です。

## はじめる

[インストール](/ja/installation.md)と[クイックスタート](/ja/quickstart.md)ガイドをご覧ください。
