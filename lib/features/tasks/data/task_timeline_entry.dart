import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meta/meta.dart';

/// Typed view of a task timeline document.
@immutable
class TaskTimelineEntry {
  const TaskTimelineEntry({
    required this.id,
    required this.ref,
    required this.data,
    required this.startTime,
    this.endTimeExtended,
    this.timelineCategory,
    this.teamRef,
  });

  final String id;
  final DocumentReference<Map<String, dynamic>> ref;
  final Map<String, dynamic> data;
  final DateTime startTime;
  final DateTime? endTimeExtended;
  final String? timelineCategory;
  final DocumentReference<Map<String, dynamic>>? teamRef;

  factory TaskTimelineEntry.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return TaskTimelineEntry(
      id: doc.id,
      ref: doc.reference,
      data: data,
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTimeExtended:
          (data['endTimeExtended'] as Timestamp?)?.toDate(),
      timelineCategory: data['timelineCategory'] as String?,
      teamRef: data['teamId'] is DocumentReference
          ? (data['teamId'] as DocumentReference).withConverter<
              Map<String, dynamic>>(
              fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
              toFirestore: (value, _) => value,
            )
          : null,
    );
  }

  bool get isComplete => data['completeTimestamp'] != null;
}
