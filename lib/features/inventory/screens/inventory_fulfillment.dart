// lib/features/inventory/screens/inventory_fulfillment.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:shared_widgets/search/search_field_action.dart';
import 'package:shared_widgets/services/firestore_service.dart';
import 'package:shared_widgets/tiles/selectable_row_tile.dart';

import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';

class InventoryFulfillmentScreen extends StatelessWidget {
  const InventoryFulfillmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      drawer: const UserDrawer(),
      body: StandardCanvas(
        child: SafeArea(
          top: true,
          bottom: false,
          child: Stack(
            children: [
              const Positioned.fill(child: InventoryFulfillmentContent()),
              const Positioned(
                left: 0, right: 0, top: 0,
                child: CanvasTopBookend(),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DetailsAppBar(title: 'Fulfillment'),
          const HomeNavBarAdapter(),
        ],
      ),
    );
  }
}

class InventoryFulfillmentContent extends ConsumerStatefulWidget {
  const InventoryFulfillmentContent({super.key});

  @override
  InventoryFulfillmentContentState createState() =>
      InventoryFulfillmentContentState();
}

class InventoryFulfillmentContentState
    extends ConsumerState<InventoryFulfillmentContent> {
  bool _creatingFulfillment = false;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('User not logged in.'));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('fulfillment')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Failed to load fulfillments: ${snapshot.error}'),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No fulfillments yet.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, index) {
            final doc = docs[index];
            final data = doc.data();
            final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
            final status = data['status']?.toString() ?? 'open';
            final requestCount =
                (data['requestIds'] as List<dynamic>? ?? []).length;

            return Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: ListTile(
                // No admin inventoryFulfillmentDetails route — open the
                // fulfillment list screen as a placeholder until details
                // ports land.
                onTap: () =>
                    context.push(AppRoutePaths.inventoryFulfillment),
                title: Text(
                  createdAt != null
                      ? _formatDate(createdAt)
                      : 'Fulfillment ${doc.id}',
                ),
                subtitle: Text(
                  '${_statusLabel(status)} • Requests: $requestCount',
                ),
                trailing: const Icon(Icons.chevron_right),
              ),
            );
          },
        );
      },
    );
  }

  /// Opens the request picker and creates a new fulfillment doc with the
  /// chosen requests. Returns the new fulfillment ref (or null on cancel).
  Future<DocumentReference<Map<String, dynamic>>?> beginFulfillmentFlow(
      BuildContext context) async {
    if (_creatingFulfillment) return null;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar(context, 'User not logged in.');
      return null;
    }

    try {
      final requestSnap = await FirebaseFirestore.instance
          .collection('inventoryRequest')
          .where('status', isEqualTo: 'submitted')
          .get();

      final requestDocs = requestSnap.docs;

      if (requestDocs.isEmpty) {
        _showSnackBar(context, 'No submitted inventory requests to fulfill.');
        return null;
      }

      final options = await Future.wait(
        requestDocs.map((doc) async {
          final data = doc.data();
          final DocumentReference? teamRef =
              data['teamId'] as DocumentReference?;
          String teamName = 'Unknown Team';
          if (teamRef != null) {
            try {
              final teamSnap = await teamRef.get();
              final teamData =
                  teamSnap.data() as Map<String, dynamic>? ?? {};
              teamName = teamData['name']?.toString() ?? teamName;
            } catch (_) {
              // ignore lookup failures
            }
          }

          final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final requestNumber = data['requestNumber']?.toString() ?? doc.id;

          return _RequestSelection(
            doc: doc.reference,
            requestNumber: requestNumber,
            teamName: teamName,
            createdAt: createdAt,
            teamRef: teamRef,
          );
        }),
      );

      options.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final selected = await _showRequestPicker(context, options);
      if (selected == null || selected.isEmpty) {
        return null;
      }

      return await _createFulfillmentFromRequests(context, selected);
    } on FirebaseException catch (e) {
      _showSnackBar(context, 'Unable to load requests: ${e.message}');
      return null;
    }
  }

  Future<List<_RequestSelection>?> _showRequestPicker(
    BuildContext context,
    List<_RequestSelection> options,
  ) async {
    if (options.isEmpty) return null;

    final searchCtrl = TextEditingController();
    final selected = <String>{};
    String query = '';

    List<_RequestSelection> filtered() {
      if (query.trim().isEmpty) return options;
      final lower = query.toLowerCase();
      return options
          .where(
            (opt) =>
                opt.teamName.toLowerCase().contains(lower) ||
                opt.requestNumber.toLowerCase().contains(lower),
          )
          .toList();
    }

    final result = await showDialog<List<_RequestSelection>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setState) {
            final visible = filtered();
            return DialogAction(
              title: 'Select Requests',
              cancelText: 'Cancel',
              onCancel: () {
                Navigator.of(context).pop();
              },
              actionText: 'Start',
              onAction: () {
                if (selected.isEmpty) return;
                final chosen = options
                    .where((opt) => selected.contains(opt.doc.id))
                    .toList();
                Navigator.of(context).pop(chosen);
              },
              wrapContentInScrollView: false,
              content: SizedBox(
                height: 420,
                child: Column(
                  children: [
                    SearchFieldAction(
                      controller: searchCtrl,
                      labelText: 'Search requests',
                      onChanged: (value) {
                        setState(() {
                          query = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: visible.isEmpty
                          ? const Center(
                              child: Text('No requests match your search.'),
                            )
                          : ListView.builder(
                              itemCount: visible.length,
                              itemBuilder: (context, index) {
                                final option = visible[index];
                                final isChecked =
                                    selected.contains(option.doc.id);
                                return SelectableRowTile<String>(
                                  value: option.doc.id,
                                  selected: isChecked,
                                  label: option.teamName,
                                  subtitle:
                                      '${option.requestNumber} • '
                                      '${_formatDate(option.createdAt)}',
                                  onTap: () {
                                    setState(() {
                                      if (isChecked) {
                                        selected.remove(option.doc.id);
                                      } else {
                                        selected.add(option.doc.id);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    searchCtrl.dispose();
    return result;
  }

  Future<DocumentReference<Map<String, dynamic>>?>
      _createFulfillmentFromRequests(
    BuildContext context,
    List<_RequestSelection> selected,
  ) async {
    setState(() {
      _creatingFulfillment = true;
    });

    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final fulfillmentCollection = FirebaseFirestore.instance
          .collection('fulfillment')
          .withConverter<Map<String, dynamic>>(
            fromFirestore: (snapshot, _) => snapshot.data() ?? {},
            toFirestore: (data, _) => data,
          );
      final fulfillmentRef = fulfillmentCollection.doc();

      final requestRefs = selected.map((e) => e.doc).toList();
      final teamRefs = <String, DocumentReference>{};
      for (final ref
          in selected.map((e) => e.teamRef).whereType<DocumentReference>()) {
        teamRefs[ref.path] = ref;
      }

      await FirestoreService().saveDocument(
        collectionRef: fulfillmentCollection,
        docId: fulfillmentRef.id,
        data: {
          'status': 'open',
          'requestIds': requestRefs,
          if (teamRefs.isNotEmpty) 'teamIds': teamRefs.values.toList(),
        },
      );

      await _createFulfillmentItems(
        fulfillmentRef: fulfillmentRef,
        requestRefs: requestRefs,
      );

      await Future.wait(requestRefs.map((requestRef) {
        return requestRef.update({
          'status': 'inProcess',
          'fulfillmentId': fulfillmentRef,
          'inProcessAt': FieldValue.serverTimestamp(),
        });
      }));

      return fulfillmentRef;
    } catch (error) {
      _showSnackBar(context, 'Failed to create fulfillment: $error');
      return null;
    } finally {
      if (navigator.canPop()) navigator.pop();
      if (mounted) {
        setState(() {
          _creatingFulfillment = false;
        });
      }
    }
  }

  Future<void> _createFulfillmentItems({
    required DocumentReference<Map<String, dynamic>> fulfillmentRef,
    required List<DocumentReference<Map<String, dynamic>>> requestRefs,
  }) async {
    final timelineCollection = FirebaseFirestore.instance
        .collection('timeline')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) => snapshot.data() ?? {},
          toFirestore: (data, _) => data,
        );

    final aggregates = <String, _FulfillmentAggregate>{};

    for (final requestRef in requestRefs) {
      final timelineSnap = await timelineCollection
          .where('inventoryRequestId', isEqualTo: requestRef)
          .get();

      for (final itemDoc in timelineSnap.docs) {
        final itemData = itemDoc.data();
        final objectRef =
            itemData['companyObjectId'] as DocumentReference<Object?>?;
        if (objectRef == null) continue;

        final quantity = _parseQuantity(itemData['quantity']);
        final key = objectRef.path;
        final aggregate = aggregates.putIfAbsent(
          key,
          () => _FulfillmentAggregate(objectRef: objectRef),
        );

        aggregate.requestedQuantity += quantity;
        aggregate.requestRefs.add(requestRef);
        aggregate.timelineRefs.add(itemDoc.reference);
      }
    }

    final fulfillmentItems = fulfillmentRef
        .collection('fulfillmentItem')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) => snapshot.data() ?? {},
          toFirestore: (data, _) => data,
        );

    for (final aggregate in aggregates.values) {
      await FirestoreService().saveDocument(
        collectionRef: fulfillmentItems,
        docId: aggregate.objectRef.id,
        data: {
          'companyObjectId': aggregate.objectRef,
          'requestedQuantity': aggregate.requestedQuantity,
          'fulfilledQuantity': 0,
          'requestIds': aggregate.requestRefs.toList(),
          'timelineItemRefs': aggregate.timelineRefs.toList(),
        },
      );
    }
  }

  static int _parseQuantity(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw) ?? 1;
    return 1;
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'submitted':
        return 'Submitted';
      case 'inProcess':
        return 'In Process';
      case 'fulfilled':
        return 'Fulfilled';
      case 'completed':
        return 'Completed';
      case 'open':
        return 'Open';
      case 'draft':
        return 'Draft';
      default:
        if (status.isEmpty) return 'Unknown';
        return status[0].toUpperCase() + status.substring(1);
    }
  }

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$month/$day/$year $hour:$minute $period';
  }

  void _showSnackBar(BuildContext context, String message) {
    if (!mounted) return;
    SnackbarService.instance.showSnackBar(
      SnackBar(duration: const Duration(seconds: 5), content: Text(message)),
    );
  }
}

class _RequestSelection {
  _RequestSelection({
    required this.doc,
    required this.requestNumber,
    required this.teamName,
    required this.createdAt,
    this.teamRef,
  });

  final DocumentReference<Map<String, dynamic>> doc;
  final DocumentReference? teamRef;
  final String requestNumber;
  final String teamName;
  final DateTime createdAt;
}

class _FulfillmentAggregate {
  _FulfillmentAggregate({required this.objectRef});

  final DocumentReference<Object?> objectRef;
  int requestedQuantity = 0;
  final Set<DocumentReference<Map<String, dynamic>>> requestRefs = {};
  final Set<DocumentReference<Map<String, dynamic>>> timelineRefs = {};
}
