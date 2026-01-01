import 'package:chase/chase.dart';

import 'metrics.dart';

/// Prometheus-style metrics plugin for Chase.
///
/// Collects HTTP request metrics and exposes them at a configurable endpoint.
///
/// ## Example
///
/// ```dart
/// final app = Chase()
///   ..plugin(MetricsPlugin());
///
/// // Metrics available at GET /metrics
/// ```
///
/// ## Collected Metrics
///
/// - `http_requests_total` - Total number of HTTP requests (counter)
/// - `http_request_duration_seconds` - Request duration (histogram)
///
/// Labels: `method`, `path`, `status`
class MetricsPlugin extends Plugin {
  /// The endpoint path for metrics. Defaults to `/metrics`.
  final String path;

  /// The metrics collector instance.
  final Metrics metrics;

  /// Creates a new MetricsPlugin.
  ///
  /// - [path]: The endpoint to expose metrics. Defaults to `/metrics`.
  /// - [metrics]: Optional custom Metrics instance. Defaults to a new instance.
  MetricsPlugin({this.path = '/metrics', Metrics? metrics})
    : metrics = metrics ?? Metrics();

  @override
  String get name => 'metrics';

  @override
  void onInstall(Chase app) {
    // Add metrics collection middleware
    app.use(_MetricsMiddleware(metrics));

    // Add metrics endpoint
    app.get(path).handle((ctx) {
      return Response.ok()
          .header('content-type', 'text/plain; version=0.0.4; charset=utf-8')
          .text(metrics.export());
    });
  }
}

class _MetricsMiddleware extends Middleware {
  final Metrics metrics;

  _MetricsMiddleware(this.metrics);

  @override
  Future<void> handle(Context ctx, NextFunction next) async {
    final stopwatch = Stopwatch()..start();

    try {
      await next();
    } finally {
      stopwatch.stop();

      final labels = {
        'method': ctx.req.method,
        'path': _normalizePath(ctx.req.path),
        'status': ctx.res.statusCode.toString(),
      };

      metrics.increment('http_requests_total', labels: labels);
      metrics.observe(
        'http_request_duration_seconds',
        stopwatch.elapsedMicroseconds / 1000000,
        labels: labels,
      );
    }
  }

  /// Normalizes path by replacing dynamic segments with placeholders.
  String _normalizePath(String path) {
    // Replace UUID-like patterns
    var normalized = path.replaceAll(
      RegExp(
        r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
        caseSensitive: false,
      ),
      ':id',
    );
    // Replace numeric IDs
    normalized = normalized.replaceAll(RegExp(r'/\d+'), '/:id');
    return normalized;
  }
}
