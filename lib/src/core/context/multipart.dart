import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

class MultipartFile {
  final String filename;
  final ContentType? contentType;
  final Uint8List bytes;

  MultipartFile({
    required this.filename,
    required this.bytes,
    this.contentType,
  });
}

class MultipartBody {
  final Map<String, String> _fields;
  final Map<String, MultipartFile> _files;

  MultipartBody({
    Map<String, String> fields = const {},
    Map<String, MultipartFile> files = const {},
  })  : _fields = Map.unmodifiable(fields),
        _files = Map.unmodifiable(files);

  UnmodifiableMapView<String, String> get fields => UnmodifiableMapView(_fields);
  UnmodifiableMapView<String, MultipartFile> get files => UnmodifiableMapView(_files);
}

