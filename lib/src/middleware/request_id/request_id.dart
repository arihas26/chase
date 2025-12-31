import 'dart:async';
import 'dart:math';

import 'package:chase/src/core/context/context.dart';
import 'package:chase/src/core/middleware.dart';

/// Function type for generating request IDs.
typedef IdGenerator = String Function();

/// Options for configuring request ID generation.
class RequestIdOptions {
  /// The header name to use for the request ID.
  ///
  /// Default: 'X-Request-ID'
  final String headerName;

  /// Whether to use an existing request ID from the incoming request header.
  ///
  /// When true, if the request contains the configured header, that value
  /// will be used instead of generating a new one. This is useful for
  /// distributed tracing where upstream services may have already assigned an ID.
  ///
  /// Default: true
  final bool useExisting;

  /// Whether to add the request ID to the response headers.
  ///
  /// Default: true
  final bool setResponseHeader;

  /// Custom function to generate request IDs.
  ///
  /// If null, a default UUID v4-like generator will be used.
  final IdGenerator? generator;

  /// Creates request ID options with the specified configuration.
  const RequestIdOptions({
    this.headerName = 'X-Request-ID',
    this.useExisting = true,
    this.setResponseHeader = true,
    this.generator,
  });

  /// Creates options that always generate a new ID (ignores existing headers).
  const RequestIdOptions.alwaysNew({
    this.headerName = 'X-Request-ID',
    this.setResponseHeader = true,
    this.generator,
  }) : useExisting = false;

  /// Creates options with a custom header name.
  const RequestIdOptions.withHeader(
    String header, {
    this.useExisting = true,
    this.setResponseHeader = true,
    this.generator,
  }) : headerName = header;
}

/// Middleware that assigns a unique ID to each request.
///
/// This middleware generates or extracts a unique identifier for each HTTP
/// request, making it available in the request context and optionally adding
/// it to response headers. Request IDs are essential for:
///
/// - **Logging**: Correlate log entries across a single request
/// - **Debugging**: Track requests through complex systems
/// - **Distributed Tracing**: Follow requests across microservices
/// - **Support**: Reference specific requests in error reports
///
/// Features:
/// - UUID v4-like ID generation by default
/// - Respects existing request IDs from upstream services
/// - Adds ID to response headers for client reference
/// - Stores ID in context for access by other middleware/handlers
/// - Configurable header name and generator function
///
/// Example usage:
/// ```dart
/// // Basic usage with defaults
/// app.use(RequestId());
///
/// // Access the request ID in handlers
/// app.get('/api/data').handle((ctx) async {
///   final requestId = ctx.get<String>('requestId');
///   print('Processing request: $requestId');
///   await ctx.res.json({'requestId': requestId});
/// });
///
/// // Custom header name
/// app.use(RequestId(const RequestIdOptions.withHeader('X-Correlation-ID')));
///
/// // Always generate new IDs (ignore existing headers)
/// app.use(RequestId(const RequestIdOptions.alwaysNew()));
///
/// // Custom ID generator
/// app.use(RequestId(RequestIdOptions(
///   generator: () => 'req-${DateTime.now().millisecondsSinceEpoch}',
/// )));
///
/// // With logging middleware
/// app.use(RequestId());
/// app.use((ctx, next) async {
///   final id = ctx.get<String>('requestId');
///   print('[$id] ${ctx.req.method} ${ctx.req.uri.path}');
///   final result = await next();
///   print('[$id] Response sent');
///   return result;
/// });
/// ```
///
/// The request ID is stored in the context with the key 'requestId' and can
/// be accessed using `ctx.get<String>('requestId')`.
class RequestId implements Middleware {
  final RequestIdOptions options;
  final IdGenerator _generator;

  /// Creates a RequestId middleware with the given [options].
  ///
  /// If no options are provided, uses default configuration:
  /// - Header: 'X-Request-ID'
  /// - Uses existing IDs from incoming requests
  /// - Adds ID to response headers
  /// - Generates UUID v4-like IDs
  RequestId([this.options = const RequestIdOptions()])
      : _generator = options.generator ?? _defaultGenerator;

  @override
  FutureOr<void> handle(Context ctx, NextFunction next) async {
    // Get existing ID or generate new one
    String requestId;

    if (options.useExisting) {
      final existingId = ctx.req.header(options.headerName);
      requestId = existingId ?? _generator();
    } else {
      requestId = _generator();
    }

    // Store in context for access by handlers
    ctx.set('requestId', requestId);

    // Add to response headers if enabled
    if (options.setResponseHeader) {
      ctx.res.headers.set(options.headerName, requestId);
    }

    await next();
  }

  /// Default UUID v4-like generator.
  ///
  /// Generates a string in the format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
  /// where x is a random hex digit and y is one of 8, 9, a, or b.
  static String _defaultGenerator() {
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
