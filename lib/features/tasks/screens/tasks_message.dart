import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kleenops_admin/features/tasks/details/tasks_message_details.dart';
import 'package:shared_widgets/tiles/standard_bubble_tile.dart';

class TasksMessageContent extends StatelessWidget {
  const TasksMessageContent({
    super.key,
    required this.pendingDocs,
    required this.memberRef,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> pendingDocs;
  final DocumentReference<Map<String, dynamic>> memberRef;

  @override
  Widget build(BuildContext context) {
    if (pendingDocs.isEmpty) {
      return const Center(
        child: Text('No pending messages.'),
      );
    }

    final sortedDocs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
      pendingDocs,
    )..sort((a, b) {
        final at = (a.data()['createdAt'] as Timestamp?)?.toDate();
        final bt = (b.data()['createdAt'] as Timestamp?)?.toDate();

        if (at == null && bt == null) return 0;
        if (at == null) return 1;
        if (bt == null) return -1;
        return bt.compareTo(at);
      });

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sortedDocs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final doc = sortedDocs[index];
        final item = _TaskMessageListItem.fromDoc(doc);

        return StandardBubbleTile(
          title: item.title,
          description: item.descriptionPreview,
          metaLabel: item.createdAtLabel,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TasksMessageDetails(
                  docRef: doc.reference,
                  memberRef: memberRef,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _TaskMessageListItem {
  _TaskMessageListItem({
    required this.title,
    required this.createdAt,
    this.descriptionPreview,
  });

  final String title;
  final DateTime? createdAt;
  final String? descriptionPreview;

  String get createdAtLabel {
    if (createdAt == null) {
      return 'Date unavailable';
    }
    return DateFormat('M/d/yyyy h:mm a').format(createdAt!.toLocal());
  }

  static _TaskMessageListItem fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    String? stringField(dynamic value) {
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty) return trimmed;
      }
      return null;
    }

    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

    final title = stringField(data['title']) ??
        stringField(data['name']) ??
        'Message';

    final description = stringField(data['message']) ??
        stringField(data['body']) ??
        stringField(data['description']);

    return _TaskMessageListItem(
      title: title,
      createdAt: createdAt,
      descriptionPreview: description,
    );
  }
}
