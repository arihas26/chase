# Installation

## Requirements

- Dart SDK 3.0 or higher

## Add Dependency

Add chase to your `pubspec.yaml`:

```yaml
dependencies:
  chase: ^0.1.0
```

Then run:

```bash
dart pub get
```

## Verify Installation

Create a simple server to verify:

```dart
import 'package:chase/chase.dart';

void main() async {
  final app = Chase();

  app.get('/').handle((ctx) => 'chase is working!');

  await app.start(port: 6060);
  print('Server running on http://localhost:6060');
}
```

Run it:

```bash
dart run bin/server.dart
```

Visit http://localhost:6060 in your browser.

## Development Mode

Enable development mode for helpful debugging:

```dart
final app = Chase(dev: true);
```

This will:
- Print registered routes on startup
- Show more detailed error messages
