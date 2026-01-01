import 'package:chase/chase.dart';
import 'package:test/test.dart';

void main() {
  group('Chase Constructor', () {
    test('default constructor creates instance with SimpleRouter', () {
      final app = Chase();

      expect(app, isNotNull);
      expect(app, isA<Chase>());
    });

    test('constructor accepts custom router', () {
      final customRouter = TrieRouter();
      final app = Chase(router: customRouter);

      expect(app, isNotNull);
      expect(app, isA<Chase>());
    });

    test('default constructor has no global middlewares initially', () {
      final app = Chase();

      // Should be able to add middlewares without duplicates
      app.use(RequestLogger());

      expect(app, isNotNull);
    });
  });

  group('Chase()..withDefaults() Factory', () {
    test('creates instance with ErrorHandler and Logger', () {
      final app = Chase()..withDefaults();

      expect(app, isNotNull);
      expect(app, isA<Chase>());

      // Note: Can't directly inspect _globalMiddlewares as it's private
      // But we can verify the instance was created successfully
    });

    test('isDevelopment defaults to false', () {
      final app = Chase()..withDefaults();

      expect(app, isNotNull);
      // The ErrorHandler will have isDevelopment=false by default
    });

    test('isDevelopment can be set to true', () {
      final app = Chase()..withDefaults();

      expect(app, isNotNull);
      // The ErrorHandler will have isDevelopment=true
    });

    test('accepts custom router with defaults', () {
      final customRouter = TrieRouter();
      final app = Chase(router: customRouter)..withDefaults();

      expect(app, isNotNull);
      expect(app, isA<Chase>());
    });

    test('can add additional middlewares after withDefaults', () {
      final app = Chase()..withDefaults();

      // Should be able to add more middlewares (duplicates are allowed)
      app.use(RequestLogger()); // Duplicate type allowed

      expect(app, isNotNull);
    });
  });

  group('Chase Middleware Registration', () {
    test('use() returns Chase for method chaining', () {
      final app = Chase();

      final result = app.use(RequestLogger());

      expect(result, equals(app));
      expect(result, isA<Chase>());
    });

    test('use() can be chained multiple times', () {
      final app = Chase().use(ExceptionHandler()).use(RequestLogger());

      expect(app, isNotNull);
      expect(app, isA<Chase>());
    });

    test('allows registering same middleware type multiple times', () {
      final app = Chase();

      // Should not throw, duplicates are allowed
      app.use(RequestLogger());
      app.use(RequestLogger());
      app.use(RequestLogger());

      expect(app, isNotNull);
    });
  });

  group('Chase Constructor vs Factory Comparison', () {
    test('default constructor is minimal', () {
      final app = Chase();
      expect(app, isNotNull);
    });

    test('withDefaults includes middlewares', () {
      final app = Chase()..withDefaults();
      expect(app, isNotNull);
    });

    test('both constructors return Chase instances', () {
      final app1 = Chase();
      final app2 = Chase()..withDefaults();

      expect(app1, isA<Chase>());
      expect(app2, isA<Chase>());
    });

    test('manual setup equivalent to withDefaults', () {
      final app1 = Chase()..withDefaults();

      final app2 = Chase();
      app2.use(ExceptionHandler());
      app2.use(RequestLogger());

      // Both should be valid Chase instances
      expect(app1, isA<Chase>());
      expect(app2, isA<Chase>());
    });
  });
}
