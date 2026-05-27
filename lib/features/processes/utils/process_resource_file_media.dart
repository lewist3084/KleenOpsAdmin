import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kleenops_admin/services/storage_service.dart';
import 'package:path/path.dart' as p;

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

int _intFromData(Map<String, dynamic> data, List<String> keys, int fallback) {
  for (final key in keys) {
    final value = data[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
  }
  return fallback;
}

String _extensionFromUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return '';
  final path = Uri.tryParse(trimmed)?.path ?? trimmed;
  final ext = p.extension(path).toLowerCase();
  if (ext.isEmpty) return '';
  return ext.startsWith('.') ? ext.substring(1) : ext;
}

String? _storagePathFromUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.startsWith('gs://')) {
    final withoutScheme = trimmed.substring(5);
    final parts = withoutScheme.split('/');
    if (parts.length >= 2) {
      return parts.sublist(1).join('/');
    }
    return null;
  }
  if (trimmed.startsWith('http')) {
    final path = StorageService().extractPathFromUrl(trimmed).trim();
    return path.isNotEmpty ? path : null;
  }
  return trimmed.contains('/') ? trimmed : null;
}

String _fileKeyFromUrl(String url, String? storagePath) {
  if (storagePath != null && storagePath.trim().isNotEmpty) {
    return 'storage:${storagePath.trim()}';
  }
  final trimmed = url.trim();
  return trimmed.isNotEmpty ? 'url:$trimmed' : '';
}

bool _isVideoFile(Map<String, dynamic> data, String url) {
  final fileType = (data['fileType'] ?? data['mediaType'] ?? '')
      .toString()
      .toLowerCase();
  if (fileType.contains('video')) return true;
  final ext = _extensionFromUrl(url);
  return const <String>{'mp4', 'mov', 'webm', 'm4v'}.contains(ext);
}

bool _isImageFile(Map<String, dynamic> data, String url) {
  final fileType = (data['fileType'] ?? data['mediaType'] ?? '')
      .toString()
      .toLowerCase();
  if (fileType.contains('image')) return true;
  final ext = _extensionFromUrl(url);
  return const <String>{
    'jpg',
    'jpeg',
    'png',
    'gif',
    'bmp',
    'webp',
  }.contains(ext);
}

bool _isDocumentFile(Map<String, dynamic> data, String url) {
  final fileType = (data['fileType'] ?? data['mediaType'] ?? '')
      .toString()
      .toLowerCase();
  if (fileType.contains('document') || fileType.contains('pdf')) return true;
  final ext = _extensionFromUrl(url);
  return const <String>{
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
  }.contains(ext);
}

class ProcessResourceFileMedia {
  final List<Map<String, dynamic>> images;
  final List<Map<String, dynamic>> videos;
  final List<Map<String, dynamic>> documents;

  const ProcessResourceFileMedia({
    required this.images,
    required this.videos,
    required this.documents,
  });

  String? get primaryImageUrl =>
      images.isNotEmpty ? (images.first['url'] as String?) : null;

  String? get primaryVideoUrl =>
      videos.isNotEmpty ? (videos.first['videoUrl'] as String?) : null;

  String? get primaryVideoThumbnail =>
      videos.isNotEmpty ? (videos.first['videoThumbnail'] as String?) : null;

  int? get primaryVideoDuration =>
      videos.isNotEmpty ? videos.first['videoDuration'] as int? : null;

  String? get primaryDocumentUrl =>
      documents.isNotEmpty ? (documents.first['fileUrl'] as String?) : null;

  static Future<ProcessResourceFileMedia> load({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required DocumentReference<Map<String, dynamic>> resourceRef,
  }) async {
    try {
      final snap = await companyRef
          .collection('file')
          .where('resourceRef', isEqualTo: resourceRef)
          .get();

      final images = <Map<String, dynamic>>[];
      final videos = <Map<String, dynamic>>[];
      final documents = <Map<String, dynamic>>[];
      var fallbackOrder = 0;

      for (final doc in snap.docs) {
        final data = doc.data();
        final url = _stringFromData(data, const [
          'downloadUrl',
          'url',
          'fileUrl',
          'imageUrl',
          'videoUrl',
        ]);
        if (url == null || url.isEmpty) continue;
        final order = _intFromData(data, const ['order'], fallbackOrder);
        final isMaster = data['isMaster'] == true;

        if (_isVideoFile(data, url)) {
          videos.add({
            'videoUrl': url,
            'videoThumbnail': _stringFromData(
              data,
              const ['thumbnailUrl', 'videoThumbnail', 'imageUrl'],
            ),
            'videoDuration': _intFromData(
              data,
              const ['videoDuration', 'duration'],
              0,
            ),
            'order': order,
            'isMaster': isMaster,
          });
        } else if (_isImageFile(data, url)) {
          images.add({
            'url': url,
            'order': order,
            'isMaster': isMaster,
          });
        } else if (_isDocumentFile(data, url)) {
          documents.add({
            'fileUrl': url,
            'order': order,
            'isMaster': isMaster,
            'fileName': _stringFromData(
              data,
              const ['sourceFileName', 'fileName', 'name'],
            ),
          });
        }

        fallbackOrder += 1;
      }

      _sortMediaEntries(images);
      _sortMediaEntries(videos);
      _sortMediaEntries(documents);

      return ProcessResourceFileMedia(
        images: images,
        videos: videos,
        documents: documents,
      );
    } catch (_) {
      return const ProcessResourceFileMedia(
        images: <Map<String, dynamic>>[],
        videos: <Map<String, dynamic>>[],
        documents: <Map<String, dynamic>>[],
      );
    }
  }

  static Future<void> syncResourceMedia({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required DocumentReference<Map<String, dynamic>> resourceRef,
    required String resourceName,
    required String? imageUrl,
    required String? videoUrl,
    required String? videoThumbnail,
    required int? videoDuration,
    required String? documentUrl,
  }) async {
    final attachments = <_ResourceAttachment>[];
    final trimmedVideoUrl = (videoUrl ?? '').trim();
    final trimmedImageUrl = (imageUrl ?? '').trim();
    final trimmedDocUrl = (documentUrl ?? '').trim();

    if (trimmedVideoUrl.isNotEmpty) {
      attachments.add(
        _ResourceAttachment(
          url: trimmedVideoUrl,
          fileType: 'video',
          mediaType: 'Video',
          order: 0,
          isMaster: true,
          thumbnailUrl: (videoThumbnail ?? '').trim(),
          duration: videoDuration,
        ),
      );
    }

    if (trimmedImageUrl.isNotEmpty) {
      attachments.add(
        _ResourceAttachment(
          url: trimmedImageUrl,
          fileType: 'image',
          mediaType: 'Image',
          order: attachments.length,
          isMaster: attachments.isEmpty,
        ),
      );
    }

    if (trimmedDocUrl.isNotEmpty) {
      attachments.add(
        _ResourceAttachment(
          url: trimmedDocUrl,
          fileType: 'document',
          mediaType: 'Document',
          order: attachments.length,
          isMaster: attachments.isEmpty,
        ),
      );
    }

    final fileCollection = companyRef.collection('file');
    final existingSnap = await fileCollection
        .where('resourceRef', isEqualTo: resourceRef)
        .get();

    if (attachments.isEmpty) {
      if (existingSnap.docs.isEmpty) return;
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in existingSnap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      return;
    }

    final existingByKey =
        <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final doc in existingSnap.docs) {
      final data = doc.data();
      final url = _stringFromData(data, const [
        'downloadUrl',
        'url',
        'fileUrl',
        'imageUrl',
        'videoUrl',
      ]);
      if (url == null || url.isEmpty) continue;
      final storagePath =
          (data['storagePath'] as String?)?.trim() ?? _storagePathFromUrl(url);
      final key = _fileKeyFromUrl(url, storagePath);
      if (key.isNotEmpty) existingByKey[key] = doc;
    }

    final batch = FirebaseFirestore.instance.batch();
    final usedKeys = <String>{};
    for (var i = 0; i < attachments.length; i += 1) {
      final attachment = attachments[i];
      final url = attachment.url.trim();
      if (url.isEmpty) continue;
      final storagePath = _storagePathFromUrl(url);
      final key = _fileKeyFromUrl(url, storagePath);
      if (key.isEmpty || usedKeys.contains(key)) continue;
      usedKeys.add(key);

      final existing = existingByKey[key];
      final docRef = existing?.reference ?? fileCollection.doc();
      final extension = _extensionFromUrl(url);

      final payload = <String, dynamic>{
        'firestorePath': docRef.path,
        'downloadUrl': url,
        'fileUrl': url,
        'name': '$resourceName ${attachment.mediaType}',
        'mediaType': attachment.mediaType,
        'fileType': attachment.fileType,
        'resourceRef': resourceRef,
        'order': attachment.order ?? i,
        'isMaster': attachment.isMaster,
        'updatedAt': FieldValue.serverTimestamp(),
        if (existing == null) 'createdAt': FieldValue.serverTimestamp(),
      };
      if (storagePath != null && storagePath.isNotEmpty) {
        payload['storagePath'] = storagePath;
      }
      if (extension.isNotEmpty) {
        payload['fileExtension'] = extension;
      }
      if (attachment.thumbnailUrl != null &&
          attachment.thumbnailUrl!.isNotEmpty) {
        payload['thumbnailUrl'] = attachment.thumbnailUrl;
        payload['videoThumbnail'] = attachment.thumbnailUrl;
      }
      if (attachment.duration != null) {
        payload['duration'] = attachment.duration;
        payload['videoDuration'] = attachment.duration;
      }

      batch.set(docRef, payload, SetOptions(merge: true));
    }

    for (final entry in existingByKey.entries) {
      if (!usedKeys.contains(entry.key)) {
        batch.delete(entry.value.reference);
      }
    }

    await batch.commit();
  }
}

void _sortMediaEntries(List<Map<String, dynamic>> entries) {
  entries.sort((a, b) {
    final aMaster = a['isMaster'] == true;
    final bMaster = b['isMaster'] == true;
    if (aMaster != bMaster) return aMaster ? -1 : 1;
    final aOrder = a['order'] is int ? a['order'] as int : 0;
    final bOrder = b['order'] is int ? b['order'] as int : 0;
    return aOrder.compareTo(bOrder);
  });
}

class _ResourceAttachment {
  final String url;
  final String fileType;
  final String mediaType;
  final int? order;
  final bool isMaster;
  final String? thumbnailUrl;
  final int? duration;

  const _ResourceAttachment({
    required this.url,
    required this.fileType,
    required this.mediaType,
    required this.order,
    required this.isMaster,
    this.thumbnailUrl,
    this.duration,
  });
}
