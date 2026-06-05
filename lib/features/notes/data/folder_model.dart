import 'package:cloud_firestore/cloud_firestore.dart';

class FolderModel {
  final String id;
  final DocumentReference<Map<String, dynamic>> ref;
  final String name;
  final DocumentReference<Map<String, dynamic>>? parentFolderRef;
  final int position;
  final String memberId;
  final DocumentReference<Map<String, dynamic>>? memberRef;
  final DateTime? createdAt;

  FolderModel({
    required this.id,
    required this.ref,
    required this.name,
    this.parentFolderRef,
    this.position = 0,
    required this.memberId,
    this.memberRef,
    this.createdAt,
  });

  factory FolderModel.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final d = snap.data() ?? {};
    return FolderModel(
      id: snap.id,
      ref: snap.reference,
      name: (d['name'] as String?) ?? '',
      parentFolderRef:
          d['parentFolderRef'] as DocumentReference<Map<String, dynamic>>?,
      position: (d['position'] as num?)?.toInt() ?? 0,
      memberId: (d['memberId'] as String?) ?? '',
      memberRef:
          d['memberRef'] as DocumentReference<Map<String, dynamic>>?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'parentFolderRef': parentFolderRef,
        'position': position,
        'memberId': memberId,
        'memberRef': memberRef,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
      };
}
