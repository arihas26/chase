import 'package:chase/chase.dart';

class TrieNode {
  // staircase map for child nodes
  final Map<String, TrieNode> children = {};

  // parameter child node (e.g., :id or :id?)
  TrieNode? paramChild;

  // name of the parameter (e.g., id)
  String? paramName;

  // whether the parameter is optional (e.g., :id?)
  bool paramOptional = false;

  // wildcard child node (e.g., *path)
  TrieNode? wildcardChild;

  // name of the wildcard parameter (e.g., path)
  String? wildcardName;

  // handlers for different HTTP methods at this node
  // (e.g., {'GET': handler, 'POST': handler})
  final Map<String, Handler> handlers = {};

  bool hasHandler(String method) => handlers.containsKey(method);

  bool get isEmptyHandler => handlers.isEmpty;
}
