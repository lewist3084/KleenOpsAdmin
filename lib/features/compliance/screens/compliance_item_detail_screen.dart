// lib/features/compliance/screens/compliance_item_detail_screen.dart
//
// Port reads/writes the top-level `complianceItem` collection (admin uses
// top-level Firestore docs — no per-company subcollection).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/theme/app_palette.dart';

class ComplianceItemDetailScreen extends ConsumerWidget {
  final String docId;

  factory ComplianceItemDetailScreen.fromExtra(Map<String, dynamic>? extra) {
    return ComplianceItemDetailScreen(
      docId: (extra?['docId'] ?? '').toString(),
    );
  }

  const ComplianceItemDetailScreen({super.key, required this.docId});

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
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: null,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          DetailsAppBar(title: 'Compliance Item'),
          HomeNavBarAdapter(highlightSelected: false),
        ],
      ),
      body: _wrapCanvas(_ItemDetailBody(docId: docId)),
    );
  }
}

class _ItemDetailBody extends StatelessWidget {
  final String docId;

  const _ItemDetailBody({required this.docId});

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteScope.of(context);
    const bottomInset = 16.0;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('complianceItem')
          .doc(docId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data?.data();
        if (data == null) {
          return const Center(child: Text('Item not found'));
        }

        final title = (data['title'] ?? '').toString();
        final description = (data['description'] ?? '').toString();
        final category = (data['category'] ?? '').toString();
        final stateCode = (data['stateCode'] ?? '').toString();
        final status = (data['status'] ?? 'pending').toString();
        final externalUrl = data['externalUrl']?.toString();
        final recurring = data['recurring'] == true;
        final recurrence = data['recurrenceRule'] as Map<String, dynamic>?;
        final completedAt = data['completedAt'];
        final notes = (data['notes'] ?? '').toString();

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, bottomInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _statusBadge(status),
                  const SizedBox(width: 8),
                  _categoryBadge(context, category, stateCode),
                  if (recurring) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.purple[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.purple[200]!),
                      ),
                      child: Text(
                        'Recurring',
                        style: TextStyle(
                            fontSize: 11, color: Colors.purple[800]),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (description.isNotEmpty)
                Text(
                  description,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              if (externalUrl != null && externalUrl.isNotEmpty) ...[
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final uri = Uri.tryParse(externalUrl);
                    if (uri != null && await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: palette.primary2.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: palette.primary2.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.open_in_new,
                            size: 18, color: palette.primary2),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Open Resource',
                            style: TextStyle(
                              fontSize: 14,
                              color: palette.primary2,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios,
                            size: 14, color: palette.primary2),
                      ],
                    ),
                  ),
                ),
              ],
              if (recurring && recurrence != null) ...[
                const SizedBox(height: 16),
                _detailSection('Schedule', [
                  _detailRow(Icons.repeat, 'Frequency',
                      _capitalize(recurrence['frequency']?.toString() ?? '')),
                  if (recurrence['months'] is List)
                    _detailRow(Icons.calendar_month, 'Months',
                        (recurrence['months'] as List).join(', ')),
                  if (recurrence['dayDue'] != null)
                    _detailRow(Icons.event, 'Due Day',
                        'Day ${recurrence['dayDue']}'),
                ]),
              ],
              if (completedAt is Timestamp) ...[
                const SizedBox(height: 16),
                _detailSection('Completion', [
                  _detailRow(
                    Icons.check_circle_outline,
                    'Completed',
                    DateFormat('yMMMd').format(completedAt.toDate()),
                  ),
                ]),
              ],
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 16),
                _detailSection('Notes', [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child:
                        Text(notes, style: const TextStyle(fontSize: 14)),
                  ),
                ]),
              ],
              const SizedBox(height: 24),
              if (status != 'complete')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _markComplete(context),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Mark as Complete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.primary4,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              if (status == 'complete')
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _markPending(context),
                    icon: const Icon(Icons.undo),
                    label: const Text('Reopen'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _markComplete(BuildContext context) async {
    try {
      await FirebaseFirestore.instance
          .collection('complianceItem')
          .doc(docId)
          .update({
        'status': 'complete',
        'completedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (context.mounted) {
        SnackbarService.instance.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 5),
            content: Text('Error: $e'),
          ),
        );
      }
    }
  }

  Future<void> _markPending(BuildContext context) async {
    try {
      await FirebaseFirestore.instance
          .collection('complianceItem')
          .doc(docId)
          .update({
        'status': 'pending',
        'completedAt': FieldValue.delete(),
      });
    } catch (e) {
      if (context.mounted) {
        SnackbarService.instance.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 5),
            content: Text('Error: $e'),
          ),
        );
      }
    }
  }

  Widget _statusBadge(String status) {
    Color bg;
    Color fg;
    String label;
    switch (status) {
      case 'complete':
        bg = Colors.green[50]!;
        fg = Colors.green[800]!;
        label = 'Complete';
      case 'overdue':
        bg = Colors.red[50]!;
        fg = Colors.red[800]!;
        label = 'Overdue';
      case 'notApplicable':
        bg = Colors.grey[100]!;
        fg = Colors.grey[600]!;
        label = 'N/A';
      default:
        bg = Colors.orange[50]!;
        fg = Colors.orange[800]!;
        label = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withAlpha(80)),
      ),
      child: Text(label,
          style:
              TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
    );
  }

  Widget _categoryBadge(
      BuildContext context, String category, String stateCode) {
    final palette = AppPaletteScope.of(context);
    String label;
    switch (category) {
      case 'federal':
        label = 'Federal';
      case 'state':
        label = stateCode.isNotEmpty ? 'State ($stateCode)' : 'State';
      case 'insurance':
        label = 'Insurance';
      default:
        label = category;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: palette.primary2.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.primary2.withValues(alpha: 0.5)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: palette.primary2)),
    );
  }

  Widget _detailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 10),
          SizedBox(
            width: 100,
            child: Text(label,
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
