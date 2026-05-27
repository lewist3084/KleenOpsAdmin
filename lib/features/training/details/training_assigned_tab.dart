// lib/features/training/details/training_assigned_tab.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:kleenops_admin/features/hr/utils/member_file_images.dart';
import 'package:kleenops_admin/features/training/details/training_assigned_training_details.dart';
import 'package:shared_widgets/lists/swipe_delete_flow.dart';
import 'package:shared_widgets/theme/app_palette.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';

/// Lists every member assigned to a training and lets the user swipe right to
/// unassign (with confirm + 5s undo). Tapping a row opens the assigned training
/// details screen so the user can see signatures / completion info.
class TrainingAssignedTab extends StatefulWidget {
  const TrainingAssignedTab({
    super.key,
    required this.companyRef,
    required this.trainingRef,
  });

  final DocumentReference<Map<String, dynamic>> companyRef;
  final DocumentReference<Map<String, dynamic>> trainingRef;

  @override
  State<TrainingAssignedTab> createState() => _TrainingAssignedTabState();
}

class _TrainingAssignedTabState extends State<TrainingAssignedTab> {
  // assignedTraining doc IDs that are pending visual removal (snackbar undo
  // window). Once committed, the doc's `active` flag flips to false and the
  // stream stops emitting it; we leave the id in this set as a no-op so that
  // restored ids during undo don't have to re-stream.
  final Set<String> _pendingRemoval = <String>{};

  Stream<QuerySnapshot<Map<String, dynamic>>> get _stream => FirebaseFirestore.instance
      .collection('assignedTraining')
      .where('trainingId', isEqualTo: widget.trainingRef)
      .where('active', isEqualTo: true)
      .snapshots();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text('Unable to load assignees: ${snap.error}'),
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs
            .where((d) => !_pendingRemoval.contains(d.id))
            .toList();
        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            child: Center(
              child: Text(
                'No one is assigned to this training yet.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final doc = docs[i];
            return _AssignedRow(
              key: ValueKey(doc.id),
              companyRef: widget.companyRef,
              assignedDoc: doc,
              onConfirmUnassign: (memberName) =>
                  _handleUnassign(doc, memberName),
            );
          },
        );
      },
    );
  }

  Future<bool> _handleUnassign(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String memberName,
  ) async {
    final confirmed = await confirmAndUndoDelete(
      context,
      confirmTitle: 'Unassign training?',
      confirmMessage:
          'Remove $memberName from this training? They will no longer see it in their assigned list.',
      snackBarMessage: '$memberName unassigned',
      confirmLabel: 'Unassign',
      onUndo: () {
        if (!mounted) return;
        setState(() => _pendingRemoval.remove(doc.id));
      },
      onCommit: () async {
        try {
          await doc.reference.update({'active': false});
        } catch (e) {
          if (!mounted) return;
          setState(() => _pendingRemoval.remove(doc.id));
          SnackbarService.instance.showSnackBar(
            SnackBar(duration: const Duration(seconds: 5), content: Text('Failed to unassign: $e')),
          );
        }
      },
    );
    if (confirmed && mounted) {
      setState(() => _pendingRemoval.add(doc.id));
    }
    // Return false so the Dismissible widget snaps back; we control visibility
    // via _pendingRemoval in our list filter.
    return false;
  }
}

class _AssignedRow extends StatefulWidget {
  const _AssignedRow({
    super.key,
    required this.companyRef,
    required this.assignedDoc,
    required this.onConfirmUnassign,
  });

  final DocumentReference<Map<String, dynamic>> companyRef;
  final QueryDocumentSnapshot<Map<String, dynamic>> assignedDoc;
  final Future<bool> Function(String memberName) onConfirmUnassign;

  @override
  State<_AssignedRow> createState() => _AssignedRowState();
}

class _AssignedRowState extends State<_AssignedRow> {
  // Memoized member-doc fetches keyed by path, so a recycled row doesn't
  // refetch on rebuild nor show a stale member when the list changes.
  final Map<String, Future<DocumentSnapshot<Map<String, dynamic>>>>
      _memberFutureCache = {};

  @override
  Widget build(BuildContext context) {
    final companyRef = widget.companyRef;
    final assignedDoc = widget.assignedDoc;
    final onConfirmUnassign = widget.onConfirmUnassign;
    final memberRef = assignedDoc.data()['memberId']
        as DocumentReference<Map<String, dynamic>>?;
    if (memberRef == null) return const SizedBox.shrink();

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _memberFutureCache[memberRef.path] ??= memberRef.get(),
      builder: (context, mSnap) {
        final memberData = mSnap.data?.data();
        final name = _resolveMemberName(memberData, memberRef.id);

        return Dismissible(
          key: ValueKey('dismiss-${assignedDoc.id}'),
          direction: DismissDirection.startToEnd,
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_remove, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Unassign',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          confirmDismiss: (_) => onConfirmUnassign(name),
          child: FutureBuilder<String>(
            future: MemberFileImages.primaryProfileImageUrl(
              companyRef: companyRef,
              memberId: memberRef.id,
            ),
            builder: (context, iSnap) {
              final imageUrl = iSnap.data ?? '';
              final assignedData = assignedDoc.data();
              final complete = assignedData['complete'] as bool? ?? false;
              final goodUntilTs = assignedData['goodUntil'] as Timestamp?;

              IconData? statusIcon;
              Color? statusColor;
              String? statusText;
              if (complete) {
                statusIcon = Icons.check_circle_outlined;
                statusColor = AppPaletteScope.of(context).primary2;
              } else if (goodUntilTs != null) {
                final goodUntil = goodUntilTs.toDate();
                final now = DateTime.now();
                if (goodUntil.isBefore(now)) {
                  statusIcon = Icons.error_outline;
                  statusColor = Theme.of(context).colorScheme.error;
                  statusText = 'Expired';
                } else {
                  statusText =
                      '${goodUntil.difference(now).inDays} days left';
                }
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TrainingAssignedTrainingDetailsScreen(
                            companyRef: companyRef,
                            assignedTrainingId: assignedDoc.id,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: StandardTileSmallDart(
                        label: name,
                        imageUrl: imageUrl.isNotEmpty ? imageUrl : null,
                        leadingIcon: imageUrl.isEmpty
                            ? Icons.person_outline
                            : null,
                        secondaryText: statusText,
                        trailingIcon1: statusIcon,
                        trailingIconColor: statusColor,
                        tileColor: Colors.white,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _resolveMemberName(Map<String, dynamic>? data, String fallback) {
    if (data == null) return fallback;
    final n = (data['name'] as String?)?.trim();
    if (n != null && n.isNotEmpty) return n;
    final f = (data['firstName'] as String?)?.trim() ?? '';
    final l = (data['lastName'] as String?)?.trim() ?? '';
    final combined = [f, l].where((p) => p.isNotEmpty).join(' ');
    return combined.isEmpty ? fallback : combined;
  }
}
