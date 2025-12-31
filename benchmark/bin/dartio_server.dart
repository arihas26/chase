import 'dart:convert';
import 'dart:io';

/// Pure dart:io benchmark server (baseline)
///
/// Endpoints:
/// - GET /              : Plain text response
/// - GET /json          : JSON response
/// - GET /user/:id      : Route parameter (manual parsing)
/// - POST /echo         : Echo JSON body
/// - GET /query         : Query parameters
/// - GET /large         : Large JSON response
/// - GET /middleware    : Simulated middleware chain
void main() async {
  final server = await HttpServer.bind(InternetAddress.anyIPv4, 3002);
  print('dart:io server running on http://localhost:${server.port}');

  int counter = 0;

  server.listen((request) async {
    final path = request.uri.path;
    final method = request.method;

    if (method == 'GET') {
      if (path == '/') {
        // Plain text
        request.response
          ..headers.contentType = ContentType.text
          ..write('Hello, World!');
        await request.response.close();
      } else if (path == '/json') {
        // JSON response
        request.response
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({'message': 'Hello, World!', 'framework': 'dart:io'}),
          );
        await request.response.close();
      } else if (path.startsWith('/user/')) {
        // Route parameter (manual)
        final id = path.substring(6);
        request.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'id': id, 'name': 'User $id'}));
        await request.response.close();
      } else if (path == '/query') {
        // Query parameters
        final name = request.uri.queryParameters['name'] ?? 'anonymous';
        final age = request.uri.queryParameters['age'] ?? '0';
        request.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'name': name, 'age': age}));
        await request.response.close();
      } else if (path == '/large') {
        // Large JSON response
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
        request.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'items': items}));
        await request.response.close();
      } else if (path == '/middleware') {
        // Simulated middleware chain
        counter++;
        request.response
          ..headers.contentType = ContentType.json
          ..headers.set('X-Benchmark', 'dart:io')
          ..write(jsonEncode({'processed': true}));
        await request.response.close();
      } else {
        request.response
          ..statusCode = HttpStatus.notFound
          ..write('Not Found');
        await request.response.close();
      }
    } else if (method == 'POST' && path == '/echo') {
      // Echo JSON body
      final body = await utf8.decoder.bind(request).join();
      request.response
        ..headers.contentType = ContentType.json
        ..write(body);
      await request.response.close();
    } else {
      request.response
        ..statusCode = HttpStatus.methodNotAllowed
        ..write('Method Not Allowed');
      await request.response.close();
    }
  });
}
