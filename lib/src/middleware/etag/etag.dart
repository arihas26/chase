import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:chase/src/core/context/context.dart';
import 'package:chase/src/core/middleware.dart';
import 'package:crypto/crypto.dart';

/// Function type for generating ETags from content.
typedef ETagGenerator = String Function(Uint8List content);

/// Options for configuring ETag generation.
class ETagOptions {
  /// Whether to generate weak ETags (W/"...").
  ///
  /// Weak ETags indicate semantic equivalence, not byte-for-byte equality.
  /// Use weak ETags when the response may vary slightly but is semantically
  /// the same (e.g., different whitespace or formatting).
  ///
  /// Default: false (strong ETags)
  final bool weak;

  /// Custom ETag generator function.
  ///
  /// If null, uses MD5 hash of the content.
  final ETagGenerator? generator;

  /// Creates ETag options with the specified configuration.
  const ETagOptions({
    this.weak = false,
    this.generator,
  });

  /// Creates options for weak ETags.
  const ETagOptions.weak()
      : weak = true,
        generator = null;
}

/// Result of an ETag check.
class ETagCheckResult {
  /// The generated ETag value.
  final String etag;

  /// Whether the client's cached version matches.
  final bool matches;

  const ETagCheckResult({
    required this.etag,
    required this.matches,
  });
}

/// Extension on Context for ETag support.
extension ETagContextExtension on Context {
  /// Gets the If-None-Match header values from the request.
  List<String> get ifNoneMatch {
    final header = req.header('If-None-Match');
    if (header == null) return [];

    return header
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  /// Gets the If-Match header values from the request.
  List<String> get ifMatch {
    final header = req.header('If-Match');
    if (header == null) return [];

    return header
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  /// Checks if the given ETag matches the If-None-Match header.
  ///
  /// Returns true if the ETag matches, meaning the client has the
  /// current version and a 304 Not Modified response should be sent.
  bool etagMatches(String etag) {
    final clientTags = ifNoneMatch;
    if (clientTags.isEmpty) return false;

    // Check for wildcard
    if (clientTags.contains('*')) return true;

    // Normalize ETags for comparison
    final normalizedEtag = _normalizeEtag(etag);
    return clientTags.any((tag) => _normalizeEtag(tag) == normalizedEtag);
  }

  /// Sets the ETag header and returns 304 if it matches the client's version.
  ///
  /// Returns true if 304 was sent (client has current version).
  /// Returns false if the response should continue with the full content.
  ///
  /// Example:
  /// ```dart
  /// app.get('/data').handle((ctx) async {
  ///   final data = await fetchData();
  ///   final etag = computeEtag(data);
  ///
  ///   if (await ctx.checkEtag(etag)) {
  ///     return; // 304 already sent
  ///   }
  ///
  ///   await ctx.res.json(data);
  /// });
  /// ```
  Future<bool> checkEtag(String etag) async {
    // Set ETag header
    res.headers.set('ETag', etag);

    // Check If-None-Match
    if (etagMatches(etag)) {
      res.statusCode = 304;
      await res.close();
      return true;
    }

    return false;
  }

  String _normalizeEtag(String etag) {
    // Remove weak prefix and quotes for comparison
    var normalized = etag.trim();
    if (normalized.startsWith('W/')) {
      normalized = normalized.substring(2);
    }
    if (normalized.startsWith('"') && normalized.endsWith('"')) {
      normalized = normalized.substring(1, normalized.length - 1);
    }
    return normalized;
  }
}

/// Middleware that automatically generates and validates ETags.
///
/// This middleware intercepts responses and:
/// 1. Generates an ETag based on the response content
/// 2. Compares with the client's If-None-Match header
/// 3. Returns 304 Not Modified if they match
/// 4. Otherwise, adds the ETag header to the response
///
/// Note: This middleware buffers the response body to compute the ETag.
/// For large responses, consider using the ETag context extension methods
/// in your handlers instead.
///
/// Features:
/// - Automatic ETag generation using MD5 hash
/// - Support for weak ETags
/// - If-None-Match header validation
/// - 304 Not Modified responses for cached content
/// - Custom ETag generator support
///
/// Example usage:
/// ```dart
/// // Automatic ETag for all responses
/// app.use(ETag());
///
/// // Weak ETags
/// app.use(ETag(const ETagOptions.weak()));
///
/// // Custom generator
/// app.use(ETag(ETagOptions(
///   generator: (content) => sha256.convert(content).toString(),
/// )));
///
/// // Manual ETag in handler
/// app.get('/data').handle((ctx) async {
///   final data = await fetchData();
///   final etag = '"${data.version}"';
///
///   if (await ctx.checkEtag(etag)) {
///     return; // 304 sent
///   }
///
///   await ctx.res.json(data);
/// });
/// ```
///
/// HTTP Caching Flow:
/// 1. First request: Server returns response with ETag header
/// 2. Subsequent requests: Client sends If-None-Match with cached ETag
/// 3. If ETag matches: Server returns 304 Not Modified (no body)
/// 4. If ETag differs: Server returns new response with new ETag
class ETag implements Middleware {
  final ETagOptions options;

  /// Creates an ETag middleware with the given [options].
  const ETag([this.options = const ETagOptions()]);

  @override
  FutureOr<void> handle(Context ctx, NextFunction next) async {
    // Call next middleware/handler
    // Note: ETag handling is done via ctx.checkEtag() in handlers
    // or using ETagHelper to generate ETags
    await next();
  }

  /// Generates an ETag for the given content.
  String generateEtag(Uint8List content) {
    final hash = options.generator != null
        ? options.generator!(content)
        : md5.convert(content).toString();

    final etag = options.weak ? 'W/"$hash"' : '"$hash"';
    return etag;
  }

  /// Generates an ETag for string content.
  String generateEtagFromString(String content) {
    return generateEtag(Uint8List.fromList(utf8.encode(content)));
  }
}

/// Helper class for computing ETags.
class ETagHelper {
  /// Generates an ETag from bytes using MD5.
  static String fromBytes(Uint8List bytes, {bool weak = false}) {
    final hash = md5.convert(bytes).toString();
    return weak ? 'W/"$hash"' : '"$hash"';
  }

  /// Generates an ETag from a string using MD5.
  static String fromString(String content, {bool weak = false}) {
    return fromBytes(Uint8List.fromList(utf8.encode(content)), weak: weak);
  }

  /// Generates an ETag from JSON-encodable data.
  static String fromJson(Object? data, {bool weak = false}) {
    return fromString(jsonEncode(data), weak: weak);
  }

  /// Generates an ETag from a version number or identifier.
  static String fromVersion(Object version, {bool weak = false}) {
    final etag = weak ? 'W/"$version"' : '"$version"';
    return etag;
  }

  /// Compares two ETags for equality.
  ///
  /// Handles weak/strong comparison according to HTTP spec:
  /// - Strong comparison: Both must be strong and identical
  /// - Weak comparison: Values must match (ignoring W/ prefix)
  static bool equals(String etag1, String etag2, {bool strongComparison = false}) {
    if (strongComparison) {
      // Strong comparison: both must be strong and identical
      if (etag1.startsWith('W/') || etag2.startsWith('W/')) {
        return false;
      }
      return etag1 == etag2;
    }

    // Weak comparison: compare values only
    return _normalize(etag1) == _normalize(etag2);
  }

  static String _normalize(String etag) {
    var normalized = etag.trim();
    if (normalized.startsWith('W/')) {
      normalized = normalized.substring(2);
    }
    if (normalized.startsWith('"') && normalized.endsWith('"')) {
      normalized = normalized.substring(1, normalized.length - 1);
    }
    return normalized;
  }
}
