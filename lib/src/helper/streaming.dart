import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chase/src/core/context/context.dart';
import 'package:chase/src/core/response.dart';

/// A response that executes a streaming callback.
///
/// This class is used internally to handle streaming responses in Chase.
/// When Chase encounters a StreamingResponse, it will execute the callback
/// instead of writing a static body.
class StreamingResponse extends Response {
  /// The callback that performs the streaming.
  final Future<void> Function(HttpResponse response) _callback;

  /// Creates a new streaming response.
  StreamingResponse({
    int status = HttpStatus.ok,
    Map<String, String> headers = const {},
    required Future<void> Function(HttpResponse response) callback,
  }) : _callback = callback,
       super(status, headers: headers);

  @override
  Future<void> writeTo(HttpResponse response, {bool prettyJson = false}) async {
    // Set status code
    response.statusCode = statusCode;

    // Set headers
    for (final entry in headers.entries) {
      response.headers.set(entry.key, entry.value);
    }

    // Disable buffering for real-time streaming
    response.bufferOutput = false;

    // Execute the streaming callback
    await _callback(response);
  }
}

/// Stream API for binary streaming (Hono-style).
class StreamApi {
  final HttpResponse _response;
  bool _closed = false;
  void Function()? _onAbortCallback;

  StreamApi._(this._response) {
    // Listen for client disconnection
    _response.done.catchError((error) {
      _onAbortCallback?.call();
    });
  }

  /// Whether the stream has been closed.
  bool get isClosed => _closed;

  /// Writes binary data to the stream.
  Future<void> write(List<int> data) async {
    if (_closed) return;
    _response.add(data);
    await _response.flush();
  }

  /// Pipes data from a readable stream.
  Future<void> pipe(Stream<List<int>> stream) async {
    if (_closed) return;
    await for (final chunk in stream) {
      if (_closed) break;
      _response.add(chunk);
      await _response.flush();
    }
  }

  /// Registers a callback for when the client disconnects.
  void onAbort(void Function() callback) {
    _onAbortCallback = callback;
  }

  /// Closes the stream.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _response.close();
  }
}

/// Text stream API for text streaming (Hono-style).
class TextStreamApi {
  final HttpResponse _response;
  bool _closed = false;
  void Function()? _onAbortCallback;

  TextStreamApi._(this._response) {
    _response.done.catchError((error) {
      _onAbortCallback?.call();
    });
  }

  /// Whether the stream has been closed.
  bool get isClosed => _closed;

  /// Writes text to the stream.
  Future<void> write(String text) async {
    if (_closed) return;
    _response.add(utf8.encode(text));
    await _response.flush();
  }

  /// Writes text with a newline.
  Future<void> writeln(String text) async {
    await write('$text\n');
  }

  /// Pauses execution for the specified duration.
  Future<void> sleep(Duration duration) async {
    await Future.delayed(duration);
  }

  /// Registers a callback for when the client disconnects.
  void onAbort(void Function() callback) {
    _onAbortCallback = callback;
  }

  /// Closes the stream.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _response.close();
  }
}

/// SSE event data.
class SSEMessage {
  /// The event data.
  final String data;

  /// The event type (optional).
  final String? event;

  /// The event ID (optional).
  final String? id;

  /// Retry interval in milliseconds (optional).
  final int? retry;

  const SSEMessage({required this.data, this.event, this.id, this.retry});
}

/// SSE stream API for Server-Sent Events (Hono-style).
class SSEStreamApi {
  final HttpResponse _response;
  bool _closed = false;
  void Function()? _onAbortCallback;

  SSEStreamApi._(this._response) {
    _response.done.catchError((error) {
      _onAbortCallback?.call();
    });
  }

  /// Whether the stream has been closed.
  bool get isClosed => _closed;

  /// Writes an SSE event.
  Future<void> writeSSE({
    required String data,
    String? event,
    String? id,
    int? retry,
  }) async {
    if (_closed) return;

    final buffer = StringBuffer();

    if (id != null) {
      buffer.writeln('id: $id');
    }

    if (event != null) {
      buffer.writeln('event: $event');
    }

    if (retry != null) {
      buffer.writeln('retry: $retry');
    }

    // Handle multi-line data
    for (final line in data.split('\n')) {
      buffer.writeln('data: $line');
    }

    buffer.writeln(); // Empty line to end the event

    _response.add(utf8.encode(buffer.toString()));
    await _response.flush();
  }

  /// Writes an SSE message object.
  Future<void> writeSSEMessage(SSEMessage message) async {
    await writeSSE(
      data: message.data,
      event: message.event,
      id: message.id,
      retry: message.retry,
    );
  }

  /// Pauses execution for the specified duration.
  Future<void> sleep(Duration duration) async {
    await Future.delayed(duration);
  }

  /// Writes a comment (for keep-alive).
  Future<void> writeComment(String comment) async {
    if (_closed) return;
    _response.add(utf8.encode(': $comment\n'));
    await _response.flush();
  }

  /// Registers a callback for when the client disconnects.
  void onAbort(void Function() callback) {
    _onAbortCallback = callback;
  }

  /// Closes the stream.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _response.close();
  }
}

// =============================================================================
// Hono-style Helper Functions
// =============================================================================

/// Returns a binary streaming response.
///
/// Example:
/// ```dart
/// app.get('/stream').handle((ctx) {
///   return stream(ctx, (s) async {
///     await s.write(Uint8List.fromList([1, 2, 3]));
///     await s.pipe(fileStream);
///   });
/// });
/// ```
Response stream(
  Context ctx,
  Future<void> Function(StreamApi stream) callback, {
  void Function(Object error, StreamApi stream)? onError,
  Map<String, String>? headers,
}) {
  return StreamingResponse(
    headers: {
      'content-type': 'application/octet-stream',
      'transfer-encoding': 'chunked',
      ...?headers,
    },
    callback: (response) async {
      final api = StreamApi._(response);
      try {
        await callback(api);
        if (!api.isClosed) {
          await api.close();
        }
      } catch (e) {
        if (onError != null) {
          onError(e, api);
        }
        if (!api.isClosed) {
          await api.close();
        }
      }
    },
  );
}

/// Returns a text streaming response.
///
/// Example:
/// ```dart
/// app.get('/text').handle((ctx) {
///   return streamText(ctx, (s) async {
///     await s.writeln('Hello');
///     await s.sleep(Duration(seconds: 1));
///     await s.write('World!');
///   });
/// });
/// ```
Response streamText(
  Context ctx,
  Future<void> Function(TextStreamApi stream) callback, {
  void Function(Object error, TextStreamApi stream)? onError,
  String contentType = 'text/plain; charset=utf-8',
  Map<String, String>? headers,
}) {
  return StreamingResponse(
    headers: {
      'content-type': contentType,
      'transfer-encoding': 'chunked',
      'x-content-type-options': 'nosniff',
      ...?headers,
    },
    callback: (response) async {
      final api = TextStreamApi._(response);
      try {
        await callback(api);
        if (!api.isClosed) {
          await api.close();
        }
      } catch (e) {
        if (onError != null) {
          onError(e, api);
        }
        if (!api.isClosed) {
          await api.close();
        }
      }
    },
  );
}

/// Returns a Server-Sent Events streaming response.
///
/// Example:
/// ```dart
/// app.get('/sse').handle((ctx) {
///   return streamSSE(ctx, (s) async {
///     var id = 0;
///     while (!s.isClosed) {
///       await s.writeSSE(
///         data: 'Current time: ${DateTime.now()}',
///         event: 'time',
///         id: '${id++}',
///       );
///       await s.sleep(Duration(seconds: 1));
///     }
///   });
/// });
/// ```
Response streamSSE(
  Context ctx,
  Future<void> Function(SSEStreamApi stream) callback, {
  void Function(Object error, SSEStreamApi stream)? onError,
}) {
  return StreamingResponse(
    headers: {
      'content-type': 'text/event-stream',
      'cache-control': 'no-cache',
      'connection': 'keep-alive',
    },
    callback: (response) async {
      final api = SSEStreamApi._(response);
      try {
        await callback(api);
        if (!api.isClosed) {
          await api.close();
        }
      } catch (e) {
        if (onError != null) {
          onError(e, api);
        }
        if (!api.isClosed) {
          await api.close();
        }
      }
    },
  );
}
