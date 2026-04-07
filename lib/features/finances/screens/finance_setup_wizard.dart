import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/features/admin/models/setup_wizard_data.dart';
import 'package:kleenops_admin/features/finances/models/finance_setup_wizard_data.dart';
import 'package:kleenops_admin/features/finances/services/finance_setup_wizard_service.dart';
import 'package:kleenops_admin/features/finances/services/plaid_service.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';

class FinanceSetupWizardScreen extends ConsumerStatefulWidget {
  const FinanceSetupWizardScreen({super.key});

  @override
  ConsumerState<FinanceSetupWizardScreen> createState() =>
      _FinanceSetupWizardScreenState();
}

class _FinanceSetupWizardScreenState
    extends ConsumerState<FinanceSetupWizardScreen> {
  FinanceSetupWizardService? _service;
  PlaidService? _plaidService;
  bool _initialized = false;

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

  Future<void> _initService(
      DocumentReference<Map<String, dynamic>> companyRef) async {
    if (_service != null) return;
    _service = FinanceSetupWizardService(companyRef: companyRef);
    _plaidService = PlaidService(companyRef: companyRef);
    await _service!.initializeIfNeeded();
    if (mounted) setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
    final companyAsync = ref.watch(companyIdProvider);

    Widget buildBottomBar({
      VoidCallback? onAiPressed,
      MenuDrawerSections? menuSections,
    }) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: 'Finance Setup',
            onAiPressed: onAiPressed,
            menuSections: menuSections,
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
          companyAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (companyRef) {
              if (companyRef == null) {
                return const Center(child: Text('No company found'));
              }
              _initService(companyRef);
              if (!_initialized || _service == null) {
                return const Center(child: CircularProgressIndicator());
              }
              return _FinanceWizardBody(
                service: _service!,
                plaidService: _plaidService!,
                companyRef: companyRef,
              );
            },
          ),
        ),
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final menuSections = MenuDrawerSections(
            actions: [
              ContentMenuItem(
                icon: Icons.account_balance_outlined,
                label: 'Banking',
                onTap: () => context.push(AppRoutePaths.financeBanking),
              ),
              ContentMenuItem(
                icon: Icons.receipt_long_outlined,
                label: 'Invoices',
                onTap: () => context.push(AppRoutePaths.financeInvoices),
              ),
              ContentMenuItem(
                icon: Icons.list_alt_outlined,
                label: 'Ledger',
                onTap: () => context.push(AppRoutePaths.financeLedger),
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

class _FinanceWizardBody extends StatelessWidget {
  final FinanceSetupWizardService service;
  final PlaidService plaidService;
  final DocumentReference<Map<String, dynamic>> companyRef;

  const _FinanceWizardBody({
    required this.service,
    required this.plaidService,
    required this.companyRef,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: service.watchProgress(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final wizardData = snapshot.data?.data() ?? {};
        final items =
            (wizardData['items'] as Map<String, dynamic>?) ?? {};
        final overallProgress =
            (wizardData['overallProgress'] as num?)?.toDouble() ?? 0.0;

        final totalItems = kFinanceSetupTotalItems;
        final doneCount = items.values
            .where((v) {
              final s = (v as Map<String, dynamic>)['status'];
              return s == 'complete' || s == 'skipped';
            })
            .length;

        return SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: kBottomNavigationBarHeight +
                16.0 +
                MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ProgressHeader(
                progress: overallProgress,
                doneCount: doneCount,
                totalCount: totalItems,
              ),
              for (final cat in kFinanceSetupCategories)
                _CategorySection(
                  category: cat,
                  itemsData: items,
                  service: service,
                  plaidService: plaidService,
                  companyRef: companyRef,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  final double progress;
  final int doneCount;
  final int totalCount;

  const _ProgressHeader({
    required this.progress,
    required this.doneCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).round();
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 6,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress >= 1.0
                        ? Colors.green
                        : Theme.of(context).primaryColor,
                  ),
                ),
                Center(
                  child: Text(
                    '$percent%',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  progress >= 1.0
                      ? 'Finance Setup Complete!'
                      : 'Setting Up Your Finances',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '$doneCount of $totalCount steps completed',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final WizardCategory category;
  final Map<String, dynamic> itemsData;
  final FinanceSetupWizardService service;
  final PlaidService plaidService;
  final DocumentReference<Map<String, dynamic>> companyRef;

  const _CategorySection({
    required this.category,
    required this.itemsData,
    required this.service,
    required this.plaidService,
    required this.companyRef,
  });

  @override
  Widget build(BuildContext context) {
    return ContainerActionWidget(
      title: category.label,
      actionText: '',
      content: Column(
        children: [
          for (final item in category.items) ...[
            _WizardTile(
              item: item,
              itemData:
                  (itemsData[item.key] as Map<String, dynamic>?) ?? {},
              service: service,
              plaidService: plaidService,
              companyRef: companyRef,
            ),
            if (item != category.items.last)
              Divider(height: 1, color: Colors.grey[200]),
          ],
        ],
      ),
    );
  }
}

class _WizardTile extends StatelessWidget {
  final WizardItem item;
  final Map<String, dynamic> itemData;
  final FinanceSetupWizardService service;
  final PlaidService plaidService;
  final DocumentReference<Map<String, dynamic>> companyRef;

  const _WizardTile({
    required this.item,
    required this.itemData,
    required this.service,
    required this.plaidService,
    required this.companyRef,
  });

  @override
  Widget build(BuildContext context) {
    final status = parseWizardStatus(itemData['status'] as String?);
    final statusLabel = wizardStatusLabel(status);
    final statusColor = wizardStatusColor(status);

    return StandardTileSmallDart(
      label: item.label,
      secondaryText: item.description,
      leadingIcon: item.icon,
      leadingIconColor: status == WizardItemStatus.complete
          ? Colors.green
          : Theme.of(context).primaryColor,
      trailingIcon1:
          status == WizardItemStatus.complete ? Icons.check_circle : null,
      onTap: () => _onTileTap(context, status),
      trailingWidget: status != WizardItemStatus.complete
          ? _StatusButton(
              label: statusLabel,
              color: statusColor,
              aiAvailable: item.aiAssistAvailable,
              onTap: () => _onTileTap(context, status),
            )
          : null,
    );
  }

  void _onTileTap(BuildContext context, WizardItemStatus status) {
    // Special handling: "Link Your Bank Account" launches Plaid directly.
    if (item.key == 'link_bank_plaid') {
      _launchPlaidLink(context);
      return;
    }

    if (status == WizardItemStatus.notStarted) {
      service.updateItemStatus(item.key, WizardItemStatus.inProgress);
    }

    showDialog(
      context: context,
      builder: (ctx) => _StepDialog(
        item: item,
        itemData: itemData,
        service: service,
      ),
    );
  }

  Future<void> _launchPlaidLink(BuildContext context) async {
    service.updateItemStatus(item.key, WizardItemStatus.inProgress);

    try {
      await plaidService.openPlaidLink();
      // If we get here, Plaid Link succeeded.
      service.completeItem(item.key, data: {'connectedViaPlaid': true});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bank account linked successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bank linking failed: $e')),
        );
      }
    }
  }
}

class _StatusButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool aiAvailable;
  final VoidCallback onTap;

  const _StatusButton({
    required this.label,
    required this.color,
    required this.aiAvailable,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (aiAvailable)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child:
                Icon(Icons.auto_awesome, size: 14, color: Colors.amber[700]),
          ),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              label,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

class _StepDialog extends StatefulWidget {
  final WizardItem item;
  final Map<String, dynamic> itemData;
  final FinanceSetupWizardService service;

  const _StepDialog({
    required this.item,
    required this.itemData,
    required this.service,
  });

  @override
  State<_StepDialog> createState() => _StepDialogState();
}

class _StepDialogState extends State<_StepDialog> {
  late final TextEditingController _notesCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _notesCtrl =
        TextEditingController(text: (widget.itemData['notes'] ?? '').toString());
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(widget.item.icon, color: Theme.of(context).primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(widget.item.label,
                style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.item.description,
                style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            if (widget.item.aiAssistAvailable) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome,
                        size: 18, color: Colors.amber[700]),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('AI assistant available for this step.',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Add any details or progress notes...',
                border: OutlineInputBorder(),
              ),
              minLines: 2,
              maxLines: 5,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.service.skipItem(widget.item.key);
            Navigator.pop(context);
          },
          child: const Text('Skip'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving
              ? null
              : () async {
                  setState(() => _saving = true);
                  await widget.service.completeItem(widget.item.key,
                      data: {'notes': _notesCtrl.text.trim()});
                  if (context.mounted) Navigator.pop(context);
                },
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Mark Complete'),
        ),
      ],
    );
  }
}
