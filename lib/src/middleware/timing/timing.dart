import 'dart:async';

import 'package:chase/chase.dart';

/// Key for storing timing metrics in context.
const _timingMetricsKey = '_timing_metrics';
const _timingStartTimesKey = '_timing_start_times';

/// Middleware that adds Server-Timing headers for performance monitoring.
///
/// The Server-Timing header communicates performance metrics to the browser's
/// developer tools, useful for debugging and monitoring.
///
/// ## Example
///
/// ```dart
/// final app = Chase();
/// app.use(Timing());
///
/// app.get('/users').handle((ctx) async {
///   // Measure database query
///   startTime(ctx, 'db');
///   final users = await db.getUsers();
///   endTime(ctx, 'db');
///
///   // Add custom metric
///   setMetric(ctx, 'cache', desc: 'Cache status', value: 'hit');
///
///   return users;
/// });
/// ```
///
/// ## Response Header
///
/// ```
/// Server-Timing: total;dur=123.45;desc="Total Response Time", db;dur=45.2
/// ```
///
/// ## Browser DevTools
///
/// The metrics appear in the Network tab under "Timing" for each request.
class Timing implements Middleware {
  /// Whether to include total response time.
  final bool total;

  /// Description for the total metric.
  final String totalDescription;

  /// Whether timing is enabled.
  ///
  /// Can be a boolean or a function that receives the context.
  final bool Function(Context ctx)? enabled;

  /// Whether to automatically end unfinished timers.
  final bool autoEnd;

  /// Cross-origin setting for Timing-Allow-Origin header.
  ///
  /// - `null`: Don't set the header
  /// - `'*'`: Allow all origins
  /// - Custom value: Specific origin
  final String? crossOrigin;

  /// Creates a Timing middleware.
  const Timing({
    this.total = true,
    this.totalDescription = 'Total Response Time',
    this.enabled,
    this.autoEnd = true,
    this.crossOrigin,
  });

  @override
  FutureOr<void> handle(Context ctx, NextFunction next) async {
    // Check if timing is enabled
    if (enabled != null && !enabled!(ctx)) {
      return next();
    }

    // Initialize timing storage
    ctx.set<List<_TimingMetric>>(_timingMetricsKey, []);
    ctx.set<Map<String, Stopwatch>>(_timingStartTimesKey, {});

    final totalStopwatch = Stopwatch()..start();

    await next();

    totalStopwatch.stop();

    // Auto-end any unfinished timers
    if (autoEnd) {
      final startTimes = ctx.get<Map<String, Stopwatch>>(_timingStartTimesKey);
      if (startTimes != null) {
        for (final entry in startTimes.entries) {
          if (entry.value.isRunning) {
            entry.value.stop();
            _addMetric(
              ctx,
              _TimingMetric(
                name: entry.key,
                duration: entry.value.elapsedMicroseconds / 1000,
              ),
            );
          }
        }
      }
    }

    // Add total time if enabled
    if (total) {
      _addMetric(
        ctx,
        _TimingMetric(
          name: 'total',
          duration: totalStopwatch.elapsedMicroseconds / 1000,
          description: totalDescription,
        ),
      );
    }

    // Build and set Server-Timing header
    final metrics = ctx.get<List<_TimingMetric>>(_timingMetricsKey);
    if (metrics != null && metrics.isNotEmpty) {
      final headerValue = metrics.map((m) => m.toHeaderValue()).join(', ');
      ctx.res.headers.set('Server-Timing', headerValue);
    }

    // Set Timing-Allow-Origin if specified
    if (crossOrigin != null) {
      ctx.res.headers.set('Timing-Allow-Origin', crossOrigin!);
    }
  }
}

/// A single timing metric.
class _TimingMetric {
  final String name;
  final double? duration;
  final String? description;
  final String? value;

  _TimingMetric({
    required this.name,
    this.duration,
    this.description,
    this.value,
  });

  String toHeaderValue() {
    final parts = <String>[name];

    if (duration != null) {
      parts.add('dur=${duration!.toStringAsFixed(2)}');
    }

    if (description != null) {
      parts.add('desc="${_escapeDescription(description!)}"');
    }

    if (value != null) {
      parts.add('value="${_escapeDescription(value!)}"');
    }

    return parts.join(';');
  }

  static String _escapeDescription(String desc) {
    return desc.replaceAll('"', '\\"').replaceAll('\n', ' ');
  }
}

void _addMetric(Context ctx, _TimingMetric metric) {
  final metrics = ctx.get<List<_TimingMetric>>(_timingMetricsKey);
  metrics?.add(metric);
}

/// Starts a timer with the given name.
///
/// Use [endTime] to stop the timer and record the duration.
///
/// ```dart
/// startTime(ctx, 'db');
/// final data = await db.query();
/// endTime(ctx, 'db');
/// ```
void startTime(Context ctx, String name, {String? description}) {
  final startTimes = ctx.get<Map<String, Stopwatch>>(_timingStartTimesKey);
  if (startTimes == null) return;

  final stopwatch = Stopwatch()..start();
  startTimes[name] = stopwatch;

  // Store description for later
  if (description != null) {
    ctx.set('_timing_desc_$name', description);
  }
}

/// Ends a timer started with [startTime] and records the metric.
///
/// ```dart
/// startTime(ctx, 'db');
/// final data = await db.query();
/// endTime(ctx, 'db');
/// ```
void endTime(Context ctx, String name) {
  final startTimes = ctx.get<Map<String, Stopwatch>>(_timingStartTimesKey);
  if (startTimes == null) return;

  final stopwatch = startTimes.remove(name);
  if (stopwatch == null) return;

  stopwatch.stop();
  final description = ctx.get<String>('_timing_desc_$name');

  _addMetric(
    ctx,
    _TimingMetric(
      name: name,
      duration: stopwatch.elapsedMicroseconds / 1000,
      description: description,
    ),
  );
}

/// Sets a custom metric.
///
/// ```dart
/// // With duration
/// setMetric(ctx, 'db', duration: 45.2);
///
/// // With description
/// setMetric(ctx, 'cache', desc: 'Cache status', value: 'hit');
///
/// // Simple label
/// setMetric(ctx, 'region', value: 'us-west-1');
/// ```
void setMetric(
  Context ctx,
  String name, {
  double? duration,
  String? desc,
  String? value,
}) {
  _addMetric(
    ctx,
    _TimingMetric(
      name: name,
      duration: duration,
      description: desc,
      value: value,
    ),
  );
}

/// Times an async operation and records the metric.
///
/// ```dart
/// final users = await timeAsync(ctx, 'db', () => db.getUsers());
/// ```
Future<T> timeAsync<T>(
  Context ctx,
  String name,
  Future<T> Function() operation, {
  String? description,
}) async {
  startTime(ctx, name, description: description);
  try {
    return await operation();
  } finally {
    endTime(ctx, name);
  }
}

/// Creates a Timing middleware.
///
/// ```dart
/// app.use(timing());
/// ```
Timing timing({
  bool total = true,
  String totalDescription = 'Total Response Time',
  bool Function(Context ctx)? enabled,
  bool autoEnd = true,
  String? crossOrigin,
}) {
  return Timing(
    total: total,
    totalDescription: totalDescription,
    enabled: enabled,
    autoEnd: autoEnd,
    crossOrigin: crossOrigin,
  );
}
