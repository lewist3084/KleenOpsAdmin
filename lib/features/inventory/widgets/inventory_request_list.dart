// lib/features/inventory/widgets/inventory_request_list.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_widgets/lists/standardViewGroup.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';

/// Admin-side inventory-request list. Reads from the top-level
/// `inventoryRequest` collection — admin uses top-level collections,
/// not per-company subcollections.
class InventoryRequestList extends ConsumerStatefulWidget {
  const InventoryRequestList({
    super.key,
    required this.detailsRoute,
  });

  final String detailsRoute;

  @override
  ConsumerState<InventoryRequestList> createState() =>
      _InventoryRequestListState();
}

class _InventoryRequestListState extends ConsumerState<InventoryRequestList> {
  final Map<String, Future<DocumentSnapshot>> _teamFutureCache = {};

  @override
  Widget build(BuildContext context) {
    final detailsRoute = widget.detailsRoute;

    final query = FirebaseFirestore.instance
        .collection('inventoryRequest')
        .orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            SnackbarService.instance.showSnackBar(
              const SnackBar(
                duration: Duration(seconds: 5),
                content: Text('Error loading inventory requests.'),
                backgroundColor: Colors.red,
              ),
            );
          });
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Text('No inventory requests found.'),
          );
        }

        return StandardViewGroup(
          queryStream: query.snapshots(),
          groupBy: (doc) {
            final Timestamp ts =
                (doc.data()['createdAt'] as Timestamp?) ??
                    Timestamp.now();
            final date = ts.toDate();
            return '${date.year}-${date.month}-${date.day}';
          },
          itemBuilder: (doc) {
            final data = doc.data();
            final teamRef = data['teamId'] as DocumentReference?;
            final status = (data['status'] as String?) ?? 'draft';
            String? statusLabel;
            IconData? statusIcon;
            switch (status) {
              case 'submitted':
                statusLabel = 'Submitted';
                statusIcon = Icons.outbox_outlined;
                break;
              case 'inProcess':
                statusLabel = 'In Process';
                statusIcon = Icons.sync;
                break;
              case 'fulfilled':
              case 'completed':
                statusLabel = 'Fulfilled';
                statusIcon = Icons.check_circle_outline;
                break;
              case 'open':
                statusLabel = 'Open';
                statusIcon = Icons.pending_actions;
                break;
              default:
                statusLabel = 'Draft';
                statusIcon = Icons.edit_outlined;
                break;
            }
            return FutureBuilder<DocumentSnapshot>(
              future: teamRef == null
                  ? null
                  : (_teamFutureCache[teamRef.path] ??= teamRef.get()),
              builder: (context, teamSnap) {
                String teamName = 'Unknown';
                if (teamSnap.hasData && teamSnap.data!.exists) {
                  final teamData =
                      teamSnap.data!.data() as Map<String, dynamic>? ??
                          {};
                  teamName = teamData['name'] ?? 'Unknown';
                }
                return InkWell(
                  onTap: () {
                    context.push('$detailsRoute?docId=${doc.id}');
                  },
                  child: StandardTileSmallDart.iconText(
                    leadingicon: Icons.meeting_room_outlined,
                    text: teamName,
                    secondText: statusLabel,
                    secondTextIcon: statusIcon,
                    trailingIcon1: null,
                  ),
                );
              },
            );
          },
          groupSort: (a, b) => b.compareTo(a),
          headerIcon: null,
          onSwipeLeft: null,
          onSwipeRight: null,
          shrinkWrap: true,
        );
      },
    );
  }
}
