import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
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

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            32,
            20,
            kBottomNavigationBarHeight +
                32.0 +
                MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ProgressHeader(progress: overallProgress),
              const SizedBox(height: 28),
              for (final cat in kSetupWizardCategories) ...[
                _CategorySection(
                  category: cat,
                  itemsData: items,
                  service: service,
                ),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 12),
              _BottomActions(service: service),
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

  const _ProgressHeader({required this.progress});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    final isDone = progress >= 1.0;
    final accent = isDone ? Colors.green : color;

    return Column(
      children: [
        // Circular icon (matches the registration ForkCard motif:
        // large tinted circle with a centered glyph).
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isDone ? Icons.check_circle_outline : Icons.rocket_launch_outlined,
            size: 56,
            color: accent,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          isDone ? 'All Set!' : 'Business Setup Wizard',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: accent,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── Category section ───────────────────────────────────────────────────────

class _CategorySection extends StatefulWidget {
  final WizardCategory category;
  final Map<String, dynamic> itemsData;
  final SetupWizardService service;

  const _CategorySection({
    required this.category,
    required this.itemsData,
    required this.service,
  });

  @override
  State<_CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends State<_CategorySection> {
  bool _expanded = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    // Resolve the selected entity type from wizard data (if completed).
    final entityData =
        (widget.itemsData['entity_type'] as Map<String, dynamic>?) ?? {};
    final entityTypeRaw =
        ((entityData['data'] as Map<String, dynamic>?)?['entityType']
                as String?) ??
            (entityData['notes'] as String?);
    final entityType = entityTypeRaw?.toLowerCase().trim();

    // Filter items based on entity type requirement.
    final visibleItems = widget.category.items.where((item) {
      if (item.requiredEntityTypes == null) return true;
      if (entityType == null) return false; // hide until entity type chosen
      return item.requiredEntityTypes!.contains(entityType);
    }).toList();

    if (visibleItems.isEmpty) {
      return const SizedBox.shrink();
    }

    final color = Theme.of(context).primaryColor;
    final completedCount = visibleItems.where((item) {
      final data =
          (widget.itemsData[item.key] as Map<String, dynamic>?) ?? {};
      final s = parseWizardStatus(data['status'] as String?);
      return s == WizardItemStatus.complete || s == WizardItemStatus.skipped;
    }).length;
    final hasAnyProgress = visibleItems.any((item) {
      final data =
          (widget.itemsData[item.key] as Map<String, dynamic>?) ?? {};
      final s = parseWizardStatus(data['status'] as String?);
      return s != WizardItemStatus.notStarted;
    });
    final total = visibleItems.length;
    final isComplete = total > 0 && completedCount >= total;
    final percent = total > 0 ? ((completedCount / total) * 100).round() : 0;
    final accent = isComplete ? Colors.green : color;

    return Material(
      color: Colors.white,
      elevation: 1,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accent.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tappable header — toggles expansion.
            InkWell(
              onTap: _toggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(widget.category.icon,
                          size: 26, color: accent),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.category.label,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isComplete
                                ? 'Complete'
                                : '$completedCount of $total complete',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _CategoryChip(
                      isComplete: isComplete,
                      hasAnyProgress: hasAnyProgress,
                      percent: percent,
                      expanded: _expanded,
                    ),
                  ],
                ),
              ),
            ),
            // Expanded item list.
            if (_expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Divider(height: 1),
                    const SizedBox(height: 4),
                    for (final item in visibleItems)
                      _WizardTile(
                        item: item,
                        itemData:
                            (widget.itemsData[item.key] as Map<String, dynamic>?) ??
                                {},
                        service: widget.service,
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Category chip (Start / percent / done) ─────────────────────────────────

class _CategoryChip extends StatelessWidget {
  final bool isComplete;
  final bool hasAnyProgress;
  final int percent;
  final bool expanded;

  const _CategoryChip({
    required this.isComplete,
    required this.hasAnyProgress,
    required this.percent,
    required this.expanded,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;

    if (isComplete) {
      return Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: Colors.green,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, size: 18, color: Colors.white),
      );
    }

    final String label;
    final Color bg;
    final Color fg;
    if (hasAnyProgress) {
      label = '$percent%';
      bg = Colors.amber.shade100;
      fg = Colors.amber.shade900;
    } else if (expanded) {
      label = '0%';
      bg = color.withValues(alpha: 0.1);
      fg = color;
    } else {
      label = 'Start';
      bg = color.withValues(alpha: 0.1);
      fg = color;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            expanded ? Icons.expand_less : Icons.expand_more,
            size: 16,
            color: fg,
          ),
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
    final color = Theme.of(context).primaryColor;
    final status = parseWizardStatus(itemData['status'] as String?);
    final isComplete = status == WizardItemStatus.complete;
    final tileColor = isComplete ? Colors.green : color;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _onTileTap(context, status),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tileColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.icon, size: 22, color: tileColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (item.aiAssistAvailable)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Icon(
                            Icons.auto_awesome,
                            size: 14,
                            color: Colors.amber[700],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _StatusButton(
              status: status,
              onTap: () => _onTileTap(context, status),
            ),
          ],
        ),
      ),
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
  final WizardItemStatus status;
  final VoidCallback onTap;

  const _StatusButton({
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;

    if (status == WizardItemStatus.complete) {
      return Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: Colors.green,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, size: 18, color: Colors.white),
      );
    }

    final label = wizardStatusLabel(status);
    final isContinue = status == WizardItemStatus.inProgress;
    final bg = isContinue
        ? Colors.amber.shade100
        : color.withValues(alpha: 0.1);
    final fg = isContinue ? Colors.amber.shade900 : color;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Bottom actions ─────────────────────────────────────────────────────────

class _BottomActions extends StatelessWidget {
  final SetupWizardService service;
  const _BottomActions({required this.service});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: Text(
            'Skip for now',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
        TextButton(
          onPressed: () => _confirmDismiss(context),
          child: Text(
            'Don\'t show again',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDismiss(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hide setup wizard?'),
        content: const Text(
          'You can still find this wizard later in the side menu under '
          '"Business Setup Wizard".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hide'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await service.dismiss();
      if (context.mounted) Navigator.of(context).maybePop();
    }
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
