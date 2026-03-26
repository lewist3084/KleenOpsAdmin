// lib/features/finances/details/financeAccountDetails.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:kleenops_admin/features/finances/forms/financeAccountForm.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/container_header.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';

class FinanceAccountDetailsScreen extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final String docId;

  const FinanceAccountDetailsScreen({
    super.key,
    required this.companyRef,
    required this.docId,
  });

  Widget _wrapCanvas(Widget child) {
    return StandardCanvas(
      child: SafeArea(
        top: true,
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(child: child),
            const Positioned(
              left: 0, right: 0, top: 0,
              child: CanvasTopBookend(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: null,
      drawer: const UserDrawer(),
      body: _wrapCanvas(
          _AccountDetailsContent(companyRef: companyRef, docId: docId),
        ),
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final menuSections = MenuDrawerSections(
            actions: [
              ContentMenuItem(
                icon: Icons.edit_outlined,
                label: 'Edit Account',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FinanceAccountForm(
                        companyRef: companyRef,
                        docId: docId,
                      ),
                    ),
                  );
                },
              ),
            ],
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DetailsAppBar(
                title: 'Account Details',
                menuSections: menuSections,
              ),
              const HomeNavBarAdapter(),
            ],
          );
        },
      ),
    );
  }
}

class _AccountDetailsContent extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final String docId;

  const _AccountDetailsContent({
    required this.companyRef,
    required this.docId,
  });

  @override
  Widget build(BuildContext context) {
    final accountRef = FirebaseFirestore.instance.collection('account').doc(docId);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: accountRef.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snap.data!.data() ?? {};
        final name = (data['name'] ?? 'Unnamed').toString();
        final type = (data['type'] ?? '').toString();
        final balance = (data['balance'] as num?)?.toDouble() ?? 0.0;

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 120),
          child: Column(
            children: [
              ContainerHeader(
                showImage: false,
                titleHeader: 'Account',
                title: name,
                descriptionHeader: 'Type',
                description: type.isEmpty ? '—' : type,
              ),
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Balance',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '\$${balance.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: balance >= 0 ? Colors.green[700] : Colors.red[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Recent Transactions',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ),
              _TransactionList(companyRef: companyRef, accountRef: accountRef),
            ],
          ),
        );
      },
    );
  }
}

class _TransactionList extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final DocumentReference<Map<String, dynamic>> accountRef;

  const _TransactionList({
    required this.companyRef,
    required this.accountRef,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('timeline')
          .where('debitAccountId', isEqualTo: accountRef)
          .orderBy('createdAt', descending: true)
          .limit(25)
          .snapshots(),
      builder: (context, debitSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('timeline')
              .where('creditAccountId', isEqualTo: accountRef)
              .orderBy('createdAt', descending: true)
              .limit(25)
              .snapshots(),
          builder: (context, creditSnap) {
            if (!debitSnap.hasData || !creditSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final allDocs = [
              ...debitSnap.data!.docs,
              ...creditSnap.data!.docs,
            ];

            // Deduplicate
            final seen = <String>{};
            final unique = allDocs.where((d) => seen.add(d.id)).toList();

            unique.sort((a, b) {
              final tsA = a.data()['createdAt'] as Timestamp?;
              final tsB = b.data()['createdAt'] as Timestamp?;
              if (tsA == null && tsB == null) return 0;
              if (tsA == null) return 1;
              if (tsB == null) return -1;
              return tsB.compareTo(tsA);
            });

            if (unique.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No transactions found.'),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: unique.length,
              itemBuilder: (context, index) {
                final data = unique[index].data();
                final entryName = (data['name'] ?? 'Entry').toString();
                final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
                final ts = data['createdAt'] as Timestamp?;
                final date = ts != null
                    ? DateFormat('MMM d, y').format(ts.toDate())
                    : '';
                final isDebit = data['debitAccountId'] == accountRef;

                return StandardTileSmallDart(
                  label: entryName,
                  secondaryText: date,
                  leadingIcon: isDebit
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                  leadingIconColor: isDebit ? Colors.red : Colors.green,
                  trailingWidget: Text(
                    '${isDebit ? "-" : "+"}\$${amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDebit ? Colors.red : Colors.green,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
