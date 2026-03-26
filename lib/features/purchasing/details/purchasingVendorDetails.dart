// lib/features/purchasing/details/purchasingVendorDetails.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:kleenops_admin/services/firestore_service.dart';

import 'package:shared_widgets/containers/container_header.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:kleenops_admin/widgets/fields/google_address.dart';
import 'package:shared_widgets/lists/standardViewGroup.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';
import 'package:kleenops_admin/constants/google_api_key.dart';
import 'vendorContactDetails.dart';

class PurchasingVendorDetails extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyId;
  final String docId;

  const PurchasingVendorDetails({
    super.key,
    required this.companyId,
    required this.docId,
  });

  @override
  State<PurchasingVendorDetails> createState() => _PurchasingVendorDetailsState();
}

class _PurchasingVendorDetailsState extends State<PurchasingVendorDetails> {
  Future<void> _addBillingLocation(
      DocumentReference<Map<String, dynamic>> vendorRef) async {
    final addressCtl = TextEditingController();
    final cityCtl = TextEditingController();
    final stateCtl = TextEditingController();
    final zipCtl = TextEditingController();
    double? lat;
    double? lng;

    await showDialog(
      context: context,
      builder: (ctx) => DialogAction(
        title: 'Add Location',
        cancelText: 'Cancel',
        actionText: 'Save',
        onCancel: () => Navigator.of(ctx).pop(),
        onAction: () async {
          final map = {
            'address': addressCtl.text.trim(),
            'city': cityCtl.text.trim(),
            'state': stateCtl.text.trim(),
            'zip': zipCtl.text.trim(),
            if (lat != null) 'lat': lat,
            if (lng != null) 'lng': lng,
          };
          await vendorRef.update({
            'billingLocations': FieldValue.arrayUnion([map])
          });
          Navigator.of(ctx).pop();
        },
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GoogleAddressField(
                apiKey: kGoogleApiKey,
                controller: addressCtl,
                onSelected: (m) {
                  lat = (m['lat'] as num?)?.toDouble();
                  lng = (m['lng'] as num?)?.toDouble();
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: cityCtl,
                decoration: const InputDecoration(labelText: 'City'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: stateCtl,
                decoration: const InputDecoration(labelText: 'State'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: zipCtl,
                decoration: const InputDecoration(labelText: 'Zip Code'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addContact(
      DocumentReference<Map<String, dynamic>> vendorRef) async {
    final nameCtl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => DialogAction(
        title: 'Add Contact',
        cancelText: 'Cancel',
        actionText: 'Save',
        onCancel: () => Navigator.of(ctx).pop(),
        onAction: () async {
          final name = nameCtl.text.trim();
          if (name.isEmpty) return;
          final col  = widget.companyId.collection('contact');
          final meta = await FirestoreService().buildCreateMeta(col);
          await col.add({
            'name': name,
            'companyCompanyId': vendorRef,
            ...meta,
          });
          Navigator.of(ctx).pop();
        },
        content: TextField(
          controller: nameCtl,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vendorRef =
        widget.companyId.collection('companyCompany').doc(widget.docId);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: vendorRef.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snap.data!.data() ?? {};
        final name = data['name'] ?? '';
        final List<dynamic> locations = data['billingLocations'] ?? [];

        final contactsQuery = widget.companyId
            .collection('contact')
            .where('companyCompanyId', isEqualTo: vendorRef);

        return SingleChildScrollView(
          child: Column(
            children: [
              ContainerHeader(
                showImage: false,
                titleHeader: 'Vendor',
                title: name.toString(),
                descriptionHeader: '',
                description: '',
              ),
              ContainerActionStandardViewGroup(
                title: 'Contacts',
                actionText: 'Add',
                onAction: () => _addContact(vendorRef),
                queryStream: contactsQuery.snapshots(),
                groupBy: (doc) => null,
                emptyMessage: 'No contacts found.',
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (doc) {
                    final d = doc.data();
                    final contactName = d['name'] ?? '';
                    return StandardTileSmallDart.iconText(
                      leadingicon: Icons.person_outline,
                      text: contactName.toString(),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => VendorContactDetails(
                              companyId: widget.companyId,
                              contactId: doc.id,
                            ),
                          ),
                        );
                      },
                    );
                  },
              ),
              ContainerActionWidget(
                title: 'Locations',
                actionText: 'Add',
                onAction: () => _addBillingLocation(vendorRef),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: locations.map<Widget>((loc) {
                    final m = Map<String, dynamic>.from(loc as Map);
                    final address = m['address'] ?? '';
                    final city = m['city'] ?? '';
                    final state = m['state'] ?? '';
                    final zip = m['zip'] ?? '';
                    final parts = [address, city, state, zip]
                        .where((e) => (e as String).isNotEmpty)
                        .join(', ');
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text(parts),
                    );
                  }).toList(),
                ),
              ),
              // Purchase Orders for this vendor
              ContainerActionStandardViewGroup(
                title: 'Purchase Orders',
                actionText: '',
                queryStream: widget.companyId
                    .collection('purchaseOrder')
                    .where('vendorId', isEqualTo: vendorRef)
                    .orderBy('createdAt', descending: true)
                    .limit(10)
                    .snapshots(),
                groupBy: (doc) => null,
                emptyMessage: 'No purchase orders.',
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (doc) {
                  final d = doc.data();
                  final poNumber = d['poNumber']?.toString() ?? '';
                  final status = (d['status'] ?? 'draft').toString();
                  return StandardTileSmallDart.iconText(
                    leadingicon: Icons.shopping_cart_outlined,
                    text: 'PO #$poNumber — $status',
                    trailingIcon1: Icons.chevron_right,
                  );
                },
              ),
              // Bills for this vendor
              ContainerActionStandardViewGroup(
                title: 'Bills',
                actionText: '',
                queryStream: widget.companyId
                    .collection('bill')
                    .where('vendorId', isEqualTo: vendorRef)
                    .orderBy('createdAt', descending: true)
                    .limit(10)
                    .snapshots(),
                groupBy: (doc) => null,
                emptyMessage: 'No bills.',
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (doc) {
                  final d = doc.data();
                  final billNumber = d['billNumber']?.toString() ?? '';
                  final status = (d['status'] ?? 'unpaid').toString();
                  final total =
                      (d['total'] as num?)?.toDouble() ?? 0.0;
                  return StandardTileSmallDart.iconText(
                    leadingicon: Icons.receipt_long_outlined,
                    text: '$billNumber — $status — \$${total.toStringAsFixed(2)}',
                    trailingIcon1: Icons.chevron_right,
                  );
                },
              ),
              // Vendor balance summary
              _VendorBalanceSummary(companyRef: widget.companyId, vendorRef: vendorRef),
            ],
          ),
        );
      },
    );
  }
}

class _VendorBalanceSummary extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final DocumentReference<Map<String, dynamic>> vendorRef;

  const _VendorBalanceSummary({
    required this.companyRef,
    required this.vendorRef,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('bill')
          .where('vendorId', isEqualTo: vendorRef)
          .where('status', whereIn: const ['unpaid', 'partial'])
          .snapshots(),
      builder: (context, snap) {
        double outstanding = 0;
        int count = 0;
        if (snap.hasData) {
          count = snap.data!.docs.length;
          for (final doc in snap.data!.docs) {
            final total = (doc.data()['total'] as num?)?.toDouble() ?? 0.0;
            final paid =
                (doc.data()['amountPaid'] as num?)?.toDouble() ?? 0.0;
            outstanding += (total - paid);
          }
        }

        return ContainerActionWidget(
          title: 'Balance',
          actionText: '',
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Outstanding bills'),
                  Text(
                    '$count',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Amount owed'),
                  Text(
                    '\$${outstanding.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: outstanding > 0 ? Colors.red[700] : Colors.green[700],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
