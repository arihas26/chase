import 'package:chase/src/core/handler.dart';
import 'package:chase/src/core/route_match.dart';

/// An interface for a router that can add routes and match incoming requests to handlers.
/// Implementations of this interface should provide mechanisms to store and retrieve routes based on HTTP methods and paths.
abstract interface class Router {
  void add(String method, String path, Handler handler);
  RouteMatch? match(String method, String path);
}
