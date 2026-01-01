import 'dart:async';
import 'dart:math';

import 'package:chase/src/core/context/context.dart';
import 'package:chase/src/core/middleware.dart';

/// Configuration options for RequestId middleware.
class RequestIdOptions {
  /// Header name to use for the request ID.
  ///
  /// Used both for reading incoming request IDs and setting response headers.
  ///
  /// Default: 'X-Request-Id'
  final String headerName;

  /// Whether to set the request ID in the response headers.
  ///
  /// Default: true
  final bool setResponseHeader;

  /// Whether to use an existing request ID from the incoming request header.
  ///
  /// When enabled, if the incoming request has a request ID header,
  /// that value will be used instead of generating a new one.
  /// This is useful for distributed tracing.
  ///
  /// Default: true
  final bool useIncoming;

  /// Custom request ID generator function.
  ///
  /// If null, uses the default UUID v4 generator.
  final String Function()? generator;

  /// Validator function for incoming request IDs.
  ///
  /// If provided, incoming request IDs must pass this validation
  /// to be used. Invalid IDs will trigger generation of a new ID.
  ///
  /// Default: null (accepts any non-empty string)
  final bool Function(String id)? validator;

  /// Creates request ID options with the specified configuration.
  const RequestIdOptions({
    this.headerName = 'X-Request-Id',
    this.setResponseHeader = true,
    this.useIncoming = true,
    this.generator,
    this.validator,
  });
}

/// Middleware that assigns a unique ID to each request.
///
/// Request IDs are useful for:
/// - Logging and debugging (correlate logs across services)
/// - Distributed tracing (track requests across microservices)
/// - Error reporting (identify specific requests in error reports)
/// - Support tickets (customers can provide request IDs for investigation)
///
/// By default, uses UUID v4 for ID generation, but you can provide
/// a custom generator function.
///
/// Example usage:
/// ```dart
/// // Basic usage
/// app.use(RequestId());
///
/// // Custom header name
/// app.use(RequestId(
///   const RequestIdOptions(headerName: 'X-Correlation-Id'),
/// ));
///
/// // Custom ID generator
/// app.use(RequestId(
///   RequestIdOptions(generator: () => 'req-${DateTime.now().millisecondsSinceEpoch}'),
/// ));
///
/// // Disable using incoming IDs (always generate new)
/// app.use(RequestId(
///   const RequestIdOptions(useIncoming: false),
/// ));
///
/// // Access request ID in handlers
/// app.get('/api/data').handle((ctx) async {
///   final id = ctx.requestId;
///   print('Processing request: $id');
///   await ctx.res.json({'requestId': id});
/// });
/// ```
class RequestId implements Middleware {
  /// Options for configuring the middleware.
  final RequestIdOptions options;

  /// The ID generator function.
  final String Function() _generator;

  /// Creates a RequestId middleware with the given [options].
  RequestId([this.options = const RequestIdOptions()])
      : _generator = options.generator ?? _defaultGenerator;

  @override
  FutureOr<void> handle(Context ctx, NextFunction next) async {
    String? requestId;

    // Try to use incoming request ID if enabled
    if (options.useIncoming) {
      final incoming = ctx.req.header(options.headerName);
      if (incoming != null && incoming.isNotEmpty) {
        // Validate incoming ID if validator is provided
        if (options.validator == null || options.validator!(incoming)) {
          requestId = incoming;
        }
      }
    }

    // Generate new ID if not using incoming
    requestId ??= _generator();

    // Store in context (same key as RequestLogger for compatibility)
    ctx.set('requestId', requestId);

    // Set response header if enabled
    if (options.setResponseHeader) {
      ctx.res.headers.set(options.headerName, requestId);
    }

    await next();
  }

  /// Default UUID v4 generator.
  static String _defaultGenerator() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));

    // Set version (4) and variant bits
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // Version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // Variant 1

    // Format as UUID string
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}

/// Convenience function to create a RequestId middleware.
///
/// Example:
/// ```dart
/// app.use(requestId());
/// app.use(requestId(headerName: 'X-Correlation-Id'));
/// ```
RequestId requestId({
  String headerName = 'X-Request-Id',
  bool setResponseHeader = true,
  bool useIncoming = true,
  String Function()? generator,
  bool Function(String id)? validator,
}) {
  return RequestId(RequestIdOptions(
    headerName: headerName,
    setResponseHeader: setResponseHeader,
    useIncoming: useIncoming,
    generator: generator,
    validator: validator,
  ));
}

/// Extension on Context for request ID access.
///
/// Works with both [RequestId] and [RequestLogger] middleware.
extension RequestIdContextExtension on Context {
  /// Gets the request ID for the current request.
  ///
  /// Works with both [RequestId] and [RequestLogger] middleware.
  ///
  /// Throws if neither middleware is configured.
  String get requestId {
    final id = get<String>('requestId');
    if (id == null) {
      throw StateError(
        'Request ID not available. Did you add the RequestId or RequestLogger middleware?',
      );
    }
    return id;
  }

  /// Gets the request ID or null if not available.
  String? get requestIdOrNull => get<String>('requestId');
}
