// lib/features/inventory/details/inventory_fulfillment_details.dart
//
// DEGRADED port: the kleenops version depends on
//   - kleenops/services/tenant_firebase_service.dart (no admin equiv)
//   - kleenops/widgets/tiles/fulfillment_item_tile.dart (no admin equiv)
//   - kleenops/widgets/viewers/live_barcode_scanner_page.dart (admin has)
// to drive a per-company pick-location QR flow and a rich, image-laden
// fulfillment-item row. The admin port keeps the core flow — fulfillment
// status, request list, item list with simple quantity editing, complete
// button — and drops the pick-location scan + per-item barcode lookup
// dialogs.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';
import 'package:kleenops_admin/widgets/layout/bookended_canvas.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/containers/container_header.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';

class InventoryFulfillmentDetailsScreen extends ConsumerStatefulWidget {
  const InventoryFulfillmentDetailsScreen({
    super.key,
    required this.fulfillmentId,
  });

  final String fulfillmentId;

  @override
  InventoryFulfillmentDetailsScreenState createState() =>
      InventoryFulfillmentDetailsScreenState();
}

class InventoryFulfillmentDetailsScreenState
    extends ConsumerState<InventoryFulfillmentDetailsScreen> {
  bool _completing = false;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _fulfillmentStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _fulfillmentItemsStream;

  @override
  Widget build(BuildContext context) {
    final fulfillmentRef = FirebaseFirestore.instance
        .collection('fulfillment')
        .doc(widget.fulfillmentId);

    return Scaffold(
      drawer: const UserDrawer(),
      body: BookendedCanvas(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _fulfillmentStream ??= fulfillmentRef.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _buildCenteredMessage(
                'Failed to load fulfillment: ${snapshot.error}',
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final doc = snapshot.data;
            if (doc == null || !doc.exists) {
              return _buildCenteredMessage('Fulfillment not found.');
            }
            final data = doc.data() ?? <String, dynamic>{};
            final status = data['status']?.toString() ?? 'open';
            final requestRefs = _extractRequestRefs(data['requestIds']);
            final pickLocationName =
                data['pickedLocationName']?.toString() ?? '';

            const bottomPadding = 16.0;

            return ListView(
              padding: EdgeInsets.only(
                bottom:
                    bottomPadding + MediaQuery.of(context).padding.bottom,
              ),
              children: [
                FutureBuilder<List<_FulfillmentRequestDetail>>(
                  future: requestRefs.isEmpty
                      ? Future.value(<_FulfillmentRequestDetail>[])
                      : _loadRequestDetails(requestRefs),
                  builder: (context, requestSnapshot) {
                    final hasRequests = requestRefs.isNotEmpty;
                    final requestDescription = () {
                      if (!hasRequests) {
                        return 'No inventory requests selected.';
                      }
                      if (requestSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return 'Loading inventory requests...';
                      }
                      if (requestSnapshot.hasError) {
                        return 'Failed to load inventory requests.';
                      }
                      final items = requestSnapshot.data ?? [];
                      if (items.isEmpty) {
                        return 'No inventory requests found.';
                      }
                      final labels = items
                          .map(
                            (item) => item.requestNumber.trim().isNotEmpty
                                ? item.requestNumber.trim()
                                : item.teamName.trim(),
                          )
                          .where((label) => label.isNotEmpty)
                          .toList();
                      if (labels.isEmpty) {
                        return '${items.length} inventory request${items.length == 1 ? '' : 's'}';
                      }
                      return labels.join(', ');
                    }();

                    return ContainerHeader(
                      showImage: false,
                      titleHeader: 'Status',
                      title: _statusLabel(status),
                      descriptionHeader: 'Inventory Requests',
                      description: requestDescription,
                    );
                  },
                ),
                const SizedBox(height: 12),
                if (pickLocationName.isNotEmpty)
                  ContainerActionWidget(
                    title: 'Pick Location',
                    actionText: '',
                    content: Text(pickLocationName),
                  ),
                const SizedBox(height: 12),
                ContainerActionWidget(
                  title: 'Items to Fulfill',
                  actionText: '',
                  content: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _fulfillmentItemsStream ??= fulfillmentRef
                        .collection('fulfillmentItem')
                        .snapshots(),
                    builder: (context, itemSnapshot) {
                      if (itemSnapshot.hasError) {
                        return Text(
                          'Failed to load items: ${itemSnapshot.error}',
                        );
                      }
                      if (itemSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }

                      final docs = itemSnapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return const Text(
                            'No items aggregated for this fulfillment.');
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (_, index) {
                          final itemDoc = docs[index];
                          final itemData = itemDoc.data();
                          final objectRef = itemData['companyObjectId']
                              as DocumentReference<Object?>?;
                          final requested =
                              _parseQuantity(itemData['requestedQuantity']);
                          final fulfilled =
                              _parseQuantity(itemData['fulfilledQuantity']);
                          return _FulfillmentItemRow(
                            itemRef: itemDoc.reference,
                            objectRef: objectRef,
                            requested: requested,
                            fulfilled: fulfilled,
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ElevatedButton(
                    onPressed: status == 'completed' || _completing
                        ? null
                        : () => _confirmComplete(
                              context,
                              fulfillmentRef,
                              requestRefs,
                            ),
                    child: _completing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Complete Fulfillment'),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DetailsAppBar(title: 'Fulfillment Details'),
          const HomeNavBarAdapter(highlightSelected: false),
        ],
      ),
    );
  }

  Widget _buildCenteredMessage(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }

  Future<void> _confirmComplete(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> fulfillmentRef,
    List<DocumentReference<Map<String, dynamic>>> requestRefs,
  ) async {
    final shouldComplete = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DialogAction(
        title: 'Complete Fulfillment',
        content: const Text(
          'Are you sure you want to mark this fulfillment as complete?',
        ),
        cancelText: 'Cancel',
        onCancel: () => Navigator.of(ctx).pop(false),
        actionText: 'Complete',
        onAction: () => Navigator.of(ctx).pop(true),
        wrapContentInScrollView: false,
      ),
    );

    if (shouldComplete != true || !mounted) return;

    setState(() => _completing = true);

    try {
      await fulfillmentRef.update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });

      await Future.wait(requestRefs.map((requestRef) {
        return requestRef.update({
          'status': 'fulfilled',
          'fulfilledAt': FieldValue.serverTimestamp(),
        });
      }));

      if (mounted) {
        SnackbarService.instance.showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 5),
            content: Text('Fulfillment marked complete.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        SnackbarService.instance.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 5),
            content: Text('Failed to complete fulfillment: $error'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _completing = false);
      }
    }
  }

  Future<List<_FulfillmentRequestDetail>> _loadRequestDetails(
    List<DocumentReference<Map<String, dynamic>>> refs,
  ) async {
    final futures = refs.map((ref) async {
      try {
        final snap = await ref.get();
        if (!snap.exists) return null;
        final data = snap.data() ?? <String, dynamic>{};
        final teamRef = data['teamId'] as DocumentReference?;
        String teamName = 'Unknown Team';
        if (teamRef != null) {
          try {
            final teamSnap = await teamRef.get();
            final teamData =
                teamSnap.data() as Map<String, dynamic>? ?? <String, dynamic>{};
            teamName = teamData['name']?.toString() ?? teamName;
          } catch (_) {
            // fallback to default
          }
        }
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final status = data['status']?.toString() ?? 'draft';
        final requestNumber = data['requestNumber']?.toString() ?? ref.id;
        return _FulfillmentRequestDetail(
          ref: ref,
          teamName: teamName,
          status: status,
          createdAt: createdAt,
          requestNumber: requestNumber,
        );
      } catch (_) {
        return null;
      }
    }).toList();

    final list = (await Future.wait(futures))
        .whereType<_FulfillmentRequestDetail>()
        .toList();

    list.sort(
      (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
    );

    return list;
  }

  List<DocumentReference<Map<String, dynamic>>> _extractRequestRefs(
    dynamic raw,
  ) {
    if (raw is! List) return const [];
    return raw
        .whereType<DocumentReference>()
        .map((ref) => ref as DocumentReference<Map<String, dynamic>>)
        .toList();
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

  static int _parseQuantity(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw) ?? 0;
    return 0;
  }
}

class _FulfillmentItemRow extends StatefulWidget {
  const _FulfillmentItemRow({
    required this.itemRef,
    required this.objectRef,
    required this.requested,
    required this.fulfilled,
  });

  final DocumentReference<Map<String, dynamic>> itemRef;
  final DocumentReference<Object?>? objectRef;
  final int requested;
  final int fulfilled;

  @override
  State<_FulfillmentItemRow> createState() => _FulfillmentItemRowState();
}

class _FulfillmentItemRowState extends State<_FulfillmentItemRow> {
  String? _objectName;

  @override
  void initState() {
    super.initState();
    _loadObject();
  }

  Future<void> _loadObject() async {
    final ref = widget.objectRef;
    if (ref == null) return;
    try {
      final snap = await ref.get();
      final data = snap.data() as Map<String, dynamic>? ?? {};
      if (!mounted) return;
      setState(() {
        _objectName = data['localName']?.toString() ?? ref.id;
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _updateFulfilled(int delta) async {
    final next = (widget.fulfilled + delta)
        .clamp(0, widget.requested);
    if (next == widget.fulfilled) return;
    try {
      await widget.itemRef.update({'fulfilledQuantity': next});
    } catch (_) {
      if (!mounted) return;
      SnackbarService.instance.showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 5),
          content: Text('Failed to update quantity.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name =
        _objectName ?? widget.objectRef?.id ?? 'Unknown item';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.inventory_2_outlined),
      title: Text(name),
      subtitle: Text(
        'Fulfilled ${widget.fulfilled} of ${widget.requested}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: widget.fulfilled <= 0 ? null : () => _updateFulfilled(-1),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: widget.fulfilled >= widget.requested
                ? null
                : () => _updateFulfilled(1),
          ),
        ],
      ),
    );
  }
}

class _FulfillmentRequestDetail {
  _FulfillmentRequestDetail({
    required this.ref,
    required this.teamName,
    required this.status,
    required this.createdAt,
    required this.requestNumber,
  });

  final DocumentReference<Map<String, dynamic>> ref;
  final String teamName;
  final String status;
  final DateTime? createdAt;
  final String requestNumber;
}
