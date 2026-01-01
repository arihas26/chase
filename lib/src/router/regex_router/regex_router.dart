import 'dart:collection';

import 'package:chase/chase.dart';

/// A route entry that stores the regex pattern, parameter names, and handler.
class _RouteEntry {
  final RegExp pattern;
  final List<String> paramNames;
  final Handler handler;

  _RouteEntry(this.pattern, this.paramNames, this.handler);
}

/// A regex-based router implementation.
///
/// This router converts path patterns to regular expressions for matching.
/// It supports:
/// - Static paths: `/users`, `/api/v1/posts`
/// - Named parameters: `/users/:id`, `/posts/:postId/comments/:commentId`
/// - Wildcards: `/files/*path`
/// - Custom regex patterns: `/users/:id(\\d+)` (id must be digits)
///
/// Example:
/// ```dart
/// final router = RegexRouter();
/// router.add('GET', '/users/:id', handler);
/// router.add('GET', '/files/*path', fileHandler);
/// router.add('GET', '/posts/:id(\\d+)', postHandler); // id must be numeric
/// ```
class RegexRouter implements Router {
  final Map<String, List<_RouteEntry>> _routes = {};

  @override
  void add(String method, String path, Handler handler) {
    final entry = _compileRoute(path, handler);
    _routes.putIfAbsent(method, () => []).add(entry);
  }

  @override
  RouteMatch? match(String method, String path) {
    final routes = _routes[method];
    if (routes == null) return null;

    for (final entry in routes) {
      final match = entry.pattern.firstMatch(path);
      if (match != null) {
        final params = <String, String>{};
        for (var i = 0; i < entry.paramNames.length; i++) {
          final value = match.group(i + 1);
          if (value != null) {
            params[entry.paramNames[i]] = value;
          }
        }
        return _RegexMatch(entry.handler, params);
      }
    }

    return null;
  }

  _RouteEntry _compileRoute(String path, Handler handler) {
    final paramNames = <String>[];
    final buffer = StringBuffer('^');

    final segments = path.split('/').where((s) => s.isNotEmpty).toList();

    // Handle root path
    if (segments.isEmpty) {
      buffer.write('/');
    }

    for (final segment in segments) {
      if (segment.startsWith(':')) {
        // Named parameter with optional marker
        // e.g., :id, :id?, :id(\d+), :id(\d+)?
        final isOptional = segment.endsWith('?');
        final segmentWithoutOptional = isOptional
            ? segment.substring(0, segment.length - 1)
            : segment;

        final customPatternMatch = RegExp(
          r'^:(\w+)\((.+)\)$',
        ).firstMatch(segmentWithoutOptional);

        String name;
        String pattern;

        if (customPatternMatch != null) {
          // Custom pattern: :id(\d+)
          name = customPatternMatch.group(1)!;
          pattern = customPatternMatch.group(2)!;
        } else {
          // Default pattern: :id
          name = segmentWithoutOptional.substring(1);
          pattern = '[^/]+';
        }

        paramNames.add(name);

        if (isOptional) {
          // Optional: make the whole /segment optional
          buffer.write('(?:/($pattern))?');
        } else {
          buffer.write('/($pattern)');
        }
      } else if (segment.startsWith('*')) {
        // Wildcard parameter
        buffer.write('/');
        final name = segment.substring(1);
        paramNames.add(name);
        buffer.write('(.*)');
      } else {
        // Static segment - escape special regex characters
        buffer.write('/');
        buffer.write(RegExp.escape(segment));
      }
    }

    buffer.write(r'$');

    return _RouteEntry(RegExp(buffer.toString()), paramNames, handler);
  }
}

class _RegexMatch implements RouteMatch {
  final Handler _handler;
  final UnmodifiableMapView<String, String> _params;

  _RegexMatch(this._handler, Map<String, String> params)
    : _params = UnmodifiableMapView(params);

  @override
  Handler get handler => _handler;

  @override
  UnmodifiableMapView<String, String> get params => _params;
}
