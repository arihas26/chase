import 'package:chase/chase.dart';
import 'package:chase/src/router/trie_router/trie_match.dart';
import 'package:chase/src/router/trie_router/trie_node.dart';

class TrieRouter implements Router {
  final Map<String, TrieNode> _roots = {};

  @override
  void add(String method, String path, Handler handler) {
    final root = _roots.putIfAbsent(method, () => TrieNode());

    var node = root;
    final segments = _splitPath(path);
    TrieNode? parentOfOptional;

    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];
      if (segment.startsWith('*') && i != segments.length - 1) {
        throw ArgumentError('Wildcard segment must be the last segment.');
      }

      // Track parent if next segment is optional parameter
      final isOptional = segment.startsWith(':') && segment.endsWith('?');
      if (isOptional) {
        parentOfOptional = node;
      }

      node = _getOrCreateChild(node, segment);
      if (segment.startsWith('*')) break;
    }

    node.handlers[method] = handler;

    // If the last segment was optional, also register handler at parent
    if (parentOfOptional != null) {
      parentOfOptional.handlers[method] = handler;
    }
  }

  @override
  RouteMatch? match(String method, String path) {
    final root = _roots[method];
    if (root == null) return null;

    final segments = _splitPath(path);

    final params = <String, String>{};

    // Search the trie for a matching node
    // /users/123/profile -> segments: ['users', '123', 'profile']
    final node = _search(root, segments, 0, params);
    if (node == null) return null;

    final handler = node.handlers[method];
    if (handler == null) return null;

    return TrieMatch(handler, params);
  }

  List<String> _splitPath(String path) =>
      path.split('/').where((segment) => segment.isNotEmpty).toList();

  TrieNode _getOrCreateChild(TrieNode node, String segment) {
    if (segment.startsWith(':')) {
      // parameter segment (e.g., :id or :id?)
      final isOptional = segment.endsWith('?');
      node.paramChild ??= TrieNode();
      // Extract name: remove ':' prefix and '?' suffix if present
      node.paramName ??= isOptional
          ? segment.substring(1, segment.length - 1)
          : segment.substring(1);
      if (isOptional) {
        node.paramOptional = true;
      }
      return node.paramChild!;
    } else if (segment.startsWith('*')) {
      // wildcard segment
      node.wildcardChild ??= TrieNode();
      node.wildcardName ??= segment.substring(1); // exclude '*'
      return node.wildcardChild!;
    } else {
      // static segment
      return node.children.putIfAbsent(segment, () => TrieNode());
    }
  }

  TrieNode? _search(
    TrieNode node,
    List<String> segments,
    int index,
    Map<String, String> params,
  ) {
    // base case
    if (index == segments.length) {
      return node.isEmptyHandler ? null : node;
    }

    final segment = segments[index];

    // 1. Try static match
    final staticChild = node.children[segment];
    if (staticChild != null) {
      final result = _search(staticChild, segments, index + 1, params);
      if (result != null) return result;
    }

    // 2. Try parameter match
    if (node.paramChild != null && node.paramName != null) {
      params[node.paramName!] = segment;
      final result = _search(node.paramChild!, segments, index + 1, params);
      if (result != null) return result;
      // backtrack
      params.remove(node.paramName!);
    }

    // 3. Try wildcard match
    if (node.wildcardChild != null && node.wildcardName != null) {
      params[node.wildcardName!] = segments.sublist(index).join('/');
      return node.wildcardChild;
    }

    // No match found
    return null;
  }
}
