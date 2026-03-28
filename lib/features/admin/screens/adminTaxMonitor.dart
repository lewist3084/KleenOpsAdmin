// lib/features/admin/screens/adminTaxMonitor.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';

import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';

class AdminTaxMonitorScreen extends StatelessWidget {
  const AdminTaxMonitorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: StandardCanvas(
        child: SafeArea(
          top: true,
          bottom: false,
          child: Stack(
            children: [
              const Positioned.fill(child: _TaxMonitorContent()),
              const Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: CanvasTopBookend(),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          DetailsAppBar(title: 'Tax Monitor'),
          HomeNavBarAdapter(),
        ],
      ),
    );
  }
}

class _TaxMonitorContent extends StatefulWidget {
  const _TaxMonitorContent();

  @override
  State<_TaxMonitorContent> createState() => _TaxMonitorContentState();
}

class _TaxMonitorContentState extends State<_TaxMonitorContent> {
  bool _scanning = false;
  String _scanStatus = '';

  Future<void> _triggerManualScan() async {
    setState(() {
      _scanning = true;
      _scanStatus = 'Starting scan...';
    });
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('taxMonitorManualScan');
      final result = await callable.call<dynamic>({'all': true});
      final data = result.data as Map<String, dynamic>?;
      final count = data?['scannedCount'] ?? 0;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan complete: $count sources checked')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _applyAlert(String alertId) async {
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('taxMonitorApplyAlert');
      final result =
          await callable.call<dynamic>({'alertId': alertId});
      final data = result.data as Map<String, dynamic>?;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Applied ${data?['applied'] ?? 0} of ${data?['total'] ?? 0} changes',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Apply error: $e')),
        );
      }
    }
  }

  Future<void> _dismissAlert(String alertId) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Dismiss Alert'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Reason (optional)',
              hintText: 'e.g., False positive, already handled',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Dismiss'),
            ),
          ],
        );
      },
    );
    if (reason == null) return;

    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('taxMonitorDismissAlert');
      await callable.call<dynamic>({
        'alertId': alertId,
        'reason': reason,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alert dismissed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dismiss error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset =
        kBottomNavigationBarHeight + 16.0 + MediaQuery.of(context).padding.bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Scan Controls ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _scanning ? null : _triggerManualScan,
                icon: _scanning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.radar_outlined, size: 18),
                label: Text(
                  _scanning ? _scanStatus : 'Run Manual Scan (All Sources)',
                ),
              ),
            ),
          ),

          // ── Monitor Status ──
          const _MonitorStatusSection(),

          // ── Pending Alerts ──
          _PendingAlertsSection(
            onApply: _applyAlert,
            onDismiss: _dismissAlert,
          ),

          // ── Recent Scan Runs ──
          const _RecentRunsSection(),

          // ── Source Health ──
          const _SourceHealthSection(),
        ],
      ),
    );
  }
}

// ─────────────────────── Monitor Status ───────────────────────

class _MonitorStatusSection extends StatelessWidget {
  const _MonitorStatusSection();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: FirebaseFunctions.instance
          .httpsCallable('taxMonitorStatus')
          .call<dynamic>({}),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final data =
            (snapshot.data?.data as Map<String, dynamic>?) ?? {};
        final totalSources = data['totalSources'] ?? 0;
        final pendingAlerts = data['pendingAlerts'] ?? 0;
        final staleCount = data['staleSourceCount'] ?? 0;

        return ContainerActionWidget(
          title: 'Monitor Status',
          actionText: '',
          content: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                _statusRow(
                  'Total Sources',
                  '$totalSources',
                  Icons.source_outlined,
                ),
                _statusRow(
                  'Pending Alerts',
                  '$pendingAlerts',
                  Icons.warning_amber_outlined,
                  color: pendingAlerts > 0 ? Colors.orange : null,
                ),
                _statusRow(
                  'Stale Sources (90+ days)',
                  '$staleCount',
                  Icons.schedule_outlined,
                  color: staleCount > 0 ? Colors.red : null,
                ),
                if (data['lastRun'] != null) ...[
                  const Divider(height: 16),
                  _statusRow(
                    'Last Run',
                    _formatTimestamp(data['lastRun']['completedAt']),
                    Icons.check_circle_outline,
                  ),
                  _statusRow(
                    'Last Run Results',
                    '${data['lastRun']['checkedCount']} checked, '
                        '${data['lastRun']['alertsCreated']} alerts, '
                        '${data['lastRun']['errorCount']} errors',
                    Icons.summarize_outlined,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statusRow(
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? Colors.grey[600]),
          const SizedBox(width: 8),
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: color != null ? FontWeight.w600 : null,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTimestamp(dynamic ts) {
    if (ts == null) return '—';
    if (ts is Timestamp) {
      return DateFormat('MMM d, yyyy h:mm a').format(ts.toDate());
    }
    if (ts is Map && ts['_seconds'] != null) {
      final dt = DateTime.fromMillisecondsSinceEpoch(
        (ts['_seconds'] as int) * 1000,
      );
      return DateFormat('MMM d, yyyy h:mm a').format(dt);
    }
    return ts.toString();
  }
}

// ─────────────────────── Pending Alerts ───────────────────────

class _PendingAlertsSection extends StatelessWidget {
  final Future<void> Function(String alertId) onApply;
  final Future<void> Function(String alertId) onDismiss;

  const _PendingAlertsSection({
    required this.onApply,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('taxChangeAlert')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        return ContainerActionWidget(
          title: 'Pending Alerts (${docs.length})',
          actionText: '',
          content: docs.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green[400], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'No pending tax changes detected',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: docs.map((doc) {
                    return _AlertTile(
                      alertId: doc.id,
                      data: doc.data(),
                      onApply: onApply,
                      onDismiss: onDismiss,
                    );
                  }).toList(),
                ),
        );
      },
    );
  }
}

class _AlertTile extends StatelessWidget {
  final String alertId;
  final Map<String, dynamic> data;
  final Future<void> Function(String) onApply;
  final Future<void> Function(String) onDismiss;

  const _AlertTile({
    required this.alertId,
    required this.data,
    required this.onApply,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final description = (data['description'] ?? '').toString();
    final stateCode = data['stateCode']?.toString();
    final diffs = (data['diffs'] as List<dynamic>?) ?? [];
    final category = (data['category'] ?? '').toString();
    final diffSummary = diffs.map((d) {
      if (d is Map) {
        final field = d['field'] ?? '';
        final type = d['type'] ?? '';
        if (type == 'rate_changed') {
          return '$field: ${d['currentValue']} → ${d['extractedValue']}';
        }
        return '$field ($type)';
      }
      return '';
    }).where((s) => s.isNotEmpty).join(', ');

    final label = stateCode != null ? '$stateCode — $description' : description;

    return Column(
      children: [
        StandardTileSmallDart(
          label: label,
          secondaryText: diffSummary.isNotEmpty
              ? diffSummary
              : '${diffs.length} change(s) detected',
          labelIcon: _iconForCategory(category),
          onTap: () => _showAlertDetails(context),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(56, 0, 16, 8),
          child: Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: () => onApply(alertId),
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Apply'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green[100],
                  foregroundColor: Colors.green[800],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => onDismiss(alertId),
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Dismiss'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAlertDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final diffs = (data['diffs'] as List<dynamic>?) ?? [];
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                controller: scrollController,
                children: [
                  Text(
                    data['description']?.toString() ?? 'Tax Change Alert',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  if (data['stateCode'] != null)
                    _detailRow('State', data['stateCode'].toString()),
                  _detailRow('Category', data['category']?.toString() ?? ''),
                  _detailRow('Source', data['sourceUrl']?.toString() ?? ''),
                  const Divider(height: 24),
                  Text(
                    'Changes Detected (${diffs.length})',
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ...diffs.map((d) {
                    if (d is! Map) return const SizedBox.shrink();
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${d['field'] ?? 'Unknown field'}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Current: ${_formatValue(d['currentValue'])}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              'New: ${_formatValue(d['extractedValue'])}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.green[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            onApply(alertId);
                          },
                          icon: const Icon(Icons.check),
                          label: const Text('Apply Changes'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            onDismiss(alertId);
                          },
                          icon: const Icon(Icons.close),
                          label: const Text('Dismiss'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  String _formatValue(dynamic value) {
    if (value == null) return '—';
    if (value is List) {
      return value.map((e) => e.toString()).join(', ');
    }
    if (value is Map) {
      return value.entries.map((e) => '${e.key}: ${e.value}').join(', ');
    }
    return value.toString();
  }

  IconData _iconForCategory(String category) {
    if (category.startsWith('federal')) return Icons.account_balance;
    if (category.startsWith('state')) return Icons.location_on_outlined;
    if (category.startsWith('local')) return Icons.location_city_outlined;
    if (category == 'sui') return Icons.people_outline;
    return Icons.receipt_long_outlined;
  }
}

// ─────────────────────── Recent Runs ───────────────────────

class _RecentRunsSection extends StatelessWidget {
  const _RecentRunsSection();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('taxMonitorRun')
          .orderBy('completedAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        return ContainerActionWidget(
          title: 'Recent Scan Runs',
          actionText: '',
          content: docs.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No scan runs yet. Run a manual scan or wait for the weekly schedule.',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                )
              : Column(
                  children: docs.map((doc) {
                    final data = doc.data();
                    final checked = data['checkedCount'] ?? 0;
                    final alerts = data['alertsCreated'] ?? 0;
                    final errors = data['errorCount'] ?? 0;
                    final total = data['totalSources'] ?? 0;
                    final completedAt = data['completedAt'] as Timestamp?;

                    final dateStr = completedAt != null
                        ? DateFormat('MMM d, h:mm a')
                            .format(completedAt.toDate())
                        : '—';

                    return StandardTileSmallDart(
                      label: dateStr,
                      secondaryText:
                          '$checked/$total checked · $alerts alerts · $errors errors',
                      labelIcon: errors > 0
                          ? Icons.error_outline
                          : alerts > 0
                              ? Icons.warning_amber_outlined
                              : Icons.check_circle_outline,
                    );
                  }).toList(),
                ),
        );
      },
    );
  }
}

// ─────────────────────── Source Health ───────────────────────

class _SourceHealthSection extends StatelessWidget {
  const _SourceHealthSection();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('taxSource')
          .orderBy('lastCheckedAt', descending: false)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        return ContainerActionWidget(
          title: 'Source Health',
          actionText: '',
          content: docs.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No tax sources seeded yet. Seed compliance data first.',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                )
              : Column(
                  children: docs.map((doc) {
                    final data = doc.data();
                    final description =
                        (data['description'] ?? doc.id).toString();
                    final status =
                        (data['lastCheckStatus'] ?? 'never_checked').toString();
                    final lastChecked = data['lastCheckedAt'] as Timestamp?;
                    final error = data['lastCheckError']?.toString();

                    final dateStr = lastChecked != null
                        ? DateFormat('MMM d').format(lastChecked.toDate())
                        : 'never';

                    final statusIcon = _statusIcon(status);
                    final statusColor = _statusColor(status);

                    return StandardTileSmallDart(
                      label: description,
                      secondaryText: error != null
                          ? '$dateStr · $status · $error'
                          : '$dateStr · $status',
                      labelIcon: statusIcon,
                      labelIconColor: statusColor,
                    );
                  }).toList(),
                ),
        );
      },
    );
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'no_changes':
        return Icons.check_circle_outline;
      case 'changes_detected':
        return Icons.warning_amber_outlined;
      case 'fetch_failed':
      case 'error':
        return Icons.error_outline;
      default:
        return Icons.schedule_outlined;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'no_changes':
        return Colors.green;
      case 'changes_detected':
        return Colors.orange;
      case 'fetch_failed':
      case 'error':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
