import 'dart:collection';

import 'package:chase/chase.dart';

class TrieMatch implements RouteMatch {
  final Handler _handler;
  final Map<String, String> _params;

  TrieMatch(this._handler, Map<String, String> params) : _params = UnmodifiableMapView(params);

  @override
  Handler get handler => _handler;

  @override
  UnmodifiableMapView<String, String> get params => UnmodifiableMapView(_params);
}
