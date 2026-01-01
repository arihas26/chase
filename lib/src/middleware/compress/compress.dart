import 'dart:async';
import 'dart:io';

import 'package:chase/src/core/context/context.dart';
import 'package:chase/src/core/middleware.dart';

/// HTTP Response Compression middleware.
///
/// Automatically compresses HTTP responses using gzip, deflate, or brotli
/// encoding based on the client's Accept-Encoding header and content size.
///
/// The middleware:
/// - Parses the Accept-Encoding header with quality values
/// - Selects the best compression algorithm
/// - Sets Content-Encoding and Vary headers
/// - Only compresses responses larger than the threshold
///
/// Compression algorithms (in preference order):
/// - `br` (Brotli): Best compression ratio, supported by modern browsers
/// - `gzip`: Good compression, widely supported
/// - `deflate`: Basic compression, legacy support
///
/// Notes:
/// - This middleware sets up compression headers and parameters
/// - Actual compression is handled by Dart's HttpServer when autoCompress is enabled
/// - Only responses with compressible content types should be compressed
/// - Small responses (below threshold) are not compressed to save CPU
///
/// Security considerations:
/// - Compression can expose data through timing attacks (BREACH, CRIME)
/// - Don't compress responses containing secrets and user input together
/// - Consider disabling compression for CSRF tokens and sensitive data
///
/// Example usage:
/// ```dart
/// // Default configuration (1KB threshold)
/// app.use(Compress());
///
/// // Custom threshold (compress only if > 2KB)
/// app.use(Compress(threshold: 2048));
///
/// // Disable compression for small responses
/// app.use(Compress(threshold: 10240)); // 10KB
///
/// // Enable only specific encodings
/// app.use(Compress(
///   enableBrotli: true,
///   enableGzip: true,
///   enableDeflate: false,
/// ));
///
/// // In a route, check if compression is enabled
/// app.get('/data', (ctx) async {
///   final encoding = ctx.req.params['content-encoding'];
///   // compression will be applied if encoding is set
///   await ctx.res.json({'data': largeData});
/// });
/// ```
class Compress implements Middleware {
  /// Minimum response size (in bytes) to trigger compression.
  /// Responses smaller than this won't be compressed to save CPU.
  /// Default: 1024 bytes (1KB)
  final int threshold;

  /// Enable Brotli compression (br).
  /// Provides best compression ratio but requires modern browsers.
  /// Default: true
  final bool enableBrotli;

  /// Enable Gzip compression (gzip).
  /// Good compression ratio with wide browser support.
  /// Default: true
  final bool enableGzip;

  /// Enable Deflate compression (deflate).
  /// Basic compression, mainly for legacy support.
  /// Default: true
  final bool enableDeflate;

  /// Creates a Compress middleware with the specified configuration.
  ///
  /// [threshold] sets the minimum response size in bytes to compress (default: 1024).
  /// [enableBrotli] enables Brotli compression (default: true).
  /// [enableGzip] enables Gzip compression (default: true).
  /// [enableDeflate] enables Deflate compression (default: true).
  const Compress({
    this.threshold = 1024,
    this.enableBrotli = true,
    this.enableGzip = true,
    this.enableDeflate = true,
  });

  @override
  Future<void> handle(Context ctx, NextFunction next) async {
    final acceptEncoding = ctx.req.header(HttpHeaders.acceptEncodingHeader);

    // No Accept-Encoding header, skip compression
    if (acceptEncoding == null) {
      await next();
      return;
    }

    // Parse Accept-Encoding header and select best encoding
    final selectedEncoding = _selectEncoding(acceptEncoding);

    // No suitable encoding found, skip compression
    if (selectedEncoding == null) {
      await next();
      return;
    }

    // Store compression parameters for potential use
    ctx.set('_content_encoding', selectedEncoding);
    ctx.set('_compression_threshold', threshold);

    // Set Content-Encoding header
    ctx.res.headers.set(HttpHeaders.contentEncodingHeader, selectedEncoding);

    // Set Vary header to indicate response varies by Accept-Encoding
    // This is important for caching proxies
    final currentVary = ctx.res.headers.value(HttpHeaders.varyHeader);
    if (currentVary == null) {
      ctx.res.headers.set(HttpHeaders.varyHeader, 'Accept-Encoding');
    } else if (!currentVary.contains('Accept-Encoding')) {
      ctx.res.headers.set(HttpHeaders.varyHeader, '$currentVary, Accept-Encoding');
    }

    await next();
  }

  /// Selects the best compression encoding based on Accept-Encoding header.
  ///
  /// Parses quality values (q=) and selects the highest quality encoding
  /// that is also enabled in this middleware configuration.
  ///
  /// Returns null if no suitable encoding is found.
  String? _selectEncoding(String acceptEncoding) {
    // Parse Accept-Encoding: gzip, deflate, br;q=1.0, *;q=0.5
    final encodings = <String, double>{};

    for (final part in acceptEncoding.split(',')) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;

      final segments = trimmed.split(';');
      final encoding = segments[0].trim().toLowerCase();

      // Parse quality value (default: 1.0)
      var quality = 1.0;
      if (segments.length > 1) {
        final qPart = segments[1].trim();
        if (qPart.startsWith('q=')) {
          quality = double.tryParse(qPart.substring(2)) ?? 1.0;
        }
      }

      // Ignore if quality is 0 (explicitly disabled)
      if (quality > 0) {
        encodings[encoding] = quality;
      }
    }

    // Build list of available encodings based on configuration
    final available = <_EncodingOption>[];

    if (enableBrotli && encodings.containsKey('br')) {
      available.add(_EncodingOption('br', encodings['br']!, 3)); // Highest preference
    }
    if (enableGzip && encodings.containsKey('gzip')) {
      available.add(_EncodingOption('gzip', encodings['gzip']!, 2));
    }
    if (enableDeflate && encodings.containsKey('deflate')) {
      available.add(_EncodingOption('deflate', encodings['deflate']!, 1));
    }

    // Handle wildcard (*) - use it as default quality for all enabled encodings
    if (encodings.containsKey('*')) {
      final wildcardQuality = encodings['*']!;
      if (enableBrotli && !encodings.containsKey('br')) {
        available.add(_EncodingOption('br', wildcardQuality, 3));
      }
      if (enableGzip && !encodings.containsKey('gzip')) {
        available.add(_EncodingOption('gzip', wildcardQuality, 2));
      }
      if (enableDeflate && !encodings.containsKey('deflate')) {
        available.add(_EncodingOption('deflate', wildcardQuality, 1));
      }
    }

    if (available.isEmpty) {
      return null;
    }

    // Sort by quality (descending), then by preference (descending)
    available.sort((a, b) {
      final qualityCompare = b.quality.compareTo(a.quality);
      if (qualityCompare != 0) return qualityCompare;
      return b.preference.compareTo(a.preference);
    });

    return available.first.encoding;
  }
}

/// Internal class to represent an encoding option with its quality and preference.
class _EncodingOption {
  final String encoding;
  final double quality;
  final int preference; // Higher = more preferred

  _EncodingOption(this.encoding, this.quality, this.preference);
}
