import 'dart:async';
import 'dart:io';

/// Binary streaming for sending data chunks to the client.
///
/// This class provides low-level streaming capabilities for sending binary data
/// to the HTTP response. It handles:
/// - Writing binary data chunks
/// - Piping from streams
/// - Flush control for immediate sending
/// - Abort handling and cleanup
/// - Connection state management
///
/// Use cases:
/// - File downloads with progress
/// - Video/audio streaming
/// - Real-time data feeds
/// - Large file processing
/// - Custom protocol implementations
///
/// The stream is automatically managed and will be cleaned up when:
/// - The client disconnects
/// - An error occurs
/// - abort() is called
/// - The piped stream completes
///
/// Example usage:
/// ```dart
/// // Stream a file to the client
/// app.get('/download', (ctx) async {
///   final file = File('large-file.dat');
///   ctx.res.headers.contentType = ContentType.binary;
///
///   final streaming = ctx.res.stream();
///   await streaming.pipe(file.openRead());
///   await streaming.done;
/// });
///
/// // Write chunks manually
/// app.get('/progress', (ctx) async {
///   final streaming = ctx.res.stream();
///
///   for (var i = 0; i < 100; i++) {
///     await streaming.writeBytes([i]);
///     await Future.delayed(Duration(milliseconds: 100));
///   }
///
///   await streaming.close();
/// });
///
/// // Handle client disconnection
/// app.get('/long-process', (ctx) async {
///   final streaming = ctx.res.stream();
///
///   streaming.onAbort(() {
///     print('Client disconnected, cleaning up...');
///   });
///
///   try {
///     await streaming.pipe(longRunningStream);
///     await streaming.done;
///   } catch (e) {
///     print('Stream error: $e');
///   }
/// });
/// ```
class Streaming {
  final HttpResponse _response;
  final Completer<void> _completer = Completer<void>();
  StreamSubscription<List<int>>? _subscription;
  bool _closed = false;

  /// Creates a new Streaming instance wrapping the given HTTP response.
  Streaming(this._response) {
    // Disable buffering to enable real-time streaming
    _response.bufferOutput = false;
  }

  /// A future that completes when the stream is done (successfully or with error).
  ///
  /// This future will:
  /// - Complete successfully when close() is called or a piped stream ends
  /// - Complete with error if an error occurs during streaming
  /// - Complete with error if abort() is called
  Future<void> get done => _completer.future;

  /// Whether the stream has been closed or aborted.
  bool get isClosed => _closed;

  /// Writes binary data to the stream.
  ///
  /// The data is written to the HTTP response and flushed immediately
  /// to ensure it's sent to the client without buffering.
  ///
  /// Throws if the stream has been closed or aborted.
  ///
  /// Example:
  /// ```dart
  /// final streaming = ctx.res.stream();
  /// await streaming.writeBytes([72, 101, 108, 108, 111]); // "Hello"
  /// await streaming.close();
  /// ```
  Future<void> writeBytes(List<int> data) async {
    if (_closed) {
      throw StateError('Cannot write to closed stream');
    }

    try {
      _response.add(data);
      await _response.flush();
    } catch (e, st) {
      await _handleError(e, st);
      rethrow;
    }
  }

  /// Pipes data from a stream to the HTTP response.
  ///
  /// This method efficiently transfers data from any `Stream<List<int>>` to the
  /// HTTP response. It handles backpressure, errors, and cleanup automatically.
  ///
  /// The stream will be:
  /// - Automatically paused/resumed based on the HTTP response buffer
  /// - Cancelled if an error occurs
  /// - Cancelled if abort() is called
  /// - Cleaned up when complete
  ///
  /// The done future will complete when the piped stream ends or an error occurs.
  ///
  /// Example:
  /// ```dart
  /// // Pipe a file
  /// final file = File('video.mp4');
  /// await streaming.pipe(file.openRead());
  ///
  /// // Pipe a transformed stream
  /// final stream = File('data.txt')
  ///   .openRead()
  ///   .transform(utf8.decoder)
  ///   .transform(LineSplitter())
  ///   .map((line) => utf8.encode('$line\n'));
  /// await streaming.pipe(stream);
  /// ```
  Future<void> pipe(Stream<List<int>> stream) async {
    if (_closed) {
      throw StateError('Cannot pipe to closed stream');
    }

    try {
      _subscription = stream.listen(
        (data) {
          _response.add(data);
        },
        onDone: () {
          _close();
        },
        onError: (error, stackTrace) {
          _handleError(error, stackTrace);
        },
        cancelOnError: true,
      );
    } catch (e, st) {
      await _handleError(e, st);
      rethrow;
    }
  }

  /// Registers a callback to be called when the stream is aborted.
  ///
  /// The callback is triggered when:
  /// - The client disconnects
  /// - The HTTP connection is closed unexpectedly
  /// - abort() is called
  ///
  /// This is useful for cleanup operations like:
  /// - Cancelling background tasks
  /// - Closing file handles
  /// - Releasing resources
  /// - Logging disconnections
  ///
  /// Note: The callback is not called if the stream completes normally via close().
  ///
  /// Example:
  /// ```dart
  /// final streaming = ctx.res.stream();
  ///
  /// streaming.onAbort(() {
  ///   print('Client disconnected');
  ///   cancelBackgroundTask();
  ///   closeResources();
  /// });
  /// ```
  void onAbort(void Function() callback) {
    _response.done.catchError((error) {
      if (!_completer.isCompleted) {
        callback();
      }
    });
  }

  /// Closes the stream normally.
  ///
  /// This method should be called when you're done writing to the stream.
  /// It will complete the done future successfully.
  ///
  /// After calling close(), no more data can be written.
  ///
  /// Example:
  /// ```dart
  /// final streaming = ctx.res.stream();
  /// await streaming.writeBytes(data);
  /// await streaming.close();
  /// await streaming.done; // Completes successfully
  /// ```
  Future<void> close() async {
    _close();
  }

  /// Aborts the stream with an error.
  ///
  /// This method:
  /// - Cancels any active piped stream
  /// - Completes the done future with an error
  /// - Triggers the onAbort callback
  /// - Prevents further writes
  ///
  /// Use this when you need to terminate streaming due to an error condition
  /// or when the client should no longer receive data.
  ///
  /// Example:
  /// ```dart
  /// final streaming = ctx.res.stream();
  ///
  /// if (someErrorCondition) {
  ///   await streaming.abort();
  ///   return;
  /// }
  /// ```
  Future<void> abort() async {
    if (_closed) return;

    _closed = true;
    await _subscription?.cancel();

    if (!_completer.isCompleted) {
      _completer.completeError(StateError('Stream aborted'));
    }
  }

  /// Internal method to close the stream normally.
  void _close() {
    if (_closed) return;

    _closed = true;
    _response.close();

    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }

  /// Internal method to handle errors.
  Future<void> _handleError(Object error, [StackTrace? stackTrace]) async {
    if (_closed) return;

    _closed = true;
    await _subscription?.cancel();

    if (!_completer.isCompleted) {
      _completer.completeError(error, stackTrace);
    }
  }
}
