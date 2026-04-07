import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';
import 'package:go_router/go_router.dart';
import '../models/setup_wizard_data.dart';
import '../services/setup_wizard_service.dart';
import '../widgets/phone_provisioning_dialog.dart';
import '../widgets/email_routing_dialog.dart';
import '../widgets/website_generator_dialog.dart';
import '../widgets/call_routing_dialog.dart';
import '../widgets/registered_agent_dialog.dart';

class AdminSetupWizardScreen extends StatefulWidget {
  const AdminSetupWizardScreen({super.key});

  @override
  State<AdminSetupWizardScreen> createState() => _AdminSetupWizardScreenState();
}

class _AdminSetupWizardScreenState extends State<AdminSetupWizardScreen> {
  final _service = SetupWizardService.instance;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _service.initializeIfNeeded();
    if (mounted) setState(() => _initialized = true);
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
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: null,
      drawer: const UserDrawer(),
      body: _wrapCanvas(
        _initialized
            ? _WizardBody(service: _service)
            : const Center(child: CircularProgressIndicator()),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: 'Business Setup Wizard',
            menuSections: MenuDrawerSections(
              actions: [
                ContentMenuItem(
                  icon: Icons.business,
                  label: 'Company',
                  onTap: () => context.push(AppRoutePaths.adminCompany),
                ),
                ContentMenuItem(
                  icon: Icons.policy_outlined,
                  label: 'Policies',
                  onTap: () => context.push(AppRoutePaths.adminPolicies),
                ),
              ],
            ),
          ),
          const HomeNavBarAdapter(),
        ],
      ),
    );
  }
}

class _WizardBody extends StatelessWidget {
  final SetupWizardService service;
  const _WizardBody({required this.service});

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

        final totalItems = kSetupWizardTotalItems;
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
              // Progress header
              _ProgressHeader(
                progress: overallProgress,
                doneCount: doneCount,
                totalCount: totalItems,
              ),
              // Category sections
              for (final cat in kSetupWizardCategories)
                _CategorySection(
                  category: cat,
                  itemsData: items,
                  service: service,
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Progress header ────────────────────────────────────────────────────────

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
                    progress >= 1.0 ? Colors.green : Theme.of(context).primaryColor,
                  ),
                ),
                Center(
                  child: Text(
                    '$percent%',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
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
                      ? 'All Set!'
                      : 'Getting Your Business Ready',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$doneCount of $totalCount steps completed',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Category section ───────────────────────────────────────────────────────

class _CategorySection extends StatelessWidget {
  final WizardCategory category;
  final Map<String, dynamic> itemsData;
  final SetupWizardService service;

  const _CategorySection({
    required this.category,
    required this.itemsData,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    // Resolve the selected entity type from wizard data (if completed).
    final entityData =
        (itemsData['entity_type'] as Map<String, dynamic>?) ?? {};
    final entityTypeRaw =
        ((entityData['data'] as Map<String, dynamic>?)?['entityType']
                as String?) ??
            (entityData['notes'] as String?);
    final entityType = entityTypeRaw?.toLowerCase().trim();

    // Filter items based on entity type requirement.
    final visibleItems = category.items.where((item) {
      if (item.requiredEntityTypes == null) return true;
      if (entityType == null) return false; // hide until entity type chosen
      return item.requiredEntityTypes!.contains(entityType);
    }).toList();

    if (visibleItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return ContainerActionWidget(
      title: category.label,
      actionText: '',
      content: Column(
        children: [
          for (final item in visibleItems) ...[
            _WizardTile(
              item: item,
              itemData: (itemsData[item.key] as Map<String, dynamic>?) ?? {},
              service: service,
            ),
            if (item != visibleItems.last)
              Divider(height: 1, color: Colors.grey[200]),
          ],
        ],
      ),
    );
  }
}

// ── Wizard tile ────────────────────────────────────────────────────────────

class _WizardTile extends StatelessWidget {
  final WizardItem item;
  final Map<String, dynamic> itemData;
  final SetupWizardService service;

  const _WizardTile({
    required this.item,
    required this.itemData,
    required this.service,
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
      trailingIcon1: status == WizardItemStatus.complete
          ? Icons.check_circle
          : null,
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
    // Mark as in_progress if not started.
    if (status == WizardItemStatus.notStarted) {
      service.updateItemStatus(item.key, WizardItemStatus.inProgress);
    }

    // Route to specialized dialogs for automated steps.
    final Widget dialog;
    switch (item.key) {
      case 'business_phone':
        dialog = PhoneProvisioningDialog(itemData: itemData);
      case 'business_website':
        dialog = WebsiteGeneratorDialog(itemData: itemData);
      case 'business_email':
        dialog = EmailRoutingDialog(itemData: itemData);
      case 'call_routing':
        dialog = const CallRoutingDialog();
      case 'registered_agent':
        dialog = RegisteredAgentDialog(itemData: itemData);
      default:
        dialog = _StepDialog(
          item: item,
          itemData: itemData,
          service: service,
        );
    }

    showDialog(context: context, builder: (_) => dialog);
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
            child: Icon(Icons.auto_awesome, size: 14, color: Colors.amber[700]),
          ),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Step dialog ────────────────────────────────────────────────────────────

class _StepDialog extends StatefulWidget {
  final WizardItem item;
  final Map<String, dynamic> itemData;
  final SetupWizardService service;

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
    final existingNotes =
        (widget.itemData['notes'] ?? '').toString();
    _notesCtrl = TextEditingController(text: existingNotes);
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
            child: Text(
              widget.item.label,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.item.description,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
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
                    Icon(Icons.auto_awesome, size: 18, color: Colors.amber[700]),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'AI assistant available for this step.',
                        style: TextStyle(fontSize: 12),
                      ),
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
                  await widget.service.completeItem(
                    widget.item.key,
                    data: {
                      'notes': _notesCtrl.text.trim(),
                    },
                  );
                  if (context.mounted) Navigator.pop(context);
                },
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Mark Complete'),
        ),
      ],
    );
  }
}
