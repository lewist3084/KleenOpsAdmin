// lib/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  /// Saves or updates a Firestore document, allowing FieldValue.delete()
  Future<void> saveDocument({
    required CollectionReference<Map<String, dynamic>> collectionRef,
    required Map<String, dynamic> data,
    String? docId,
  }) async {
    final docRef = (docId != null && docId.trim().isNotEmpty)
        ? collectionRef.doc(docId)
        : collectionRef.doc();

    bool isCreate = docId == null || docId.trim().isEmpty;
    if (!isCreate) {
      try {
        final snap = await docRef.get();
        isCreate = !snap.exists;
      } catch (_) {
        isCreate = false;
      }
    }

    final payload = Map<String, dynamic>.from(data);
    if (isCreate) {
      final meta = await buildCreateMeta(collectionRef);
      meta.forEach((k, v) {
        if (!payload.containsKey(k)) payload[k] = v;
      });
    }

    await docRef.set(payload, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>> buildCreateMeta(
      CollectionReference<Map<String, dynamic>> collectionRef) async {
    final meta = <String, dynamic>{
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      final companyRef = _findCompanyAncestor(collectionRef);
      if (companyRef == null) return meta;

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || uid.isEmpty) return meta;

      final indexSnap =
          await companyRef.collection('memberByUid').doc(uid).get();
      if (indexSnap.exists) {
        final data = indexSnap.data() ?? {};
        final memberId = data['memberId'];
        if (memberId is String && memberId.isNotEmpty) {
          meta['createdBy'] = companyRef.collection('member').doc(memberId);
          return meta;
        }
      }
    } catch (_) {}
    return meta;
  }

  DocumentReference<Map<String, dynamic>>? _findCompanyAncestor(
      CollectionReference<Map<String, dynamic>> collection) {
    dynamic currentCollection = collection;
    dynamic parentDoc = currentCollection.parent;
    while (parentDoc != null) {
      final parentCollection = parentDoc.parent;
      if (parentCollection != null && parentCollection.id == 'company') {
        return parentDoc as DocumentReference<Map<String, dynamic>>;
      }
      currentCollection = parentCollection;
      parentDoc = parentCollection?.parent;
    }
    return null;
  }
}
