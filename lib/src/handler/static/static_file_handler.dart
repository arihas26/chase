import 'dart:async';
import 'dart:io';

import 'package:chase/src/core/context/context.dart';
import 'package:path/path.dart' as p;

/// Options for configuring static file serving behavior.
class StaticOptions {
  /// The default file to serve when a directory is requested.
  /// Defaults to 'index.html'.
  final String index;

  /// List of file extensions to try when the exact file is not found.
  /// For example, if extensions contains '.html', requesting '/about' will
  /// try to serve '/about.html' if '/about' doesn't exist.
  final List<String> extensions;

  /// Maximum age for caching static files.
  /// Sets the Cache-Control header with 'public, max-age=X'.
  final Duration? maxAge;

  /// Whether to generate and use ETag headers for caching.
  /// ETags are based on file size and modification time.
  final bool etag;

  /// Whether to set Last-Modified header.
  /// Helps with client-side caching.
  final bool lastModified;

  /// Whether to serve precompressed files (.br, .gz) when available.
  ///
  /// When enabled, if the client accepts compressed content and a precompressed
  /// file exists (e.g., 'file.js.br' or 'file.js.gz'), it will be served instead
  /// of the original file.
  ///
  /// Compression priority: Brotli (.br) > Gzip (.gz)
  final bool precompressed;

  /// Threshold in bytes for using streaming instead of reading entire file.
  /// Files larger than this will be streamed to reduce memory usage.
  /// Defaults to 1MB (1048576 bytes). Set to 0 to always stream.
  final int streamingThreshold;

  /// Callback called when a file is found and about to be served.
  /// Useful for setting custom headers or logging.
  final void Function(String path, Context ctx)? onFound;

  /// Callback called when a file is not found.
  /// Useful for custom 404 handling or logging.
  final void Function(String path, Context ctx)? onNotFound;

  /// Function to rewrite the request path before resolving the file.
  /// Return null to use the original path.
  final String? Function(String path)? rewriteRequestPath;

  const StaticOptions({
    this.index = 'index.html',
    this.extensions = const [],
    this.maxAge,
    this.etag = false,
    this.lastModified = true,
    this.precompressed = false,
    this.streamingThreshold = 1048576, // 1MB
    this.onFound,
    this.onNotFound,
    this.rewriteRequestPath,
  });
}

/// Handler for serving static files from the filesystem.
///
/// This handler serves files from a specified root directory with support for:
/// - Directory index files (e.g., index.html)
/// - Extension fallbacks (e.g., /about -> /about.html)
/// - ETag-based caching
/// - Last-Modified headers
/// - Cache-Control headers
/// - Path traversal protection
/// - MIME type detection
/// - Precompressed files (.br, .gz)
/// - Range requests for partial content
/// - Streaming for large files
///
/// Example usage:
/// ```dart
/// final app = Chase();
/// app.static('/assets', './public', StaticOptions(
///   maxAge: Duration(days: 365),
///   etag: true,
///   precompressed: true,
/// ));
/// ```
class StaticFileHandler {
  /// The root directory from which to serve files.
  final String rootDirectory;

  /// Configuration options for static file serving.
  final StaticOptions options;

  /// The name of the parameter that contains the requested file path.
  /// This is typically 'path' when using wildcard routes like '/assets/*path'.
  final String wildcardParam;

  /// Creates a new static file handler.
  ///
  /// [rootDirectory] is the directory from which to serve files.
  /// [options] configures caching, index files, and extensions.
  /// [wildcardParam] is the name of the route parameter containing the file path.
  StaticFileHandler(
    this.rootDirectory, {
    this.options = const StaticOptions(),
    this.wildcardParam = 'path',
  });

  /// Handles a request for a static file.
  ///
  /// Serves the file or sends a 404 response.
  FutureOr<void> call(Context ctx) async {
    try {
      final raw = ctx.req.params[wildcardParam] ?? '';
      var requested = raw.isEmpty ? options.index : raw;

      // Apply path rewriting if configured
      if (options.rewriteRequestPath != null) {
        requested = options.rewriteRequestPath!(requested) ?? requested;
      }

      // Resolve and validate the file path
      final root = p.normalize(p.absolute(rootDirectory));
      final candidate = p.normalize(p.join(root, requested));

      // Security: Prevent directory traversal attacks
      if (!_isPathSafe(root, candidate)) {
        _handleNotFound(ctx, requested);
        return;
      }

      // Find the file (with extension fallback if configured)
      var file = await _resolveFile(candidate);
      if (file == null) {
        _handleNotFound(ctx, requested);
        return;
      }

      // Verify it's actually a file, not a directory
      final stat = await file.stat();
      if (stat.type != FileSystemEntityType.file) {
        _handleNotFound(ctx, requested);
        return;
      }

      // Check for precompressed version if enabled
      String? contentEncoding;
      FileStat fileStat = stat;
      if (options.precompressed) {
        final (compressedFile, encoding) =
            await _findPrecompressedFile(file.path, ctx);
        if (compressedFile != null) {
          file = compressedFile;
          contentEncoding = encoding;
          fileStat = await compressedFile.stat();
        }
      }

      // Check if client's cached version is still valid (ETag)
      if (options.etag && _isNotModifiedByETag(ctx, fileStat)) {
        _sendNotModified(ctx);
        return;
      }

      // Check for Range request
      final rangeHeader = ctx.req.header(HttpHeaders.rangeHeader);
      if (rangeHeader != null && contentEncoding == null) {
        await _handleRangeRequest(ctx, file, fileStat, rangeHeader);
        return;
      }

      // Call onFound callback
      options.onFound?.call(requested, ctx);

      // Set caching headers
      _setCachingHeaders(ctx, fileStat);

      // Set content type (use original file path for MIME detection)
      _setContentType(ctx, candidate);

      // Set content encoding if serving precompressed file
      if (contentEncoding != null) {
        ctx.res.headers.set(HttpHeaders.contentEncodingHeader, contentEncoding);
      }

      // Send the file
      await _sendFile(ctx, file, fileStat);
    } catch (e) {
      // On any error (file I/O, permissions, etc.), return 404
      final raw = ctx.req.params[wildcardParam] ?? '';
      _handleNotFound(ctx, raw);
    }
  }

  /// Checks if the requested path is safe (no directory traversal).
  bool _isPathSafe(String root, String candidate) {
    return p.isWithin(root, candidate) || p.equals(root, candidate);
  }

  /// Resolves the file to serve, trying extensions if configured.
  Future<File?> _resolveFile(String candidate) async {
    File file = File(candidate);

    // Check if exact file exists
    if (await file.exists()) {
      return file;
    }

    // Try index file for directories
    final dir = Directory(candidate);
    if (await dir.exists()) {
      final indexFile = File(p.join(candidate, options.index));
      if (await indexFile.exists()) {
        return indexFile;
      }
    }

    // Try with extensions
    return await _resolveWithExtensions(candidate);
  }

  /// Finds a precompressed version of the file if available.
  ///
  /// Returns the compressed file and encoding, or (null, null) if not available.
  Future<(File?, String?)> _findPrecompressedFile(
      String filePath, Context ctx) async {
    final acceptEncoding = ctx.req.header(HttpHeaders.acceptEncodingHeader);
    if (acceptEncoding == null) return (null, null);

    // Priority: Brotli > Gzip
    if (acceptEncoding.contains('br')) {
      final brFile = File('$filePath.br');
      if (await brFile.exists()) {
        return (brFile, 'br');
      }
    }

    if (acceptEncoding.contains('gzip')) {
      final gzFile = File('$filePath.gz');
      if (await gzFile.exists()) {
        return (gzFile, 'gzip');
      }
    }

    return (null, null);
  }

  /// Checks if the client's cached version is still valid based on ETag.
  bool _isNotModifiedByETag(Context ctx, FileStat stat) {
    final etag = _generateETag(stat);
    final ifNoneMatch = ctx.req.header(HttpHeaders.ifNoneMatchHeader);
    return ifNoneMatch == etag;
  }

  /// Generates an ETag based on file size and modification time.
  String _generateETag(FileStat stat) {
    return 'W/"${stat.size}-${stat.modified.toUtc().millisecondsSinceEpoch}"';
  }

  /// Sets caching-related headers (Cache-Control, ETag, Last-Modified).
  void _setCachingHeaders(Context ctx, FileStat stat) {
    // Cache-Control
    if (options.maxAge != null) {
      ctx.res.headers.set(
        HttpHeaders.cacheControlHeader,
        'public, max-age=${options.maxAge!.inSeconds}',
      );
    }

    // ETag
    if (options.etag) {
      final etag = _generateETag(stat);
      ctx.res.headers.set(HttpHeaders.etagHeader, etag);
    }

    // Last-Modified
    if (options.lastModified) {
      ctx.res.headers.set(
        HttpHeaders.lastModifiedHeader,
        HttpDate.format(stat.modified),
      );
    }
  }

  /// Sets the Content-Type header based on the file extension.
  void _setContentType(Context ctx, String filePath) {
    final contentType = _guessContentType(filePath);
    if (contentType != null) {
      ctx.res.headers.contentType = contentType;
    }
  }

  /// Sends the file contents to the client.
  Future<void> _sendFile(Context ctx, File file, FileStat stat) async {
    ctx.res.headers.contentLength = stat.size;

    // Use streaming for large files
    if (stat.size > options.streamingThreshold) {
      await ctx.res.addStream(file.openRead());
      await ctx.res.close();
    } else {
      final bytes = await file.readAsBytes();
      ctx.res.add(bytes);
      await ctx.res.close();
    }
  }

  /// Handles Range requests for partial content.
  Future<void> _handleRangeRequest(
    Context ctx,
    File file,
    FileStat stat,
    String rangeHeader,
  ) async {
    final range = _parseRangeHeader(rangeHeader, stat.size);
    if (range == null) {
      // Invalid range
      ctx.res.statusCode = HttpStatus.requestedRangeNotSatisfiable;
      ctx.res.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes */${stat.size}',
      );
      await ctx.res.close();
      return;
    }

    final (start, end) = range;
    final length = end - start + 1;

    ctx.res.statusCode = HttpStatus.partialContent;
    ctx.res.headers.set(
      HttpHeaders.contentRangeHeader,
      'bytes $start-$end/${stat.size}',
    );
    ctx.res.headers.contentLength = length;
    ctx.res.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');

    _setContentType(ctx, file.path);
    _setCachingHeaders(ctx, stat);

    // Stream the requested range
    await ctx.res.addStream(file.openRead(start, end + 1));
    await ctx.res.close();
  }

  /// Parses a Range header and returns the start and end positions.
  ///
  /// Returns null if the range is invalid.
  (int, int)? _parseRangeHeader(String header, int fileSize) {
    if (!header.startsWith('bytes=')) return null;

    final rangeSpec = header.substring(6);
    final parts = rangeSpec.split('-');
    if (parts.length != 2) return null;

    int start;
    int end;

    if (parts[0].isEmpty) {
      // Suffix range: -500 means last 500 bytes
      final suffix = int.tryParse(parts[1]);
      if (suffix == null || suffix <= 0) return null;
      start = fileSize - suffix;
      end = fileSize - 1;
    } else if (parts[1].isEmpty) {
      // Open-ended range: 500- means from 500 to end
      start = int.tryParse(parts[0]) ?? -1;
      if (start < 0) return null;
      end = fileSize - 1;
    } else {
      // Normal range: 500-999
      start = int.tryParse(parts[0]) ?? -1;
      end = int.tryParse(parts[1]) ?? -1;
      if (start < 0 || end < 0) return null;
    }

    // Validate range
    if (start < 0) start = 0;
    if (end >= fileSize) end = fileSize - 1;
    if (start > end) return null;

    return (start, end);
  }

  /// Handles not found - calls callback or sends 404.
  void _handleNotFound(Context ctx, String path) {
    if (options.onNotFound != null) {
      options.onNotFound!(path, ctx);
    } else {
      _sendNotFound(ctx);
    }
  }

  /// Sends a 404 Not Found response.
  void _sendNotFound(Context ctx) {
    ctx.res
      ..statusCode = HttpStatus.notFound
      ..write('404 Not Found')
      ..close();
  }

  /// Sends a 304 Not Modified response.
  void _sendNotModified(Context ctx) {
    ctx.res
      ..statusCode = HttpStatus.notModified
      ..close();
  }

  /// Tries to resolve a file by appending configured extensions.
  ///
  /// For example, if extensions is ['.html'] and the file '/about' doesn't exist,
  /// this will try '/about.html'.
  Future<File?> _resolveWithExtensions(String candidate) async {
    if (options.extensions.isEmpty) return null;
    if (p.extension(candidate).isNotEmpty) return null;

    for (final ext in options.extensions) {
      final normalizedExt = ext.startsWith('.') ? ext : '.$ext';
      final withExt = '$candidate$normalizedExt';
      final file = File(withExt);
      if (await file.exists()) return file;
    }
    return null;
  }

  /// Guesses the Content-Type based on file extension.
  ///
  /// Returns null if the extension is not recognized.
  ContentType? _guessContentType(String filePath) {
    final ext = p.extension(filePath).toLowerCase();

    // Text types
    switch (ext) {
      case '.html':
      case '.htm':
        return ContentType.html;
      case '.css':
        return ContentType('text', 'css', charset: 'utf-8');
      case '.js':
      case '.mjs':
        return ContentType('application', 'javascript', charset: 'utf-8');
      case '.json':
        return ContentType.json;
      case '.txt':
        return ContentType.text;
      case '.xml':
        return ContentType('application', 'xml', charset: 'utf-8');
      case '.csv':
        return ContentType('text', 'csv', charset: 'utf-8');
      case '.md':
      case '.markdown':
        return ContentType('text', 'markdown', charset: 'utf-8');
    }

    // Image types
    switch (ext) {
      case '.png':
        return ContentType('image', 'png');
      case '.jpg':
      case '.jpeg':
        return ContentType('image', 'jpeg');
      case '.gif':
        return ContentType('image', 'gif');
      case '.svg':
        return ContentType('image', 'svg+xml');
      case '.ico':
        return ContentType('image', 'x-icon');
      case '.webp':
        return ContentType('image', 'webp');
      case '.bmp':
        return ContentType('image', 'bmp');
      case '.tiff':
      case '.tif':
        return ContentType('image', 'tiff');
      case '.avif':
        return ContentType('image', 'avif');
    }

    // Font types
    switch (ext) {
      case '.woff':
        return ContentType('font', 'woff');
      case '.woff2':
        return ContentType('font', 'woff2');
      case '.ttf':
        return ContentType('font', 'ttf');
      case '.otf':
        return ContentType('font', 'otf');
      case '.eot':
        return ContentType('application', 'vnd.ms-fontobject');
    }

    // Audio/Video types
    switch (ext) {
      case '.mp3':
        return ContentType('audio', 'mpeg');
      case '.mp4':
        return ContentType('video', 'mp4');
      case '.webm':
        return ContentType('video', 'webm');
      case '.ogg':
        return ContentType('audio', 'ogg');
      case '.wav':
        return ContentType('audio', 'wav');
      case '.m4a':
        return ContentType('audio', 'mp4');
      case '.flac':
        return ContentType('audio', 'flac');
      case '.avi':
        return ContentType('video', 'x-msvideo');
      case '.mov':
        return ContentType('video', 'quicktime');
      case '.mkv':
        return ContentType('video', 'x-matroska');
    }

    // Application types
    switch (ext) {
      case '.pdf':
        return ContentType('application', 'pdf');
      case '.zip':
        return ContentType('application', 'zip');
      case '.tar':
        return ContentType('application', 'x-tar');
      case '.gz':
        return ContentType('application', 'gzip');
      case '.wasm':
        return ContentType('application', 'wasm');
      case '.map':
        return ContentType.json; // Source maps
    }

    return null;
  }
}
