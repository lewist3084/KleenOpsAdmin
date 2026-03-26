import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:shared_widgets/tiles/standard_tile_large.dart';
import 'package:shared_widgets/lists/standardViewGroup.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';
import 'package:kleenops_admin/widgets/labels/icon_text_checkbox.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/services/firestore_service.dart';
import '../details/marketingDataDetails.dart';

class MarketingDataContent extends ConsumerStatefulWidget {
  const MarketingDataContent({super.key});

  @override
  ConsumerState<MarketingDataContent> createState() =>
      _MarketingDataContentState();
}

class _MarketingDataContentState extends ConsumerState<MarketingDataContent> {
  static final FirestoreService _fs = FirestoreService();

  Future<void> _showAddDialog(
      DocumentReference<Map<String, dynamic>> companyRef) async {
    final nameCtl = TextEditingController();
    final descCtl = TextEditingController();
    bool firstName = false;
    bool lastName = false;
    bool email = false;
    bool phoneNumber = false;
    bool company = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDState) => DialogAction(
          title: 'New Marketing Data',
          cancelText: 'Cancel',
          actionText: 'Save',
          onCancel: () => Navigator.of(ctx2).pop(),
          onAction: () async {
            final name = nameCtl.text.trim();
            final desc = descCtl.text.trim();
            if (name.isEmpty) return;

            await _fs.saveDocument(
              collectionRef: FirebaseFirestore.instance.collection('marketingData'),
              data: {
                'name': name,
                'description': desc,
                'firstName': firstName,
                'lastName': lastName,
                'email': email,
                'phoneNumber': phoneNumber,
                'company': company,
                'createdAt': FieldValue.serverTimestamp(),
              },
            );
            if (mounted) Navigator.of(ctx2).pop();
          },
          content: SingleChildScrollView(
            child: Column(
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
                const SizedBox(height: 16),
                IconTextCheckbox(
                  text: 'First Name',
                  value: firstName,
                  onChanged: (v) => setDState(() => firstName = v ?? false),
                ),
                IconTextCheckbox(
                  text: 'Last Name',
                  value: lastName,
                  onChanged: (v) => setDState(() => lastName = v ?? false),
                ),
                IconTextCheckbox(
                  text: 'Email',
                  value: email,
                  onChanged: (v) => setDState(() => email = v ?? false),
                ),
                IconTextCheckbox(
                  text: 'Phone Number',
                  value: phoneNumber,
                  onChanged: (v) => setDState(() => phoneNumber = v ?? false),
                ),
                IconTextCheckbox(
                  text: 'Company',
                  value: company,
                  onChanged: (v) => setDState(() => company = v ?? false),
                ),
              ],
            ),
          ),
        ),
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

        final query = FirebaseFirestore.instance.collection('marketingData').orderBy('name');

        final list = StandardViewGroup(
          queryStream: query.snapshots(),
          groupBy: (_) => '',
          itemBuilder: (doc) {
            final data = doc.data();
            final name = data['name'] ?? '';
            final desc = data['description'] ?? '';
            return StandardTileLargeDart(
              imageUrl: '',
              showImage: false,
              firstLine: name,
              secondLine: desc,
              firstLineIcon: Icons.storage,
            );
          },
          onTap: (doc) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    MarketingDataDetailsScreen(docRef: doc.reference),
              ),
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
