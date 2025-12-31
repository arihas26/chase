import 'dart:async';

import 'package:chase/src/core/chase.dart';

/// Base class for Chase plugins.
///
/// Plugins extend Chase functionality by adding routes, middleware,
/// or lifecycle hooks. Unlike middleware which runs on every request,
/// plugins are installed once and can configure the application.
///
/// ## Example
///
/// ```dart
/// class HealthCheckPlugin extends Plugin {
///   @override
///   String get name => 'health-check';
///
///   @override
///   void onInstall(Chase app) {
///     app.get('/health').handle((ctx) => ctx.res.json({'status': 'ok'}));
///   }
/// }
///
/// final app = Chase()..plugin(HealthCheckPlugin());
/// ```
///
/// ## Lifecycle
///
/// 1. [onInstall] - Called when `app.plugin()` is invoked
/// 2. [onStart] - Called when the server starts
/// 3. [onStop] - Called when the server stops
abstract class Plugin {
  /// Unique plugin name.
  ///
  /// Used to prevent duplicate plugin installation.
  String get name;

  /// Called when the plugin is installed via `app.plugin()`.
  ///
  /// Use this to add routes, middleware, or configure the app.
  void onInstall(Chase app);

  /// Called when the server starts.
  ///
  /// Override to perform async initialization (e.g., connect to services).
  FutureOr<void> onStart(Chase app) {}

  /// Called when the server stops.
  ///
  /// Override to perform cleanup (e.g., close connections).
  FutureOr<void> onStop(Chase app) {}
}
