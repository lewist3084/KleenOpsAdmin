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

class CatalogObjectFileImages {
  static Future<List<Map<String, dynamic>>> headerImageEntries({
    required FirebaseFirestore firestore,
    required String objectId,
  }) async {
    try {
      final snap = await firestore
          .collection('file')
          .where('objectId', isEqualTo: objectId)
          .where('objectMediaRole', isEqualTo: 'header')
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

  static Future<List<String>> headerImageUrls({
    required FirebaseFirestore firestore,
    required String objectId,
  }) async {
    final entries = await headerImageEntries(
      firestore: firestore,
      objectId: objectId,
    );
    return entries
        .map((entry) => entry['url'])
        .whereType<String>()
        .toList();
  }

  static Future<String> primaryHeaderImageUrl({
    required FirebaseFirestore firestore,
    required String objectId,
  }) async {
    try {
      final entries = await headerImageEntries(
        firestore: firestore,
        objectId: objectId,
      );
      if (entries.isEmpty) return '';
      final url = entries.first['url'];
      return url is String ? url : '';
    } catch (_) {
      return '';
    }
  }

  static Future<void> syncPrimaryHeaderImage({
    required FirebaseFirestore firestore,
    required String objectId,
    required String? imageUrl,
    String? objectName,
  }) async {
    final trimmed = (imageUrl ?? '').trim();
    final fileCollection = firestore.collection('file');
    final existingSnap = await fileCollection
        .where('objectId', isEqualTo: objectId)
        .where('objectMediaRole', isEqualTo: 'header')
        .get();

    if (trimmed.isEmpty) {
      if (existingSnap.docs.isEmpty) return;
      final batch = firestore.batch();
      for (final doc in existingSnap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      return;
    }

    final storagePath = _storagePathFromUrl(trimmed);
    final key = _fileKeyFromUrl(trimmed, storagePath);
    QueryDocumentSnapshot<Map<String, dynamic>>? matching;
    for (final doc in existingSnap.docs) {
      final data = doc.data();
      final url = _stringFromData(data, const [
        'downloadUrl',
        'url',
        'fileUrl',
        'imageUrl',
      ]);
      if (url == null || url.isEmpty) continue;
      final existingPath =
          (data['storagePath'] as String?)?.trim() ?? _storagePathFromUrl(url);
      if (_fileKeyFromUrl(url, existingPath) == key) {
        matching = doc;
        break;
      }
    }

    final docRef = matching?.reference ?? fileCollection.doc();
    final baseName =
        objectName != null && objectName.trim().isNotEmpty ? objectName : 'Item';
    final payload = <String, dynamic>{
      'firestorePath': docRef.path,
      'downloadUrl': trimmed,
      'fileUrl': trimmed,
      'name': '$baseName Image 1',
      'mediaType': 'Image',
      'fileType': 'image',
      'objectId': objectId,
      'objectMediaRole': 'header',
      'order': 0,
      'isMaster': true,
      'updatedAt': FieldValue.serverTimestamp(),
      if (matching == null) 'createdAt': FieldValue.serverTimestamp(),
      if (storagePath != null && storagePath.isNotEmpty)
        'storagePath': storagePath,
      if (_extensionFromUrl(trimmed).isNotEmpty)
        'fileExtension': _extensionFromUrl(trimmed),
    };
    await docRef.set(payload, SetOptions(merge: true));

    if (existingSnap.docs.length <= 1) return;
    final batch = firestore.batch();
    for (final doc in existingSnap.docs) {
      if (doc.reference.path == docRef.path) continue;
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
