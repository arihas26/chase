import 'dart:io';

import 'package:chase/chase.dart';

/// Example: File streaming and progress tracking
///
/// This example demonstrates:
/// - Binary file streaming
/// - Text log streaming
/// - Progress updates
///
/// Run: dart run bin/example_streaming.dart
/// Test: curl http://localhost:6060/download
///       curl http://localhost:6060/logs
void main() async {
  final app = Chase();

  // Example 1: Stream a large file
  app.get('/download').handle((ctx) async {
    final file = File('README.md');

    if (!await file.exists()) {
      return ctx.res.notFound('File not found');
    }

    final fileSize = await file.length();
    ctx.res.headers.contentType = ContentType.binary;
    ctx.res.headers.set('content-length', fileSize);
    ctx.res.headers.set('content-disposition', 'attachment; filename="README.md"');

    final streaming = ctx.res.stream();

    print('📥 Starting file download ($fileSize bytes)...');

    // Pipe the file stream to the response
    await streaming.pipe(file.openRead());
    await streaming.done;

    print('✅ Download complete!');
  });

  // Example 2: Stream logs in real-time
  app.get('/logs').handle((ctx) async {
    ctx.res.headers.contentType = ContentType.text;

    final streaming = ctx.res.textStream();

    streaming.onAbort(() {
      print('⚠️  Client disconnected from logs');
    });

    await streaming.writeln('=== Server Logs ===');
    await streaming.writeln('');

    // Simulate log entries
    for (var i = 1; i <= 10; i++) {
      if (streaming.isClosed) break;

      final timestamp = DateTime.now().toIso8601String();
      await streaming.writeln('[$timestamp] Log entry #$i');

      await Future.delayed(Duration(seconds: 1));
    }

    await streaming.writeln('');
    await streaming.writeln('=== End of Logs ===');
    await streaming.close();
  });

  // Example 3: Progress tracking for long operations
  app.get('/process').handle((ctx) async {
    ctx.res.headers.contentType = ContentType.text;

    final streaming = ctx.res.textStream();

    await streaming.writeln('Processing started...\n');

    for (var progress = 0; progress <= 100; progress += 10) {
      if (streaming.isClosed) break;

      final bar = '█' * (progress ~/ 10) + '░' * (10 - progress ~/ 10);
      await streaming.write('\r[$bar] $progress%');

      await Future.delayed(Duration(milliseconds: 500));
    }

    await streaming.writeln('\n\n✅ Processing complete!');
    await streaming.close();
  });

  // Example 4: Stream JSON lines (NDJSON)
  app.get('/data-stream').handle((ctx) async {
    ctx.res.headers.contentType = ContentType('application', 'x-ndjson');

    final streaming = ctx.res.textStream();

    // Stream 20 JSON objects
    for (var i = 1; i <= 20; i++) {
      if (streaming.isClosed) break;

      final data = {
        'id': i,
        'timestamp': DateTime.now().toIso8601String(),
        'value': (i * 42) % 100,
        'status': i % 2 == 0 ? 'even' : 'odd',
      };

      await streaming.writeln(data.toString());
      await Future.delayed(Duration(milliseconds: 200));
    }

    await streaming.close();
  });

  // Example 5: Chunked data transfer
  app.get('/chunks').handle((ctx) async {
    ctx.res.headers.contentType = ContentType.binary;
    ctx.res.headers.chunkedTransferEncoding = true;

    final streaming = ctx.res.stream();

    // Send data in chunks
    for (var i = 0; i < 10; i++) {
      final chunk = List.generate(1024, (j) => (i * 1024 + j) % 256);
      await streaming.writeBytes(chunk);
      await Future.delayed(Duration(milliseconds: 100));
    }

    await streaming.close();
  });

  final port = 3000;
  print('🚀 Streaming server running on http://localhost:$port');
  print('');
  print('Try these endpoints:');
  print('  curl http://localhost:$port/download');
  print('  curl http://localhost:$port/logs');
  print('  curl http://localhost:$port/process');
  print('  curl http://localhost:$port/data-stream');
  print('  curl http://localhost:$port/chunks');

  await app.start(port: port);
}
