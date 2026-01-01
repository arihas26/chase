import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Log level for filtering log output.
enum LogLevel {
  /// Detailed debugging information.
  debug,

  /// General information.
  info,

  /// Warning conditions.
  warn,

  /// Error conditions.
  error,
}

/// A structured log entry.
class LogRecord {
  /// Timestamp when the log was created.
  final DateTime timestamp;

  /// Log level.
  final LogLevel level;

  /// Log message.
  final String message;

  /// Additional fields.
  final Map<String, dynamic> fields;

  /// Error object if present.
  final Object? error;

  /// Stack trace if present.
  final StackTrace? stackTrace;

  const LogRecord({
    required this.timestamp,
    required this.level,
    required this.message,
    this.fields = const {},
    this.error,
    this.stackTrace,
  });

  /// Converts to JSON-serializable map.
  Map<String, dynamic> toJson() {
    return {
      'time': timestamp.toIso8601String(),
      'level': level.name,
      'msg': message,
      ...fields,
      if (error != null) 'error': error.toString(),
      if (stackTrace != null) 'stack': stackTrace.toString(),
    };
  }
}

/// Handler for log records.
typedef LogHandler = void Function(LogRecord record);

/// Abstract logger interface.
abstract class ChaseLogger {
  /// Logs a debug message.
  void debug(String message, [Map<String, dynamic>? fields]);

  /// Logs an info message.
  void info(String message, [Map<String, dynamic>? fields]);

  /// Logs a warning message.
  void warn(String message, [Map<String, dynamic>? fields]);

  /// Logs an error message.
  void error(String message, [Map<String, dynamic>? fields, Object? err, StackTrace? stackTrace]);

  /// Creates a child logger with additional default fields.
  ChaseLogger withFields(Map<String, dynamic> fields);
}

/// ANSI color codes for terminal output.
class _AnsiColors {
  static const reset = '\x1B[0m';
  static const gray = '\x1B[90m';
  static const blue = '\x1B[34m';
  static const yellow = '\x1B[33m';
  static const red = '\x1B[31m';
  static const cyan = '\x1B[36m';
  static const dim = '\x1B[2m';
}

/// Default logger implementation.
class DefaultLogger implements ChaseLogger {
  /// Minimum log level to output.
  final LogLevel minLevel;

  /// Output as JSON (true) or text (false).
  final bool json;

  /// Enable colored output (default: true).
  final bool color;

  /// Custom log handler. If null, outputs to stdout/stderr.
  final LogHandler? handler;

  /// Default fields to include in every log.
  final Map<String, dynamic> _defaultFields;

  /// Creates a default logger.
  const DefaultLogger({
    this.minLevel = LogLevel.debug,
    this.json = false,
    this.color = true,
    this.handler,
    Map<String, dynamic> defaultFields = const {},
  }) : _defaultFields = defaultFields;

  @override
  void debug(String message, [Map<String, dynamic>? fields]) {
    _log(LogLevel.debug, message, fields);
  }

  @override
  void info(String message, [Map<String, dynamic>? fields]) {
    _log(LogLevel.info, message, fields);
  }

  @override
  void warn(String message, [Map<String, dynamic>? fields]) {
    _log(LogLevel.warn, message, fields);
  }

  @override
  void error(String message, [Map<String, dynamic>? fields, Object? err, StackTrace? stackTrace]) {
    _log(LogLevel.error, message, fields, err, stackTrace);
  }

  @override
  ChaseLogger withFields(Map<String, dynamic> fields) {
    return DefaultLogger(
      minLevel: minLevel,
      json: json,
      color: color,
      handler: handler,
      defaultFields: {..._defaultFields, ...fields},
    );
  }

  void _log(LogLevel level, String message, [Map<String, dynamic>? fields, Object? err, StackTrace? stackTrace]) {
    if (level.index < minLevel.index) return;

    final record = LogRecord(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      fields: {..._defaultFields, ...?fields},
      error: err,
      stackTrace: stackTrace,
    );

    if (handler != null) {
      handler!(record);
    } else {
      _defaultOutput(record);
    }
  }

  void _defaultOutput(LogRecord record) {
    final output = record.level.index >= LogLevel.warn.index ? stderr : stdout;
    final text = json ? jsonEncode(record.toJson()) : _formatText(record);
    output.writeln(text);
  }

  String _formatText(LogRecord record) {
    final buffer = StringBuffer();

    // Timestamp (dim)
    if (color) buffer.write(_AnsiColors.dim);
    buffer.write(record.timestamp.toIso8601String());
    if (color) buffer.write(_AnsiColors.reset);
    buffer.write(' ');

    // Level (colored)
    final levelStr = record.level.name.toUpperCase().padRight(5);
    if (color) {
      buffer.write(_levelColor(record.level));
      buffer.write('[$levelStr]');
      buffer.write(_AnsiColors.reset);
    } else {
      buffer.write('[$levelStr]');
    }
    buffer.write(' ');

    // Message
    buffer.write(record.message);

    // Fields (cyan)
    if (record.fields.isNotEmpty) {
      if (color) buffer.write(_AnsiColors.cyan);
      final fieldsStr = record.fields.entries
          .map((e) => '${e.key}=${e.value}')
          .join(' ');
      buffer.write(' $fieldsStr');
      if (color) buffer.write(_AnsiColors.reset);
    }

    // Error (red)
    if (record.error != null) {
      if (color) buffer.write(_AnsiColors.red);
      buffer.write(' error=${record.error}');
      if (color) buffer.write(_AnsiColors.reset);
    }

    return buffer.toString();
  }

  String _levelColor(LogLevel level) {
    return switch (level) {
      LogLevel.debug => _AnsiColors.gray,
      LogLevel.info => _AnsiColors.blue,
      LogLevel.warn => _AnsiColors.yellow,
      LogLevel.error => _AnsiColors.red,
    };
  }
}

/// A silent logger that does nothing.
class NullLogger implements ChaseLogger {
  const NullLogger();

  @override
  void debug(String message, [Map<String, dynamic>? fields]) {}

  @override
  void info(String message, [Map<String, dynamic>? fields]) {}

  @override
  void warn(String message, [Map<String, dynamic>? fields]) {}

  @override
  void error(String message, [Map<String, dynamic>? fields, Object? err, StackTrace? stackTrace]) {}

  @override
  ChaseLogger withFields(Map<String, dynamic> fields) => this;
}

/// Global logger instance used by Chase.
///
/// This can be configured via [Chase.logger] or [ChaseLoggerConfig.global].
ChaseLogger _globalLogger = const DefaultLogger();

/// Configuration for the global logger.
class ChaseLoggerConfig {
  ChaseLoggerConfig._();

  /// Gets the global logger instance.
  static ChaseLogger get global => _globalLogger;

  /// Sets the global logger instance.
  static set global(ChaseLogger logger) => _globalLogger = logger;
}

// -----------------------------------------------------------------------------
// Zone-based Log Context
// -----------------------------------------------------------------------------

/// Key for storing log context fields in Zone.
const Symbol _logContextKey = #chase.logContext;

/// Static logger that automatically includes Zone context fields.
///
/// Use this in Service, Repository, or any class outside of request handlers.
/// Context fields (like request_id) are automatically included when running
/// within a [LogContext] zone.
///
/// Example:
/// ```dart
/// class UserService {
///   // Create a named logger for this class
///   static final _log = Log.named('UserService');
///
///   Future<User> findUser(String id) async {
///     _log.info('Finding user', {'userId': id});
///     // Output: ... [INFO] Finding user logger=UserService request_id=abc-123 userId=42
///     return await _repository.find(id);
///   }
/// }
/// ```
///
/// For quick logging without a class name, use the top-level [log] constant:
/// ```dart
/// log.info('message');
/// ```
class Log {
  /// Logger name (typically the class name).
  final String? name;

  const Log._([this.name]);

  /// Creates a named logger.
  ///
  /// Use this to include the class/module name in log output.
  ///
  /// ```dart
  /// class UserService {
  ///   static final _log = Log.named('UserService');
  ///
  ///   void doSomething() {
  ///     _log.info('message');  // includes logger=UserService
  ///   }
  /// }
  /// ```
  static Log named(String name) => Log._(name);

  /// Gets the current zone context fields.
  static Map<String, dynamic> get _zoneFields {
    final fields = Zone.current[_logContextKey];
    return fields is Map<String, dynamic> ? fields : const {};
  }

  /// Builds fields map with logger name and zone context.
  Map<String, dynamic> _buildFields([Map<String, dynamic>? fields]) {
    return {
      if (name != null) 'logger': name,
      ..._zoneFields,
      ...?fields,
    };
  }

  // ---------------------------------------------------------------------------
  // Instance methods (for named loggers)
  // ---------------------------------------------------------------------------

  /// Logs a debug message (instance method).
  void debug(String message, [Map<String, dynamic>? fields]) {
    ChaseLoggerConfig.global.debug(message, _buildFields(fields));
  }

  /// Logs an info message (instance method).
  void info(String message, [Map<String, dynamic>? fields]) {
    ChaseLoggerConfig.global.info(message, _buildFields(fields));
  }

  /// Logs a warning message (instance method).
  void warn(String message, [Map<String, dynamic>? fields]) {
    ChaseLoggerConfig.global.warn(message, _buildFields(fields));
  }

  /// Logs an error message (instance method).
  void error(String message,
      [Map<String, dynamic>? fields, Object? err, StackTrace? stackTrace]) {
    ChaseLoggerConfig.global.error(message, _buildFields(fields), err, stackTrace);
  }

  /// Runs the given function within a log context zone.
  ///
  /// All [Log] calls within [fn] will include [fields] automatically.
  ///
  /// Example:
  /// ```dart
  /// await Log.runWithContext({'request_id': 'abc-123'}, () async {
  ///   Log.global.info('Processing');  // includes request_id
  ///   await someService.doWork();  // logs here also include request_id
  /// });
  /// ```
  static R runWithContext<R>(Map<String, dynamic> fields, R Function() fn) {
    final merged = {..._zoneFields, ...fields};
    return runZoned(fn, zoneValues: {_logContextKey: merged});
  }

  /// Runs the given async function within a log context zone.
  static Future<R> runWithContextAsync<R>(
      Map<String, dynamic> fields, Future<R> Function() fn) {
    final merged = {..._zoneFields, ...fields};
    return runZoned(fn, zoneValues: {_logContextKey: merged});
  }
}

/// Default logger instance for quick logging.
///
/// Use this when you don't need a named logger:
/// ```dart
/// log.info('message');
/// log.error('failed', {'op': 'test'}, error, stackTrace);
/// ```
///
/// For named loggers, use [Log.named] instead:
/// ```dart
/// static final _log = Log.named('UserService');
/// ```
const log = Log._();
