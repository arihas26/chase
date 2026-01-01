/// Example: File Upload with Multipart
///
/// Chase provides built-in multipart/form-data parsing for handling file uploads.
/// Supports multiple files with the same field name (e.g., `<input type="file" multiple>`).
///
/// Run with: dart run example/multipart.dart
/// Test with: curl -F "name=John" -F "avatar=@photo.png" http://localhost:3000/upload
library;

import 'dart:io';

import 'package:chase/chase.dart';

void main() async {
  final app = Chase();

  // Simple file upload endpoint
  app.post('/upload').handle((ctx) async {
    if (!ctx.req.isMultipart) {
      return Response.badRequest().json({
        'error': 'Expected multipart/form-data',
      });
    }

    final data = await ctx.req.multipart();

    // New API: Use field() and file() for single values
    final name = data.field('name') ?? 'Unknown';
    final avatar = data.file('avatar');

    return Response.json({
      'message': 'Upload successful',
      'name': name,
      'avatar': avatar != null
          ? {
              'filename': avatar.filename,
              'size': avatar.size,
              'extension': avatar.extension,
              'mimeType': avatar.mimeType,
              'isImage': avatar.isImage,
            }
          : null,
    });
  });

  // Multiple files with same name (e.g., <input type="file" name="photos" multiple>)
  app.post('/gallery').handle((ctx) async {
    final data = await ctx.req.multipart();

    // Use fileAll() to get all files with the same name
    final photos = data.fileAll('photos');

    // Filter only images
    final images = photos.where((f) => f.isImage).toList();

    return Response.json({
      'totalFiles': photos.length,
      'images': images.length,
      'files': photos
          .map(
            (f) => {
              'filename': f.filename,
              'size': f.size,
              'extension': f.extension,
            },
          )
          .toList(),
    });
  });

  // Multiple tags (same field name)
  app.post('/article').handle((ctx) async {
    final data = await ctx.req.multipart();

    final title = data.field('title');
    // Use fieldAll() for multiple values with same name
    final tags = data.fieldAll('tags');

    return Response.json({
      'title': title,
      'tags': tags,
      'tagCount': tags.length,
    });
  });

  // Save uploaded file
  app.post('/save').handle((ctx) async {
    final data = await ctx.req.multipart();
    final doc = data.file('document');

    if (doc == null) {
      return Response.badRequest().json({'error': 'No document uploaded'});
    }

    // Save to disk using saveTo() helper
    final uploadPath = 'uploads/${doc.filename}';
    await doc.saveTo(uploadPath);

    return Response.json({'saved': true, 'path': uploadPath, 'size': doc.size});
  });

  // Check available fields and files
  app.post('/info').handle((ctx) async {
    final data = await ctx.req.multipart();

    return Response.json({
      'fieldNames': data.fieldNames.toList(),
      'fileNames': data.fileNames.toList(),
      'fieldCount': data.fieldCount,
      'fileCount': data.fileCount,
      'totalFileCount': data.totalFileCount,
      'hasAvatar': data.hasFile('avatar'),
      'hasName': data.hasField('name'),
    });
  });

  await app.start(port: 3000);
  print('''
File Upload (Multipart) Example
===============================

API:
  data.field('name')     - Get single field value (last if multiple)
  data.fieldAll('tags')  - Get all values for a field name
  data.file('avatar')    - Get single file (last if multiple)
  data.fileAll('photos') - Get all files for a field name

  data.hasField('name')  - Check if field exists
  data.hasFile('avatar') - Check if file exists
  data.fieldNames        - All field names
  data.fileNames         - All file field names

MultipartFile helpers:
  file.size       - File size in bytes
  file.extension  - File extension (e.g., 'png')
  file.mimeType   - MIME type string
  file.isImage    - Whether content-type is image/*
  file.text       - Content as UTF-8 string
  file.saveTo()   - Save to disk

Endpoints:
  POST /upload   - Single file upload
  POST /gallery  - Multiple files (same name)
  POST /article  - Multiple field values
  POST /save     - Save file to disk
  POST /info     - Show all fields and files

Try these commands:

  # Single file upload
  curl -F "name=John" -F "avatar=@photo.png" http://localhost:3000/upload

  # Multiple files with same name
  curl -F "photos=@a.png" -F "photos=@b.jpg" http://localhost:3000/gallery

  # Multiple values for same field
  curl -F "title=My Post" -F "tags=dart" -F "tags=web" -F "tags=api" \\
       http://localhost:3000/article

Server running at http://localhost:3000 (pid: $pid)
''');
}
