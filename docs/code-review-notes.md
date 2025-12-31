# chase コードレビューノート

## lib/src/core/chase.dart

### 1. ~~ミドルウェアチェーンの毎リクエスト再構築~~ [FIXED]

~~**問題**: `_buildMiddlewareChain` がリクエストごとに呼び出され、新しいクロージャが毎回生成される。~~

**修正済み**: ルート登録時 (`_addRoute`) にミドルウェアチェーンを構築するように変更。

---

### 2. ~~`_defaultNotFoundHandler` の毎アクセス再生成~~ [FIXED]

~~**問題**: getterが呼び出されるたびに新しいラムダを生成する。~~

**修正済み**: static メソッドに変更し、サーバー起動時に `_cachedNotFoundHandler` としてキャッシュ。

---

### 3. `Map<String, dynamic>` の型チェックが厳格すぎる (line 308)

**問題**: `Map<String, Object>` や `Map<String, String>` は `Map<String, dynamic>` にマッチしない。

```dart
case Map<String, dynamic> json:
  await ctx.res.json(json);
```

**影響**: 意図しないフォールバック (`result.toString()`) が発生する可能性。

**推奨**: `Map` でパターンマッチングを行う。

```dart
case Map json:
  await ctx.res.json(json);
```

---

### 4. `host` パラメータが `dynamic` 型 (line 197)

**問題**: 型安全性が低下している。

```dart
Future<HttpServer> start({
  int port = 6060,
  dynamic host,  // <- dynamic
  bool shared = false,
}) async {
```

**推奨**: `Object?` または適切な型を使用する。

```dart
Object? host,  // InternetAddress or String
```

---

### 5. デフォルトのフォールバック動作 (line 316-317)

**問題**: 不明な型の場合 `toString()` が呼ばれるが、これは意図した動作か不明確。

```dart
default:
  // Fallback: convert to string
  await ctx.res.text(result.toString());
```

**検討事項**:
- 例外を投げるべきか?
- 警告ログを出すべきか?
- 明示的に許可された型のみ対応するべきか?

---

### 6. ChaseGroup の委譲チェーン (line 391-392)

**問題**: ネストしたグループで `_buildMiddlewareChain` が親に委譲される。深いネストで非効率になる可能性。

```dart
@override
Handler _buildMiddlewareChain(List<Middleware> middlewares, Handler handler) =>
    _parent._buildMiddlewareChain(middlewares, handler);
```

**影響**: 軽微。深いネストは一般的ではないため、実際の問題になることは少ない。

---

## 改善優先度

| 優先度 | 項目 | 状態 |
|--------|------|------|
| 高 | #1 ミドルウェアチェーン | **FIXED** |
| 高 | #3 Map型チェック | 未対応 |
| 中 | #2 NotFoundHandler | **FIXED** |
| 低 | #4 host型 | 未対応 |
| 低 | #5 フォールバック | 未対応 |
| 低 | #6 委譲チェーン | 未対応 |
