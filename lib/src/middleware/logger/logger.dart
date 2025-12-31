import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chase/src/core/context/context.dart';
import 'package:chase/src/core/middleware.dart';

/// Log level for filtering log output.
enum LogLevel {
  /// Detailed debugging information.
  debug,

  /// General information about request processing.
  info,

  /// Warning conditions (e.g., slow requests).
  warn,

  /// Error conditions (e.g., 5xx responses).
  error,
}

/// A structured log entry containing request/response information.
class LogEntry {
  /// Timestamp when the request started.
  final DateTime timestamp;

  /// HTTP method (GET, POST, etc.).
  final String method;

  /// Request path.
  final String path;

  /// Query string (without leading '?').
  final String? query;

  /// HTTP status code.
  final int status;

  /// Request processing duration.
  final Duration duration;

  /// Request ID if available (from RequestId middleware).
  final String? requestId;

  /// Client IP address.
  final String? ip;

  /// User-Agent header.
  final String? userAgent;

  /// Log level based on status code.
  final LogLevel level;

  /// Additional message.
  final String? message;

  /// Error object if an exception occurred.
  final Object? error;

  /// Stack trace if an exception occurred.
  final StackTrace? stackTrace;

  const LogEntry({
    required this.timestamp,
    required this.method,
    required this.path,
    this.query,
    required this.status,
    required this.duration,
    this.requestId,
    this.ip,
    this.userAgent,
    required this.level,
    this.message,
    this.error,
    this.stackTrace,
  });

  /// Converts the log entry to a JSON-serializable map.
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'method': method,
      'path': path,
      if (query != null && query!.isNotEmpty) 'query': query,
      'status': status,
      'duration_ms': duration.inMilliseconds,
      if (requestId != null) 'request_id': requestId,
      if (ip != null) 'ip': ip,
      if (userAgent != null) 'user_agent': userAgent,
      'level': level.name,
      if (message != null) 'message': message,
      if (error != null) 'error': error.toString(),
    };
  }

  /// Formats the log entry as a human-readable string.
  String toText() {
    final buffer = StringBuffer();
    buffer.write('${timestamp.toIso8601String()} ');
    buffer.write('[${level.name.toUpperCase()}] ');
    buffer.write('$method $path');
    if (query != null && query!.isNotEmpty) {
      buffer.write('?$query');
    }
    buffer.write(' $status ${duration.inMilliseconds}ms');
    if (requestId != null) {
      buffer.write(' req_id=$requestId');
    }
    if (message != null) {
      buffer.write(' - $message');
    }
    if (error != null) {
      buffer.write(' error=$error');
    }
    return buffer.toString();
  }

  @override
  String toString() => toText();
}

/// ANSI color codes for terminal output.
class _AnsiColor {
  static const reset = '\x1B[0m';
  static const dim = '\x1B[2m';

  // Status code colors
  static const green = '\x1B[32m'; // 2xx success
  static const cyan = '\x1B[36m'; // 3xx redirect
  static const yellow = '\x1B[33m'; // 4xx client error
  static const red = '\x1B[31m'; // 5xx server error

  // Log level colors
  static const gray = '\x1B[90m'; // debug
  static const blue = '\x1B[34m'; // info
  static const magenta = '\x1B[35m'; // method

  static String forStatus(int status) {
    if (status >= 500) return red;
    if (status >= 400) return yellow;
    if (status >= 300) return cyan;
    if (status >= 200) return green;
    return reset;
  }

  static String forLevel(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return gray;
      case LogLevel.info:
        return blue;
      case LogLevel.warn:
        return yellow;
      case LogLevel.error:
        return red;
    }
  }
}

/// Structured logging middleware for HTTP requests.
///
/// Logs request method, path, status code, and duration.
/// Supports JSON and text output formats.
///
/// ## Example
///
/// ```dart
/// // Basic usage - logs to stdout in text format with colors
/// app.use(Logger());
///
/// // JSON format for log aggregation
/// app.use(Logger(json: true));
///
/// // Disable colors (for log files)
/// app.use(Logger(colored: false));
///
/// // Custom log handler (e.g., send to external service)
/// app.use(Logger(
///   onLog: (entry) => myLogService.log(entry.toJson()),
/// ));
///
/// // Skip health check endpoints
/// app.use(Logger(
///   skip: (ctx) => ctx.req.path == '/health',
/// ));
/// ```
class Logger implements Middleware {
  /// Minimum log level to output.
  final LogLevel level;

  /// Output format: true for JSON, false for text.
  final bool json;

  /// Custom log handler. If null, outputs to stdout/stderr.
  final void Function(LogEntry entry)? onLog;

  /// Skip logging for certain requests. Return true to skip.
  final bool Function(Context ctx)? skip;

  /// Include request ID in log output.
  final bool includeRequestId;

  /// Include client IP in log output.
  final bool includeIp;

  /// Include User-Agent in log output.
  final bool includeUserAgent;

  /// Duration threshold for warning level (slow request).
  final Duration slowThreshold;

  /// Enable colored output for terminal.
  final bool colored;

  /// Creates a Logger middleware.
  const Logger({
    this.level = LogLevel.info,
    this.json = false,
    this.onLog,
    this.skip,
    this.includeRequestId = true,
    this.includeIp = true,
    this.includeUserAgent = false,
    this.slowThreshold = const Duration(seconds: 1),
    this.colored = true,
  });

  @override
  FutureOr<void> handle(Context ctx, NextFunction next) async {
    // Check if logging should be skipped
    if (skip != null && skip!(ctx)) {
      return next();
    }

    final startTime = DateTime.now();
    Object? error;
    StackTrace? stackTrace;

    try {
      await next();
    } catch (e, st) {
      error = e;
      stackTrace = st;
      rethrow;
    } finally {
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      final entry = _createEntry(
        ctx: ctx,
        startTime: startTime,
        duration: duration,
        error: error,
        stackTrace: stackTrace,
      );

      // Only log if level meets threshold
      if (entry.level.index >= level.index) {
        _log(entry);
      }
    }
  }

  LogEntry _createEntry({
    required Context ctx,
    required DateTime startTime,
    required Duration duration,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final status = ctx.res.statusCode;
    final lvl = _determineLevel(status, duration, error);

    return LogEntry(
      timestamp: startTime,
      method: ctx.req.method,
      path: ctx.req.path,
      query: ctx.req.uri.query,
      status: status,
      duration: duration,
      requestId: includeRequestId ? ctx.get<String>('requestId') : null,
      ip: includeIp ? ctx.req.ip : null,
      userAgent: includeUserAgent ? ctx.req.userAgent : null,
      level: lvl,
      error: error,
      stackTrace: stackTrace,
    );
  }

  LogLevel _determineLevel(int status, Duration duration, Object? error) {
    if (error != null || status >= 500) {
      return LogLevel.error;
    }
    if (status >= 400) {
      return LogLevel.warn;
    }
    if (duration >= slowThreshold) {
      return LogLevel.warn;
    }
    return LogLevel.info;
  }

  void _log(LogEntry entry) {
    if (onLog != null) {
      onLog!(entry);
    } else {
      final output =
          entry.level.index >= LogLevel.warn.index ? stderr : stdout;
      final message = json
          ? jsonEncode(entry.toJson())
          : colored
              ? _formatColored(entry)
              : entry.toText();
      output.writeln(message);
    }
  }

  String _formatColored(LogEntry entry) {
    const reset = _AnsiColor.reset;
    const dim = _AnsiColor.dim;
    const magenta = _AnsiColor.magenta;
    const red = _AnsiColor.red;
    const yellow = _AnsiColor.yellow;

    final levelColor = _AnsiColor.forLevel(entry.level);
    final statusColor = _AnsiColor.forStatus(entry.status);

    final buffer = StringBuffer();

    // Timestamp (dim)
    buffer.write('$dim${entry.timestamp.toIso8601String()}$reset ');

    // Level (colored)
    buffer.write('$levelColor[${entry.level.name.toUpperCase()}]$reset ');

    // Method (magenta/bold)
    buffer.write('$magenta${entry.method}$reset ');

    // Path
    buffer.write(entry.path);
    if (entry.query != null && entry.query!.isNotEmpty) {
      buffer.write('$dim?${entry.query}$reset');
    }

    // Status (colored by status code)
    buffer.write(' $statusColor${entry.status}$reset');

    // Duration
    final durationMs = entry.duration.inMilliseconds;
    final durationColor = durationMs > 100 ? yellow : dim;
    buffer.write(' $durationColor${durationMs}ms$reset');

    // Request ID
    if (entry.requestId != null) {
      buffer.write(' ${dim}req_id=${entry.requestId}$reset');
    }

    // Message
    if (entry.message != null) {
      buffer.write(' - ${entry.message}');
    }

    // Error
    if (entry.error != null) {
      buffer.write(' ${red}error=${entry.error}$reset');
    }

    return buffer.toString();
  }
}
