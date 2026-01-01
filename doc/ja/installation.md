# インストール

## 必要条件

- Dart SDK 3.0 以上

## 依存関係の追加

`pubspec.yaml` に chase を追加:

```yaml
dependencies:
  chase: ^0.1.0
```

そして実行:

```bash
dart pub get
```

## インストールの確認

シンプルなサーバーを作成して確認:

```dart
import 'package:chase/chase.dart';

void main() async {
  final app = Chase();

  app.get('/').handle((ctx) => 'chase is working!');

  await app.start(port: 6060);
  print('Server running on http://localhost:6060');
}
```

実行:

```bash
dart run bin/server.dart
```

ブラウザで http://localhost:6060 にアクセス。

## 開発モード

デバッグに便利な開発モードを有効化:

```dart
final app = Chase(dev: true);
```

これにより:
- 起動時に登録されたルートを表示
- より詳細なエラーメッセージを表示
