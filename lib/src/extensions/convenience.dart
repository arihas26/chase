import 'package:chase/src/core/chase.dart';
import 'package:chase/src/middleware/exception/exception_handler.dart';
import 'package:chase/src/middleware/logger/request_logger.dart';
import 'package:chase/src/middleware/static/static_file_handler.dart';

/// Convenience extension for Chase with common middleware setup.
extension ChaseConvenience on Chase {
  /// Sets up commonly used middleware for development.
  ///
  /// Adds:
  /// - [ExceptionHandler] - Catches exceptions and returns error responses
  /// - [RequestLogger] - Logs requests with method, path, status, and response time
  ///
  /// ## Example
  ///
  /// ```dart
  /// final app = Chase()..withDefaults();
  /// ```
  Chase withDefaults() {
    use(ExceptionHandler());
    use(RequestLogger());
    return this;
  }

  /// Serves static files from a directory.
  ///
  /// ## Example
  ///
  /// ```dart
  /// app.staticFiles('/assets', './public');
  /// ```
  Chase staticFiles(
    String mountPath,
    String rootDirectory, [
    StaticOptions options = const StaticOptions(),
  ]) {
    final handler = StaticFileHandler(
      rootDirectory,
      options: options,
      wildcardParam: 'path',
    );

    final path = _normalizePath(mountPath);
    get(path).handle(handler.call);
    final wildcardPattern = path == '/' ? '/*path' : '$path/*path';
    get(wildcardPattern).handle(handler.call);

    return this;
  }
}

/// Static file serving extension for ChaseGroup.
extension ChaseGroupConvenience on ChaseGroup {
  /// Serves static files from a directory.
  ///
  /// ## Example
  ///
  /// ```dart
  /// group.staticFiles('/assets', './public');
  /// ```
  ChaseGroup staticFiles(
    String mountPath,
    String rootDirectory, [
    StaticOptions options = const StaticOptions(),
  ]) {
    final handler = StaticFileHandler(
      rootDirectory,
      options: options,
      wildcardParam: 'path',
    );

    final path = _normalizePath(mountPath);
    get(path).handle(handler.call);
    final wildcardPattern = path == '/' ? '/*path' : '$path/*path';
    get(wildcardPattern).handle(handler.call);

    return this;
  }
}

String _normalizePath(String path) {
  var p = path.trim();
  if (p.isEmpty) p = '/';
  if (!p.startsWith('/')) p = '/$p';
  if (p.length > 1 && p.endsWith('/')) {
    p = p.substring(0, p.length - 1);
  }
  return p;
}
