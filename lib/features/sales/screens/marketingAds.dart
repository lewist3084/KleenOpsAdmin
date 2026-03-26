//  marketingAds.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:shared_widgets/lists/standardViewGroup.dart';
import 'package:shared_widgets/tiles/standard_tile_large.dart';
import 'package:shared_widgets/search/search_field_action.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/services/firestore_service.dart';
import 'package:kleenops_admin/features/admin/utils/company_file_images.dart';
import '../details/marketingAdsDetails.dart';

class MarketingAdsContent extends ConsumerStatefulWidget {
  const MarketingAdsContent({super.key});

  @override
  ConsumerState<MarketingAdsContent> createState() =>
      _MarketingAdsContentState();
}

class _MarketingAdsContentState extends ConsumerState<MarketingAdsContent> {
  static final FirestoreService _fs = FirestoreService();
  final _searchCtl = TextEditingController();
  String _search = '';

  Future<void> _showAddDialog(
      DocumentReference<Map<String, dynamic>> companyRef) async {
    final nameCtl = TextEditingController();
    final descCtl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => DialogAction(
        title: 'New Marketing Material',
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

          final user = FirebaseAuth.instance.currentUser;
          if (user == null) return;
          final indexSnap =
              await FirebaseFirestore.instance.collection('memberByUid').doc(user.uid).get();
          DocumentReference<Map<String, dynamic>>? memberRef;
          DocumentReference? teamRef;
          final indexData = indexSnap.data();
          if (indexData?['active'] == true) {
            final memberId = indexData?['memberId'] as String?;
            if (memberId != null && memberId.trim().isNotEmpty) {
              memberRef = FirebaseFirestore.instance.collection('member').doc(memberId.trim());
              final memberSnap = await memberRef.get();
              final memberData = memberSnap.data() ?? <String, dynamic>{};
              teamRef = memberData['primaryTeamId'] as DocumentReference?;
            }
          }

          await _fs.saveDocument(
            collectionRef: FirebaseFirestore.instance.collection('marketingMaterial'),
            data: {
              'name': name,
              'description': desc,
              if (memberRef != null) 'memberId': memberRef,
              'teamId': teamRef,
              'createdAt': FieldValue.serverTimestamp(),
            },
          );
          if (mounted) Navigator.of(ctx).pop();
        },
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

        final query =
            FirebaseFirestore.instance.collection('marketingMaterial').orderBy('name');

        final list = StandardViewGroup(
          queryStream: query.snapshots(),
          groupBy: (_) => '',
          itemBuilder: (doc) {
            final data = doc.data();
            final name = data['name'] ?? '';
            final desc = data['description'] ?? '';
            return FutureBuilder<List<Map<String, dynamic>>>(
              future: CompanyFileImages.headerImageEntries(
                companyRef: companyRef,
              ),
              builder: (context, imageSnap) {
                final fileImages =
                    imageSnap.data ?? const <Map<String, dynamic>>[];
                final imageUrl = fileImages.isNotEmpty
                    ? (fileImages.first['url'] as String?)?.trim() ?? ''
                    : '';
                return StandardTileLargeDart(
                  imageUrl: imageUrl,
                  firstLine: name,
                  secondLine: desc,
                  firstLineIcon: Icons.campaign,
                );
              },
            );
          },
          onTap: (doc) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    MarketingAdsDetailsScreen(docRef: doc.reference),
              ),
            );
          },
          emptyMessage: 'No marketing materials found.',
        );

        return Stack(
          children: [
            Column(
              children: [
                SearchFieldAction(
                  controller: _searchCtl,
                  labelText: 'Search Materials',
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
