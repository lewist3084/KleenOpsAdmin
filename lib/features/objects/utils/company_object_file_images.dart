import 'package:cloud_firestore/cloud_firestore.dart';
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

class CompanyObjectFileImages {
  static Future<String> primaryHeaderImageUrl({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required String objectId,
  }) async {
    try {
      final snap = await companyRef
          .collection('file')
          .where('objectId', isEqualTo: objectId)
          .where('objectMediaRole', isEqualTo: 'header')
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
        final order = _intFromData(data, const ['order'], fallbackOrder);
        final isMaster = data['isMaster'] == true;
        final isImage = _isImageFile(data, url);
        ordered.add(
          _FileCandidate(
            url: url,
            order: order,
            isMaster: isMaster,
            isImage: isImage,
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
        if (a.isImage != b.isImage) {
          return a.isImage ? -1 : 1;
        }
        return 0;
      });
      return ordered.first.url;
    } catch (_) {
      return '';
    }
  }

  static Future<String> primaryHeaderImageUrlForRef({
    required DocumentReference objectRef,
  }) async {
    final companyRef = objectRef.parent.parent;
    if (companyRef == null) return '';
    final typedCompanyRef = companyRef.withConverter<Map<String, dynamic>>(
      fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
      toFirestore: (data, _) => data,
    );
    return primaryHeaderImageUrl(
      companyRef: typedCompanyRef,
      objectId: objectRef.id,
    );
  }

  static Future<List<CompanyObjectFileImageData>> headerImageGallery({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required String objectId,
  }) async {
    try {
      final snap = await companyRef
          .collection('file')
          .where('objectId', isEqualTo: objectId)
          .where('objectMediaRole', isEqualTo: 'header')
          .get();
      if (snap.docs.isEmpty) return const <CompanyObjectFileImageData>[];

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
            isImage: true,
            caption: _stringFromData(data, const ['caption']),
            altText: _stringFromData(data, const ['altText']),
          ),
        );
        fallbackOrder += 1;
      }

      if (ordered.isEmpty) return const <CompanyObjectFileImageData>[];
      ordered.sort((a, b) {
        if (a.isMaster != b.isMaster) {
          return a.isMaster ? -1 : 1;
        }
        if (a.order != b.order) {
          return a.order.compareTo(b.order);
        }
        return 0;
      });

      return [
        for (final item in ordered)
          CompanyObjectFileImageData(
            url: item.url,
            order: item.order,
            isMaster: item.isMaster,
            caption: item.caption,
            altText: item.altText,
          ),
      ];
    } catch (_) {
      return const <CompanyObjectFileImageData>[];
    }
  }

  static Future<List<CompanyObjectFileImageData>> headerImageGalleryForRef({
    required DocumentReference objectRef,
  }) async {
    final companyRef = objectRef.parent.parent;
    if (companyRef == null) return const <CompanyObjectFileImageData>[];
    final typedCompanyRef = companyRef.withConverter<Map<String, dynamic>>(
      fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
      toFirestore: (data, _) => data,
    );
    return headerImageGallery(
      companyRef: typedCompanyRef,
      objectId: objectRef.id,
    );
  }

  static Future<List<String>> headerImageUrls({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required String objectId,
  }) async {
    final images = await headerImageGallery(
      companyRef: companyRef,
      objectId: objectId,
    );
    return images.map((img) => img.url).toList();
  }
}

class CompanyObjectFileImageData {
  final String url;
  final int order;
  final bool isMaster;
  final String? caption;
  final String? altText;

  const CompanyObjectFileImageData({
    required this.url,
    required this.order,
    required this.isMaster,
    this.caption,
    this.altText,
  });
}

class _FileCandidate {
  final String url;
  final int order;
  final bool isMaster;
  final bool isImage;
  final String? caption;
  final String? altText;

  const _FileCandidate({
    required this.url,
    required this.order,
    required this.isMaster,
    required this.isImage,
    this.caption,
    this.altText,
  });
}
