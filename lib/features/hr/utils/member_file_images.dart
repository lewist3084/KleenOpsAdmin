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

class MemberFileImages {
  static Future<String> primaryProfileImageUrl({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required String memberId,
  }) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('file')
          .where('memberId', isEqualTo: memberId)
          .where('memberMediaRole', isEqualTo: 'profile')
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

  static Future<void> syncProfileImage({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required String memberId,
    required String imageUrl,
    String? memberName,
  }) async {
    final trimmedUrl = imageUrl.trim();
    final fileCollection = FirebaseFirestore.instance.collection('file');
    final existingSnap = await fileCollection
        .where('memberId', isEqualTo: memberId)
        .where('memberMediaRole', isEqualTo: 'profile')
        .get();

    if (trimmedUrl.isEmpty) {
      if (existingSnap.docs.isEmpty) return;
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in existingSnap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      return;
    }

    final existingDoc =
        existingSnap.docs.isNotEmpty ? existingSnap.docs.first : null;
    final docRef = existingDoc?.reference ?? fileCollection.doc();
    final storagePath = _storagePathFromUrl(trimmedUrl);
    final extension = _extensionFromUrl(trimmedUrl);
    final displayName =
        memberName != null && memberName.trim().isNotEmpty
            ? memberName.trim()
            : 'Member';

    final payload = <String, dynamic>{
      'firestorePath': docRef.path,
      'downloadUrl': trimmedUrl,
      'name': '$displayName Profile Image',
      'mediaType': 'Image',
      'fileType': 'image',
      'memberId': memberId,
      'memberMediaRole': 'profile',
      'order': 0,
      'isMaster': true,
      'updatedAt': FieldValue.serverTimestamp(),
      if (existingDoc == null) 'createdAt': FieldValue.serverTimestamp(),
    };
    if (storagePath != null && storagePath.isNotEmpty) {
      payload['storagePath'] = storagePath;
    }
    if (extension.isNotEmpty) {
      payload['fileExtension'] = extension;
    }

    await docRef.set(payload, SetOptions(merge: true));
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
