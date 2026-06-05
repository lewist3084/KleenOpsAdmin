// lib/services/storage_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

/// Define the three image quality settings.
enum ImageQualitySetting {
  max,      // No resizing; use original pixel dimensions.
  high,     // Resize to a max of 1600px.
  standard, // Resize to a max of 1080px.
}

class StorageService {
  final firebase_storage.FirebaseStorage _storage =
      firebase_storage.FirebaseStorage.instance;

  /// Create a Firebase Storage Reference for the given [path].
  firebase_storage.Reference getStorageRef(String path) {
    return _storage.ref().child(path);
  }

  /// Lets the user pick an image from camera or gallery without compression.
  Future<File?> pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile == null) return null;
    return File(pickedFile.path);
  }

  /// Lets the user pick an image **and** compress it based on the [qualitySetting].
  /// All settings use 80% JPEG quality by default.
  /// - [max]: returns the original file (no resizing)
  /// - [high]: resizes the image so that its width and height are at most 1600 pixels.
  /// - [standard]: resizes the image so that its width and height are at most 1080 pixels.
  Future<File?> pickAndCompressImage(
    ImageSource source, {
    ImageQualitySetting qualitySetting = ImageQualitySetting.standard,
    int quality = 80,
  }) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile == null) return null;

    final file = File(pickedFile.path);

    if (qualitySetting == ImageQualitySetting.max) {
      // No resizing, return original file.
      return file;
    } else if (qualitySetting == ImageQualitySetting.high) {
      return await _compressImage(
        file,
        quality: quality,
        targetWidth: 1600,
        targetHeight: 1600,
      );
    } else {
      // Default = standard
      return await _compressImage(
        file,
        quality: quality,
        targetWidth: 1080,
        targetHeight: 1080,
      );
    }
  }

  /// Compress an image file to the given pixel dimensions, with the given [quality].
  Future<File?> _compressImage(
    File file, {
    required int quality,
    required int targetWidth,
    required int targetHeight,
  }) async {
    final targetPath =
        '${file.parent.path}/temp_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: quality,
      minWidth: targetWidth,
      minHeight: targetHeight,
    );
    // Convert the XFile to File.
    return (result != null) ? File(result.path) : null;
  }

  /// Uploads a [File] to Firebase Storage at [storagePath] and returns the download URL.
  Future<String> uploadFile(
    File file,
    String storagePath, {
    String? contentType,
  }) async {
    final ref = _storage.ref().child(storagePath);
    if (!await file.exists()) {
      throw Exception("File does not exist at path: ${file.path}");
    }
    await ref.putFile(
      file,
      contentType != null
          ? firebase_storage.SettableMetadata(contentType: contentType)
          : null,
    );
    return await ref.getDownloadURL();
  }

  /// Web-safe upload from a cross-platform [XFile]: bytes+putData on web,
  /// putFile on mobile. Avoids the `dart:io` File ops that throw
  /// `Unsupported operation: _Namespace` in the browser.
  Future<String> uploadXFile(
    XFile file,
    String storagePath, {
    String? contentType,
  }) async {
    final ref = _storage.ref().child(storagePath);
    final meta = contentType != null
        ? firebase_storage.SettableMetadata(contentType: contentType)
        : null;
    if (kIsWeb) {
      await ref.putData(await file.readAsBytes(), meta);
    } else {
      await ref.putFile(File(file.path), meta);
    }
    return ref.getDownloadURL();
  }

  /// Like [pickAndCompressImage] but returns a cross-platform [XFile] (never a
  /// `dart:io` File), so it's safe to upload on web via [uploadXFile].
  Future<XFile?> pickAndCompressImageX(
    ImageSource source, {
    ImageQualitySetting qualitySetting = ImageQualitySetting.standard,
    int quality = 80,
  }) async {
    final picker = ImagePicker();
    if (qualitySetting == ImageQualitySetting.max) {
      return picker.pickImage(source: source);
    }
    final targetSize =
        qualitySetting == ImageQualitySetting.high ? 1600.0 : 1080.0;
    return picker.pickImage(
      source: source,
      imageQuality: quality,
      maxWidth: targetSize,
      maxHeight: targetSize,
    );
  }

  /// Upload a video [file]. The admin app has no client-side video compression
  /// (video_compress is mobile-only and not a dependency here), so this is a
  /// straight upload — kept as a named method for parity with the kleenops
  /// StorageService API used by the texting attachment flow.
  Future<String> uploadVideo(
    File file,
    String storagePath, {
    String? contentType,
  }) async {
    return uploadFile(file, storagePath, contentType: contentType);
  }

  /// Uploads [data] (as bytes) to Firebase Storage at [storagePath] and returns the download URL.
  Future<String> uploadData(
    Uint8List data,
    String storagePath, {
    String contentType = 'application/octet-stream',
  }) async {
    final ref = _storage.ref().child(storagePath);
    await ref.putData(
      data,
      firebase_storage.SettableMetadata(contentType: contentType),
    );
    return await ref.getDownloadURL();
  }

  /// Delete the file at [storagePath] in Firebase Storage.
  Future<void> deleteFile(String storagePath) async {
    final ref = _storage.ref().child(storagePath);
    await ref.delete();
  }

  /// Convenience helper that deletes a file directly from its [downloadUrl].
  Future<void> deleteFileFromUrl(String downloadUrl) async {
    final ref = _storage.refFromURL(downloadUrl);
    await ref.delete();
  }

  /// Extracts the "folder/filename.png" portion from a typical Firebase Storage download URL,
  /// so you can call [deleteFile] with it if needed.
  String extractPathFromUrl(String downloadUrl) {
    // Typically the URL looks like:
    // https://firebasestorage.googleapis.com/v0/b/<YOUR-BUCKET>/o/user_images%2F1679311000000.png?...
    // We'll parse out "user_images/1679311000000.png"
    try {
      final uri = Uri.parse(downloadUrl);
      // Path segments might be: [v0, b, YOUR-BUCKET, o, user_images%2F1679311000000.png]
      // The last part is the encoded path, e.g. "user_images%2F1679311000000.png"
      final encodedPath =
          uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
      final decodedPath =
          Uri.decodeComponent(encodedPath); // "user_images/1679311000000.png"
      // If there's a query param, it's after the '?', which decodeComponent won't handle for the path.
      // But typically the "last" segment includes the encoded slash, so this is enough.
      return decodedPath;
    } catch (_) {
      return '';
    }
  }
}
