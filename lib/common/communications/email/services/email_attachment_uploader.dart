// lib/common/communications/email/services/email_attachment_uploader.dart
//
// Picks a file from the device, uploads it to Cloud Storage, and creates a
// matching `company/{cid}/file/{docId}` document so the attachment is reusable
// later. Returns an EmailAttachment with downloadUrl + storagePath that the
// `emailSend` Cloud Function can read with the admin SDK.
//
// Adapted from the kleenops uploader: uses firebase_storage directly (the admin
// app has no shared StorageService) and computes the file extension inline (no
// `path` package dependency).

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../models/email_attachment.dart';

class EmailAttachmentUploader {
  EmailAttachmentUploader({
    required this.companyRef,
    this.userRef,
    this.memberRef,
    this.teamRef,
  });

  final DocumentReference<Map<String, dynamic>> companyRef;
  final DocumentReference<Map<String, dynamic>>? userRef;
  final DocumentReference<Map<String, dynamic>>? memberRef;
  final DocumentReference<Map<String, dynamic>>? teamRef;

  /// Open the OS file picker. Returns null if the user cancels.
  Future<EmailAttachment?> pickAndUpload() async {
    // On web there is no filesystem path; load the bytes instead so we can
    // upload via putData. Touching a dart:io File on web throws
    // "Unsupported operation: _Namespace".
    final result = await FilePicker.platform.pickFiles(withData: kIsWeb);
    if (result == null || result.files.isEmpty) return null;

    final picked = result.files.single;
    final path = picked.path;
    final bytes = picked.bytes;
    if (path == null && bytes == null) return null;

    final fileName = picked.name;
    final ext = _extension(fileName);
    final fileRef = companyRef.collection('file').doc();
    final storagePath =
        ext.isEmpty ? 'file/${fileRef.id}' : 'file/${fileRef.id}$ext';

    final mimeType = _mimeFromExtension(ext.toLowerCase());
    final metadata =
        mimeType != null ? SettableMetadata(contentType: mimeType) : null;

    final storageRef = FirebaseStorage.instance.ref(storagePath);
    if (kIsWeb || path == null) {
      if (bytes == null) return null;
      await storageRef.putData(bytes, metadata);
    } else {
      final file = File(path);
      if (!await file.exists()) return null;
      await storageRef.putFile(file, metadata);
    }
    final downloadUrl = await storageRef.getDownloadURL();

    final data = <String, dynamic>{
      'firestorePath': fileRef.path,
      'storagePath': storagePath,
      'downloadUrl': downloadUrl,
      'name': fileName,
      'sourceFileName': fileName,
      'sizeBytes': picked.size,
      'teamAccess': true,
      'publicInternal': false,
      'publicExternal': false,
      'createdAt': FieldValue.serverTimestamp(),
      'createdIn': 'communications.email.attachment',
      'sectionKey': 'communications',
      if (userRef != null) 'userRef': userRef,
      if (memberRef != null) 'createdBy': memberRef,
      if (teamRef != null) 'teamId': teamRef,
    };

    await fileRef.set(data);

    return EmailAttachment(
      id: fileRef.id,
      fileName: fileName,
      mimeType: mimeType,
      sizeBytes: picked.size,
      url: downloadUrl,
      storagePath: storagePath,
      type: EmailAttachment.typeFromMime(mimeType),
    );
  }
}

/// Return the dotted extension (".pdf") of a filename, or '' if none.
String _extension(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot < 0 || dot == fileName.length - 1) return '';
  return fileName.substring(dot);
}

String? _mimeFromExtension(String ext) {
  switch (ext) {
    case '.pdf':
      return 'application/pdf';
    case '.png':
      return 'image/png';
    case '.jpg':
    case '.jpeg':
      return 'image/jpeg';
    case '.gif':
      return 'image/gif';
    case '.webp':
      return 'image/webp';
    case '.heic':
      return 'image/heic';
    case '.mp4':
      return 'video/mp4';
    case '.mov':
      return 'video/quicktime';
    case '.mp3':
      return 'audio/mpeg';
    case '.wav':
      return 'audio/wav';
    case '.txt':
      return 'text/plain';
    case '.csv':
      return 'text/csv';
    case '.doc':
      return 'application/msword';
    case '.docx':
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    case '.xls':
      return 'application/vnd.ms-excel';
    case '.xlsx':
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    case '.ppt':
      return 'application/vnd.ms-powerpoint';
    case '.pptx':
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    case '.zip':
      return 'application/zip';
    case '.json':
      return 'application/json';
    case '.html':
    case '.htm':
      return 'text/html';
    default:
      return null;
  }
}
