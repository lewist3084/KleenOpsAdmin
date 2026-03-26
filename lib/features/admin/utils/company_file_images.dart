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

class CompanyFileImages {
  static Future<List<Map<String, dynamic>>> headerImageEntries({
    required DocumentReference<Map<String, dynamic>> companyRef,
  }) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('file')
          .where('companyRef', isEqualTo: companyRef)
          .where('companyMediaRole', isEqualTo: 'header')
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
        entries.add({
          'url': url,
          'order': order,
          'isMaster': isMaster,
        });
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

  static Future<void> syncHeaderImages({
    required DocumentReference<Map<String, dynamic>> companyRef,
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

    final fileCollection = FirebaseFirestore.instance.collection('file');
    final existingSnap = await fileCollection
        .where('companyRef', isEqualTo: companyRef)
        .where('companyMediaRole', isEqualTo: 'header')
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

    final existingByKey =
        <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
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
      final companyName = name != null && name.trim().isNotEmpty
          ? name.trim()
          : 'Company';
      final order = entry['order'] is int ? entry['order'] as int : i;
      final isMaster = entry['isMaster'] == true || i == 0;

      final payload = <String, dynamic>{
        'firestorePath': docRef.path,
        'downloadUrl': url,
        'fileUrl': url,
        'name': '$companyName Image ${i + 1}',
        'mediaType': 'Image',
        'fileType': 'image',
        'companyRef': companyRef,
        'companyMediaRole': 'header',
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
