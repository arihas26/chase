import 'dart:async';
import 'dart:io';

import 'package:chase/chase.dart';

/// Middleware that normalizes trailing slashes in URLs.
///
/// This middleware handles trailing slashes by either removing or appending
/// them, with an optional redirect.
///
/// ## Example
///
/// ```dart
/// // Remove trailing slashes: /about/ → /about
/// app.use(trimTrailingSlash());
///
/// // Append trailing slashes: /about → /about/
/// app.use(appendTrailingSlash());
/// ```
///
/// ## Behavior
///
/// - Only applies to GET and HEAD requests
/// - By default, issues a 301 redirect
/// - Preserves query strings during redirect
///
/// ## See also
///
/// * [trimTrailingSlash] - Removes trailing slashes
/// * [appendTrailingSlash] - Appends trailing slashes
class TrailingSlash implements Middleware {
  /// The mode of operation.
  final TrailingSlashMode mode;

  /// The HTTP status code for redirects (default: 301).
  final int redirectStatus;

  /// Creates a TrailingSlash middleware.
  ///
  /// Use [trimTrailingSlash] or [appendTrailingSlash] for convenience.
  const TrailingSlash({
    required this.mode,
    this.redirectStatus = HttpStatus.movedPermanently,
  });

  /// Creates a middleware that removes trailing slashes.
  ///
  /// Redirects `/about/` to `/about`.
  ///
  /// ```dart
  /// app.use(trimTrailingSlash());
  /// ```
  static TrailingSlash trim({
    int redirectStatus = HttpStatus.movedPermanently,
  }) {
    return TrailingSlash(
      mode: TrailingSlashMode.trim,
      redirectStatus: redirectStatus,
    );
  }

  /// Creates a middleware that appends trailing slashes.
  ///
  /// Redirects `/about` to `/about/`.
  ///
  /// ```dart
  /// app.use(appendTrailingSlash());
  /// ```
  static TrailingSlash append({
    int redirectStatus = HttpStatus.movedPermanently,
  }) {
    return TrailingSlash(
      mode: TrailingSlashMode.append,
      redirectStatus: redirectStatus,
    );
  }

  @override
  FutureOr<void> handle(Context ctx, NextFunction next) async {
    final method = ctx.req.method;

    // Only apply to GET and HEAD requests
    if (method != 'GET' && method != 'HEAD') {
      return next();
    }

    final path = ctx.req.path;

    // Skip root path
    if (path == '/') {
      return next();
    }

    switch (mode) {
      case TrailingSlashMode.trim:
        if (path.endsWith('/')) {
          final newPath = path.substring(0, path.length - 1);
          final query = ctx.req.uri.query;
          final location = query.isEmpty ? newPath : '$newPath?$query';
          return ctx.res.redirect(location, status: redirectStatus);
        }
      case TrailingSlashMode.append:
        if (!path.endsWith('/')) {
          final newPath = '$path/';
          final query = ctx.req.uri.query;
          final location = query.isEmpty ? newPath : '$newPath?$query';
          return ctx.res.redirect(location, status: redirectStatus);
        }
    }

    return next();
  }
}

/// The mode of trailing slash handling.
enum TrailingSlashMode {
  /// Remove trailing slashes.
  trim,

  /// Append trailing slashes.
  append,
}

/// Removes trailing slashes from URLs.
///
/// Redirects `/about/` to `/about`.
///
/// ```dart
/// app.use(trimTrailingSlash());
///
/// // With custom redirect status
/// app.use(trimTrailingSlash(redirectStatus: 302));
/// ```
TrailingSlash trimTrailingSlash({
  int redirectStatus = HttpStatus.movedPermanently,
}) {
  return TrailingSlash.trim(redirectStatus: redirectStatus);
}

/// Appends trailing slashes to URLs.
///
/// Redirects `/about` to `/about/`.
///
/// ```dart
/// app.use(appendTrailingSlash());
///
/// // With custom redirect status
/// app.use(appendTrailingSlash(redirectStatus: 302));
/// ```
TrailingSlash appendTrailingSlash({
  int redirectStatus = HttpStatus.movedPermanently,
}) {
  return TrailingSlash.append(redirectStatus: redirectStatus);
}
