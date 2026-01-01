import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

/// Shelf benchmark server
///
/// Endpoints:
/// - GET /              : Plain text response
/// - GET /json          : JSON response
/// - GET /user/:id      : Route parameter
/// - POST /echo         : Echo JSON body
/// - GET /query         : Query parameters
/// - GET /large         : Large JSON response
/// - GET /middleware    : Multiple middleware chain
void main() async {
  final router = Router();

  // Plain text
  router.get('/', (Request request) {
    return Response.ok('Hello, World!');
  });

  // JSON response
  router.get('/json', (Request request) {
    return Response.ok(
      jsonEncode({'message': 'Hello, World!', 'framework': 'shelf'}),
      headers: {'content-type': 'application/json'},
    );
  });

  // Route parameter
  router.get('/user/<id>', (Request request, String id) {
    return Response.ok(
      jsonEncode({'id': id, 'name': 'User $id'}),
      headers: {'content-type': 'application/json'},
    );
  });

  // Echo JSON body
  router.post('/echo', (Request request) async {
    final body = await request.readAsString();
    return Response.ok(body, headers: {'content-type': 'application/json'});
  });

  // Query parameters
  router.get('/query', (Request request) {
    final name = request.url.queryParameters['name'] ?? 'anonymous';
    final age = request.url.queryParameters['age'] ?? '0';
    return Response.ok(
      jsonEncode({'name': name, 'age': age}),
      headers: {'content-type': 'application/json'},
    );
  });

  // Large JSON response
  router.get('/large', (Request request) {
    final items = List.generate(
      100,
      (i) => {
        'id': i,
        'name': 'Item $i',
        'description': 'This is a description for item $i',
        'price': i * 10.5,
        'inStock': i % 2 == 0,
      },
    );
    return Response.ok(
      jsonEncode({'items': items}),
      headers: {'content-type': 'application/json'},
    );
  });

  // Middleware chain (simulated inline)
  router.get('/middleware', (Request request) {
    // Simulate 3 middleware layers
    final start = DateTime.now().microsecondsSinceEpoch;
    _counter++;
    final _ = DateTime.now().microsecondsSinceEpoch - start;

    return Response.ok(
      jsonEncode({'processed': true}),
      headers: {'content-type': 'application/json', 'X-Benchmark': 'shelf'},
    );
  });

  final server = await shelf_io.serve(
    router.call,
    InternetAddress.anyIPv4,
    3001,
  );
  print('Shelf server running on http://localhost:${server.port}');
}

int _counter = 0;
