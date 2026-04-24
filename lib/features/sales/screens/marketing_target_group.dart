//  marketing_target_group.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:shared_widgets/lists/standardViewGroup.dart';
import 'package:shared_widgets/tiles/standard_tile_large.dart';
import 'package:kleenops_admin/app/shared_widgets/search/search_control_strip_adapter.dart';
import 'package:shared_widgets/search/search_field_action.dart'
    show SearchAddSelectDropdown;
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:shared_widgets/services/firestore_service.dart';
import '../details/marketing_target_group_details.dart';

class MarketingTargetGroupContent extends ConsumerStatefulWidget {
  const MarketingTargetGroupContent({super.key, this.searchVisible = false});

  final bool searchVisible;

  @override
  ConsumerState<MarketingTargetGroupContent> createState() =>
      _MarketingTargetGroupContentState();
}

class _MarketingTargetGroupContentState
    extends ConsumerState<MarketingTargetGroupContent> {
  static final FirestoreService _fs = FirestoreService();
  final _searchCtl = TextEditingController();
  String _search = '';

  Future<void> _showAddDialog(
      DocumentReference<Map<String, dynamic>> companyRef) async {
    final nameCtl = TextEditingController();
    final descCtl = TextEditingController();
    DocumentReference<Map<String, dynamic>>? customerRef;
    // Placeholder for second dropdown value
    dynamic secondaryValue;

    final custSnap =
        await FirebaseFirestore.instance.collection('customer').orderBy('name').get();
    final custDocs = custSnap.docs;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDState) => DialogAction(
          title: 'New Target Group',
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
                minLines: 2,
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              SearchAddSelectDropdown<DocumentReference<Map<String, dynamic>>>(
                label: 'Customer',
                items: custDocs.map((d) => d.reference).toList(),
                itemLabel: (ref) {
                  final d = custDocs.firstWhere((e) => e.reference == ref);
                  return (d.data()['name'] ?? 'Unnamed') as String;
                },
                onChanged: (val) => setDState(() => customerRef = val),
              ),
              const SizedBox(height: 16),
              SearchAddSelectDropdown<String>(
                label: 'Second Dropdown',
                items: const [],
                itemLabel: (v) => v,
                onChanged: (val) => setDState(() => secondaryValue = val),
              ),
            ],
          ),
          cancelText: 'Cancel',
          actionText: 'Save',
          onCancel: () => Navigator.of(ctx2).pop(),
          onAction: () async {
            final name = nameCtl.text.trim();
            final desc = descCtl.text.trim();
            if (name.isEmpty) return;

            await _fs.saveDocument(
              collectionRef: FirebaseFirestore.instance.collection('targetGroup'),
              data: {
                'name': name,
                'description': desc,
                if (customerRef != null) 'customerId': customerRef,
                'createdAt': FieldValue.serverTimestamp(),
              },
            );
            if (mounted) Navigator.of(ctx2).pop();
          },
        ),
      ),
    );

    nameCtl.dispose();
    descCtl.dispose();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
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

        final query = FirebaseFirestore.instance.collection('targetGroup').orderBy('name');

        final list = StandardViewGroup(
          queryStream: query.snapshots(),
          groupBy: (_) => '',
          onTap: (doc) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MarketingTargetGroupDetailsScreen(
                  companyRef: companyRef,
                  docId: doc.id,
                ),
              ),
            );
          },
          itemBuilder: (doc) {
            final data = doc.data();
            final name = data['name'] ?? '';
            return StandardTileLargeDart(
              imageUrl: '',
              firstLine: name,
              firstLineIcon: Icons.flag_outlined,
            );
          },
          emptyMessage: 'No target groups found.',
        );

        return Stack(
          children: [
            Column(
              children: [
                if (widget.searchVisible)
                  SearchControlStrip(
                    controller: _searchCtl,
                    hintText: 'Search Target Groups',
                    onChanged: (t) => setState(() => _search = t.trim()),
                  ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: bottomInset),
                    child: list,
                  ),
                ),
              ],
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
