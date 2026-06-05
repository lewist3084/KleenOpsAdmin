import 'package:cloud_firestore/cloud_firestore.dart';

class ContentModel {
  final String id;
  final DocumentReference<Map<String, dynamic>> ref;
  final DocumentReference<Map<String, dynamic>> folderRef;
  final String text;
  final int position;
  final String source; // 'manual', 'phone_transcription', 'intercom_transcription', 'video_transcription'
  final DocumentReference<Map<String, dynamic>>? timelineRef;
  final Map<String, dynamic>? callMeta;
  final DocumentReference<Map<String, dynamic>>? memberRef;
  final DateTime? createdAt;

  ContentModel({
    required this.id,
    required this.ref,
    required this.folderRef,
    required this.text,
    this.position = 0,
    this.source = 'manual',
    this.timelineRef,
    this.callMeta,
    this.memberRef,
    this.createdAt,
  });

  factory ContentModel.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final d = snap.data() ?? {};
    return ContentModel(
      id: snap.id,
      ref: snap.reference,
      folderRef: d['folderRef'] as DocumentReference<Map<String, dynamic>>,
      text: (d['text'] as String?) ?? '',
      position: (d['position'] as num?)?.toInt() ?? 0,
      source: (d['source'] as String?) ?? 'manual',
      timelineRef:
          d['timelineRef'] as DocumentReference<Map<String, dynamic>>?,
      callMeta: d['callMeta'] as Map<String, dynamic>?,
      memberRef:
          d['memberRef'] as DocumentReference<Map<String, dynamic>>?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'folderRef': folderRef,
        'text': text,
        'position': position,
        'source': source,
        'timelineRef': timelineRef,
        'callMeta': callMeta,
        'memberRef': memberRef,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
      };

  /// Human-readable badge for the content source.
  String get sourceBadge {
    switch (source) {
      case 'phone_transcription':
        return 'Phone';
      case 'intercom_transcription':
        return 'Intercom';
      case 'video_transcription':
        return 'Video';
      default:
        return 'Manual';
    }
  }
}
