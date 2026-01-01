/// Example: File streaming and progress tracking (Hono-style API)
///
/// This example demonstrates:
/// - Binary file streaming
/// - Text log streaming
/// - Progress updates
///
/// Run: dart run example/streaming.dart
/// Test: curl http://localhost:3000/download
///       curl http://localhost:3000/logs
library;

import 'dart:io';

import 'package:chase/chase.dart';

void main() async {
  final app = Chase();

  // Example 1: Stream a large file
  app.get('/download').handle((ctx) async {
    final file = File('README.md');

    if (!await file.exists()) {
      return Response.notFound().text('File not found');
    }

    final fileSize = await file.length();

    return stream(
      ctx,
      (s) async {
        print('Starting file download ($fileSize bytes)...');
        await s.pipe(file.openRead());
        print('Download complete!');
      },
      headers: {
        'content-type': 'application/octet-stream',
        'content-length': '$fileSize',
        'content-disposition': 'attachment; filename="README.md"',
      },
    );
  });

  // Example 2: Stream logs in real-time
  app.get('/logs').handle((ctx) {
    return streamText(ctx, (s) async {
      s.onAbort(() {
        print('Client disconnected from logs');
      });

      await s.writeln('=== Server Logs ===');
      await s.writeln('');

      // Simulate log entries
      for (var i = 1; i <= 10; i++) {
        if (s.isClosed) break;

        final timestamp = DateTime.now().toIso8601String();
        await s.writeln('[$timestamp] Log entry #$i');

        await s.sleep(Duration(seconds: 1));
      }

      await s.writeln('');
      await s.writeln('=== End of Logs ===');
    });
  });

  // Example 3: Progress tracking for long operations
  app.get('/process').handle((ctx) {
    return streamText(ctx, (s) async {
      await s.writeln('Processing started...\n');

      for (var progress = 0; progress <= 100; progress += 10) {
        if (s.isClosed) break;

        final bar = '${'█' * (progress ~/ 10)}${'░' * (10 - progress ~/ 10)}';
        await s.write('\r[$bar] $progress%');

        await s.sleep(Duration(milliseconds: 500));
      }

      await s.writeln('\n\nProcessing complete!');
    });
  });

  // Example 4: Stream JSON lines (NDJSON)
  app.get('/data-stream').handle((ctx) {
    return streamText(ctx, (s) async {
      // Stream 20 JSON objects
      for (var i = 1; i <= 20; i++) {
        if (s.isClosed) break;

        final data = {
          'id': i,
          'timestamp': DateTime.now().toIso8601String(),
          'value': (i * 42) % 100,
          'status': i % 2 == 0 ? 'even' : 'odd',
        };

        await s.writeln(data.toString());
        await s.sleep(Duration(milliseconds: 200));
      }
    }, contentType: 'application/x-ndjson');
  });

  // Example 5: Chunked data transfer
  app.get('/chunks').handle((ctx) {
    return stream(
      ctx,
      (s) async {
        // Send data in chunks
        for (var i = 0; i < 10; i++) {
          final chunk = List.generate(1024, (j) => (i * 1024 + j) % 256);
          await s.write(chunk);
          await Future.delayed(Duration(milliseconds: 100));
        }
      },
      headers: {
        'content-type': 'application/octet-stream',
        'transfer-encoding': 'chunked',
      },
    );
  });

  final port = 3000;
  print('Streaming server running on http://localhost:$port');
  print('');
  print('Try these endpoints:');
  print('  curl http://localhost:$port/download');
  print('  curl http://localhost:$port/logs');
  print('  curl http://localhost:$port/process');
  print('  curl http://localhost:$port/data-stream');
  print('  curl http://localhost:$port/chunks');

  await app.start(port: port);
}
