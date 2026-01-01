import 'dart:async';
import 'dart:io';

import 'package:chase/src/core/context/context.dart';
import 'package:chase/src/core/middleware.dart';
import 'package:zlogger/zlogger.dart';

/// Function type for extracting a unique key from a request.
///
/// The key is used to track request counts per client/resource.
/// Common strategies include using IP address, user ID, or API key.
typedef KeyExtractor = String Function(Context ctx);

/// Function type for callback when rate limit is exceeded.
typedef OnLimitReached = void Function(Context ctx, RateLimitInfo info);

/// Information about rate limit status.
class RateLimitInfo {
  /// The key that was rate limited.
  final String key;

  /// Number of requests made in the current window.
  final int requestCount;

  /// Maximum requests allowed per window.
  final int maxRequests;

  /// Time remaining until the window resets (in milliseconds).
  final int resetInMs;

  /// Timestamp when the window resets.
  final DateTime resetAt;

  const RateLimitInfo({
    required this.key,
    required this.requestCount,
    required this.maxRequests,
    required this.resetInMs,
    required this.resetAt,
  });

  /// Whether the rate limit has been exceeded.
  bool get isExceeded => requestCount > maxRequests;

  /// Number of remaining requests in the current window.
  int get remaining => (maxRequests - requestCount).clamp(0, maxRequests);
}

/// Options for configuring rate limiting.
class RateLimitOptions {
  /// Maximum number of requests allowed per window.
  ///
  /// Default: 100 requests
  final int maxRequests;

  /// Time window in milliseconds.
  ///
  /// Default: 60000 (1 minute)
  final int windowMs;

  /// Function to extract a unique key from the request.
  ///
  /// Default: Uses the remote IP address.
  final KeyExtractor keyExtractor;

  /// Custom error message when rate limit is exceeded.
  ///
  /// If null, a default message will be used.
  final String? errorMessage;

  /// Whether to include rate limit headers in responses.
  ///
  /// Headers include:
  /// - X-RateLimit-Limit: Maximum requests per window
  /// - X-RateLimit-Remaining: Remaining requests in current window
  /// - X-RateLimit-Reset: Unix timestamp when the window resets
  /// - Retry-After: Seconds until rate limit resets (only on 429 responses)
  ///
  /// Default: true
  final bool includeHeaders;

  /// Whether to skip rate limiting for successful requests.
  ///
  /// When true, only counts requests that result in errors (4xx, 5xx).
  /// Useful for APIs where you want to limit failed attempts.
  ///
  /// Default: false
  final bool skipSuccessfulRequests;

  /// Whether to skip rate limiting for failed requests.
  ///
  /// When true, only counts successful requests.
  /// Useful when you want to limit API usage regardless of errors.
  ///
  /// Default: false
  final bool skipFailedRequests;

  /// Callback function called when rate limit is exceeded.
  ///
  /// Can be used for logging, alerting, or custom handling.
  final OnLimitReached? onLimitReached;

  /// Creates rate limit options with the specified configuration.
  const RateLimitOptions({
    this.maxRequests = 100,
    this.windowMs = 60000,
    this.keyExtractor = _defaultKeyExtractor,
    this.errorMessage,
    this.includeHeaders = true,
    this.skipSuccessfulRequests = false,
    this.skipFailedRequests = false,
    this.onLimitReached,
  }) : assert(maxRequests > 0, 'maxRequests must be greater than 0'),
       assert(windowMs > 0, 'windowMs must be greater than 0');

  /// Creates options with window specified in seconds.
  ///
  /// Example:
  /// ```dart
  /// RateLimitOptions.perSecond(10) // 10 requests per second
  /// ```
  const RateLimitOptions.perSecond(
    int requests, {
    this.keyExtractor = _defaultKeyExtractor,
    this.errorMessage,
    this.includeHeaders = true,
    this.skipSuccessfulRequests = false,
    this.skipFailedRequests = false,
    this.onLimitReached,
  }) : maxRequests = requests,
       windowMs = 1000,
       assert(requests > 0, 'requests must be greater than 0');

  /// Creates options with window specified in minutes.
  ///
  /// Example:
  /// ```dart
  /// RateLimitOptions.perMinute(60) // 60 requests per minute
  /// ```
  const RateLimitOptions.perMinute(
    int requests, {
    this.keyExtractor = _defaultKeyExtractor,
    this.errorMessage,
    this.includeHeaders = true,
    this.skipSuccessfulRequests = false,
    this.skipFailedRequests = false,
    this.onLimitReached,
  }) : maxRequests = requests,
       windowMs = 60000,
       assert(requests > 0, 'requests must be greater than 0');

  /// Creates options with window specified in hours.
  ///
  /// Example:
  /// ```dart
  /// RateLimitOptions.perHour(1000) // 1000 requests per hour
  /// ```
  const RateLimitOptions.perHour(
    int requests, {
    this.keyExtractor = _defaultKeyExtractor,
    this.errorMessage,
    this.includeHeaders = true,
    this.skipSuccessfulRequests = false,
    this.skipFailedRequests = false,
    this.onLimitReached,
  }) : maxRequests = requests,
       windowMs = 3600000,
       assert(requests > 0, 'requests must be greater than 0');

  /// Default key extractor using the client's IP address.
  static String _defaultKeyExtractor(Context ctx) {
    return ctx.req.remoteAddress;
  }
}

/// Entry in the rate limit store.
class _RateLimitEntry {
  int count;
  DateTime windowStart;

  _RateLimitEntry({required this.count, required this.windowStart});
}

/// In-memory store for rate limit data.
///
/// For production use with multiple instances, consider using
/// a distributed store like Redis.
class RateLimitStore {
  final Map<String, _RateLimitEntry> _store = {};
  Timer? _cleanupTimer;

  /// Creates a rate limit store with automatic cleanup.
  ///
  /// The [cleanupInterval] determines how often expired entries are removed.
  RateLimitStore({Duration cleanupInterval = const Duration(minutes: 5)}) {
    _cleanupTimer = Timer.periodic(cleanupInterval, (_) => _cleanup());
  }

  /// Increments the request count for the given key.
  ///
  /// Returns the rate limit info after incrementing.
  RateLimitInfo increment(String key, RateLimitOptions options) {
    final now = DateTime.now();
    final windowDuration = Duration(milliseconds: options.windowMs);

    final entry = _store[key];

    if (entry == null || now.difference(entry.windowStart) >= windowDuration) {
      // Start a new window
      _store[key] = _RateLimitEntry(count: 1, windowStart: now);
      return RateLimitInfo(
        key: key,
        requestCount: 1,
        maxRequests: options.maxRequests,
        resetInMs: options.windowMs,
        resetAt: now.add(windowDuration),
      );
    }

    // Increment existing window
    entry.count++;
    final resetAt = entry.windowStart.add(windowDuration);
    final resetInMs = resetAt.difference(now).inMilliseconds;

    return RateLimitInfo(
      key: key,
      requestCount: entry.count,
      maxRequests: options.maxRequests,
      resetInMs: resetInMs.clamp(0, options.windowMs),
      resetAt: resetAt,
    );
  }

  /// Gets the current rate limit info for the given key without incrementing.
  RateLimitInfo? peek(String key, RateLimitOptions options) {
    final entry = _store[key];
    if (entry == null) return null;

    final now = DateTime.now();
    final windowDuration = Duration(milliseconds: options.windowMs);

    if (now.difference(entry.windowStart) >= windowDuration) {
      return null; // Window has expired
    }

    final resetAt = entry.windowStart.add(windowDuration);
    final resetInMs = resetAt.difference(now).inMilliseconds;

    return RateLimitInfo(
      key: key,
      requestCount: entry.count,
      maxRequests: options.maxRequests,
      resetInMs: resetInMs.clamp(0, options.windowMs),
      resetAt: resetAt,
    );
  }

  /// Resets the rate limit for the given key.
  void reset(String key) {
    _store.remove(key);
  }

  /// Clears all rate limit data.
  void clear() {
    _store.clear();
  }

  /// Cleans up expired entries.
  void _cleanup() {
    final now = DateTime.now();
    _store.removeWhere((key, entry) {
      // Remove entries older than 1 hour by default
      return now.difference(entry.windowStart) > const Duration(hours: 1);
    });
  }

  /// Disposes the store and stops the cleanup timer.
  void dispose() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _store.clear();
  }
}

/// Middleware that limits the rate of incoming requests.
///
/// This middleware tracks request counts per client (identified by IP address
/// or custom key) and returns a 429 Too Many Requests status when the limit
/// is exceeded.
///
/// Features:
/// - Configurable request limits per time window
/// - Multiple window configurations (per second, minute, hour)
/// - Custom key extraction (IP, user ID, API key, etc.)
/// - Rate limit headers (X-RateLimit-*)
/// - Retry-After header for 429 responses
/// - Callback for limit exceeded events
/// - Optional skip for successful/failed requests
///
/// Security considerations:
/// - Set appropriate limits based on your API's expected usage
/// - Consider stricter limits for authentication endpoints
/// - Use IP-based limiting for anonymous access
/// - Use user/API key-based limiting for authenticated access
/// - Monitor rate limit events for potential abuse
///
/// Example usage:
/// ```dart
/// // Global rate limit: 100 requests per minute
/// app.use(RateLimit(const RateLimitOptions.perMinute(100)));
///
/// // Stricter limit for login endpoint
/// app.post('/login')
///   .use(RateLimit(const RateLimitOptions(
///     maxRequests: 5,
///     windowMs: 900000, // 15 minutes
///     errorMessage: 'Too many login attempts. Please try again later.',
///   )))
///   .handle((ctx) async {
///     // Handle login
///   });
///
/// // Custom key extraction by API key
/// app.use(RateLimit(RateLimitOptions(
///   maxRequests: 1000,
///   windowMs: 3600000, // 1 hour
///   keyExtractor: (ctx) => ctx.req.header('X-API-Key') ?? 'anonymous',
/// )));
///
/// // With callback for logging
/// app.use(RateLimit(RateLimitOptions(
///   maxRequests: 50,
///   windowMs: 60000,
///   onLimitReached: (ctx, info) {
///     print('Rate limit exceeded for ${info.key}');
///   },
/// )));
/// ```
///
/// Rate limit headers:
/// - `X-RateLimit-Limit`: Maximum requests allowed
/// - `X-RateLimit-Remaining`: Remaining requests in current window
/// - `X-RateLimit-Reset`: Unix timestamp when the window resets
/// - `Retry-After`: Seconds until next request allowed (429 only)
class RateLimit implements Middleware {
  static final _log = Log.named('RateLimit');

  final RateLimitOptions options;
  final RateLimitStore _store;

  /// Creates a RateLimit middleware with the given [options].
  ///
  /// Optionally accepts a custom [store] for rate limit data.
  /// If not provided, uses an in-memory store with automatic cleanup.
  ///
  /// Example:
  /// ```dart
  /// // Default: 100 requests per minute
  /// app.use(RateLimit());
  ///
  /// // Custom: 10 requests per second
  /// app.use(RateLimit(const RateLimitOptions.perSecond(10)));
  ///
  /// // With custom store
  /// final store = RateLimitStore();
  /// app.use(RateLimit(const RateLimitOptions(), store: store));
  /// ```
  RateLimit([this.options = const RateLimitOptions(), RateLimitStore? store])
    : _store = store ?? RateLimitStore();

  @override
  FutureOr<void> handle(Context ctx, NextFunction next) async {
    final key = options.keyExtractor(ctx);
    final info = _store.increment(key, options);

    // Add rate limit headers if enabled
    if (options.includeHeaders) {
      _addRateLimitHeaders(ctx, info);
    }

    // Check if rate limit exceeded
    if (info.isExceeded) {
      _log.warn('Rate limit exceeded', {
        'request_id': ctx.get<String>('_requestId'),
        'key': info.key,
        'method': ctx.req.method,
        'path': ctx.req.path,
        'request_count': info.requestCount,
        'max_requests': info.maxRequests,
        'reset_in_seconds': (info.resetInMs / 1000).ceil(),
      });

      options.onLimitReached?.call(ctx, info);

      final errorMsg = _buildErrorMessage(info);
      final retryAfterSeconds = (info.resetInMs / 1000).ceil();

      ctx.res.statusCode = HttpStatus.tooManyRequests;
      ctx.res.headers.contentType = ContentType.json;
      ctx.res.headers.set('Retry-After', retryAfterSeconds.toString());
      ctx.res.write(errorMsg);
      await ctx.res.close();

      return;
    }

    await next();
  }

  /// Adds rate limit headers to the response.
  void _addRateLimitHeaders(Context ctx, RateLimitInfo info) {
    final resetTimestamp = info.resetAt.millisecondsSinceEpoch ~/ 1000;

    ctx.res.headers.set('X-RateLimit-Limit', info.maxRequests.toString());
    ctx.res.headers.set('X-RateLimit-Remaining', info.remaining.toString());
    ctx.res.headers.set('X-RateLimit-Reset', resetTimestamp.toString());
  }

  /// Builds the error message for rate limit exceeded responses.
  String _buildErrorMessage(RateLimitInfo info) {
    if (options.errorMessage != null) {
      return '{"error": "${options.errorMessage}"}';
    }

    final retryAfterSeconds = (info.resetInMs / 1000).ceil();
    return '{"error": "Too many requests. Please try again in $retryAfterSeconds seconds."}';
  }

  /// Gets the rate limit store for this middleware instance.
  ///
  /// Can be used to manually reset rate limits or inspect state.
  RateLimitStore get store => _store;
}
