// ledger_tabs.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/features/finances/screens/finance_ledger.dart';
import 'package:kleenops_admin/features/finances/screens/finance_profit_loss.dart';
import 'package:kleenops_admin/features/finances/screens/finance_balance_sheet.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:shared_widgets/tabs/lazy_tab_view.dart';
import 'package:shared_widgets/tabs/standard_tab.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kleenops_admin/services/firebase_ai/gemini_translation_service.dart';

/// Top-level screen with its own Scaffold (app bar + content + bottom nav)
class FinanceLedgerTabsScreen extends StatefulWidget {
  const FinanceLedgerTabsScreen({super.key});

  @override
  State<FinanceLedgerTabsScreen> createState() =>
      _FinanceLedgerTabsScreenState();
}

class _FinanceLedgerTabsScreenState extends State<FinanceLedgerTabsScreen> {
  bool _searchVisible = false;
  void _toggleSearch() => setState(() => _searchVisible = !_searchVisible);

  /// Backfills `nameLocalized` (all supported languages) on every account +
  /// section that doesn't have it yet, so the P&L / Balance Sheet / Ledger
  /// render localized. New accounts created by the AI Bookkeeper are translated
  /// at creation; this covers the existing/standard chart.
  Future<void> _localizeChart() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(
      duration: Duration(minutes: 2),
      content: Text('Translating accounts into all languages…'),
    ));
    try {
      final db = FirebaseFirestore.instance;
      const cols = [
        'account',
        'companyProfitLossSection',
        'companyBalanceSheetSection',
      ];
      final docRefs = <DocumentReference<Map<String, dynamic>>, String>{};
      final names = <String>{};
      for (final c in cols) {
        final snap = await db.collection(c).get();
        for (final d in snap.docs) {
          final data = d.data();
          final name = (data['name'] ?? '').toString();
          if (name.isEmpty) continue;
          final existing = data['nameLocalized'];
          if (existing is Map && existing.length > 1) continue; // done already
          docRefs[d.reference] = name;
          names.add(name);
        }
      }
      if (names.isEmpty) {
        if (!mounted) return;
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(const SnackBar(
          duration: Duration(seconds: 4),
          content: Text('Accounts are already localized.'),
        ));
        return;
      }
      final translations =
          await GeminiTranslationService().translateNames(names.toList());
      var count = 0;
      for (final entry in docRefs.entries) {
        final t = translations[entry.value];
        if (t == null) continue;
        await entry.key.set({'nameLocalized': t}, SetOptions(merge: true));
        count++;
      }
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        duration: const Duration(seconds: 5),
        backgroundColor: Colors.green,
        content: Text('Localized $count account(s)/section(s) into '
            '${kAccountLocales.length + 1} languages.'),
      ));
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        duration: const Duration(seconds: 6),
        content: Text('Localization failed: $e'),
      ));
    }
  }

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
            title: 'Ledger',
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
          FinanceLedgerTabs(searchVisible: _searchVisible),
      ),
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final menuSections = MenuDrawerSections(
            resources: [
              ContentMenuItem(
                icon: Icons.account_balance_outlined,
                label: 'Accounts',
                onTap: () => context.push(AppRoutePaths.financeAccounts),
              ),
              ContentMenuItem(
                icon: Icons.translate_outlined,
                label: 'Localize Accounts',
                onTap: () => _localizeChart(),
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

class FinanceLedgerTabs extends ConsumerStatefulWidget {
  const FinanceLedgerTabs({super.key, this.searchVisible = false});

  final bool searchVisible;

  @override
  _FinanceLedgerTabsState createState() => _FinanceLedgerTabsState();
}

class _FinanceLedgerTabsState extends ConsumerState<FinanceLedgerTabs>
    with SingleTickerProviderStateMixin {
  late TabController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hideChrome = false;
    final bottomInset =
        (hideChrome ? 16.0 : kBottomNavigationBarHeight + 16.0) +
            MediaQuery.of(context).padding.bottom;

    return Column(
      children: [
        Container(
          color: Colors.white,
          child: StandardTabBar(
            controller: _ctrl,
            isScrollable: true,
            dividerColor: Colors.grey[300],
            indicatorWeight: 3.0,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey[600],
            tabs: const [
              Tab(text: 'Ledger'),
              Tab(text: 'Profit and Loss'),
              Tab(text: 'Balance Sheet'),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: LazyTabView(
              physics: const NeverScrollableScrollPhysics(),
              controller: _ctrl,
              children: [
                FinanceLedgerContent(searchVisible: widget.searchVisible),
                FinanceProfitLossContent(searchVisible: widget.searchVisible),
                FinanceBalanceSheetContent(
                    searchVisible: widget.searchVisible),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
