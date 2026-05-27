// lib/features/engagement/screens/external_reports.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:kleenops_admin/app/shared_widgets/search/search_control_strip_adapter.dart';
import 'package:shared_widgets/lists/standardViewGroup.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/features/engagement/tabs/engagement_reports_tabs.dart'
    show engagementReportsTabsSearchVisibleProvider;

class ExternalReportsContent extends ConsumerStatefulWidget {
  const ExternalReportsContent({super.key});

  @override
  ConsumerState<ExternalReportsContent> createState() => _ExternalReportsContentState();
}

class _ExternalReportsContentState extends ConsumerState<ExternalReportsContent> {
  final TextEditingController _searchCtl = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final companyAsync = ref.watch(companyIdProvider);
    final showSearch = ref.watch(engagementReportsTabsSearchVisibleProvider);

    return companyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (companyRef) {
        if (companyRef == null) {
          return const Center(child: Text('No company found.'));
        }

        final categoryRef = FirebaseFirestore.instance
            .collection('timelineCategory')
            .doc('BUzHgvFBBDI27Bm6QACW');

        final query = companyRef
            .collection('timeline')
            .where('timelineCategoryId', isEqualTo: categoryRef)
            .orderBy('createdAt', descending: true);

        String? dayLabel(QueryDocumentSnapshot<Map<String, dynamic>> d) {
          final ts = d.data()['createdAt'] as Timestamp?;
          if (ts == null) return null;
          return DateFormat('yMMMd').format(ts.toDate());
        }

        final list = StandardViewGroup.paginated(
          query: query,
          sectionHeaderBuilder: (ctx, doc, prev, _) {
            final label = dayLabel(doc);
            if (label == null) return null;
            if (prev != null && dayLabel(prev) == label) return null;
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
            );
          },
          itemBuilder: (ctx, doc, _) {
            final data = doc.data();
            final name = data['name'] ?? '';
            return StandardTileSmallDart.iconText(
              leadingicon: Icons.receipt_long_outlined,
              text: name,
            );
          },
        );

        return Column(
          children: [
            Expanded(child: list),
            if (showSearch)
              SearchControlStrip(
                controller: _searchCtl,
                hintText: 'Search…',
                onChanged: (t) => setState(() => _search = t.trim()),
              ),
          ],
        );
      },
    );
  }
}


