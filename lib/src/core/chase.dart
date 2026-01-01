import 'dart:async';
import 'dart:io';

import 'package:chase/src/core/context/context.dart';
import 'package:chase/src/core/handler.dart';
import 'package:zlogger/zlogger.dart';
import 'package:chase/src/core/middleware.dart';
import 'package:chase/src/core/plugin.dart';
import 'package:chase/src/core/response.dart';
import 'package:chase/src/core/router.dart';

import 'package:chase/src/router/trie_router/trie_router.dart';

// =============================================================================
// Chase - Main Application
// =============================================================================

/// The main Chase application class.
///
/// Chase is a lightweight, fast HTTP server framework for Dart inspired by
/// [Hono](https://hono.dev/). It provides a simple and intuitive API for
/// building web applications and APIs.
///
/// ## Example
///
/// ```dart
/// final app = Chase();
/// app.get('/').handle((ctx) => ctx.res.text('Hello!'));
/// await app.start(port: 6060);
/// ```
///
/// ## See also
///
/// * [ChaseGroup], for organizing routes under a common prefix.
/// * [ChaseBuilder], for configuring individual routes with middleware.
/// * [Middleware], for creating request/response interceptors.
/// * [Context], for accessing request and response objects in handlers.
class Chase extends _ChaseBase<Chase> {
  final Router _router;
  final List<({String method, String path})> _routes = [];
  final List<Plugin> _plugins = [];
  final Set<String> _pluginNames = {};
  final bool _dev;
  HttpServer? _server;
  ErrorHandler? _errorHandler;
  Handler? _notFoundHandler;
  Handler? _cachedNotFoundHandler;
  final List<FutureOr<void> Function()> _onStartCallbacks = [];
  final List<FutureOr<void> Function()> _onStopCallbacks = [];
  MethodOverrideConfig? _methodOverrideConfig;

  @override
  final String _prefix = '/';

  @override
  final List<Middleware> _middlewares = [];

  /// Creates a new Chase application.
  ///
  /// Parameters:
  /// - [router]: Custom router implementation. Defaults to [TrieRouter].
  /// - [dev]: Enable development mode for debugging. When true, registered
  ///   routes are printed to console on server start.
  ///
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Default configuration
  /// final app = Chase();
  ///
  /// // Development mode
  /// final app = Chase(dev: true);
  ///
  /// // Custom router
  /// final app = Chase(router: MyCustomRouter());
  /// ```
  Chase({Router? router, bool dev = false})
    : _router = router ?? TrieRouter(),
      _dev = dev;

  /// The underlying HTTP server instance.
  ///
  /// Returns `null` if the server has not been started.
  HttpServer? get server => _server;

  /// Whether the server is currently running.
  bool get isRunning => _server != null;

  // ---------------------------------------------------------------------------
  // Logging
  // ---------------------------------------------------------------------------

  /// Application-level logger.
  ///
  /// Use this for logs outside of request context (startup, shutdown, etc.).
  ///
  /// ## Example
  ///
  /// ```dart
  /// app.log.info('Server starting', {'port': 8080});
  /// app.log.error('Failed to connect to database', {'host': dbHost}, e);
  /// ```
  Logger get log => LogConfig.global;

  /// Sets a custom logger for the application.
  ///
  /// This affects both `app.log` and `ctx.log`.
  ///
  /// ## Example
  ///
  /// ```dart
  /// app.logger = DefaultLogger(
  ///   minLevel: LogLevel.info,
  ///   json: true,
  /// );
  /// ```
  set logger(Logger logger) => LogConfig.global = logger;

  // ---------------------------------------------------------------------------
  // Plugins
  // ---------------------------------------------------------------------------

  /// Installs a plugin.
  ///
  /// Each plugin can only be installed once (checked by [Plugin.name]).
  ///
  /// ## Example
  ///
  /// ```dart
  /// final app = Chase()
  ///   ..plugin(MetricsPlugin())
  ///   ..plugin(HealthCheckPlugin());
  /// ```
  Chase plugin(Plugin plugin) {
    if (_pluginNames.contains(plugin.name)) {
      throw StateError('Plugin "${plugin.name}" is already installed');
    }
    _pluginNames.add(plugin.name);
    _plugins.add(plugin);
    plugin.onInstall(this);
    return this;
  }

  // ---------------------------------------------------------------------------
  // Error Handling
  // ---------------------------------------------------------------------------

  /// Sets a global error handler for uncaught exceptions.
  ///
  /// The handler receives the error, stack trace, and context, allowing
  /// custom error responses.
  ///
  /// ## Example
  ///
  /// ```dart
  /// app.onError((error, stackTrace, ctx) {
  ///   print('Error: $error');
  ///   return {'error': error.toString(), 'status': 'error'};
  /// });
  /// ```
  Chase onError(ErrorHandler handler) {
    _errorHandler = handler;
    return this;
  }

  /// Sets a custom handler for 404 Not Found responses.
  ///
  /// ## Example
  ///
  /// ```dart
  /// app.notFound((ctx) => {
  ///   'error': 'Not Found',
  ///   'path': ctx.req.path,
  ///   'method': ctx.req.method,
  /// });
  /// ```
  Chase notFound(Handler handler) {
    _notFoundHandler = handler;
    return this;
  }

  /// Enables HTTP method override for HTML forms.
  ///
  /// HTML forms can only send GET and POST requests. This feature allows
  /// overriding the HTTP method using a form field, query parameter, or header.
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Enable with defaults (form field: _method)
  /// app.methodOverride();
  ///
  /// // Enable with custom options
  /// app.methodOverride(
  ///   form: '_method',           // Form field name
  ///   header: 'X-HTTP-Method',   // Header name
  ///   query: '_method',          // Query parameter name
  /// );
  /// ```
  ///
  /// ## HTML Form Example
  ///
  /// ```html
  /// <form action="/posts/123" method="POST">
  ///   <input type="hidden" name="_method" value="DELETE" />
  ///   <button type="submit">Delete</button>
  /// </form>
  /// ```
  Chase methodOverride({
    String? form = '_method',
    String? header,
    String? query,
  }) {
    _methodOverrideConfig = MethodOverrideConfig(
      form: form,
      header: header,
      query: query,
    );
    return this;
  }

  // ---------------------------------------------------------------------------
  // Server Lifecycle
  // ---------------------------------------------------------------------------

  /// Registers a callback to run when the server starts.
  ///
  /// Multiple callbacks can be registered and will run in order.
  ///
  /// ## Example
  ///
  /// ```dart
  /// app.onStart(() => print('Server starting...'));
  /// app.onStart(() async => await db.connect());
  /// ```
  Chase onStart(FutureOr<void> Function() callback) {
    _onStartCallbacks.add(callback);
    return this;
  }

  /// Registers a callback to run when the server stops.
  ///
  /// Multiple callbacks can be registered and will run in reverse order.
  ///
  /// ## Example
  ///
  /// ```dart
  /// app.onStop(() => print('Server stopping...'));
  /// app.onStop(() async => await db.close());
  /// ```
  Chase onStop(FutureOr<void> Function() callback) {
    _onStopCallbacks.add(callback);
    return this;
  }

  /// Starts the HTTP server and begins listening for requests.
  ///
  /// ## Example
  ///
  /// ```dart
  /// await app.start(port: 8080);
  /// ```
  ///
  /// ## Throws
  ///
  /// * [SocketException] if the port is already in use.
  Future<HttpServer> start({
    int port = 6060,
    Object? host,
    bool shared = false,
  }) async {
    if (_dev) {
      printRoutes();
    }

    // Call onStart callbacks
    for (final callback in _onStartCallbacks) {
      await callback();
    }

    // Call onStart for all plugins
    for (final plugin in _plugins) {
      await plugin.onStart(this);
    }

    // Cache not found handler (with middleware chain if applicable)
    final notFoundBase = _notFoundHandler ?? _defaultNotFoundHandler;
    _cachedNotFoundHandler = _buildMiddlewareChain(_middlewares, notFoundBase);

    final bindHost = host ?? InternetAddress.anyIPv4;
    _server = await HttpServer.bind(bindHost, port, shared: shared);
    print('Server running on http://localhost:$port/');

    _server!.listen(_handleRequest);
    return _server!;
  }

  /// Stops the HTTP server.
  ///
  /// Set [force] to `true` to close active connections immediately.
  Future<void> stop({bool force = false}) async {
    // Call onStop for all plugins (reverse order)
    for (final plugin in _plugins.reversed) {
      await plugin.onStop(this);
    }

    // Call onStop callbacks (reverse order)
    for (final callback in _onStopCallbacks.reversed) {
      await callback();
    }

    await _server?.close(force: force);
    _server = null;
  }

  // ---------------------------------------------------------------------------
  // Debug
  // ---------------------------------------------------------------------------

  /// Prints all registered routes to the console.
  ///
  /// Useful for debugging route configuration. This method is automatically
  /// called on server start when [dev] mode is enabled.
  ///
  /// Example output:
  /// ```
  /// Routes:
  ///   GET     /
  ///   GET     /users
  ///   POST    /users
  ///   GET     /users/:id
  ///   DELETE  /users/:id
  /// ```
  void printRoutes() {
    print('Routes:');
    for (final route in _routes) {
      print('  ${route.method.padRight(7)} ${route.path}');
    }
  }

  // ---------------------------------------------------------------------------
  // Request Handling
  // ---------------------------------------------------------------------------

  Future<void> _handleRequest(HttpRequest req) async {
    // Check for method override before routing
    String? methodOverride;
    if (_methodOverrideConfig != null && req.method == 'POST') {
      methodOverride = await _getMethodOverride(req);
    }

    final method = methodOverride ?? req.method;
    final route = _router.match(method, req.uri.path);
    // Handler already has middleware chain built at registration time
    final handler = route?.handler ?? _cachedNotFoundHandler ?? _defaultNotFoundHandler;
    final ctx = Context(req, req.response, route?.params, methodOverride);

    try {
      final result = await handler(ctx);
      await _sendResponse(ctx, result);
    } catch (e, st) {
      if (ctx.res.isSent) return;
      await _handleError(e, st, ctx);
    }
  }

  Future<void> _handleError(Object error, StackTrace stackTrace, Context ctx) async {
    if (_errorHandler != null) {
      try {
        final result = await _errorHandler!(error, stackTrace, ctx);
        await _sendResponse(ctx, result);
      } catch (e) {
        // Error handler itself threw
        await ctx.res.text('Internal Server Error', status: HttpStatus.internalServerError);
      }
    } else {
      await ctx.res.text('Internal Server Error', status: HttpStatus.internalServerError);
    }
  }

  Future<void> _sendResponse(Context ctx, dynamic result) async {
    // Skip if response already sent
    if (ctx.res.isSent) return;

    // Handle return value based on type
    switch (result) {
      case Response response:
        await response.writeTo(
          ctx.req.$raw.response,
          prettyJson: ctx.res.prettyJson,
        );
      case String text:
        await ctx.res.text(text);
      case Map json:
        await ctx.res.json(json);
      case List list:
        await ctx.res.json(list);
      case null:
        // Handler used ctx.res directly or returned nothing
        break;
      default:
        // Objects with toJson() will be serialized
        await ctx.res.json(result);
    }
  }

  static Future<void> _defaultNotFoundHandler(Context ctx) async {
    await ctx.res.notFound();
  }

  /// Gets the overridden HTTP method from header, query, or form.
  Future<String?> _getMethodOverride(HttpRequest req) async {
    final config = _methodOverrideConfig!;
    final allowedMethods = {'PUT', 'PATCH', 'DELETE'};

    // Check header first (cheapest)
    if (config.header != null) {
      final value = req.headers.value(config.header!)?.toUpperCase();
      if (value != null && allowedMethods.contains(value)) {
        return value;
      }
    }

    // Check query parameter
    if (config.query != null) {
      final value = req.uri.queryParameters[config.query]?.toUpperCase();
      if (value != null && allowedMethods.contains(value)) {
        return value;
      }
    }

    // Check form field (requires parsing body)
    if (config.form != null) {
      final contentType = req.headers.contentType;
      if (contentType?.mimeType == 'application/x-www-form-urlencoded') {
        try {
          final body = await req.cast<List<int>>().expand((x) => x).toList();
          final text = String.fromCharCodes(body);
          final params = Uri.splitQueryString(text);
          final value = params[config.form]?.toUpperCase();
          if (value != null && allowedMethods.contains(value)) {
            return value;
          }
        } catch (_) {
          // Ignore parsing errors
        }
      }
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // Route Registration (Internal)
  // ---------------------------------------------------------------------------

  @override
  void _addRoute(String method, String path, Handler handler) {
    _routes.add((method: method, path: path));
    // Build middleware chain at registration time for better performance
    final wrappedHandler = _buildMiddlewareChain(_middlewares, handler);
    _router.add(method, path, wrappedHandler);
  }
}

// =============================================================================
// ChaseGroup - Route Grouping
// =============================================================================

/// A route group that organizes routes under a common path prefix.
///
/// Route groups share a path prefix and can have their own middleware.
///
/// ## Example
///
/// ```dart
/// final api = app.path('/api');
/// api.use(AuthMiddleware());
/// api.get('/users').handle(usersHandler);  // GET /api/users
/// ```
///
/// ## See also
///
/// * [Chase.path], for creating groups from the main application.
/// * [Chase.routes], for defining grouped routes with a callback.
/// * [ChaseBuilder], for configuring individual routes.
/// * [Middleware], for adding group-scoped middleware.
class ChaseGroup extends _ChaseBase<ChaseGroup> {
  final _ChaseRouteRegistrar _parent;

  @override
  final String _prefix;

  @override
  final List<Middleware> _middlewares = [];

  /// Creates a new route group.
  ///
  /// This constructor is not called directly. Instead, use
  /// [Chase.path] or [ChaseGroup.path] to create groups.
  ChaseGroup._(this._parent, this._prefix);

  @override
  void _addRoute(String method, String path, Handler handler) => _parent
      ._addRoute(method, path, _buildMiddlewareChain(_middlewares, handler));
}

// =============================================================================
// ChaseBuilder - Route Configuration
// =============================================================================

/// Mixin providing middleware support for route builders.
mixin _BuilderMiddlewareSupport<T> {
  List<Middleware> get _middlewares;

  /// Adds a middleware to this route.
  T use(Middleware middleware) {
    _middlewares.add(middleware);
    return this as T;
  }

  /// Adds multiple middlewares to this route.
  T useAll(List<Middleware> middlewares) {
    _middlewares.addAll(middlewares);
    return this as T;
  }
}

/// A builder for configuring and registering a single route.
///
/// Provides a fluent API for adding route-specific middleware.
///
/// ## Example
///
/// ```dart
/// app.get('/admin')
///   .use(AuthMiddleware())
///   .handle(adminHandler);
/// ```
///
/// ## See also
///
/// * [Middleware], for creating custom request/response interceptors.
/// * [Handler], for the request handler function signature.
/// * [Context], for the context object passed to handlers.
class ChaseBuilder with _BuilderMiddlewareSupport<ChaseBuilder> {
  final _ChaseRouteRegistrar _registrar;
  final String _method;
  final List<String> _paths;

  @override
  final List<Middleware> _middlewares = [];

  /// Creates a new route builder.
  ///
  /// This constructor is typically not called directly. Instead, use
  /// HTTP method helpers like [Chase.get], [Chase.post], etc.
  ChaseBuilder._(this._registrar, this._method, this._paths);

  /// Registers the handler for this route.
  void handle(Handler handler) {
    final wrappedHandler = _buildMiddlewareChain(_middlewares, handler);
    for (final path in _paths) {
      _registrar._addRoute(_method, path, wrappedHandler);
    }
  }
}

// =============================================================================
// ChaseBuilderAll - Route Configuration for All Methods
// =============================================================================

/// All standard HTTP methods that [ChaseBuilderAll] registers handlers for.
const _allHttpMethods = ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'HEAD', 'OPTIONS'];

/// A builder for configuring routes that match ALL HTTP methods.
///
/// Similar to [ChaseBuilder] but registers the handler for every HTTP method.
///
/// ## Example
///
/// ```dart
/// app.all('/api/*')
///   .use(AuthMiddleware())
///   .handle(proxyHandler);
/// ```
///
/// ## See also
///
/// * [ChaseBuilder], for single-method route configuration.
/// * [Middleware], for creating custom request/response interceptors.
class ChaseBuilderAll with _BuilderMiddlewareSupport<ChaseBuilderAll> {
  final _ChaseRouteRegistrar _registrar;
  final List<String> _paths;

  @override
  final List<Middleware> _middlewares = [];

  ChaseBuilderAll._(this._registrar, this._paths);

  /// Registers the handler for ALL HTTP methods on this route.
  void handle(Handler handler) {
    final wrappedHandler = _buildMiddlewareChain(_middlewares, handler);
    for (final path in _paths) {
      for (final method in _allHttpMethods) {
        _registrar._addRoute(method, path, wrappedHandler);
      }
    }
  }
}

// =============================================================================
// ChaseBuilderOn - Route Configuration for Specific Methods
// =============================================================================

/// A builder for configuring routes that match specific HTTP methods.
///
/// Similar to [ChaseBuilder] but registers the handler for multiple methods.
///
/// ## Example
///
/// ```dart
/// app.on(['GET', 'POST'], '/form')
///   .use(CsrfMiddleware())
///   .handle(formHandler);
/// ```
///
/// ## See also
///
/// * [ChaseBuilder], for single-method route configuration.
/// * [ChaseBuilderAll], for all-method route configuration.
class ChaseBuilderOn with _BuilderMiddlewareSupport<ChaseBuilderOn> {
  final _ChaseRouteRegistrar _registrar;
  final List<String> _methods;
  final List<String> _paths;

  @override
  final List<Middleware> _middlewares = [];

  ChaseBuilderOn._(this._registrar, List<String> methods, this._paths)
      : _methods = methods.map((m) => m.toUpperCase()).toList();

  /// Registers the handler for the specified HTTP methods on this route.
  void handle(Handler handler) {
    final wrappedHandler = _buildMiddlewareChain(_middlewares, handler);
    for (final path in _paths) {
      for (final method in _methods) {
        _registrar._addRoute(method, path, wrappedHandler);
      }
    }
  }
}

// =============================================================================
// Internal Route Registration Interface
// =============================================================================

/// Internal interface for route registration.
abstract class _ChaseRouteRegistrar {
  void _addRoute(String method, String path, Handler handler);
}

// =============================================================================
// _ChaseBase - Shared Implementation
// =============================================================================

/// Base class providing common functionality for [Chase] and [ChaseGroup].
///
/// This abstract class implements shared behavior including:
/// - HTTP method helpers (get, post, put, patch, delete, head, options)
/// - Middleware registration (use, useAll)
/// - Route grouping (path, routes)
/// - Static file serving (static)
///
/// The type parameter [T] enables fluent method chaining by allowing
/// methods like [use] to return the concrete type.
abstract class _ChaseBase<T extends _ChaseBase<T>>
    implements _ChaseRouteRegistrar {
  /// The path prefix for this registrar.
  ///
  /// For [Chase], this is always '/'.
  /// For [ChaseGroup], this is the group's prefix path.
  String get _prefix;

  /// The list of middleware for this registrar.
  ///
  /// For [Chase], these are global middlewares applied to all routes.
  /// For [ChaseGroup], these are group-specific middlewares.
  List<Middleware> get _middlewares;

  // ---------------------------------------------------------------------------
  // HTTP Methods
  // ---------------------------------------------------------------------------

  /// Creates a GET route builder for the given path(s).
  ///
  /// GET requests are used to retrieve resources.
  ///
  /// You can pass either a single path or a list of paths.
  /// When passing a list, the same handler is registered for all paths.
  ///
  /// ## Example
  ///
  /// ```dart
  /// app.get('/users').handle((ctx) async {
  ///   await ctx.res.json({'users': []});
  /// });
  ///
  /// // Multiple paths with same handler
  /// app.get(['/hello', '/ja/hello']).handle((ctx) async {
  ///   await ctx.res.text('Hello');
  /// });
  /// ```
  ChaseBuilder get([Object path = '/']) =>
      ChaseBuilder._(this, 'GET', _normalizePaths(_prefix, path));

  /// Creates a POST route builder for the given path(s).
  ChaseBuilder post([Object path = '/']) =>
      ChaseBuilder._(this, 'POST', _normalizePaths(_prefix, path));

  /// Creates a PUT route builder for the given path(s).
  ChaseBuilder put([Object path = '/']) =>
      ChaseBuilder._(this, 'PUT', _normalizePaths(_prefix, path));

  /// Creates a PATCH route builder for the given path(s).
  ChaseBuilder patch([Object path = '/']) =>
      ChaseBuilder._(this, 'PATCH', _normalizePaths(_prefix, path));

  /// Creates a DELETE route builder for the given path(s).
  ChaseBuilder delete([Object path = '/']) =>
      ChaseBuilder._(this, 'DELETE', _normalizePaths(_prefix, path));

  /// Creates a HEAD route builder for the given path(s).
  ChaseBuilder head([Object path = '/']) =>
      ChaseBuilder._(this, 'HEAD', _normalizePaths(_prefix, path));

  /// Creates an OPTIONS route builder for the given path(s).
  ChaseBuilder options([Object path = '/']) =>
      ChaseBuilder._(this, 'OPTIONS', _normalizePaths(_prefix, path));

  /// Creates a route builder for any HTTP method with the given path(s).
  ChaseBuilder route(String method, [Object path = '/']) =>
      ChaseBuilder._(this, method.toUpperCase(), _normalizePaths(_prefix, path));

  /// Creates a route builder that matches ALL HTTP methods.
  ///
  /// This is useful for:
  /// - Applying middleware to all methods on a path
  /// - Proxy/forwarding handlers
  /// - Fallback/catch-all routes
  ///
  /// You can pass either a single path or a list of paths.
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Match all methods on /api/*
  /// app.all('/api/*').use(AuthMiddleware()).handle((ctx) => ...);
  ///
  /// // Catch-all fallback
  /// app.all('*').handle((ctx) => ctx.res.notFound());
  ///
  /// // Multiple paths
  /// app.all(['/hello', '/ja/hello']).handle((ctx) => ...);
  /// ```
  ChaseBuilderAll all([Object path = '/']) =>
      ChaseBuilderAll._(this, _normalizePaths(_prefix, path));

  /// Creates a route builder for specific HTTP methods.
  ///
  /// This is useful when you want to handle multiple (but not all) methods
  /// with the same handler.
  ///
  /// You can pass either a single path or a list of paths.
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Handle both GET and POST
  /// app.on(['GET', 'POST'], '/submit').handle((ctx) => ...);
  ///
  /// // Handle read operations
  /// app.on(['GET', 'HEAD'], '/resource').handle((ctx) => ...);
  ///
  /// // Multiple paths
  /// app.on(['GET', 'POST'], ['/form', '/ja/form']).handle((ctx) => ...);
  /// ```
  ChaseBuilderOn on(List<String> methods, [Object path = '/']) =>
      ChaseBuilderOn._(this, methods, _normalizePaths(_prefix, path));

  // ---------------------------------------------------------------------------
  // Middleware
  // ---------------------------------------------------------------------------

  /// Adds a middleware to this registrar.
  ///
  /// ## Example
  ///
  /// ```dart
  /// app.use(LoggerMiddleware());
  /// ```
  T use(Middleware middleware) {
    _middlewares.add(middleware);
    return this as T;
  }

  /// Adds multiple middlewares to this registrar.
  ///
  /// ## Example
  ///
  /// ```dart
  /// app.useAll([LoggerMiddleware(), CorsMiddleware()]);
  /// ```
  T useAll(List<Middleware> middlewares) {
    _middlewares.addAll(middlewares);
    return this as T;
  }

  // ---------------------------------------------------------------------------
  // Route Grouping
  // ---------------------------------------------------------------------------

  /// Creates a route group with the given path prefix.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final api = app.path('/api');
  /// api.get('/users').handle(handler);  // GET /api/users
  /// ```
  ChaseGroup path(String prefix) =>
      ChaseGroup._(this, _joinPaths(_prefix, prefix));

  /// Creates a route group and defines routes within a callback.
  ///
  /// Combines [path] with immediate route definition.
  ///
  /// ## Example
  ///
  /// ```dart
  /// app.routes('/api', (api) {
  ///   api.get('/users').handle(usersHandler);
  /// });
  /// ```
  T routes(String prefix, void Function(ChaseGroup group) define) {
    define(path(prefix));
    return this as T;
  }
}

// =============================================================================
// Private Utilities
// =============================================================================

/// Normalizes a path by ensuring it starts with '/' and doesn't end with '/'.
///
/// Examples:
/// - '' → '/'
/// - 'users' → '/users'
/// - '/users/' → '/users'
/// - '/' → '/'
String _normalizePath(String path) {
  var p = path.trim();
  if (p.isEmpty) p = '/';
  if (!p.startsWith('/')) p = '/$p';
  if (p.length > 1 && p.endsWith('/')) {
    p = p.substring(0, p.length - 1);
  }
  return p;
}

/// Joins two path segments, handling edge cases.
///
/// Examples:
/// - ('/', '/users') → '/users'
/// - ('/api', '/users') → '/api/users'
/// - ('/api', '/') → '/api'
String _joinPaths(String a, String b) {
  final normalizedA = _normalizePath(a);
  final normalizedB = _normalizePath(b);

  if (normalizedA == '/') return normalizedB;
  if (normalizedB == '/') return normalizedA;

  return '$normalizedA$normalizedB';
}

/// Normalizes paths to a list.
///
/// Accepts either a single path string or a list of paths.
/// Each path is joined with the given prefix.
///
/// Examples:
/// - ('/api', '/users') → ['/api/users']
/// - ('/api', ['/hello', '/ja/hello']) → ['/api/hello', '/api/ja/hello']
List<String> _normalizePaths(String prefix, Object path) {
  final paths = path is List<String> ? path : [path as String];
  return paths.map((p) => _joinPaths(prefix, p)).toList();
}

/// Builds a middleware chain by wrapping the handler with each middleware.
///
/// Middlewares are applied in reverse order so the first middleware in the
/// list is the outermost wrapper (executes first).
Handler _buildMiddlewareChain(List<Middleware> middlewares, Handler handler) {
  if (middlewares.isEmpty) return handler;

  return middlewares.reversed.fold(handler, (next, mw) {
    return (ctx) => mw.handle(ctx, () => next(ctx));
  });
}

// =============================================================================
// Method Override Configuration
// =============================================================================

/// Configuration for HTTP method override.
///
/// This allows HTML forms to simulate PUT, PATCH, and DELETE requests
/// by including the method in a form field, query parameter, or header.
class MethodOverrideConfig {
  /// Form field name to check for method override.
  ///
  /// Set to `null` to disable form-based override.
  final String? form;

  /// Header name to check for method override.
  ///
  /// Common values: `X-HTTP-Method-Override`, `X-Method-Override`.
  final String? header;

  /// Query parameter name to check for method override.
  final String? query;

  const MethodOverrideConfig({
    this.form,
    this.header,
    this.query,
  });
}
