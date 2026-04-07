import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:shared_widgets/search/search_field_action.dart';
import 'package:shared_widgets/lists/standardViewGroup.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/features/sales/forms/sales_customer_form.dart';
import 'package:kleenops_admin/features/sales/tabs/customer_tabs.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';

/// Top-level screen with its own Scaffold (app bar + content + bottom nav)
class SalesSalesScreen extends StatelessWidget {
  const SalesSalesScreen({super.key});

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

    Widget buildBottomBar({VoidCallback? onAiPressed}) {
      if (hideChrome) return const SizedBox.shrink();
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: 'Sales',
            onAiPressed: onAiPressed,
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
          const SalesSalesContent(),
        ),
      bottomNavigationBar: hideChrome
          ? null
          : buildBottomBar(),
    );
  }
}

class SalesSalesContent extends ConsumerStatefulWidget {
  const SalesSalesContent({super.key});

  @override
  ConsumerState<SalesSalesContent> createState() => _SalesSalesContentState();
}

class _SalesSalesContentState extends ConsumerState<SalesSalesContent> {
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

        final query = FirebaseFirestore.instance.collection('customer').orderBy('name');

        final list = StandardViewGroup(
          queryStream: query.snapshots(),
          groupBy: (_) => '',
          onTap: (doc) {
            Navigator.of(context).push(
              MaterialPageRoute(
                settings: RouteSettings(
                  name: '/sales/customer/${doc.id}',
                ),
                builder: (_) => SalesCustomerTabsScreen(
                  customerRef: doc.reference,
                ),
              ),
            );
          },
          itemBuilder: (doc) {
            final data = doc.data();
            final name = data['name'] ?? '';
            return StandardTileSmallDart.iconText(
              leadingicon: Icons.person_outline,
              text: name,
            );
          },
        );

        return Stack(
          children: [
            Column(
              children: [
                SearchFieldAction(
                  controller: _searchCtl,
                  labelText: 'Search Customers',
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
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SalesCustomerForm(companyRef: companyRef),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
