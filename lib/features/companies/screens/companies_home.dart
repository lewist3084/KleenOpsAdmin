// lib/features/companies/screens/companies_home.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/tiles/standard_bubble_tile.dart';

import '../../../app/routes.dart';
import '../../../features/sales/services/platform_catalog_service.dart';
import '../../../services/admin_firebase_service.dart';
import '../../../theme/palette.dart';

class CompaniesHome extends StatelessWidget {
  const CompaniesHome({super.key});

  /// Backfill: hardwire every active platform product onto every existing
  /// company as a `service/{productKey}` doc, so costs can accrue. New
  /// companies are wired automatically by the onCompanyCreated trigger.
  Future<void> _provisionAll(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hardwire services?'),
        content: const Text(
            'This writes the platform-product services onto every company so '
            'their costs can be tracked. Existing services keep their accrued '
            'totals. Continue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Hardwire all')),
        ],
      ),
    );
    if (confirmed != true) return;
    messenger.showSnackBar(
        const SnackBar(content: Text('Hardwiring services…')));
    try {
      final count =
          await PlatformCatalogService.instance.provisionAllCompanies();
      messenger.showSnackBar(
          SnackBar(content: Text('Hardwired services onto $count companies.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    const palette = adminPalette;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Companies'),
        backgroundColor: palette.primary1,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutePaths.dashboard),
        ),
        actions: [
          IconButton(
            tooltip: 'Hardwire services onto all companies',
            icon: const Icon(Icons.cable_outlined),
            onPressed: () => _provisionAll(context),
          ),
        ],
      ),
      body: StandardCanvas(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: AdminFirebaseService.instance.allCompanies(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return const Center(child: Text('No companies found.'));
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data();
                final name = data['name'] as String? ?? '(unnamed)';
                final active = data['active'] as bool? ?? true;

                return StandardBubbleTile(
                  title: name,
                  description: active ? 'Active' : 'Inactive',
                  leadingBackgroundColor:
                      active ? palette.primary4 : Colors.grey.shade400,
                  leadingChild: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () => context.go(
                    '${AppRoutePaths.companiesDetails}?id=${doc.id}',
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
