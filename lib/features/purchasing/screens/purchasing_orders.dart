//  purchasingOrder.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../forms/purchasing_orders_form.dart';
import 'package:shared_widgets/search/search_field_action.dart';
import 'package:shared_widgets/lists/standardViewGroup.dart';
import 'package:kleenops_admin/widgets/tiles/purchase_order_tile.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/features/purchasing/details/purchasing_order_details.dart';

class PurchasingOrdersContent extends ConsumerStatefulWidget {
  const PurchasingOrdersContent({super.key});

  @override
  ConsumerState<PurchasingOrdersContent> createState() =>
      _PurchasingOrdersContentState();
}

class _PurchasingOrdersContentState
    extends ConsumerState<PurchasingOrdersContent> {
  final TextEditingController _searchCtl = TextEditingController();
  String _search = '';

  Future<void> _deleteOrder(
      QueryDocumentSnapshot<Map<String, dynamic>> docSnap) async {
    final ref = docSnap.reference;
    final oldData = docSnap.data();
    await ref.delete();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Purchase order deleted.'),
        duration: const Duration(minutes: 5),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () => ref.set(oldData),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final companyAsync = ref.watch(companyIdProvider);

    return companyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (companyRef) {
        if (companyRef == null) {
          return const Center(child: Text('No company found.'));
        }

        final query = FirebaseFirestore.instance
            .collection('purchaseOrder')
            .orderBy('createdAt', descending: true);

        final list = StandardViewGroup(
          queryStream: query.snapshots(),
          groupBy: (doc) {
            final ts = doc.data()['createdAt'] as Timestamp?;
            if (ts == null) return 'Unknown';
            return DateFormat('yMMMd').format(ts.toDate());
          },
          groupSort: (a, b) => b.compareTo(a),
          headerIcon: null,
          itemBuilder: (doc) {
            final data = doc.data();
            final vendorRef =
                data['vendorId'] as DocumentReference<Map<String, dynamic>>?;
            final teamRef =
                data['teamId'] as DocumentReference<Map<String, dynamic>>?;
            final poNumber = data['poNumber']?.toString() ?? '';
            final rawTotal = data['purchaseOrderTotal'];
            String purchaseOrderTotal = '';
            if (rawTotal != null) {
              final num? totalNum = rawTotal is num
                  ? rawTotal
                  : num.tryParse(rawTotal.toString());
              if (totalNum != null) {
                purchaseOrderTotal = '\$${totalNum.toStringAsFixed(2)}';
              } else {
                purchaseOrderTotal = rawTotal.toString();
              }
            }
            final pdfUrl = data['purchaseOrderPDF']?.toString() ?? '';
            final canDelete = data['purchaseOrderSent'] != true;

            return FutureBuilder<List<DocumentSnapshot<Map<String, dynamic>>>>(
              future: Future.wait([
                if (vendorRef != null) vendorRef.get(),
                if (teamRef != null) teamRef.get(),
              ]),
              builder: (context, snap) {
                String vendorName = '';
                String teamName = '';
                if (snap.hasData) {
                  final docs = snap.data!;
                  int idx = 0;
                  if (vendorRef != null && idx < docs.length) {
                    final d = docs[idx++];
                    if (d.exists) {
                      vendorName = (d.data()?['name'] ?? '') as String;
                    }
                  }
                  if (teamRef != null && idx < docs.length) {
                    final d = docs[idx];
                    if (d.exists) {
                      teamName = (d.data()?['name'] ?? '') as String;
                    }
                  }
                }

                if (snap.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 56,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                Widget tile = PurchaseOrderTile(
                  vendorName: vendorName,
                  teamName: teamName,
                  poNumber: poNumber,
                  purchaseOrderTotal: purchaseOrderTotal,
                  imageUrl: pdfUrl,
                  showImage: pdfUrl.isNotEmpty,
                  fit: BoxFit.cover,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PurchasingOrderDetailsScreen(
                          companyId: companyRef.id,
                          docId: doc.id,
                        ),
                      ),
                    );
                  },
                );

                if (canDelete) {
                  tile = Dismissible(
                    key: ValueKey(doc.id),
                    direction: DismissDirection.startToEnd,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 16),
                      child:
                          const Icon(Icons.delete_forever, color: Colors.white),
                    ),
                    confirmDismiss: (_) async {
                      await _deleteOrder(doc);
                      return false;
                    },
                    child: tile,
                  );
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 4.0, horizontal: 16.0),
                  child: tile,
                );
              },
            );
          },
        );

        return Stack(
          children: [
            Column(
              children: [
                SearchFieldAction(
                  controller: _searchCtl,
                  labelText: 'Search?I',
                  onChanged: (t) => setState(() => _search = t.trim()),
                ),
                Expanded(child: list),
              ],
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                heroTag: null,
                child: const Icon(Icons.add),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PurchasingOrdersForm(
                        companyId: companyRef,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
