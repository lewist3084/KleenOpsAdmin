import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_widgets/viewers/file_carousel_viewer.dart';

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
  if (normalized == 'pdf') return 'pdf';
  if (normalized == 'document' || normalized == 'doc') return 'document';
  return normalized;
}

class RequestFileMedia {
  final List<Map<String, dynamic>> fileEntries;
  final String? shareImageUrl;

  const RequestFileMedia({
    required this.fileEntries,
    required this.shareImageUrl,
  });

  bool get hasEntries => fileEntries.isNotEmpty;

  List<Map<String, dynamic>> get imageEntries =>
      _filterEntriesByType(const ['image', 'pdf']);

  List<Map<String, dynamic>> get videoEntries =>
      _filterEntriesByType(const ['video']);

  List<Map<String, dynamic>> get otherEntries => fileEntries
      .where((entry) {
        final type = _normalizeType(entry);
        return type.isNotEmpty &&
            type != 'image' &&
            type != 'pdf' &&
            type != 'video';
      })
      .map((entry) => Map<String, dynamic>.from(entry))
      .toList(growable: false);

  String? get primaryImageUrl =>
      _primaryUrlFrom(imageEntries, const ['url', 'imageUrl', 'fileUrl']);

  String? get primaryVideoUrl =>
      _primaryUrlFrom(videoEntries, const ['videoUrl', 'url', 'fileUrl']);

  String? get primaryVideoThumbnail => _primaryUrlFrom(
        videoEntries,
        const ['videoThumbnail', 'thumbnailUrl', 'imageUrl'],
      );

  List<FileCarouselItem> get mediaItems {
    final items = <FileCarouselItem>[];
    final ordered = List<Map<String, dynamic>>.from(fileEntries)
      ..sort((a, b) => (_entryOrder(a) ?? 0).compareTo(_entryOrder(b) ?? 0));
    for (final entry in ordered) {
      final type = _normalizeType(entry);
      if (type == 'video') {
        final url = _stringFromData(entry, const [
          'videoUrl',
          'url',
          'fileUrl',
        ]);
        if (url == null || url.isEmpty) continue;
        final thumb = _stringFromData(
          entry,
          const ['videoThumbnail', 'thumbnailUrl', 'imageUrl'],
        );
        items.add(FileCarouselItem.video(
          videoUrl: url,
          thumbnailUrl: thumb,
        ));
        continue;
      }
      if (type == 'pdf' || type == 'document') {
        final url = _stringFromData(entry, const ['fileUrl', 'url']);
        if (url == null || url.isEmpty) continue;
        final title = _stringFromData(entry, const ['fileName', 'name']);
        items.add(FileCarouselItem.document(
          fileUrl: url,
          title: title,
        ));
        continue;
      }
      final url = _stringFromData(entry, const [
        'url',
        'imageUrl',
        'fileUrl',
        'thumbnailUrl',
      ]);
      if (url == null || url.isEmpty) continue;
      items.add(FileCarouselItem.image(imageUrl: url));
    }
    return items;
  }

  static Future<RequestFileMedia> load({
    required DocumentReference<Map<String, dynamic>> userRef,
    required DocumentReference<Map<String, dynamic>> requestRef,
  }) async {
    try {
      // Admin uses top-level `file` collection (not nested under user).
      final snap = await FirebaseFirestore.instance
          .collection('file')
          .where('requestRef', isEqualTo: requestRef)
          .get();
      if (snap.docs.isEmpty) {
        return const RequestFileMedia(
          fileEntries: <Map<String, dynamic>>[],
          shareImageUrl: null,
        );
      }

      final entries = <Map<String, dynamic>>[];
      String? shareUrl;
      var fallbackOrder = 0;
      for (final doc in snap.docs) {
        final data = doc.data();
        final role = _stringFromData(
          data,
          const ['requestMediaRole', 'mediaRole'],
        );
        final url = _stringFromData(data, const [
          'downloadUrl',
          'url',
          'fileUrl',
          'imageUrl',
          'videoUrl',
        ]);
        if (url == null || url.isEmpty) continue;

        if (role == 'share') {
          shareUrl ??= url;
          continue;
        }

        final mapped = <String, dynamic>{
          'url': url,
          'fileUrl': url,
          'imageUrl': url,
          'videoUrl': url,
          'videoThumbnail': _stringFromData(
            data,
            const ['videoThumbnail', 'thumbnailUrl', 'imageUrl'],
          ),
          'videoDuration': _intFromData(
            data,
            const ['videoDuration', 'duration'],
            0,
          ),
          'fileType': data['fileType'] ?? data['mediaType'] ?? data['type'],
          'mediaType': data['mediaType'] ?? data['fileType'] ?? data['type'],
          'fileName': _stringFromData(
            data,
            const ['sourceFileName', 'fileName', 'name'],
          ),
          'order': _intFromData(data, const ['order'], fallbackOrder),
          'isMaster': data['isMaster'] == true,
        };
        entries.add(mapped);
        fallbackOrder += 1;
      }

      return RequestFileMedia(
        fileEntries: entries,
        shareImageUrl: shareUrl,
      );
    } catch (_) {
      return const RequestFileMedia(
        fileEntries: <Map<String, dynamic>>[],
        shareImageUrl: null,
      );
    }
  }

  static Future<void> syncRequestMedia({
    required DocumentReference<Map<String, dynamic>> userRef,
    required DocumentReference<Map<String, dynamic>> requestRef,
    required List<Map<String, dynamic>> files,
    required String requestName,
    String? shareImageUrl,
  }) async {
    final fileCollection = FirebaseFirestore.instance.collection('file');
    final existingSnap = await fileCollection
        .where('requestRef', isEqualTo: requestRef)
        .get();

    final existingByKey =
        <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final doc in existingSnap.docs) {
      final data = doc.data();
      final role = _stringFromData(
        data,
        const ['requestMediaRole', 'mediaRole'],
      );
      final url = _stringFromData(data, const [
        'downloadUrl',
        'url',
        'fileUrl',
        'imageUrl',
        'videoUrl',
      ]);
      if (url == null || url.isEmpty) continue;
      final key = '${role ?? 'attachment'}::$url';
      existingByKey[key] = doc;
    }

    final batch = FirebaseFirestore.instance.batch();
    final usedKeys = <String>{};

    for (var i = 0; i < files.length; i += 1) {
      final entry = files[i];
      final url = _stringFromData(entry, const [
        'fileUrl',
        'url',
        'imageUrl',
        'videoUrl',
        'downloadUrl',
      ]);
      if (url == null || url.isEmpty) continue;
      final key = 'attachment::$url';
      if (usedKeys.contains(key)) continue;
      usedKeys.add(key);

      final existing = existingByKey[key];
      final docRef = existing?.reference ?? fileCollection.doc();
      final type = _normalizeType(entry);
      final mediaType = type.isNotEmpty ? type : 'document';
      final payload = <String, dynamic>{
        'firestorePath': docRef.path,
        'downloadUrl': url,
        'fileUrl': url,
        'name': '$requestName ${mediaType.toUpperCase()}',
        'mediaType': mediaType,
        'fileType': mediaType,
        'requestRef': requestRef,
        'requestMediaRole': 'attachment',
        'order': _entryOrder(entry) ?? i,
        'isMaster': entry['isMaster'] == true || i == 0,
        'updatedAt': FieldValue.serverTimestamp(),
        if (existing == null) 'createdAt': FieldValue.serverTimestamp(),
      };
      final thumb = _stringFromData(
        entry,
        const ['videoThumbnail', 'thumbnailUrl', 'thumbnail', 'imageUrl'],
      );
      if (thumb != null && thumb.isNotEmpty) {
        payload['thumbnailUrl'] = thumb;
        payload['videoThumbnail'] = thumb;
      }
      final duration =
          _intFromData(entry, const ['videoDuration', 'duration'], 0);
      if (duration > 0) {
        payload['duration'] = duration;
        payload['videoDuration'] = duration;
      }
      final fileName = _stringFromData(entry, const ['fileName', 'name']);
      if (fileName != null && fileName.isNotEmpty) {
        payload['sourceFileName'] = fileName;
      }

      batch.set(docRef, payload, SetOptions(merge: true));
    }

    final trimmedShare = (shareImageUrl ?? '').trim();
    if (trimmedShare.isNotEmpty) {
      final key = 'share::$trimmedShare';
      if (!usedKeys.contains(key)) {
        usedKeys.add(key);
        final existing = existingByKey[key];
        final docRef = existing?.reference ?? fileCollection.doc();
        final payload = <String, dynamic>{
          'firestorePath': docRef.path,
          'downloadUrl': trimmedShare,
          'fileUrl': trimmedShare,
          'name': '$requestName Share Image',
          'mediaType': 'image',
          'fileType': 'image',
          'requestRef': requestRef,
          'requestMediaRole': 'share',
          'order': 0,
          'isMaster': true,
          'updatedAt': FieldValue.serverTimestamp(),
          if (existing == null) 'createdAt': FieldValue.serverTimestamp(),
        };
        batch.set(docRef, payload, SetOptions(merge: true));
      }
    }

    for (final entry in existingByKey.entries) {
      if (!usedKeys.contains(entry.key)) {
        batch.delete(entry.value.reference);
      }
    }

    await batch.commit();
  }

  List<Map<String, dynamic>> _filterEntriesByType(List<String> types) {
    final filtered = <Map<String, dynamic>>[];
    for (final entry in fileEntries) {
      final type = _normalizeType(entry);
      if (type.isEmpty || !types.contains(type)) continue;
      filtered.add(Map<String, dynamic>.from(entry));
    }
    filtered.sort((a, b) => (_entryOrder(a) ?? 0).compareTo(_entryOrder(b) ?? 0));
    return filtered;
  }

  String? _primaryUrlFrom(
    List<Map<String, dynamic>> entries,
    List<String> keys,
  ) {
    if (entries.isEmpty) return null;
    final sorted = List<Map<String, dynamic>>.from(entries)
      ..sort((a, b) => (_entryOrder(a) ?? 0).compareTo(_entryOrder(b) ?? 0));
    final masterIndex = sorted.indexWhere((entry) => entry['isMaster'] == true);
    final selected = masterIndex >= 0 ? sorted[masterIndex] : sorted.first;
    return _stringFromData(selected, keys);
  }
}

int? _entryOrder(Map<String, dynamic> entry) {
  final raw = entry['order'];
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return null;
}
