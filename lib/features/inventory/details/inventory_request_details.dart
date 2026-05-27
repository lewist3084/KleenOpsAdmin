// lib/features/inventory/details/inventory_request_details.dart
//
// DEGRADED port: kleenops version routed through
// facility/objects/purchasing/task repositories that don't exist in
// admin, and a live-barcode-scanner location flow tied to per-company
// `location` docs. The admin port keeps the core read/edit experience
// (team header, location text, item list + add/delete, submit button)
// and drops the QR-scan location workflow.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';
import 'package:kleenops_admin/widgets/layout/bookended_canvas.dart';
import 'package:kleenops_admin/widgets/tiles/purchase_order_item_tile.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/containers/container_header.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:shared_widgets/search/search_field_action.dart';
import 'package:shared_widgets/services/firestore_service.dart';
import 'package:shared_widgets/theme/app_palette.dart';
import 'package:shared_widgets/tiles/selectable_row_tile.dart';

class InventoryRequestDetailsScreen extends ConsumerStatefulWidget {
  final String docId;
  const InventoryRequestDetailsScreen({
    super.key,
    required this.docId,
  });

  @override
  ConsumerState<InventoryRequestDetailsScreen> createState() =>
      _InventoryRequestDetailsScreenState();
}

class _InventoryRequestDetailsScreenState
    extends ConsumerState<InventoryRequestDetailsScreen> {
  final TextEditingController _locationController = TextEditingController();
  bool _submitting = false;
  final Map<String, Future<DocumentSnapshot<Map<String, dynamic>>>>
      _teamFutureCache = {};
  final Map<String, Future<DocumentSnapshot<Map<String, dynamic>>>>
      _objectFutureCache = {};
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _requestStream;

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  Widget _buildLocationSection(Map<String, dynamic> data) {
    final locationName = data['locationName']?.toString() ?? '';
    if (_locationController.text != locationName) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_locationController.text != locationName) {
          _locationController.text = locationName;
        }
      });
    }

    return ContainerActionWidget(
      title: 'Location',
      actionText: '',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SearchFieldAction(
            controller: _locationController,
            labelText: 'Location',
            onChanged: (value) async {
              try {
                await FirebaseFirestore.instance
                    .collection('inventoryRequest')
                    .doc(widget.docId)
                    .update({'locationName': value});
              } catch (_) {
                // ignore transient update errors
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Type a location name. QR-scan workflow is not yet wired in admin.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addInventoryRequestItem(
    DocumentReference<Map<String, dynamic>> itemRef, {
    String? locationName,
  }) async {
    final invRequestRef = FirebaseFirestore.instance
        .collection('inventoryRequest')
        .doc(widget.docId);

    final trimmedLocationName = locationName?.trim() ?? '';

    final data = <String, dynamic>{
      'companyObjectId': itemRef,
      'quantity': 1,
      'createdAt': FieldValue.serverTimestamp(),
      'timelineCategory': '4XkpkXSLeGUZirMEiQ6E',
      'inventoryRequestId': invRequestRef,
    };

    if (trimmedLocationName.isNotEmpty) {
      data['locationName'] = trimmedLocationName;
    }

    await FirestoreService().saveDocument(
      collectionRef: FirebaseFirestore.instance.collection('timeline'),
      data: data,
    );
  }

  Future<void> _showAddItemDialog(
    BuildContext context,
    String locationName,
  ) async {
    final snap = await FirebaseFirestore.instance
        .collection('companyObject')
        .orderBy('localName')
        .get();
    final docs = snap.docs;
    if (docs.isEmpty) {
      if (context.mounted) {
        SnackbarService.instance.showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 5),
            content: Text('No company objects found.'),
          ),
        );
      }
      return;
    }

    DocumentReference<Map<String, dynamic>>? selected;
    final searchCtrl = TextEditingController();
    String query = '';

    List<QueryDocumentSnapshot<Map<String, dynamic>>> filtered() => docs
        .where((d) => ((d.data()['localName'] ?? d.id).toString())
            .toLowerCase()
            .contains(query.toLowerCase()))
        .toList();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setD) {
          final list = filtered();
          return DialogAction(
            title: 'Item',
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SearchFieldAction(
                  controller: searchCtrl,
                  labelText: 'Search',
                  onChanged: (v) => setD(() => query = v),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final d = list[i];
                      final objData = d.data();
                      final isSelected = selected == d.reference;
                      return SelectableRowTile<DocumentReference<Map<String, dynamic>>>(
                        value: d.reference,
                        selected: isSelected,
                        onTap: () => setD(
                          () => selected = isSelected ? null : d.reference,
                        ),
                        label: (objData['localName'] ?? d.id).toString(),
                      );
                    },
                  ),
                ),
              ],
            ),
            cancelText: 'Cancel',
            onCancel: () => Navigator.of(ctx2).pop(),
            actionText: 'Done',
            onAction: () async {
              if (selected == null) {
                SnackbarService.instance.showSnackBar(
                  const SnackBar(
                    duration: Duration(seconds: 5),
                    content: Text('Select item'),
                  ),
                );
                return;
              }

              await _addInventoryRequestItem(
                selected!,
                locationName: locationName,
              );

              if (context.mounted) Navigator.of(ctx2).pop();
            },
          );
        },
      ),
    );

    searchCtrl.dispose();
  }

  Future<void> _deleteItem(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final ref = doc.reference;
    final oldData = doc.data();
    await ref.delete();
    SnackbarService.instance.showSnackBar(
      SnackBar(
        content: const Text('Item removed.'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () => ref.set(oldData),
        ),
      ),
    );
  }

  Future<void> _handleSubmitRequest(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> requestRef,
  ) async {
    if (_submitting) return;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogCtx) => DialogAction(
            title: 'Submit Inventory Request',
            content: const Text(
              'Verify the location and requested items before submitting this request.',
            ),
            cancelText: 'Cancel',
            onCancel: () => Navigator.of(dialogCtx).pop(false),
            actionText: 'Submit',
            onAction: () => Navigator.of(dialogCtx).pop(true),
          ),
        ) ??
        false;

    if (!confirmed || !mounted) return;

    setState(() => _submitting = true);

    try {
      await requestRef.update({
        'status': 'submitted',
        'submittedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        SnackbarService.instance.showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 5),
            content: Text('Inventory request submitted.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        SnackbarService.instance.showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 5),
            content: Text('Failed to submit request.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Widget _buildSubmitSection(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> requestRef,
    Map<String, dynamic> data,
  ) {
    final status = data['status']?.toString() ?? 'draft';
    final isInProcess = status == 'inProcess';
    final isSubmitted = status == 'submitted' || isInProcess;
    final label = isInProcess
        ? 'In Process'
        : isSubmitted
            ? 'Submitted'
            : 'Submit';

    final theme = Theme.of(context);
    final buttonStyle = ElevatedButton.styleFrom(
      minimumSize: const Size.fromHeight(56),
      backgroundColor: AppPaletteScope.of(context).primary2,
      foregroundColor: Colors.black,
      disabledBackgroundColor: theme.colorScheme.surfaceContainerHighest,
      disabledForegroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
      textStyle: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );

    final onPressed = (!isSubmitted && !_submitting)
        ? () => _handleSubmitRequest(context, requestRef)
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: ElevatedButton(
        onPressed: onPressed,
        style: buttonStyle,
        child: _submitting && !isSubmitted
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final docRef = FirebaseFirestore.instance
        .collection('inventoryRequest')
        .doc(widget.docId);

    return Scaffold(
      drawer: const UserDrawer(),
      body: BookendedCanvas(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _requestStream ??= docRef.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: Text('Inventory request not found.'));
            }
            final data = snapshot.data!.data()!;
            final requestLocationName =
                data['locationName']?.toString() ?? '';
            final teamRef =
                data['teamId'] as DocumentReference<Map<String, dynamic>>?;
            return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: teamRef == null
                  ? null
                  : (_teamFutureCache[teamRef.path] ??= teamRef.get()),
              builder: (context, teamSnap) {
                final teamName =
                    (teamSnap.data?.data() ?? {})['name'] ?? 'Unknown';
                const bottomPadding = 16.0;
                return SingleChildScrollView(
                  padding: EdgeInsets.only(
                    bottom: bottomPadding +
                        MediaQuery.of(context).padding.bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ContainerHeader(
                        image: null,
                        titleHeader: 'Team',
                        title: teamName,
                        descriptionHeader: '',
                        description: '',
                      ),
                      _buildLocationSection(data),
                      Builder(
                        builder: (context) {
                          final textLocationName =
                              _locationController.text.trim();
                          final currentLocationName =
                              textLocationName.isNotEmpty
                                  ? textLocationName
                                  : requestLocationName;
                          final invRequestRef = FirebaseFirestore.instance
                              .collection('inventoryRequest')
                              .doc(widget.docId);
                          final itemsQuery = FirebaseFirestore.instance
                              .collection('timeline')
                              .where('inventoryRequestId',
                                  isEqualTo: invRequestRef)
                              .orderBy('createdAt');

                          return ContainerActionStandardViewGroup(
                            title: 'Requested Items',
                            actionText: 'Add',
                            onAction: () => _showAddItemDialog(
                              context,
                              currentLocationName,
                            ),
                            queryStream: itemsQuery.snapshots(),
                            groupBy: (doc) => null,
                            emptyMessage: 'No items.',
                            shrinkWrap: true,
                            physics: const ClampingScrollPhysics(),
                            onSwipeRight: (doc) => _deleteItem(context, doc),
                            itemBuilder: (doc) {
                              final itemData = doc.data();
                              final qtyRaw = itemData['quantity'];
                              final qty = qtyRaw is int
                                  ? qtyRaw
                                  : int.tryParse(qtyRaw?.toString() ?? '') ??
                                      1;
                              final objRef = itemData['companyObjectId']
                                  as DocumentReference<Map<String, dynamic>>?;
                              return FutureBuilder<
                                  DocumentSnapshot<Map<String, dynamic>>>(
                                future: objRef == null
                                    ? null
                                    : (_objectFutureCache[objRef.path] ??=
                                        objRef.get()),
                                builder: (context, snap) {
                                  final objData = snap.data?.data() ?? {};
                                  final objName =
                                      objData['localName']?.toString() ??
                                          objRef?.id ??
                                          '';
                                  final itemLocationName =
                                      itemData['locationName']?.toString() ??
                                          '';
                                  final locationDisplay =
                                      itemLocationName.trim().isNotEmpty
                                          ? itemLocationName.trim()
                                          : requestLocationName.isNotEmpty
                                              ? requestLocationName
                                              : null;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4.0,
                                    ),
                                    child: PurchaseOrderItemTile(
                                      key: ValueKey(doc.id),
                                      imageUrl: '',
                                      title: objName,
                                      currentPrice: 0,
                                      titleIcon: null,
                                      secondaryText: locationDisplay,
                                      secondaryIcon: locationDisplay != null
                                          ? Icons.location_on_outlined
                                          : null,
                                      showPriceRow: false,
                                      showTotalPrice: false,
                                      subTitle: 'Quantity',
                                      subTitleIcon: Icons.numbers,
                                      initialPercentage: qty,
                                      step: 1,
                                      minValue: 1,
                                      maxValue: null,
                                      suffixText: '',
                                      onPercentageChanged: (val) async {
                                        await FirestoreService().saveDocument(
                                          collectionRef: FirebaseFirestore
                                              .instance
                                              .collection('timeline'),
                                          data: {'quantity': val},
                                          docId: doc.id,
                                        );
                                      },
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                      _buildSubmitSection(context, docRef, data),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DetailsAppBar(title: 'Inventory Request'),
          const HomeNavBarAdapter(highlightSelected: false),
        ],
      ),
    );
  }
}
