// Admin port: top-level `file` collection, no per-company scoping. The
// kleenops original takes a `companyRef` and writes under it; admin uses
// `FirebaseFirestore.instance.collection('file')` directly.

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

String _extensionFromUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return '';
  final path = Uri.tryParse(trimmed)?.path ?? trimmed;
  final lastSlash = path.lastIndexOf('/');
  final basename = lastSlash >= 0 ? path.substring(lastSlash + 1) : path;
  final lastDot = basename.lastIndexOf('.');
  if (lastDot <= 0) return '';
  return basename.substring(lastDot + 1).toLowerCase();
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

bool _isImageFile(Map<String, dynamic> data, String url) {
  final fileType = (data['fileType'] ?? '').toString().toLowerCase();
  if (fileType == 'image') return true;
  final mediaType = (data['mediaType'] ?? '').toString().toLowerCase();
  if (mediaType == 'image') return true;
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

class FacilityFileImages {
  static CollectionReference<Map<String, dynamic>> get _fileCollection =>
      FirebaseFirestore.instance.collection('file');

  static Future<List<Map<String, dynamic>>> headerImageEntries({
    required DocumentReference facilityRef,
  }) async {
    try {
      final snap = await _fileCollection
          .where('facilityRef', isEqualTo: facilityRef)
          .where('facilityMediaRole', isEqualTo: 'header')
          .get();
      if (snap.docs.isEmpty) return const <Map<String, dynamic>>[];

      final entries = <Map<String, dynamic>>[];
      var fallbackOrder = 0;
      for (final doc in snap.docs) {
        final data = doc.data();
        final url = _stringFromData(data, const [
          'downloadUrl',
          'url',
          'fileUrl',
          'imageUrl',
        ]);
        if (url == null || url.isEmpty) continue;
        if (!_isImageFile(data, url)) continue;
        final order = _intFromData(data, const ['order'], fallbackOrder);
        final isMaster = data['isMaster'] == true;
        final entry = <String, dynamic>{
          'url': url,
          'order': order,
          'isMaster': isMaster,
        };
        if (data['caption'] is String) {
          entry['caption'] = (data['caption'] as String).trim();
        }
        if (data['altText'] is String) {
          entry['altText'] = (data['altText'] as String).trim();
        }
        entries.add(entry);
        fallbackOrder += 1;
      }

      if (entries.isEmpty) return const <Map<String, dynamic>>[];
      entries.sort((a, b) {
        final aMaster = a['isMaster'] == true;
        final bMaster = b['isMaster'] == true;
        if (aMaster != bMaster) return aMaster ? -1 : 1;
        final aOrder = a['order'] is int ? a['order'] as int : 0;
        final bOrder = b['order'] is int ? b['order'] as int : 0;
        return aOrder.compareTo(bOrder);
      });
      return entries;
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  static Future<({String url, double width, double height})> floorPinPayload({
    required DocumentReference floorRef,
  }) async {
    const fallbackUrl = 'https://via.placeholder.com/600x800';
    var url = fallbackUrl;
    var width = 600.0;
    var height = 800.0;

    final snap = await floorRef.get();
    if (!snap.exists) return (url: url, width: width, height: height);
    final data = (snap.data() as Map<String, dynamic>?) ?? const {};

    final entries = await headerImageEntries(facilityRef: floorRef);
    final headerUrl = entries.isNotEmpty
        ? (entries.first['url'] as String?)?.trim()
        : null;
    if (headerUrl != null && headerUrl.isNotEmpty) url = headerUrl;

    width = (data['imageWidth'] as num?)?.toDouble() ?? width;
    height = (data['imageHeight'] as num?)?.toDouble() ?? height;

    return (url: url, width: width, height: height);
  }

  static Future<void> syncHeaderImages({
    required DocumentReference facilityRef,
    required String facilityType,
    required List<Map<String, dynamic>> images,
    String? fallbackUrl,
    String? name,
  }) async {
    final normalized = <Map<String, dynamic>>[];
    for (final entry in images) {
      final url = entry['url'];
      if (url is! String) continue;
      final trimmed = url.trim();
      if (trimmed.isEmpty) continue;
      normalized.add(Map<String, dynamic>.from(entry)..['url'] = trimmed);
    }
    if (normalized.isEmpty &&
        fallbackUrl != null &&
        fallbackUrl.trim().isNotEmpty) {
      normalized.add({
        'url': fallbackUrl.trim(),
        'order': 0,
        'isMaster': true,
      });
    }

    final fileCollection = _fileCollection;
    final existingSnap = await fileCollection
        .where('facilityRef', isEqualTo: facilityRef)
        .where('facilityMediaRole', isEqualTo: 'header')
        .get();

    if (normalized.isEmpty) {
      if (existingSnap.docs.isEmpty) return;
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in existingSnap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      return;
    }

    final existingByKey = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final doc in existingSnap.docs) {
      final data = doc.data();
      final url = _stringFromData(data, const [
        'downloadUrl',
        'url',
        'fileUrl',
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
    for (var i = 0; i < normalized.length; i += 1) {
      final entry = normalized[i];
      final url = (entry['url'] as String).trim();
      if (url.isEmpty) continue;
      final storagePath = _storagePathFromUrl(url);
      final key = _fileKeyFromUrl(url, storagePath);
      if (key.isEmpty || usedKeys.contains(key)) continue;
      usedKeys.add(key);

      final existing = existingByKey[key];
      final docRef = existing?.reference ?? fileCollection.doc();
      final extension = _extensionFromUrl(url);
      final imageName = name != null && name.trim().isNotEmpty
          ? name.trim()
          : 'Facility';
      final order = entry['order'] is int ? entry['order'] as int : i;
      final isMaster = entry['isMaster'] == true || i == 0;

      final payload = <String, dynamic>{
        'firestorePath': docRef.path,
        'downloadUrl': url,
        'fileUrl': url,
        'name': '$imageName Image ${i + 1}',
        'mediaType': 'Image',
        'fileType': 'image',
        'facilityRef': facilityRef,
        'facilityType': facilityType,
        'facilityMediaRole': 'header',
        'order': order,
        'isMaster': isMaster,
        'updatedAt': FieldValue.serverTimestamp(),
        if (existing == null) 'createdAt': FieldValue.serverTimestamp(),
      };
      if (storagePath != null && storagePath.isNotEmpty) {
        payload['storagePath'] = storagePath;
      }
      if (extension.isNotEmpty) {
        payload['fileExtension'] = extension;
      }
      if (entry['caption'] is String) {
        payload['caption'] = (entry['caption'] as String).trim();
      }
      if (entry['altText'] is String) {
        payload['altText'] = (entry['altText'] as String).trim();
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

  static Future<String> primaryHeaderImageUrl({
    required DocumentReference facilityRef,
  }) async {
    try {
      final snap = await _fileCollection
          .where('facilityRef', isEqualTo: facilityRef)
          .where('facilityMediaRole', isEqualTo: 'header')
          .get();
      if (snap.docs.isEmpty) return '';

      final ordered = <_FileCandidate>[];
      var fallbackOrder = 0;
      for (final doc in snap.docs) {
        final data = doc.data();
        final url = _stringFromData(data, const [
          'downloadUrl',
          'url',
          'fileUrl',
          'imageUrl',
        ]);
        if (url == null || url.isEmpty) continue;
        if (!_isImageFile(data, url)) continue;
        final order = _intFromData(data, const ['order'], fallbackOrder);
        final isMaster = data['isMaster'] == true;
        ordered.add(
          _FileCandidate(
            url: url,
            order: order,
            isMaster: isMaster,
          ),
        );
        fallbackOrder += 1;
      }

      if (ordered.isEmpty) return '';
      ordered.sort((a, b) {
        if (a.isMaster != b.isMaster) {
          return a.isMaster ? -1 : 1;
        }
        if (a.order != b.order) {
          return a.order.compareTo(b.order);
        }
        return 0;
      });
      return ordered.first.url;
    } catch (_) {
      return '';
    }
  }
}

class _FileCandidate {
  final String url;
  final int order;
  final bool isMaster;

  const _FileCandidate({
    required this.url,
    required this.order,
    required this.isMaster,
  });
}
