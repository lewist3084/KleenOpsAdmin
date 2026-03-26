import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/features/finances/details/financeInvoiceDetails.dart';
import 'package:kleenops_admin/features/finances/forms/financeCustomerForm.dart';
import 'package:kleenops_admin/features/finances/forms/financeInvoiceForm.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/containers/container_header.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';

class FinanceCustomerDetailsScreen extends ConsumerWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final String docId;

  const FinanceCustomerDetailsScreen({
    super.key,
    required this.companyRef,
    required this.docId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: null,
      drawer: const UserDrawer(),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('customer').doc(docId).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data?.data();
            if (data == null) {
              return const Center(child: Text('Customer not found'));
            }

            final name = (data['name'] ?? 'Unnamed') as String;
            final email = (data['email'] ?? '') as String;
            final phone = (data['phone'] ?? '') as String;
            final contactName = (data['contactName'] ?? '') as String;
            final notes = (data['notes'] ?? '') as String;
            final balance = (data['balance'] as num?)?.toDouble() ?? 0.0;
            final address = data['address'] as Map<String, dynamic>?;
            final addressStr = address != null
                ? [
                    address['address'],
                    address['city'],
                    address['state'],
                    address['zip'],
                  ].where((v) => v != null && v.toString().trim().isNotEmpty).join(', ')
                : '';

            return SafeArea(
              top: true,
              bottom: false,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 120),
                children: [
                  ContainerHeader(
                    showImage: false,
                    titleHeader: 'Customer',
                    title: name,
                    descriptionHeader: 'Contact',
                    description: contactName.isNotEmpty ? contactName : '---',
                  ),
                  const SizedBox(height: 8),
                  if (email.isNotEmpty || phone.isNotEmpty || addressStr.isNotEmpty)
                    ContainerActionWidget(
                      title: 'Contact Information',
                      actionText: '',
                      content: Column(
                        children: [
                          if (email.isNotEmpty)
                            StandardTileSmallDart(
                              label: email,
                              leadingIcon: Icons.email_outlined,
                            ),
                          if (phone.isNotEmpty)
                            StandardTileSmallDart(
                              label: phone,
                              leadingIcon: Icons.phone_outlined,
                            ),
                          if (addressStr.isNotEmpty)
                            StandardTileSmallDart(
                              label: addressStr,
                              leadingIcon: Icons.location_on_outlined,
                            ),
                        ],
                      ),
                    ),
                  ContainerActionWidget(
                    title: 'Balance',
                    actionText: '',
                    content: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        '\$${balance.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: balance > 0
                              ? Colors.red
                              : balance < 0
                                  ? Colors.green
                                  : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  ContainerActionWidget(
                    title: 'Invoices',
                    headerActionText: 'Add',
                    onHeaderAction: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => FinanceInvoiceForm(
                            companyRef: companyRef,
                            initialCustomerRef:
                                FirebaseFirestore.instance.collection('customer').doc(docId),
                          ),
                        ),
                      );
                    },
                    actionText: '',
                    content: _buildInvoices(context),
                  ),
                  if (notes.isNotEmpty)
                    ContainerActionWidget(
                      title: 'Notes',
                      actionText: '',
                      content: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(notes),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final menuSections = MenuDrawerSections(
            actions: [
              ContentMenuItem(
                icon: Icons.edit_outlined,
                label: 'Edit Customer',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FinanceCustomerForm(
                        companyRef: companyRef,
                        docId: docId,
                      ),
                    ),
                  );
                },
              ),
              ContentMenuItem(
                icon: Icons.receipt_long_outlined,
                label: 'New Invoice',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FinanceInvoiceForm(
                        companyRef: companyRef,
                        initialCustomerRef:
                            FirebaseFirestore.instance.collection('customer').doc(docId),
                      ),
                    ),
                  );
                },
              ),
              ContentMenuItem(
                icon: Icons.home_outlined,
                label: 'Finance Home',
                onTap: () => context.push(AppRoutePaths.financeHome),
              ),
            ],
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DetailsAppBar(
                title: 'Customer',
                menuSections: menuSections,
              ),
              const HomeNavBarAdapter(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInvoices(BuildContext context) {
    final customerRef = FirebaseFirestore.instance.collection('customer').doc(docId);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('invoice')
          .where('customerId', isEqualTo: customerRef)
          .orderBy('createdAt', descending: true)
          .limit(8)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No invoices yet',
              style: TextStyle(color: Colors.grey[600]),
            ),
          );
        }
        return Column(
          children: snapshot.data!.docs.map((doc) {
            final invoice = doc.data();
            final number = (invoice['invoiceNumber'] ?? doc.id).toString();
            final status = (invoice['status'] ?? 'draft').toString();
            final total = (invoice['total'] as num?)?.toDouble() ?? 0.0;

            return StandardTileSmallDart(
              label: '#$number',
              secondaryText:
                  '${status.toUpperCase()}  |  \$${total.toStringAsFixed(2)}',
              trailingIcon1: Icons.chevron_right,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => FinanceInvoiceDetailsScreen(
                      companyRef: companyRef,
                      docId: doc.id,
                    ),
                  ),
                );
              },
            );
          }).toList(),
        );
      },
    );
  }
}
