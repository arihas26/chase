import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

/// dart_frog benchmark server
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
  // Create router
  final router = Router()
    // Plain text
    ..get('/', (context) => Response(body: 'Hello, World!'))

    // JSON response
    ..get('/json', (context) {
      return Response.json(
        body: {'message': 'Hello, World!', 'framework': 'dart_frog'},
      );
    })

    // Route parameter
    ..get('/user/<id>', (context, id) {
      return Response.json(body: {'id': id, 'name': 'User $id'});
    })

    // Echo JSON body
    ..post('/echo', (context) async {
      final body = await context.request.body();
      return Response(
        body: body,
        headers: {'content-type': 'application/json'},
      );
    })

    // Query parameters
    ..get('/query', (context) {
      final params = context.request.uri.queryParameters;
      final name = params['name'] ?? 'anonymous';
      final age = params['age'] ?? '0';
      return Response.json(body: {'name': name, 'age': age});
    })

    // Large JSON response
    ..get('/large', (context) {
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
      return Response.json(body: {'items': items});
    })

    // Middleware chain endpoint
    ..get('/middleware', (context) {
      return Response.json(
        body: {'processed': true},
        headers: {'X-Benchmark': 'dart_frog'},
      );
    });

  // Apply middleware and create handler
  final handler = const Pipeline()
      .addMiddleware(_timingMiddleware())
      .addMiddleware(_counterMiddleware())
      .addHandler(router.call);

  // Start server
  final server = await serve(handler, InternetAddress.anyIPv4, 3003);
  print('dart_frog server running on http://localhost:${server.port}');
}

Middleware _timingMiddleware() {
  return (handler) {
    return (context) async {
      // Simulate timing
      return handler(context);
    };
  };
}

Middleware _counterMiddleware() {
  var counter = 0;
  return (handler) {
    return (context) async {
      counter++;
      return handler(context);
    };
  };
}
