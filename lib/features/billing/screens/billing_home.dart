// lib/features/billing/screens/billing_home.dart
//
// Platform billing overview: an entry point to the sellable product catalog
// plus a live feed of recent platform sales (the dual-ledger invoices that
// `recordPlatformSale` writes when a company buys a product through the setup
// wizard). Per-company service detail lives on the company details screen.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';

import '../../../app/routes.dart';
import '../../../theme/palette.dart';
import 'platform_products_screen.dart';

class BillingHome extends StatelessWidget {
  const BillingHome({super.key});

  static const _palette = adminPalette;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing & Revenue'),
        backgroundColor: _palette.primary1,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutePaths.dashboard),
        ),
      ),
      body: StandardCanvas(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: Icon(Icons.sell_outlined, color: _palette.primary3),
                title: const Text('Platform Products'),
                subtitle: const Text(
                    'Domains, registered agent, virtual address, phone — '
                    'edit price & availability.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const PlatformProductsScreen()),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: Icon(Icons.request_quote_outlined, color: _palette.primary3),
                title: const Text('Wholesale Invoices'),
                subtitle: const Text(
                    'Invoices Northwest bills us for registered agent & filings — '
                    'our cost side. Review and pay.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutePaths.corpToolsInvoices),
              ),
            ),
            const SizedBox(height: 16),
            Text('Recent platform sales',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const _RecentPlatformSales(),
          ],
        ),
      ),
    );
  }
}

/// Streams the most recent admin-side invoices and keeps only those tagged with
/// a `platformSaleKey` (i.e. written by `recordPlatformSale` for a company's
/// product purchase). Firestore can't query field-existence, so we over-fetch
/// recent invoices and filter client-side.
class _RecentPlatformSales extends StatelessWidget {
  const _RecentPlatformSales();

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('invoice')
        .orderBy('createdAt', descending: true)
        .limit(40);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Text('Error: ${snap.error}');
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final sales = snap.data!.docs
            .where((d) => (d.data()['platformSaleKey'] as String?) != null)
            .toList();
        if (sales.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No platform sales yet. When a company buys a product in the '
                'setup wizard, it appears here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }
        return Column(
          children: [for (final d in sales) _SaleTile(data: d.data())],
        );
      },
    );
  }
}

class _SaleTile extends StatelessWidget {
  const _SaleTile({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final number = data['invoiceNumber']?.toString() ?? '—';
    final total = (data['total'] as num?)?.toDouble() ?? 0;
    final status = data['status'] as String? ?? '';
    final companyId = data['companyId'] as String? ?? '';
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final dateStr =
        createdAt != null ? DateFormat.yMMMd().format(createdAt) : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.receipt_long_outlined),
        title: Text('Invoice #$number  ·  \$${total.toStringAsFixed(2)}'),
        subtitle: Text(
          [
            if (companyId.isNotEmpty) 'Company $companyId',
            if (dateStr.isNotEmpty) dateStr,
          ].join('  ·  '),
        ),
        trailing: Text(
          status,
          style: TextStyle(
            color: status == 'paid' ? Colors.green : Colors.orange,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
