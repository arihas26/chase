import 'dart:async';
import 'dart:io';

import 'package:chase/src/core/context/context.dart';
import 'package:chase/src/core/middleware.dart';

/// HTTP Proxy middleware.
///
/// Forwards HTTP requests to a target server and returns the response.
/// This is useful for:
/// - API Gateway patterns
/// - Microservice communication
/// - Load balancing
/// - Development proxies
///
/// The proxy automatically:
/// - Forwards the request path and query parameters
/// - Copies request headers and body
/// - Adds X-Forwarded-* headers for traceability
/// - Streams the response back to the client
///
/// Security notes:
/// - Only proxy to trusted servers
/// - Be careful with authentication headers
/// - Consider rate limiting to prevent abuse
/// - Use HTTPS for sensitive data
/// - Validate the target URL to prevent SSRF attacks
///
/// Example usage:
/// ```dart
/// // Basic proxy to another server
/// app.use(Proxy('https://api.example.com'));
///
/// // Proxy with custom configuration
/// app.use(Proxy(
///   'https://api.example.com',
///   preserveHostHeader: false,
///   timeout: Duration(seconds: 30),
/// ));
///
/// // Proxy with path rewriting
/// app.use(Proxy(
///   'https://api.example.com',
///   rewritePath: (path) => path.replaceFirst('/api', ''),
/// ));
///
/// // Proxy specific routes
/// app.all('/api/*', (ctx) async {
///   final proxy = Proxy('https://backend.example.com');
///   return await proxy.handle(ctx, () async => ctx);
/// });
/// ```
class Proxy implements Middleware {
  /// The base URL of the target server.
  /// Example: 'https://api.example.com'
  final String targetUrl;

  /// Whether to preserve the Host header from the original request.
  /// Default: false (uses target server's host)
  final bool preserveHostHeader;

  /// Request timeout duration.
  /// Default: 30 seconds
  final Duration timeout;

  /// Optional function to rewrite the request path before proxying.
  /// Example: `(path) => path.replaceFirst('/api', '')`
  final String Function(String path)? rewritePath;

  /// Whether to add X-Forwarded-* headers.
  /// These headers provide information about the original request.
  /// Default: true
  final bool addForwardedHeaders;

  /// Creates a Proxy middleware with the specified configuration.
  ///
  /// [targetUrl] is the base URL of the target server (required).
  /// [preserveHostHeader] whether to keep the original Host header (default: false).
  /// [timeout] request timeout (default: 30 seconds).
  /// [rewritePath] optional function to modify the path before proxying.
  /// [addForwardedHeaders] whether to add X-Forwarded-* headers (default: true).
  const Proxy(
    this.targetUrl, {
    this.preserveHostHeader = false,
    this.timeout = const Duration(seconds: 30),
    this.rewritePath,
    this.addForwardedHeaders = true,
  });

  @override
  Future<void> handle(Context ctx, NextFunction next) async {
    final client = HttpClient();

    try {
      // Build the target URI with path and query parameters
      final targetUri = _buildTargetUri(ctx);

      // Open connection to target server
      final request = await client.openUrl(ctx.req.method, targetUri).timeout(timeout);

      // Copy headers from original request
      _copyRequestHeaders(ctx, request);

      // Add X-Forwarded-* headers if enabled
      if (addForwardedHeaders) {
        _addForwardedHeaders(ctx, request);
      }

      // Copy request body
      await _copyRequestBody(ctx, request);

      // Get response from target server
      final response = await request.close().timeout(timeout);

      // Copy response status and headers
      ctx.res.statusCode = response.statusCode;
      _copyResponseHeaders(response, ctx);

      // Stream response body to client
      await response.pipe(ctx.res.$raw);
    } on TimeoutException {
      // Handle timeout
      await ctx.res.json({
        'error': 'Gateway Timeout',
        'message': 'The upstream server did not respond in time',
      }, status: HttpStatus.gatewayTimeout);
    } on SocketException catch (e) {
      // Handle connection errors
      await ctx.res.json({
        'error': 'Bad Gateway',
        'message': 'Failed to connect to upstream server: ${e.message}',
      }, status: HttpStatus.badGateway);
    } catch (e) {
      // Handle other errors
      await ctx.res.json({
        'error': 'Internal Server Error',
        'message': 'Proxy error: $e',
      }, status: HttpStatus.internalServerError);
    } finally {
      client.close();
    }

    // Proxy is terminal - don't call next()
  }

  /// Builds the target URI with path and query parameters.
  Uri _buildTargetUri(Context ctx) {
    final baseUri = Uri.parse(targetUrl);
    var path = ctx.req.uri.path;

    // Apply path rewriting if configured
    if (rewritePath != null) {
      path = rewritePath!(path);
    }

    // Combine base URI with request path and query parameters
    return baseUri.replace(
      path: _joinPaths(baseUri.path, path),
      queryParameters: ctx.req.queries.isEmpty ? null : ctx.req.queries,
    );
  }

  /// Joins two paths, handling trailing/leading slashes.
  String _joinPaths(String basePath, String requestPath) {
    final base = basePath.endsWith('/') ? basePath.substring(0, basePath.length - 1) : basePath;
    final request = requestPath.startsWith('/') ? requestPath : '/$requestPath';

    if (base.isEmpty) return request;
    if (request == '/') return base;

    return '$base$request';
  }

  /// Copies headers from the original request to the proxy request.
  void _copyRequestHeaders(Context ctx, HttpClientRequest request) {
    ctx.req.forEachHeader((name, values) {
      // Skip Host header if not preserving it
      if (!preserveHostHeader && name.toLowerCase() == 'host') {
        return;
      }

      // Skip hop-by-hop headers that shouldn't be forwarded
      if (_isHopByHopHeader(name)) {
        return;
      }

      for (final value in values) {
        request.headers.add(name, value);
      }
    });
  }

  /// Adds X-Forwarded-* headers to provide information about the original request.
  void _addForwardedHeaders(Context ctx, HttpClientRequest request) {
    // X-Forwarded-For: client's IP address
    final remoteAddress = ctx.req.remoteAddress;
    if (remoteAddress != 'unknown') {
      final existingForwardedFor = ctx.req.header('x-forwarded-for');
      final forwardedFor = existingForwardedFor != null
          ? '$existingForwardedFor, $remoteAddress'
          : remoteAddress;
      request.headers.set('x-forwarded-for', forwardedFor);
    }

    // X-Forwarded-Proto: original protocol (http or https)
    final scheme = ctx.req.uri.scheme;
    if (scheme.isNotEmpty) {
      request.headers.set('x-forwarded-proto', scheme);
    }

    // X-Forwarded-Host: original host
    final host = ctx.req.header('host');
    if (host != null) {
      request.headers.set('x-forwarded-host', host);
    }
  }

  /// Copies the request body to the proxy request.
  Future<void> _copyRequestBody(Context ctx, HttpClientRequest request) async {
    try {
      final bodyBytes = await ctx.req.bytes();
      if (bodyBytes.isNotEmpty) {
        request.add(bodyBytes);
      }
    } catch (e) {
      // Body already consumed or error reading body
      // Continue without body
    }
  }

  /// Copies headers from the proxy response to the client response.
  void _copyResponseHeaders(HttpClientResponse response, Context ctx) {
    response.headers.forEach((name, values) {
      // Skip hop-by-hop headers
      if (_isHopByHopHeader(name)) {
        return;
      }

      for (final value in values) {
        ctx.res.headers.add(name, value);
      }
    });
  }

  /// Checks if a header is a hop-by-hop header that shouldn't be forwarded.
  ///
  /// Hop-by-hop headers are meaningful only for a single transport-level connection.
  /// They must not be forwarded by proxies.
  bool _isHopByHopHeader(String name) => [
    'connection',
    'keep-alive',
    'proxy-authenticate',
    'proxy-authorization',
    'te',
    'trailers',
    'transfer-encoding',
    'upgrade',
  ].contains(name.toLowerCase());
}
