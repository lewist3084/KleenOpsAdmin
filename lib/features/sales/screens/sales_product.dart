import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:shared_widgets/lists/standardViewGroup.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:shared_widgets/services/firestore_service.dart';
import '../tabs/products_tabs.dart';

class SalesProductContent extends ConsumerStatefulWidget {
  const SalesProductContent({super.key});

  @override
  ConsumerState<SalesProductContent> createState() =>
      _SalesProductContentState();
}

class _SalesProductContentState extends ConsumerState<SalesProductContent> {
  static final FirestoreService _fs = FirestoreService();

  Future<void> _showAddDialog(
      DocumentReference<Map<String, dynamic>> companyRef) async {
    final nameCtl = TextEditingController();
    final descCtl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => DialogAction(
        title: 'New Product',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtl,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descCtl,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        cancelText: 'Cancel',
        actionText: 'Save',
        onCancel: () => Navigator.of(ctx).pop(),
        onAction: () async {
          final name = nameCtl.text.trim();
          final desc = descCtl.text.trim();
          if (name.isEmpty) return;
          await _fs.saveDocument(
            collectionRef: FirebaseFirestore.instance.collection('product'),
            data: {
              'name': name,
              'description': desc,
              'createdAt': FieldValue.serverTimestamp(),
            },
          );
          if (context.mounted) Navigator.of(ctx).pop();
        },
      ),
    );

    nameCtl.dispose();
    descCtl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final companyAsync = ref.watch(companyIdProvider);
    final bool hideChrome = false;
    final bottomInset =
        (hideChrome ? 16.0 : kBottomNavigationBarHeight + 16.0) +
            MediaQuery.of(context).padding.bottom;

    return companyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (companyRef) {
        if (companyRef == null) {
          return const Center(child: Text('No company found.'));
        }

        final query = FirebaseFirestore.instance.collection('product').orderBy('name');

        final list = StandardViewGroup(
          queryStream: query.snapshots(),
          groupBy: (_) => '',
          onTap: (doc) {
            Navigator.of(context).push(
              MaterialPageRoute(
                settings: RouteSettings(
                  name: '/sales/product/${doc.id}',
                ),
                builder: (_) => ProductsTabsScreen(
                  companyId: companyRef,
                  docId: doc.id,
                ),
              ),
            );
          },
          itemBuilder: (doc) {
            final data = doc.data();
            final name = data['name'] ?? '';
            return StandardTileSmallDart.iconText(
              leadingicon: Icons.inventory_2_outlined,
              text: name,
            );
          },
        );

        return Stack(
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: list,
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                heroTag: null,
                child: const Icon(Icons.add),
                onPressed: () => _showAddDialog(companyRef),
              ),
            ),
          ],
        );
      },
    );
  }
}
