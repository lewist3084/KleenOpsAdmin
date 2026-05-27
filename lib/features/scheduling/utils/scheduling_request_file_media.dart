import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kleenops_admin/services/storage_service.dart';

class SchedulingRequestFileMedia {
  const SchedulingRequestFileMedia({
    this.imageUrl,
    this.documentUrl,
    this.videoUrl,
  });

  final String? imageUrl;
  final String? documentUrl;
  final String? videoUrl;

  bool get hasMedia =>
      (imageUrl != null && imageUrl!.trim().isNotEmpty) ||
      (documentUrl != null && documentUrl!.trim().isNotEmpty) ||
      (videoUrl != null && videoUrl!.trim().isNotEmpty);

  static const String _imageRole = 'task_request_image';
  static const String _documentRole = 'task_request_document';
  static const String _videoRole = 'task_request_video';

  static Future<SchedulingRequestFileMedia> load({
    required DocumentReference<Map<String, dynamic>> taskRef,
  }) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('file')
          .where('taskId', isEqualTo: taskRef)
          .where('taskMessageRole', whereIn: const [
            _imageRole,
            _documentRole,
            _videoRole,
          ])
          .get();
      if (snap.docs.isEmpty) {
        return const SchedulingRequestFileMedia();
      }

      final entries = snap.docs
          .map((doc) => doc.data())
          .toList(growable: false)
        ..sort((a, b) => _entryOrder(a).compareTo(_entryOrder(b)));

      String? imageUrl;
      String? documentUrl;
      String? videoUrl;

      for (final entry in entries) {
        final role = _stringFromData(entry, const ['taskMessageRole']);
        final type = _normalizeType(entry);
        final url = _stringFromData(entry, const [
          'fileUrl',
          'downloadUrl',
          'url',
          'imageUrl',
          'videoUrl',
        ]);
        if (url == null || url.isEmpty) continue;
        if (role == _imageRole || (role == null && type == 'image')) {
          imageUrl ??= url;
          continue;
        }
        if (role == _documentRole || (role == null && type == 'document')) {
          documentUrl ??= url;
          continue;
        }
        if (role == _videoRole || (role == null && type == 'video')) {
          videoUrl ??= url;
        }
      }

      return SchedulingRequestFileMedia(
        imageUrl: imageUrl,
        documentUrl: documentUrl,
        videoUrl: videoUrl,
      );
    } catch (_) {
      return const SchedulingRequestFileMedia();
    }
  }

  static Future<void> sync({
    required DocumentReference<Map<String, dynamic>> taskRef,
    String? imageUrl,
    String? documentUrl,
    String? videoUrl,
  }) async {
    final fileCollection = FirebaseFirestore.instance.collection('file');
    final existingSnap = await fileCollection
        .where('taskId', isEqualTo: taskRef)
        .where('taskMessageRole', whereIn: const [
          _imageRole,
          _documentRole,
          _videoRole,
        ])
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in existingSnap.docs) {
      batch.delete(doc.reference);
    }

    void addFile({
      required String url,
      required String mediaType,
      required String role,
      required int order,
    }) {
      final trimmed = url.trim();
      if (trimmed.isEmpty) return;
      final docRef = fileCollection.doc();
      final storagePath = StorageService().extractPathFromUrl(trimmed).trim();
      final payload = <String, dynamic>{
        'firestorePath': docRef.path,
        'downloadUrl': trimmed,
        'fileUrl': trimmed,
        'name': 'Task Request ${mediaType.toUpperCase()}',
        'mediaType': mediaType,
        'fileType': mediaType,
        'taskId': taskRef,
        'taskMessageRole': role,
        'order': order,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (storagePath.isNotEmpty) payload['storagePath'] = storagePath;
      batch.set(docRef, payload);
    }

    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      addFile(url: imageUrl, mediaType: 'image', role: _imageRole, order: 0);
    }
    if (documentUrl != null && documentUrl.trim().isNotEmpty) {
      addFile(
        url: documentUrl,
        mediaType: 'document',
        role: _documentRole,
        order: 1,
      );
    }
    if (videoUrl != null && videoUrl.trim().isNotEmpty) {
      addFile(url: videoUrl, mediaType: 'video', role: _videoRole, order: 2);
    }

    await batch.commit();
  }
}

String? _stringFromData(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
  }
  return null;
}

String _normalizeType(Map<String, dynamic> data) {
  final raw = _stringFromData(
    data,
    const ['fileType', 'mediaType', 'type', 'kind'],
  );
  if (raw == null) return '';
  final normalized = raw.toLowerCase();
  if (normalized == 'image' ||
      normalized == 'img' ||
      normalized == 'photo' ||
      normalized == 'picture') {
    return 'image';
  }
  if (normalized == 'video' || normalized == 'movie') return 'video';
  if (normalized == 'pdf' || normalized == 'document' || normalized == 'doc') {
    return 'document';
  }
  return normalized;
}

int _entryOrder(Map<String, dynamic> data) {
  final raw = data['order'];
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return 0;
}
