// lib/features/purchasing/screens/purchasing_objects.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_widgets/tiles/standard_tile_large.dart';
import 'package:shared_widgets/lists/standardView.dart';
import 'package:kleenops_admin/app/shared_widgets/search/search_control_strip_adapter.dart';
import 'package:shared_widgets/utils/process_localization_utils.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart'; // <-- import for companyIdProvider
import '../../objects/utils/company_object_file_images.dart';

class PurchasingObjectsContent extends ConsumerStatefulWidget {
  const PurchasingObjectsContent({super.key, this.searchVisible = false});

  final bool searchVisible;

  @override
  ConsumerState<PurchasingObjectsContent> createState() =>
      _PurchasingObjectsContentState();
}

class _PurchasingObjectsContentState
    extends ConsumerState<PurchasingObjectsContent> {
  final TextEditingController _searchCtl = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1) Watch the companyIdProvider to retrieve the user's company reference.
    final companyRef = ref.watch(companyIdProvider).maybeWhen(
      data: (refValue) => refValue,
      orElse: () => null,
    );

    // 2) If null, we display an error or loading.
    //    This can happen if the user is not logged in or Firestore is still loading.
    if (companyRef == null) {
      return const Center(child: Text("Error: No company ID found or still loading."));
    }

    // 3) Convert our DocumentReference to a string ID:
    final companyId = companyRef.id;

    // 4) Build the Firestore query. localName is now a localized map,
    //    so we can't server-side orderBy on it — sort client-side on
    //    the resolved current-locale string.
    final query = FirebaseFirestore.instance
        .collection('company')
        .doc(companyId)
        .collection('companyObject')
        .orderBy('objectCategoryId')
        .snapshots();

    final listLocaleCode = Localizations.localeOf(context).toString();

    final list = StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs.where((doc) {
          final name = ProcessLocalizationUtils.resolveLocalizedText(
            doc.data()['localName'],
            localeCode: listLocaleCode,
          ).toLowerCase();
          return name.contains(_search.toLowerCase());
        }).toList()
          ..sort((a, b) {
            final an = ProcessLocalizationUtils.resolveLocalizedText(
              a.data()['localName'],
              localeCode: listLocaleCode,
            ).toLowerCase();
            final bn = ProcessLocalizationUtils.resolveLocalizedText(
              b.data()['localName'],
              localeCode: listLocaleCode,
            ).toLowerCase();
            return an.compareTo(bn);
          });

        if (docs.isEmpty) {
          return const Center(child: Text('No objects found.'));
        }

        return StandardView<QueryDocumentSnapshot<Map<String, dynamic>>>(
          items: docs,
          groupBy: (d) => d.data()['objectCategoryId'],
          headerIcon: null,
          onTap: (doc) {
            context.push(
              '${AppRoutePaths.purchasingObjectsDetails}?docId=${doc.id}',
            );
          },
          itemBuilder: (doc) {
            final data = doc.data();
            return FutureBuilder<String>(
              future: CompanyObjectFileImages.primaryHeaderImageUrl(
                companyRef: companyRef,
                objectId: doc.id,
              ),
              builder: (context, imageSnap) {
                final imageUrl = imageSnap.data ?? '';
                return StandardTileLargeDart(
                  imageUrl: imageUrl,
                  firstLine: ProcessLocalizationUtils.resolveLocalizedText(
                    data['localName'],
                    localeCode: listLocaleCode,
                  ),
                  secondLine: '',
                );
              },
            );
          },
        );
      },
    );

    return Column(
      children: [
        if (widget.searchVisible)
          SearchControlStrip(
            controller: _searchCtl,
            hintText: 'Search…',
            onChanged: (t) => setState(() => _search = t.trim()),
          ),
        Expanded(child: list),
      ],
    );
  }
}




