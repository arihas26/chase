<p align="center">
  <img src="/chase/assets/chase-logo.png" alt="Chase Logo" width="400">
</p>

<p align="center">
  A fast, lightweight web framework for Dart
</p>

<p align="center">
  <a href="https://dart.dev"><img src="https://img.shields.io/badge/Dart-3.10+-blue.svg" alt="Dart"></a>
  <a href="https://pub.dev/packages/chase"><img src="https://img.shields.io/pub/v/chase.svg" alt="Pub"></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT"></a>
</p>

## Features

- 🚀 **Fast** - Trie-based router for optimal performance
- 🪶 **Lightweight** - Minimal dependencies, small footprint
- 🧩 **Middleware** - 18+ built-in middleware, easy to extend
- 🔌 **Plugin System** - Extend functionality with plugins
- 🌐 **Real-time** - WebSocket, SSE, streaming support
- ✅ **Validation** - Schema-based request validation
- 🌍 **i18n** - Built-in internationalization
- 🧪 **Testing** - First-class testing utilities

## Quick Start

```dart
import 'package:chase/chase.dart';

void main() async {
  final app = Chase();

  app.get('/').handle((ctx) => 'Hello, World!');

  app.get('/hello/:name').handle((ctx) {
    final name = ctx.req.param('name');
    return {'message': 'Hello, $name!'};
  });

  await app.start(port: 6060);
}
```

## Installation

```yaml
dependencies:
  chase: ^0.1.0
```

## Documentation

- [Installation](installation.md)
- [Quick Start](quickstart.md)
- [Routing](routing.md)
- [Middleware](middleware.md)
- [Request & Response](request-response.md)
- [Context](context.md)
- [Testing](testing.md)

## Links

- [GitHub Repository](https://github.com/arihas26/chase)
- [pub.dev](https://pub.dev/packages/chase)
- [API Documentation](https://pub.dev/documentation/chase/latest/)
