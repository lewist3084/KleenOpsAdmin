//  marketing_campaign.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/search/search_control_strip_adapter.dart';
import 'package:shared_widgets/lists/standardViewGroup.dart';
import 'package:shared_widgets/tiles/standard_tile_large.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:shared_widgets/services/firestore_service.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import '../details/marketing_campaign_details.dart';

/// Top-level screen with its own Scaffold (app bar + content + bottom nav)
class MarketingCampaignScreen extends StatefulWidget {
  const MarketingCampaignScreen({super.key});

  @override
  State<MarketingCampaignScreen> createState() =>
      _MarketingCampaignScreenState();
}

class _MarketingCampaignScreenState extends State<MarketingCampaignScreen> {
  bool _searchVisible = false;

  void _toggleSearch() => setState(() => _searchVisible = !_searchVisible);

  Widget _wrapCanvas(Widget child) {
    return StandardCanvas(
      child: SafeArea(
        top: true,
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(child: child),
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: CanvasTopBookend(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hideChrome = false;

    Widget buildBottomBar({
      VoidCallback? onAiPressed,
      MenuDrawerSections? menuSections,
    }) {
      if (hideChrome) return const SizedBox.shrink();
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: 'Marketing Campaigns',
            onAiPressed: onAiPressed,
            menuSections: menuSections,
            onSearchToggle: _toggleSearch,
            searchActive: _searchVisible,
          ),
          const HomeNavBarAdapter(),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: null,
      drawer: const UserDrawer(),
      body: _wrapCanvas(
          MarketingCampaignContent(searchVisible: _searchVisible),
        ),
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final menuSections = MenuDrawerSections(
            actions: [
              ContentMenuItem(
                icon: Icons.home_outlined,
                label: 'Sales Home',
                onTap: () => context.push(AppRoutePaths.salesHome),
              ),
              ContentMenuItem(
                icon: Icons.sell_outlined,
                label: 'Sales',
                onTap: () => context.push(AppRoutePaths.salesSales),
              ),
              ContentMenuItem(
                icon: Icons.bar_chart_outlined,
                label: 'Stats',
                onTap: () => context.push(AppRoutePaths.salesStats),
              ),
            ],
          );
          return buildBottomBar(
            menuSections: menuSections,
          );
        },
      ),
    );
  }
}

class MarketingCampaignContent extends ConsumerStatefulWidget {
  const MarketingCampaignContent({super.key, this.searchVisible = false});

  final bool searchVisible;

  @override
  ConsumerState<MarketingCampaignContent> createState() =>
      _SalesMarketingContentState();
}

class _SalesMarketingContentState
    extends ConsumerState<MarketingCampaignContent> {
  final _searchCtl = TextEditingController();
  String _search = '';
  static final FirestoreService _fs = FirestoreService();

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _showAddCampaignDialog({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required DocumentReference<Map<String, dynamic>>? memberRef,
    required DocumentReference<Map<String, dynamic>>? teamRef,
  }) async {
    final nameCtl = TextEditingController();
    final descCtl = TextEditingController();
    final launchCtl = TextEditingController();
    final termCtl = TextEditingController();
    DateTime? launchDate;
    DateTime? termDate;
    final dateFmt = DateFormat('yyyy-MM-dd hh:mm a');

    await showDialog(
      context: context,
      builder: (ctx) => DialogAction(
        title: 'New Campaign',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descCtl,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: launchCtl,
              readOnly: true,
              decoration: const InputDecoration(labelText: 'Launch Date'),
              onTap: () async {
                final pickedDate = await showDatePicker(
                  context: context,
                  initialDate: launchDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (pickedDate == null) return;
                final pickedTime = await showTimePicker(
                  context: context,
                  initialTime:
                      TimeOfDay.fromDateTime(launchDate ?? DateTime.now()),
                );
                if (pickedTime == null) return;
                launchDate = DateTime(
                  pickedDate.year,
                  pickedDate.month,
                  pickedDate.day,
                  pickedTime.hour,
                  pickedTime.minute,
                );
                launchCtl.text = dateFmt.format(launchDate!);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: termCtl,
              readOnly: true,
              decoration: const InputDecoration(labelText: 'Termination Date'),
              onTap: () async {
                final pickedDate = await showDatePicker(
                  context: context,
                  initialDate: termDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (pickedDate == null) return;
                final pickedTime = await showTimePicker(
                  context: context,
                  initialTime:
                      TimeOfDay.fromDateTime(termDate ?? DateTime.now()),
                );
                if (pickedTime == null) return;
                termDate = DateTime(
                  pickedDate.year,
                  pickedDate.month,
                  pickedDate.day,
                  pickedTime.hour,
                  pickedTime.minute,
                );
                termCtl.text = dateFmt.format(termDate!);
              },
            ),
          ],
        ),
        cancelText: 'Cancel',
        actionText: 'Save',
        onCancel: () => Navigator.of(ctx).pop(),
        onAction: () async {
          final name = nameCtl.text.trim();
          final desc = descCtl.text.trim();
          if (name.isEmpty || launchDate == null || termDate == null) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              const SnackBar(content: Text('Please fill all fields.')),
            );
            return;
          }

          await _fs.saveDocument(
            collectionRef: FirebaseFirestore.instance.collection('campaign'),
            data: {
              'name': name,
              'description': desc,
              'launchDate': launchDate,
              'terminationDate': termDate,
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
    launchCtl.dispose();
    termCtl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userDocAsync = ref.watch(userDocumentProvider);
    final bool hideChrome = false;
    final bottomInset =
        (hideChrome ? 16.0 : kBottomNavigationBarHeight + 16.0) +
            MediaQuery.of(context).padding.bottom;

    return userDocAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (userData) {
        final companyRef =
            userData['companyId'] as DocumentReference<Map<String, dynamic>>?;
        final uid = ref.read(authStateChangesProvider).value?.uid;
        if (companyRef == null || uid == null) {
          return const Center(child: Text('No company assigned.'));
        }

        final memberRef =
            userData['memberRef'] as DocumentReference<Map<String, dynamic>>?;
        DocumentReference<Map<String, dynamic>>? teamRef;
        final rawTeam = userData['primaryTeamId'];
        if (rawTeam is DocumentReference<Object?>) {
          teamRef = rawTeam.withConverter<Map<String, dynamic>>(
            fromFirestore: (s, _) => s.data() ?? {},
            toFirestore: (m, _) => m,
          );
        }
        final query = FirebaseFirestore.instance.collection('campaign').orderBy('name');

        final list = StandardViewGroup(
          queryStream: query.snapshots(),
          groupBy: (_) => '',
          onTap: (doc) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MarketingCampaignDetailsScreen(
                  companyRef: companyRef,
                  docId: doc.id,
                ),
              ),
            );
          },
          itemBuilder: (doc) {
            final data = doc.data();
            final name = data['name'] as String? ?? '';
            final desc = data['description'] as String? ?? '';
            return StandardTileLargeDart(
              imageUrl: '',
              firstLine: name,
              secondLine: desc,
              firstLineIcon: Icons.campaign_outlined,
            );
          },
          emptyMessage: 'No campaigns found.',
        );

        return Stack(
          children: [
            Column(
              children: [
                if (widget.searchVisible)
                  SearchControlStrip(
                    controller: _searchCtl,
                    hintText: 'Search Campaigns',
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
                onPressed: () => _showAddCampaignDialog(
                  companyRef: companyRef,
                  memberRef: memberRef,
                  teamRef: teamRef,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
