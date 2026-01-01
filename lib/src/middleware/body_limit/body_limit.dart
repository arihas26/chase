import 'dart:async';
import 'dart:io';

import 'package:chase/src/core/context/context.dart';
import 'package:chase/src/core/middleware.dart';
import 'package:zlogger/zlogger.dart';

/// Options for configuring body size limits.
class BodyLimitOptions {
  /// Maximum size of the request body in bytes.
  ///
  /// Requests with a Content-Length header exceeding this limit will be rejected
  /// with a 413 Payload Too Large status code.
  ///
  /// Default: 1MB (1048576 bytes)
  final int maxSize;

  /// Custom error message to return when the limit is exceeded.
  ///
  /// If null, a default error message will be used.
  final String? errorMessage;

  /// Whether to include the size limit in the error response.
  ///
  /// When true, the error response will include the maximum allowed size.
  /// Default: true
  final bool includeLimit;

  const BodyLimitOptions({
    this.maxSize = 1048576, // 1MB
    this.errorMessage,
    this.includeLimit = true,
  }) : assert(maxSize > 0, 'maxSize must be greater than 0');

  /// Creates options with size specified in kilobytes.
  ///
  /// Example:
  /// ```dart
  /// BodyLimitOptions.kb(500) // 500 KB
  /// ```
  const BodyLimitOptions.kb(
    int kilobytes, {
    this.errorMessage,
    this.includeLimit = true,
  }) : maxSize = kilobytes * 1024,
       assert(kilobytes > 0, 'kilobytes must be greater than 0');

  /// Creates options with size specified in megabytes.
  ///
  /// Example:
  /// ```dart
  /// BodyLimitOptions.mb(10) // 10 MB
  /// ```
  const BodyLimitOptions.mb(
    int megabytes, {
    this.errorMessage,
    this.includeLimit = true,
  }) : maxSize = megabytes * 1024 * 1024,
       assert(megabytes > 0, 'megabytes must be greater than 0');
}

/// Middleware that limits the size of request bodies.
///
/// This middleware checks the Content-Length header of incoming requests and
/// rejects requests that exceed the configured size limit with a 413 Payload Too Large
/// status code. This helps prevent denial-of-service attacks and memory exhaustion
/// from excessively large request bodies.
///
/// Features:
/// - Configurable size limit (bytes, KB, or MB)
/// - Custom error messages
/// - Early rejection before body parsing
/// - Works with all content types (JSON, form data, file uploads, etc.)
///
/// Security considerations:
/// - Always set appropriate limits based on your application's needs
/// - Be aware that requests without Content-Length headers will pass through
/// - Consider using this middleware globally or on specific routes
/// - For file uploads, consider additional validation beyond size
///
/// Example usage:
/// ```dart
/// // Global limit of 5MB for all routes
/// app.use(BodyLimit(BodyLimitOptions.mb(5)));
///
/// // Custom limit for specific route
/// app.post('/upload')
///   .use(BodyLimit(BodyLimitOptions.mb(100)))
///   .handle((ctx) async {
///     // Handle large file upload
///   });
///
/// // Limit with custom error message
/// app.use(BodyLimit(BodyLimitOptions(
///   maxSize: 2048, // 2KB
///   errorMessage: 'Request body too large. Maximum size is 2KB.',
/// )));
///
/// // Limit in kilobytes
/// app.use(BodyLimit(BodyLimitOptions.kb(500))); // 500KB
/// ```
///
/// Performance notes:
/// - This middleware has minimal overhead as it only checks headers
/// - The check happens before body parsing, saving resources
/// - No buffering or streaming of the body content is performed
class BodyLimit implements Middleware {
  static final _log = Log.named('BodyLimit');

  final BodyLimitOptions options;

  /// Creates a BodyLimit middleware with the given [options].
  ///
  /// If no options are provided, defaults to a 1MB limit.
  ///
  /// Example:
  /// ```dart
  /// // Default 1MB limit
  /// app.use(BodyLimit());
  ///
  /// // Custom 10MB limit
  /// app.use(BodyLimit(BodyLimitOptions.mb(10)));
  ///
  /// // Custom limit with error message
  /// app.use(BodyLimit(BodyLimitOptions(
  ///   maxSize: 512000,
  ///   errorMessage: 'File too large',
  /// )));
  /// ```
  BodyLimit([this.options = const BodyLimitOptions()]);

  @override
  FutureOr<void> handle(Context ctx, NextFunction next) async {
    final contentLength = ctx.req.contentLength;

    // If Content-Length header is not present or is -1, we can't check the size
    // In production, you might want to enforce Content-Length header presence
    if (contentLength <= 0) {
      await next();
      return;
    }

    // Check if content length exceeds the limit
    if (contentLength > options.maxSize) {
      _log.warn('Request body too large', {
        'request_id': ctx.get<String>('_requestId'),
        'method': ctx.req.method,
        'path': ctx.req.path,
        'ip': _safeGetIp(ctx),
        'content_length': contentLength,
        'max_size': options.maxSize,
      });

      final errorMsg = _buildErrorMessage(contentLength);

      ctx.res.statusCode = HttpStatus.requestEntityTooLarge;
      ctx.res.headers.contentType = ContentType.json;
      ctx.res.write(errorMsg);
      await ctx.res.close();

      return;
    }

    await next();
  }

  /// Builds the error message for responses exceeding the size limit.
  String _buildErrorMessage(int requestSize) {
    if (options.errorMessage != null) {
      return options.errorMessage!;
    }

    final limitStr = _formatSize(options.maxSize);
    final requestStr = _formatSize(requestSize);

    if (options.includeLimit) {
      return 'Request body too large. Maximum size: $limitStr, received: $requestStr';
    } else {
      return 'Request body too large';
    }
  }

  /// Formats a byte size into a human-readable string.
  String _formatSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes bytes';
    } else if (bytes < 1048576) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    }
  }

  /// Safely gets the remote IP address, returning null if not available.
  String? _safeGetIp(Context ctx) {
    try {
      return ctx.req.remoteAddress;
    } catch (_) {
      return null;
    }
  }
}
