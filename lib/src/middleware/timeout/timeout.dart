import 'dart:async';
import 'dart:io';

import 'package:chase/src/core/context/context.dart';
import 'package:chase/src/core/middleware.dart';
import 'package:chase/src/core/response.dart';

/// Function type for custom timeout handling.
typedef TimeoutHandler = FutureOr<void> Function(Context ctx);

/// Options for configuring request timeout.
class TimeoutOptions {
  /// The maximum duration allowed for request processing.
  ///
  /// If the handler takes longer than this duration, the timeout
  /// response will be sent.
  ///
  /// Default: 30 seconds
  final Duration duration;

  /// HTTP status code to return on timeout.
  ///
  /// Common values:
  /// - 408 Request Timeout: Client took too long to send request
  /// - 503 Service Unavailable: Server is overloaded
  /// - 504 Gateway Timeout: Upstream server timeout
  ///
  /// Default: 503 (Service Unavailable)
  final int statusCode;

  /// Custom error message for timeout response.
  ///
  /// If null, a default message will be used.
  final String? errorMessage;

  /// Custom handler for timeout events.
  ///
  /// If provided, this handler will be called instead of the default
  /// timeout response. Use this for custom error pages or logging.
  final TimeoutHandler? onTimeout;

  /// Whether to include timeout duration in the error response.
  ///
  /// Default: false
  final bool includeDuration;

  /// Creates timeout options with the specified configuration.
  const TimeoutOptions({
    this.duration = const Duration(seconds: 30),
    this.statusCode = HttpStatus.serviceUnavailable,
    this.errorMessage,
    this.onTimeout,
    this.includeDuration = false,
  });

  /// Creates options with duration in seconds.
  TimeoutOptions.seconds(
    int seconds, {
    this.statusCode = HttpStatus.serviceUnavailable,
    this.errorMessage,
    this.onTimeout,
    this.includeDuration = false,
  }) : duration = Duration(seconds: seconds);

  /// Creates options with duration in milliseconds.
  TimeoutOptions.milliseconds(
    int milliseconds, {
    this.statusCode = HttpStatus.serviceUnavailable,
    this.errorMessage,
    this.onTimeout,
    this.includeDuration = false,
  }) : duration = Duration(milliseconds: milliseconds);

  /// Creates options for a short timeout (5 seconds).
  static const short = TimeoutOptions(duration: Duration(seconds: 5));

  /// Creates options for a medium timeout (30 seconds).
  static const medium = TimeoutOptions(duration: Duration(seconds: 30));

  /// Creates options for a long timeout (120 seconds).
  static const long = TimeoutOptions(duration: Duration(seconds: 120));
}

/// Exception thrown when a request times out.
class TimeoutException implements Exception {
  /// The timeout duration that was exceeded.
  final Duration duration;

  /// Optional message describing the timeout.
  final String? message;

  const TimeoutException(this.duration, [this.message]);

  @override
  String toString() {
    if (message != null) {
      return 'TimeoutException: $message (after ${duration.inMilliseconds}ms)';
    }
    return 'TimeoutException: Request timed out after ${duration.inMilliseconds}ms';
  }
}

/// Middleware that enforces a timeout on request processing.
///
/// This middleware wraps the downstream handler with a timeout. If the
/// handler doesn't complete within the specified duration, a timeout
/// response is sent to the client.
///
/// Features:
/// - Configurable timeout duration
/// - Custom status codes and error messages
/// - Custom timeout handlers
/// - Automatic response cleanup
///
/// Important notes:
/// - The timeout only affects the response to the client
/// - Long-running background tasks may continue after timeout
/// - Use with caution for file uploads or streaming responses
///
/// Example usage:
/// ```dart
/// // Global timeout of 30 seconds
/// app.use(Timeout());
///
/// // Short timeout for specific endpoint
/// app.get('/quick')
///   .use(Timeout(const TimeoutOptions.seconds(5)))
///   .handle((ctx) async {
///     await ctx.res.json({'fast': true});
///   });
///
/// // Long timeout for file processing
/// app.post('/upload')
///   .use(Timeout(const TimeoutOptions(duration: Duration(minutes: 5))))
///   .handle((ctx) async {
///     // Process large file
///     await ctx.res.json({'uploaded': true});
///   });
///
/// // Custom timeout handler
/// app.use(Timeout(TimeoutOptions(
///   duration: Duration(seconds: 10),
///   onTimeout: (ctx) async {
///     await ctx.res.json(
///       {'error': 'Request took too long'},
///       status: HttpStatus.serviceUnavailable,
///     );
///   },
/// )));
///
/// // With custom error message
/// app.use(Timeout(const TimeoutOptions(
///   duration: Duration(seconds: 15),
///   errorMessage: 'Server is busy, please try again later',
///   statusCode: HttpStatus.serviceUnavailable,
/// )));
/// ```
///
/// Response headers:
/// - Sets appropriate status code (default: 503)
/// - Content-Type: application/json
class Timeout implements Middleware {
  final TimeoutOptions options;

  /// Creates a Timeout middleware with the given [options].
  ///
  /// If no options are provided, uses a 30-second timeout.
  const Timeout([this.options = const TimeoutOptions()]);

  @override
  FutureOr<dynamic> handle(Context ctx, NextFunction next) async {
    try {
      // Race between the handler and the timeout
      final result = await Future.any<Object?>([
        _executeNext(next),
        _timeoutFuture(),
      ]);

      if (result is _TimeoutMarker) {
        // Timeout occurred
        return _handleTimeout(ctx);
      }
    } on TimeoutException {
      return _handleTimeout(ctx);
    }
  }

  /// Executes the next middleware/handler.
  Future<Object?> _executeNext(NextFunction next) async {
    await next();
    return null;
  }

  /// Creates a future that completes after the timeout duration.
  Future<_TimeoutMarker> _timeoutFuture() async {
    await Future.delayed(options.duration);
    return const _TimeoutMarker();
  }

  /// Handles the timeout response.
  Response? _handleTimeout(Context ctx) {
    // Use custom handler if provided
    if (options.onTimeout != null) {
      options.onTimeout!(ctx);
      return null; // Custom handler manages the response
    }

    // Build error message
    final errorMsg = _buildErrorMessage();

    return Response(
      options.statusCode,
      body: errorMsg,
      headers: {'content-type': 'application/json'},
    );
  }

  /// Builds the error message for timeout response.
  String _buildErrorMessage() {
    if (options.errorMessage != null) {
      return '{"error": "${options.errorMessage}"}';
    }

    if (options.includeDuration) {
      final ms = options.duration.inMilliseconds;
      return '{"error": "Request timeout", "duration_ms": $ms}';
    }

    return '{"error": "Request timeout"}';
  }
}

/// Marker class to identify timeout in Future.any
class _TimeoutMarker {
  const _TimeoutMarker();
}

/// Extension on Context for timeout-related functionality.
extension TimeoutContextExtension on Context {
  /// Sets a deadline for the current request.
  ///
  /// Stores the deadline in the context for use by handlers.
  void setDeadline(DateTime deadline) {
    set('_deadline', deadline);
  }

  /// Gets the deadline for the current request.
  ///
  /// Returns null if no deadline is set.
  DateTime? get deadline => get<DateTime>('_deadline');

  /// Checks if the request has exceeded its deadline.
  bool get isExpired {
    final dl = deadline;
    return dl != null && DateTime.now().isAfter(dl);
  }

  /// Gets the remaining time until deadline.
  ///
  /// Returns null if no deadline is set.
  /// Returns Duration.zero if already expired.
  Duration? get remainingTime {
    final dl = deadline;
    if (dl == null) return null;

    final remaining = dl.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }
}
