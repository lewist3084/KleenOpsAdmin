// catalog_object_file_images.dart — simplified for admin app.
// TODO: Migrate full image management from kleenops app.

import 'package:kleenops_admin/services/catalog_firebase_service.dart';

class CatalogObjectFileImages {
  final String objectDocId;

  CatalogObjectFileImages({required this.objectDocId});

  Future<List<String>> headerImageUrls() async {
    final db = CatalogFirebaseService.instance.firestore;
    final snap = await db
        .collection('object')
        .doc(objectDocId)
        .collection('file')
        .where('fileType', isEqualTo: 'headerImage')
        .orderBy('order')
        .get();

    return snap.docs
        .map((d) {
          final data = d.data();
          return (data['downloadUrl'] ?? data['url'] ?? '').toString();
        })
        .where((url) => url.isNotEmpty)
        .toList();
  }

  Future<String?> primaryHeaderImageUrl() async {
    final urls = await headerImageUrls();
    return urls.isNotEmpty ? urls.first : null;
  }
}
