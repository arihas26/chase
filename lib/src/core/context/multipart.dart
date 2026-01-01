import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// Represents an uploaded file from multipart/form-data.
///
/// Example:
/// ```dart
/// final data = await ctx.req.multipart();
/// final avatar = data.file('avatar');
/// if (avatar != null) {
///   print('Filename: ${avatar.filename}');
///   print('Size: ${avatar.size} bytes');
///   print('Extension: ${avatar.extension}');
///   await avatar.saveTo('uploads/${avatar.filename}');
/// }
/// ```
class MultipartFile {
  /// The original filename from the upload.
  final String filename;

  /// The content type (MIME type) of the file.
  final ContentType? contentType;

  /// The file content as bytes.
  final Uint8List bytes;

  /// Creates a MultipartFile.
  MultipartFile({
    required this.filename,
    required this.bytes,
    this.contentType,
  });

  /// The file size in bytes.
  int get size => bytes.length;

  /// The file extension (without dot), or empty string if none.
  ///
  /// Example: 'png', 'jpg', 'pdf'
  String get extension {
    final ext = p.extension(filename);
    return ext.startsWith('.') ? ext.substring(1) : ext;
  }

  /// The MIME type string, or null if not available.
  String? get mimeType => contentType?.mimeType;

  /// Whether the file is an image (based on content type).
  bool get isImage => contentType?.primaryType == 'image';

  /// Whether the file is a video (based on content type).
  bool get isVideo => contentType?.primaryType == 'video';

  /// Whether the file is audio (based on content type).
  bool get isAudio => contentType?.primaryType == 'audio';

  /// Whether the file is text (based on content type).
  bool get isText => contentType?.primaryType == 'text';

  /// Saves the file to the specified path.
  ///
  /// Creates parent directories if they don't exist.
  ///
  /// Example:
  /// ```dart
  /// await file.saveTo('uploads/avatar.png');
  /// ```
  Future<void> saveTo(String path) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
  }

  /// Returns the file content as a UTF-8 string.
  ///
  /// Useful for text files like CSV, JSON, etc.
  String get text => String.fromCharCodes(bytes);

  @override
  String toString() =>
      'MultipartFile(filename: $filename, size: $size, contentType: $mimeType)';
}

/// Parsed multipart/form-data body containing fields and files.
///
/// Supports multiple values for the same field name (common with
/// `<input type="file" multiple>` or multiple fields with same name).
///
/// Example:
/// ```dart
/// final data = await ctx.req.multipart();
///
/// // Single value access (returns last value if multiple)
/// final name = data.field('name');
/// final avatar = data.file('avatar');
///
/// // Multiple values access
/// final tags = data.fieldAll('tags');        // List<String>
/// final photos = data.fileAll('photos');     // List<MultipartFile>
///
/// // Check existence
/// if (data.hasField('email')) { ... }
/// if (data.hasFile('document')) { ... }
///
/// // Iterate all
/// for (final name in data.fieldNames) { ... }
/// for (final name in data.fileNames) { ... }
/// ```
class MultipartBody {
  final Map<String, List<String>> _fields;
  final Map<String, List<MultipartFile>> _files;

  /// Creates a MultipartBody.
  MultipartBody({
    Map<String, List<String>>? fields,
    Map<String, List<MultipartFile>>? files,
  })  : _fields = fields ?? {},
        _files = files ?? {};

  // ---------------------------------------------------------------------------
  // Fields
  // ---------------------------------------------------------------------------

  /// Gets a single field value by name.
  ///
  /// Returns the last value if multiple values exist for the same name.
  /// Returns null if the field doesn't exist.
  String? field(String name) {
    final values = _fields[name];
    return values?.isNotEmpty == true ? values!.last : null;
  }

  /// Gets all field values for a name.
  ///
  /// Returns an empty list if the field doesn't exist.
  List<String> fieldAll(String name) => _fields[name] ?? const [];

  /// Whether a field with the given name exists.
  bool hasField(String name) => _fields.containsKey(name);

  /// All field names.
  Iterable<String> get fieldNames => _fields.keys;

  /// Number of unique field names.
  int get fieldCount => _fields.length;

  // ---------------------------------------------------------------------------
  // Files
  // ---------------------------------------------------------------------------

  /// Gets a single file by name.
  ///
  /// Returns the last file if multiple files exist for the same name.
  /// Returns null if no file with that name exists.
  MultipartFile? file(String name) {
    final files = _files[name];
    return files?.isNotEmpty == true ? files!.last : null;
  }

  /// Gets all files for a name.
  ///
  /// Returns an empty list if no files with that name exist.
  List<MultipartFile> fileAll(String name) => _files[name] ?? const [];

  /// Whether a file with the given name exists.
  bool hasFile(String name) => _files.containsKey(name);

  /// All file field names.
  Iterable<String> get fileNames => _files.keys;

  /// Number of unique file field names.
  int get fileCount => _files.length;

  /// Total number of uploaded files (including multiple files per field).
  int get totalFileCount =>
      _files.values.fold(0, (sum, list) => sum + list.length);

  // ---------------------------------------------------------------------------
  // Legacy accessors (for backwards compatibility)
  // ---------------------------------------------------------------------------

  /// All fields as a map (last value for each name).
  ///
  /// For multiple values, use [fieldAll] instead.
  Map<String, String> get fields =>
      _fields.map((key, values) => MapEntry(key, values.last));

  /// All files as a map (last file for each name).
  ///
  /// For multiple files, use [fileAll] instead.
  Map<String, MultipartFile> get files =>
      _files.map((key, files) => MapEntry(key, files.last));

  @override
  String toString() =>
      'MultipartBody(fields: ${_fields.length}, files: $totalFileCount)';
}
