import 'dart:collection';

import 'package:chase/chase.dart';

abstract interface class RouteMatch {
  Handler get handler;
  UnmodifiableMapView<String, String> get params;
}
