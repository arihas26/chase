import 'package:chase/chase.dart';
import 'package:chase/testing/testing.dart';
import 'package:test/test.dart';

class _TestPlugin extends Plugin {
  bool installed = false;
  bool started = false;
  bool stopped = false;

  @override
  String get name => 'test-plugin';

  @override
  void onInstall(Chase app) {
    installed = true;
    app.get('/plugin-test').handle((ctx) => 'plugin works');
  }

  @override
  Future<void> onStart(Chase app) async {
    started = true;
  }

  @override
  Future<void> onStop(Chase app) async {
    stopped = true;
  }
}

class _DuplicatePlugin extends Plugin {
  @override
  String get name => 'test-plugin'; // Same name as _TestPlugin

  @override
  void onInstall(Chase app) {}
}

void main() {
  group('Plugin', () {
    test('onInstall is called when plugin is added', () {
      final app = Chase();
      final plugin = _TestPlugin();

      app.plugin(plugin);

      expect(plugin.installed, isTrue);
    });

    test('plugin can add routes', () async {
      final app = Chase();
      app.plugin(_TestPlugin());

      final client = await TestClient.start(app);
      addTearDown(() => client.close());

      final res = await client.get('/plugin-test');

      expect(res.status, 200);
      expect(await res.body, 'plugin works');
    });

    test('onStart is called when server starts', () async {
      final app = Chase();
      final plugin = _TestPlugin();
      app.plugin(plugin);

      expect(plugin.started, isFalse);

      final client = await TestClient.start(app);
      addTearDown(() => client.close());

      expect(plugin.started, isTrue);
    });

    test('duplicate plugin throws error', () {
      final app = Chase();
      final plugin1 = _TestPlugin();
      final plugin2 = _DuplicatePlugin();

      app.plugin(plugin1);

      expect(() => app.plugin(plugin2), throwsA(isA<StateError>()));
    });

    test('multiple different plugins can be installed', () async {
      final app = Chase();

      final plugin1 = _TestPlugin();
      final plugin2 = _AnotherPlugin();

      app.plugin(plugin1);
      app.plugin(plugin2);

      final client = await TestClient.start(app);
      addTearDown(() => client.close());

      expect(plugin1.started, isTrue);
      expect(plugin2.started, isTrue);
    });
  });
}

class _AnotherPlugin extends Plugin {
  bool started = false;

  @override
  String get name => 'another-plugin';

  @override
  void onInstall(Chase app) {}

  @override
  Future<void> onStart(Chase app) async {
    started = true;
  }
}
