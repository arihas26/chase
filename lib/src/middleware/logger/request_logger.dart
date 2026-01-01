import 'dart:async';
import 'dart:math';

import 'package:chase/src/core/context/context.dart';
import 'package:chase/src/core/middleware.dart';
import 'package:zlogger/zlogger.dart';

/// Function type for generating request IDs.
typedef IdGenerator = String Function();

/// Structured HTTP request logging middleware with request ID and log context.
///
/// This middleware combines request ID generation, log context propagation,
/// and request logging into a single middleware.
///
/// Features:
/// - Generates unique request IDs (UUID v4) or uses existing from headers
/// - Propagates request_id to all log calls via Zone context
/// - Logs request method, path, status, and duration
/// - Configurable log level, skip conditions, and fields
///
/// ## Example
///
/// ```dart
/// // Basic usage - all-in-one logging
/// app.use(RequestLogger());
///
/// // Now all log calls include request_id automatically
/// app.get('/users/:id').handle((ctx) async {
///   log.info('Processing request');  // includes request_id
///   final user = await userService.findUser(ctx.req.params['id']!);
///   ctx.res.json(user);
/// });
/// ```
///
/// ## Configuration
///
/// ```dart
/// app.use(RequestLogger(
///   // Request ID options
///   requestIdHeader: 'X-Correlation-ID',
///   useExistingRequestId: true,
///   setResponseHeader: true,
///   idGenerator: () => 'req-${DateTime.now().millisecondsSinceEpoch}',
///
///   // Logging options
///   minLevel: LogLevel.info,
///   skip: (ctx) => ctx.req.path == '/health',
///   includeIp: true,
///   includeUserAgent: false,
///   slowThreshold: Duration(seconds: 1),
///
///   // Custom log context fields
///   fieldsBuilder: (ctx) => {
///     'tenant': ctx.get<String>('tenant'),
///   },
/// ));
/// ```
class RequestLogger implements Middleware {
  // Request ID options
  /// Header name for request ID. Default: 'X-Request-ID'
  final String requestIdHeader;

  /// Whether to use existing request ID from headers. Default: true
  final bool useExistingRequestId;

  /// Whether to set request ID in response headers. Default: true
  final bool setResponseHeader;

  /// Custom request ID generator. Default: UUID v4
  final IdGenerator _idGenerator;

  // Logging options
  /// Minimum log level to output. Default: LogLevel.info
  final LogLevel minLevel;

  /// Skip logging for certain requests. Return true to skip.
  final bool Function(Context ctx)? skip;

  /// Include client IP in log output. Default: true
  final bool includeIp;

  /// Include User-Agent in log output. Default: false
  final bool includeUserAgent;

  /// Duration threshold for warning level (slow request). Default: 1 second
  final Duration slowThreshold;

  /// Custom fields builder for log context.
  final Map<String, dynamic> Function(Context ctx)? fieldsBuilder;

  /// Named logger instance.
  final Log _log;

  /// Creates a RequestLogger middleware.
  RequestLogger({
    // Request ID options
    this.requestIdHeader = 'X-Request-ID',
    this.useExistingRequestId = true,
    this.setResponseHeader = true,
    IdGenerator? idGenerator,
    // Logging options
    this.minLevel = LogLevel.info,
    this.skip,
    this.includeIp = true,
    this.includeUserAgent = false,
    this.slowThreshold = const Duration(seconds: 1),
    this.fieldsBuilder,
    String? name,
  }) : _idGenerator = idGenerator ?? _defaultIdGenerator,
       _log = name != null ? Log.named(name) : log;

  @override
  FutureOr<void> handle(Context ctx, NextFunction next) async {
    // Generate or use existing request ID
    final requestId = _getOrGenerateRequestId(ctx);
    ctx.set('_requestId', requestId);

    if (setResponseHeader) {
      ctx.res.headers.set(requestIdHeader, requestId);
    }

    // Build log context fields
    final contextFields = <String, dynamic>{'request_id': requestId};
    if (fieldsBuilder != null) {
      contextFields.addAll(fieldsBuilder!(ctx));
    }

    // Run in log context zone
    await Log.scope(contextFields, () async {
      // Check if logging should be skipped
      if (skip != null && skip!(ctx)) {
        await next();
        return;
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
        final duration = DateTime.now().difference(startTime);
        final status = ctx.res.statusCode;
        final level = _determineLevel(status, duration, error);

        if (level.index >= minLevel.index) {
          final fields = _buildFields(ctx, status, duration);
          final message = '${ctx.req.method} ${ctx.req.path}';

          switch (level) {
            case LogLevel.debug:
              _log.debug(message, fields);
            case LogLevel.info:
              _log.info(message, fields);
            case LogLevel.warn:
              _log.warn(message, fields);
            case LogLevel.error:
              _log.error(message, fields, error, stackTrace);
          }
        }
      }
    });
  }

  String _getOrGenerateRequestId(Context ctx) {
    if (useExistingRequestId) {
      final existing = ctx.req.header(requestIdHeader);
      if (existing != null) return existing;
    }
    return _idGenerator();
  }

  Map<String, dynamic> _buildFields(
    Context ctx,
    int status,
    Duration duration,
  ) {
    final fields = <String, dynamic>{
      'status': status,
      'duration_ms': duration.inMilliseconds,
    };

    final query = ctx.req.uri.query;
    if (query.isNotEmpty) {
      fields['query'] = query;
    }

    if (includeIp) {
      fields['ip'] = ctx.req.ip;
    }

    if (includeUserAgent) {
      final userAgent = ctx.req.userAgent;
      if (userAgent != null) {
        fields['user_agent'] = userAgent;
      }
    }

    return fields;
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

  /// Default UUID v4 generator.
  static String _defaultIdGenerator() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));

    // Set version to 4
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    // Set variant to RFC 4122
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
