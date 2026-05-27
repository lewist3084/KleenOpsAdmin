import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kleenops_admin/services/storage_service.dart';

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

String _resolveFileType(Map<String, dynamic> data) {
  final fileType = (data['fileType'] ?? '').toString().toLowerCase();
  if (fileType == 'image' || fileType == 'video') return fileType;
  final mediaType = (data['mediaType'] ?? '').toString().toLowerCase();
  if (mediaType == 'image' || mediaType == 'video') return mediaType;
  return '';
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

class TaskAlertMedia {
  final List<Map<String, dynamic>> images;
  final List<Map<String, dynamic>> videos;

  const TaskAlertMedia({
    required this.images,
    required this.videos,
  });

  bool get hasMedia => images.isNotEmpty || videos.isNotEmpty;
}

class TaskAlertMediaSummary {
  final int imageCount;
  final int videoCount;

  const TaskAlertMediaSummary({
    required this.imageCount,
    required this.videoCount,
  });
}

class TaskAlertFileMedia {
  static Future<TaskAlertMedia> load({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required DocumentReference<Map<String, dynamic>> alertRef,
  }) async {
    try {
      // Admin uses top-level Firestore collections, not subcollections under
      // a company doc. The `companyRef` param is preserved for API parity
      // with kleenops call sites but is unused here.
      final snap = await FirebaseFirestore.instance
          .collection('file')
          .where('taskAlertId', isEqualTo: alertRef)
          .get();
      if (snap.docs.isEmpty) {
        return const TaskAlertMedia(images: [], videos: []);
      }

      final images = <Map<String, dynamic>>[];
      final videos = <Map<String, dynamic>>[];
      var fallbackOrder = 0;

      for (final doc in snap.docs) {
        final data = doc.data();
        final url = _stringFromData(data, const [
          'downloadUrl',
          'url',
          'fileUrl',
          'videoUrl',
          'imageUrl',
        ]);
        if (url == null || url.isEmpty) continue;
        final fileType = _resolveFileType(data);
        final order = _intFromData(data, const ['order'], fallbackOrder);
        final isMaster = data['isMaster'] == true;
        if (fileType == 'video') {
          final thumb = _stringFromData(data, const [
            'videoThumbnail',
            'thumbnailUrl',
            'thumbnail',
            'thumbUrl',
            'imageUrl',
          ]);
          videos.add({
            'videoUrl': url,
            if (thumb != null) 'videoThumbnail': thumb,
            'order': order,
            'isMaster': isMaster,
          });
        } else if (fileType == 'image') {
          images.add({
            'url': url,
            'order': order,
            'isMaster': isMaster,
          });
        }
        fallbackOrder += 1;
      }

      int orderFor(Map<String, dynamic> entry) =>
          (entry['order'] is int) ? entry['order'] as int : 0;

      images.sort((a, b) => orderFor(a).compareTo(orderFor(b)));
      videos.sort((a, b) => orderFor(a).compareTo(orderFor(b)));

      return TaskAlertMedia(images: images, videos: videos);
    } catch (_) {
      return const TaskAlertMedia(images: [], videos: []);
    }
  }

  static Future<TaskAlertMediaSummary> loadSummary({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required DocumentReference<Map<String, dynamic>> alertRef,
    Map<String, dynamic>? alertData,
  }) async {
    // Fast path: if the caller hands us the alert doc data and it carries
    // the denormalized counts written by `sync()`, return immediately
    // without a Firestore query.
    if (alertData != null &&
        (alertData.containsKey('imageCount') ||
            alertData.containsKey('videoCount'))) {
      return TaskAlertMediaSummary(
        imageCount: (alertData['imageCount'] as num?)?.toInt() ?? 0,
        videoCount: (alertData['videoCount'] as num?)?.toInt() ?? 0,
      );
    }
    // Legacy fallback: alert doc predates denormalization — query the
    // `file` collection directly. The next `sync()` will populate the
    // counts and subsequent reads will hit the fast path.
    final media = await load(companyRef: companyRef, alertRef: alertRef);
    return TaskAlertMediaSummary(
      imageCount: media.images.length,
      videoCount: media.videos.length,
    );
  }

  static Future<void> sync({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required DocumentReference<Map<String, dynamic>> alertRef,
    required List<Map<String, dynamic>> images,
    required List<Map<String, dynamic>> videos,
    DocumentReference<Map<String, dynamic>>? taskRef,
    Timestamp? alertDate,
  }) async {
    final normalizedImages = <Map<String, dynamic>>[];
    for (final entry in images) {
      final url = _stringFromData(entry, const ['url', 'imageUrl', 'image']);
      if (url == null || url.isEmpty) continue;
      normalizedImages.add({
        'url': url,
        if (entry['order'] != null) 'order': entry['order'],
        if (entry['isMaster'] != null) 'isMaster': entry['isMaster'],
      });
    }
    final normalizedVideos = <Map<String, dynamic>>[];
    for (final entry in videos) {
      final url = _stringFromData(entry, const ['videoUrl', 'url', 'video']);
      if (url == null || url.isEmpty) continue;
      final thumb = _stringFromData(entry, const [
        'videoThumbnail',
        'thumbnailUrl',
        'thumbnail',
        'thumbUrl',
        'imageUrl',
      ]);
      normalizedVideos.add({
        'url': url,
        if (thumb != null) 'thumbnailUrl': thumb,
        if (entry['order'] != null) 'order': entry['order'],
        if (entry['isMaster'] != null) 'isMaster': entry['isMaster'],
      });
    }

    if (normalizedImages.isEmpty && normalizedVideos.isEmpty) {
      return;
    }

    // Admin uses top-level collections — `companyRef` param kept for API
    // parity but unused here.
    final fileCollection = FirebaseFirestore.instance.collection('file');
    final existingSnap = await fileCollection
        .where('taskAlertId', isEqualTo: alertRef)
        .get();

    final existingByKey =
        <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final doc in existingSnap.docs) {
      final data = doc.data();
      final url = _stringFromData(data, const [
        'downloadUrl',
        'url',
        'fileUrl',
        'videoUrl',
        'imageUrl',
      ]);
      if (url == null || url.isEmpty) continue;
      final storagePath =
          (data['storagePath'] as String?)?.trim() ?? _storagePathFromUrl(url);
      final key = _fileKeyFromUrl(url, storagePath);
      if (key.isNotEmpty) existingByKey[key] = doc;
    }

    final batch = FirebaseFirestore.instance.batch();
    final usedKeys = <String>{};
    // Count what we end up persisting so we can denormalize counts onto
    // the parent alert doc (lets the alerts list show counts without a
    // per-row file query — see TaskAlertFileMedia.loadSummary fast path).
    int finalImageCount = 0;
    int finalVideoCount = 0;

    Future<void> upsertEntry({
      required String url,
      required String mediaType,
      required String fileType,
      String? thumbUrl,
      int? order,
      bool isMaster = false,
      int index = 0,
    }) async {
      final storagePath = _storagePathFromUrl(url);
      final key = _fileKeyFromUrl(url, storagePath);
      if (key.isEmpty || usedKeys.contains(key)) return;
      usedKeys.add(key);
      if (mediaType == 'Image') {
        finalImageCount += 1;
      } else if (mediaType == 'Video') {
        finalVideoCount += 1;
      }

      final existing = existingByKey[key];
      final docRef = existing?.reference ?? fileCollection.doc();

      final payload = <String, dynamic>{
        'firestorePath': docRef.path,
        'downloadUrl': url,
        'fileUrl': url,
        'name': 'Task Alert ${mediaType} ${index + 1}',
        'mediaType': mediaType,
        'fileType': fileType,
        'taskAlertId': alertRef,
        'order': order ?? index,
        'isMaster': isMaster,
        'updatedAt': FieldValue.serverTimestamp(),
        if (existing == null) 'createdAt': FieldValue.serverTimestamp(),
        if (storagePath != null && storagePath.isNotEmpty)
          'storagePath': storagePath,
        if (thumbUrl != null && thumbUrl.trim().isNotEmpty)
          'thumbnailUrl': thumbUrl.trim(),
      };
      if (thumbUrl != null &&
          thumbUrl.trim().isNotEmpty &&
          mediaType == 'Video') {
        payload['videoThumbnail'] = thumbUrl.trim();
      }
      if (taskRef != null) payload['taskId'] = taskRef;
      if (alertDate != null) payload['alertDate'] = alertDate;

      batch.set(docRef, payload, SetOptions(merge: true));
    }

    for (var i = 0; i < normalizedImages.length; i += 1) {
      final entry = normalizedImages[i];
      final url = entry['url'] as String? ?? '';
      if (url.trim().isEmpty) continue;
      await upsertEntry(
        url: url.trim(),
        mediaType: 'Image',
        fileType: 'image',
        order: entry['order'] as int?,
        isMaster: entry['isMaster'] == true || i == 0,
        index: i,
      );
    }

    for (var i = 0; i < normalizedVideos.length; i += 1) {
      final entry = normalizedVideos[i];
      final url = entry['url'] as String? ?? '';
      if (url.trim().isEmpty) continue;
      await upsertEntry(
        url: url.trim(),
        mediaType: 'Video',
        fileType: 'video',
        thumbUrl: entry['thumbnailUrl'] as String?,
        order: entry['order'] as int?,
        isMaster: entry['isMaster'] == true || i == 0,
        index: i,
      );
    }

    for (final entry in existingByKey.entries) {
      if (!usedKeys.contains(entry.key)) {
        batch.delete(entry.value.reference);
      }
    }

    // Denormalize the resulting counts onto the alert doc itself in the same
    // batch — the alerts list reads these directly to avoid a per-row query.
    batch.set(
      alertRef,
      {
        'imageCount': finalImageCount,
        'videoCount': finalVideoCount,
        'mediaUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }
}
