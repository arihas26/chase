import 'package:chase/chase.dart';

void main() async {
  final app = Chase();

  app.get('/').handle((ctx) => {'hello': 'world'});

  await app.start(port: 3001);
  print('Server started on http://localhost:3001');
}
