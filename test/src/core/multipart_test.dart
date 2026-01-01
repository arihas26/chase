import 'dart:convert';
import 'dart:typed_data';

import 'package:chase/chase.dart';
import 'package:chase/testing/testing.dart';
import 'package:test/test.dart';

void main() {
  group('Multipart', () {
    late TestClient client;

    tearDown(() async {
      await client.close();
    });

    group('parsing', () {
      test('parses text fields', () async {
        final app = Chase();
        app.post('/upload').handle((ctx) async {
          final data = await ctx.req.multipart();
          await ctx.res.json({
            'name': data.fields['name'],
            'email': data.fields['email'],
          });
        });

        client = await TestClient.start(app);
        final res = await client.postMultipart('/upload', fields: {
          'name': 'John Doe',
          'email': 'john@example.com',
        });

        expect(res.status, 200);
        final body = await res.json;
        expect(body['name'], 'John Doe');
        expect(body['email'], 'john@example.com');
      });

      test('parses file uploads', () async {
        final app = Chase();
        app.post('/upload').handle((ctx) async {
          final data = await ctx.req.multipart();
          final file = data.files['avatar'];
          await ctx.res.json({
            'filename': file?.filename,
            'size': file?.bytes.length,
            'contentType': file?.contentType?.mimeType,
          });
        });

        client = await TestClient.start(app);
        final res = await client.postMultipart('/upload', files: {
          'avatar': MultipartFileData(
            filename: 'profile.png',
            bytes: Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]),
            contentType: 'image/png',
          ),
        });

        expect(res.status, 200);
        final body = await res.json;
        expect(body['filename'], 'profile.png');
        expect(body['size'], 4);
        expect(body['contentType'], 'image/png');
      });

      test('parses mixed fields and files', () async {
        final app = Chase();
        app.post('/upload').handle((ctx) async {
          final data = await ctx.req.multipart();
          await ctx.res.json({
            'title': data.fields['title'],
            'description': data.fields['description'],
            'fileCount': data.files.length,
            'file1': data.files['doc1']?.filename,
            'file2': data.files['doc2']?.filename,
          });
        });

        client = await TestClient.start(app);
        final res = await client.postMultipart(
          '/upload',
          fields: {
            'title': 'My Upload',
            'description': 'Test files',
          },
          files: {
            'doc1': MultipartFileData(
              filename: 'readme.txt',
              bytes: utf8.encode('Hello World'),
              contentType: 'text/plain',
            ),
            'doc2': MultipartFileData(
              filename: 'data.json',
              bytes: utf8.encode('{"key":"value"}'),
              contentType: 'application/json',
            ),
          },
        );

        expect(res.status, 200);
        final body = await res.json;
        expect(body['title'], 'My Upload');
        expect(body['description'], 'Test files');
        expect(body['fileCount'], 2);
        expect(body['file1'], 'readme.txt');
        expect(body['file2'], 'data.json');
      });

      test('handles empty multipart body', () async {
        final app = Chase();
        app.post('/upload').handle((ctx) async {
          final data = await ctx.req.multipart();
          await ctx.res.json({
            'fieldCount': data.fields.length,
            'fileCount': data.files.length,
          });
        });

        client = await TestClient.start(app);
        final res = await client.postMultipart('/upload');

        expect(res.status, 200);
        final body = await res.json;
        expect(body['fieldCount'], 0);
        expect(body['fileCount'], 0);
      });

      test('caches multipart result', () async {
        final app = Chase();
        app.post('/upload').handle((ctx) async {
          // Call multipart() twice
          final data1 = await ctx.req.multipart();
          final data2 = await ctx.req.multipart();
          // Second call should return cached result
          await ctx.res.json({
            'same': identical(data1, data2),
            'name': data1.fields['name'],
          });
        });

        client = await TestClient.start(app);
        final res = await client.postMultipart('/upload', fields: {
          'name': 'Test',
        });

        expect(res.status, 200);
        final body = await res.json;
        expect(body['same'], isTrue);
        expect(body['name'], 'Test');
      });
    });

    group('isMultipart', () {
      test('returns true for multipart content-type', () async {
        final app = Chase();
        app.post('/check').handle((ctx) async {
          await ctx.res.json({'isMultipart': ctx.req.isMultipart});
        });

        client = await TestClient.start(app);
        final res = await client.postMultipart('/check');

        expect(res.status, 200);
        final body = await res.json;
        expect(body['isMultipart'], isTrue);
      });

      test('returns false for other content-types', () async {
        final app = Chase();
        app.post('/check').handle((ctx) async {
          await ctx.res.json({'isMultipart': ctx.req.isMultipart});
        });

        client = await TestClient.start(app);
        final res = await client.post('/check',
            body: '{"test": true}',
            headers: {'content-type': 'application/json'});

        expect(res.status, 200);
        final body = await res.json;
        expect(body['isMultipart'], isFalse);
      });
    });

    group('error handling', () {
      test('throws on invalid content-type', () async {
        final app = Chase();
        app.use(ExceptionHandler());
        app.post('/upload').handle((ctx) async {
          await ctx.req.multipart();
          await ctx.res.json({'error': false});
        });

        client = await TestClient.start(app);
        final res = await client.post('/upload',
            body: 'plain text', headers: {'content-type': 'text/plain'});

        expect(res.status, 400);
      });
    });

    group('multiple files with same name', () {
      test('handles multiple files with same field name', () async {
        final app = Chase();
        app.post('/upload').handle((ctx) async {
          final data = await ctx.req.multipart();
          final photos = data.fileAll('photos');
          await ctx.res.json({
            'count': photos.length,
            'filenames': photos.map((f) => f.filename).toList(),
          });
        });

        client = await TestClient.start(app);

        // Build multipart body with multiple files under same name
        final boundary = 'test-boundary-123';
        final body = _buildMultipartWithDuplicates(boundary);

        final res = await client.post(
          '/upload',
          body: String.fromCharCodes(body),
          headers: {'content-type': 'multipart/form-data; boundary=$boundary'},
        );

        expect(res.status, 200);
        final json = await res.json;
        expect(json['count'], 2);
        expect(json['filenames'], ['photo1.png', 'photo2.png']);
      });

      test('file() returns last file when multiple exist', () async {
        final app = Chase();
        app.post('/upload').handle((ctx) async {
          final data = await ctx.req.multipart();
          final photo = data.file('photos');
          await ctx.res.json({
            'filename': photo?.filename,
          });
        });

        client = await TestClient.start(app);

        final boundary = 'test-boundary-123';
        final body = _buildMultipartWithDuplicates(boundary);

        final res = await client.post(
          '/upload',
          body: String.fromCharCodes(body),
          headers: {'content-type': 'multipart/form-data; boundary=$boundary'},
        );

        expect(res.status, 200);
        final json = await res.json;
        expect(json['filename'], 'photo2.png'); // Last one
      });

      test('handles multiple field values with same name', () async {
        final app = Chase();
        app.post('/upload').handle((ctx) async {
          final data = await ctx.req.multipart();
          await ctx.res.json({
            'single': data.field('tag'),
            'all': data.fieldAll('tag'),
          });
        });

        client = await TestClient.start(app);

        final boundary = 'test-boundary-456';
        final body = _buildMultipartWithDuplicateFields(boundary);

        final res = await client.post(
          '/upload',
          body: String.fromCharCodes(body),
          headers: {'content-type': 'multipart/form-data; boundary=$boundary'},
        );

        expect(res.status, 200);
        final json = await res.json;
        expect(json['single'], 'tag3'); // Last one
        expect(json['all'], ['tag1', 'tag2', 'tag3']);
      });
    });

    group('MultipartBody API', () {
      test('hasField and hasFile work correctly', () async {
        final app = Chase();
        app.post('/upload').handle((ctx) async {
          final data = await ctx.req.multipart();
          await ctx.res.json({
            'hasName': data.hasField('name'),
            'hasMissing': data.hasField('missing'),
            'hasAvatar': data.hasFile('avatar'),
            'hasMissingFile': data.hasFile('missing'),
          });
        });

        client = await TestClient.start(app);
        final res = await client.postMultipart('/upload',
            fields: {'name': 'John'},
            files: {
              'avatar': MultipartFileData(
                filename: 'photo.png',
                bytes: Uint8List.fromList([1, 2, 3]),
              ),
            });

        expect(res.status, 200);
        final json = await res.json;
        expect(json['hasName'], isTrue);
        expect(json['hasMissing'], isFalse);
        expect(json['hasAvatar'], isTrue);
        expect(json['hasMissingFile'], isFalse);
      });

      test('fieldNames and fileNames return correct values', () async {
        final app = Chase();
        app.post('/upload').handle((ctx) async {
          final data = await ctx.req.multipart();
          await ctx.res.json({
            'fieldNames': data.fieldNames.toList(),
            'fileNames': data.fileNames.toList(),
            'fieldCount': data.fieldCount,
            'fileCount': data.fileCount,
          });
        });

        client = await TestClient.start(app);
        final res = await client.postMultipart('/upload',
            fields: {'name': 'John', 'email': 'john@test.com'},
            files: {
              'doc1': MultipartFileData(
                  filename: 'a.txt', bytes: Uint8List.fromList([1])),
              'doc2': MultipartFileData(
                  filename: 'b.txt', bytes: Uint8List.fromList([2])),
            });

        expect(res.status, 200);
        final json = await res.json;
        expect(json['fieldNames'], containsAll(['name', 'email']));
        expect(json['fileNames'], containsAll(['doc1', 'doc2']));
        expect(json['fieldCount'], 2);
        expect(json['fileCount'], 2);
      });
    });

    group('MultipartFile helpers', () {
      test('size returns correct byte count', () async {
        final app = Chase();
        app.post('/upload').handle((ctx) async {
          final data = await ctx.req.multipart();
          final file = data.file('doc');
          await ctx.res.json({'size': file?.size});
        });

        client = await TestClient.start(app);
        final res = await client.postMultipart('/upload', files: {
          'doc': MultipartFileData(
            filename: 'test.txt',
            bytes: Uint8List.fromList([1, 2, 3, 4, 5]),
          ),
        });

        expect(res.status, 200);
        final json = await res.json;
        expect(json['size'], 5);
      });

      test('extension returns file extension', () async {
        final app = Chase();
        app.post('/upload').handle((ctx) async {
          final data = await ctx.req.multipart();
          final file = data.file('doc');
          await ctx.res.json({'extension': file?.extension});
        });

        client = await TestClient.start(app);
        final res = await client.postMultipart('/upload', files: {
          'doc': MultipartFileData(
            filename: 'document.pdf',
            bytes: Uint8List.fromList([1]),
          ),
        });

        expect(res.status, 200);
        final json = await res.json;
        expect(json['extension'], 'pdf');
      });

      test('isImage returns true for image content type', () async {
        final app = Chase();
        app.post('/upload').handle((ctx) async {
          final data = await ctx.req.multipart();
          final file = data.file('img');
          await ctx.res.json({
            'isImage': file?.isImage,
            'mimeType': file?.mimeType,
          });
        });

        client = await TestClient.start(app);
        final res = await client.postMultipart('/upload', files: {
          'img': MultipartFileData(
            filename: 'photo.png',
            bytes: Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]),
            contentType: 'image/png',
          ),
        });

        expect(res.status, 200);
        final json = await res.json;
        expect(json['isImage'], isTrue);
        expect(json['mimeType'], 'image/png');
      });

      test('text returns content as string', () async {
        final app = Chase();
        app.post('/upload').handle((ctx) async {
          final data = await ctx.req.multipart();
          final file = data.file('doc');
          await ctx.res.json({'content': file?.text});
        });

        client = await TestClient.start(app);
        final res = await client.postMultipart('/upload', files: {
          'doc': MultipartFileData(
            filename: 'hello.txt',
            bytes: utf8.encode('Hello, World!'),
            contentType: 'text/plain',
          ),
        });

        expect(res.status, 200);
        final json = await res.json;
        expect(json['content'], 'Hello, World!');
      });
    });

    group('file content', () {
      test('preserves binary content', () async {
        final originalBytes = Uint8List.fromList(
            List.generate(256, (i) => i)); // All byte values 0-255

        final app = Chase();
        app.post('/upload').handle((ctx) async {
          final data = await ctx.req.multipart();
          final file = data.files['binary'];
          await ctx.res.json({
            'size': file?.bytes.length,
            'first': file?.bytes.first,
            'last': file?.bytes.last,
            'match': file?.bytes.toString() == originalBytes.toString(),
          });
        });

        client = await TestClient.start(app);
        final res = await client.postMultipart('/upload', files: {
          'binary': MultipartFileData(
            filename: 'binary.bin',
            bytes: originalBytes,
            contentType: 'application/octet-stream',
          ),
        });

        expect(res.status, 200);
        final body = await res.json;
        expect(body['size'], 256);
        expect(body['first'], 0);
        expect(body['last'], 255);
        expect(body['match'], isTrue);
      });

      test('handles UTF-8 text in fields', () async {
        final app = Chase();
        app.post('/upload').handle((ctx) async {
          final data = await ctx.req.multipart();
          await ctx.res.json({
            'greeting': data.fields['greeting'],
            'name': data.fields['name'],
          });
        });

        client = await TestClient.start(app);
        final res = await client.postMultipart('/upload', fields: {
          'greeting': 'こんにちは',
          'name': '田中太郎',
        });

        expect(res.status, 200);
        final body = await res.json;
        expect(body['greeting'], 'こんにちは');
        expect(body['name'], '田中太郎');
      });
    });
  });
}

// Helper to build multipart body with multiple files under same name
List<int> _buildMultipartWithDuplicates(String boundary) {
  final parts = <String>[
    '--$boundary\r\n',
    'Content-Disposition: form-data; name="photos"; filename="photo1.png"\r\n',
    'Content-Type: image/png\r\n',
    '\r\n',
    'PNG1',
    '\r\n',
    '--$boundary\r\n',
    'Content-Disposition: form-data; name="photos"; filename="photo2.png"\r\n',
    'Content-Type: image/png\r\n',
    '\r\n',
    'PNG2',
    '\r\n',
    '--$boundary--\r\n',
  ];
  return utf8.encode(parts.join());
}

// Helper to build multipart body with multiple fields under same name
List<int> _buildMultipartWithDuplicateFields(String boundary) {
  final parts = <String>[
    '--$boundary\r\n',
    'Content-Disposition: form-data; name="tag"\r\n',
    '\r\n',
    'tag1',
    '\r\n',
    '--$boundary\r\n',
    'Content-Disposition: form-data; name="tag"\r\n',
    '\r\n',
    'tag2',
    '\r\n',
    '--$boundary\r\n',
    'Content-Disposition: form-data; name="tag"\r\n',
    '\r\n',
    'tag3',
    '\r\n',
    '--$boundary--\r\n',
  ];
  return utf8.encode(parts.join());
}
