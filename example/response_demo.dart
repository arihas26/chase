import 'package:chase/chase.dart';

void main() async {
  final app = Chase();

  // 1. Map を直接返す → JSON
  app.get('/json').handle((ctx) {
    return {'message': 'Hello', 'timestamp': DateTime.now().toIso8601String()};
  });

  // 2. String を直接返す → text/plain
  app.get('/text').handle((ctx) {
    return 'Hello, World!';
  });

  // 3. List を直接返す → JSON
  app.get('/list').handle((ctx) {
    return [1, 2, 3, {'name': 'item'}];
  });

  // 4. Response でステータスコード指定
  app.post('/users').handle((ctx) async {
    final body = await ctx.req.json() as Map<String, dynamic>;
    return Response.created().json({'id': 1, ...body});
  });

  // 5. Response でヘッダー追加
  app.get('/custom-header').handle((ctx) {
    return Response.ok()
        .header('X-Custom', 'my-value')
        .json({'with': 'custom header'});
  });

  // 6. リダイレクト
  app.get('/old').handle((ctx) {
    return Response.redirect('/json');
  });

  // 7. エラーレスポンス
  app.get('/error').handle((ctx) {
    return Response.badRequest().json({'error': 'Invalid request'});
  });

  await app.start(port: 3000);

  print('''
Test commands:
  curl http://localhost:3000/json
  curl http://localhost:3000/text
  curl http://localhost:3000/list
  curl -X POST -H "Content-Type: application/json" -d '{"name":"test"}' http://localhost:3000/users
  curl -v http://localhost:3000/custom-header
  curl -v http://localhost:3000/old
  curl http://localhost:3000/error
''');
}
