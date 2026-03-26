// lib/features/finances/details/financePayrollRunDetails.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/features/finances/services/payroll_service.dart';
import 'package:kleenops_admin/features/finances/services/ach_file_service.dart';
import 'package:kleenops_admin/features/finances/services/payroll_distribution_service.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';

class FinancePayrollRunDetailsScreen extends ConsumerWidget {
  final String runId;

  factory FinancePayrollRunDetailsScreen.fromExtra(
      Map<String, dynamic>? extra) {
    return FinancePayrollRunDetailsScreen(
      runId: (extra ?? {})['runId'] as String? ?? '',
    );
  }

  const FinancePayrollRunDetailsScreen({
    super.key,
    required this.runId,
  });

  Widget _wrapCanvas(Widget child) {
    return StandardCanvas(
      child: SafeArea(
        top: true,
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(child: child),
            const Positioned(
              left: 0, right: 0, top: 0,
              child: CanvasTopBookend(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool hideChrome = false;

    Widget buildBottomBar({VoidCallback? onAiPressed}) {
      if (hideChrome) return const SizedBox.shrink();
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: 'Payroll Run',
            onAiPressed: onAiPressed,
          ),
          const HomeNavBarAdapter(highlightSelected: false),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: null,
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          return buildBottomBar();
        },
      ),
      body: _wrapCanvas(
          ref.watch(companyIdProvider).when(
                data: (companyRef) {
                  if (companyRef == null) {
                    return const Center(child: Text('No company'));
                  }
                  return _RunDetailsBody(
                    companyRef: companyRef,
                    runId: runId,
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
      ),
    );
  }
}

class _RunDetailsBody extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final String runId;

  const _RunDetailsBody({required this.companyRef, required this.runId});

  @override
  State<_RunDetailsBody> createState() => _RunDetailsBodyState();
}

class _RunDetailsBodyState extends State<_RunDetailsBody> {
  bool _generatingAch = false;
  bool _emailing = false;

  Future<void> _emailPayStubs() async {
    setState(() => _emailing = true);
    try {
      final service = PayrollDistributionService();
      final sent = await service.distributePayStubs(
        companyRef: widget.companyRef,
        runId: widget.runId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$sent pay stub email(s) sent')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Email error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _emailing = false);
    }
  }

  Future<void> _generateAch() async {
    setState(() => _generatingAch = true);
    try {
      // Load company data for ACH fields
      final companySnap = await widget.companyRef.get();
      final companyData = companySnap.data() ?? {};

      final achService = AchFileService();
      final achContent = await achService.generateAchFile(
        companyRef: widget.companyRef,
        runId: widget.runId,
        companyName: (companyData['name'] ?? 'KleenOps').toString(),
        companyEin: (companyData['ein'] ?? '').toString(),
        originatingBank:
            (companyData['payrollRoutingNumber'] ?? '000000000').toString(),
        bankAccountNumber:
            (companyData['payrollAccountNumber'] ?? '').toString(),
      );

      if (achContent.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('No direct deposit entries to generate')),
          );
        }
        return;
      }

      if (!kIsWeb) {
        final dir = await getApplicationDocumentsDirectory();
        final file = File(
            '${dir.path}/ach_payroll_${widget.runId.substring(0, 8)}.ach');
        await file.writeAsString(achContent);
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'Payroll ACH File',
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ACH file generated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ACH error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingAch = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final runStream =
        FirebaseFirestore.instance.collection('payrollRun').doc(widget.runId).snapshots();
    final stubStream = FirebaseFirestore.instance
        .collection('payrollRun')
        .doc(widget.runId)
        .collection('payStub')
        .orderBy('memberName')
        .snapshots();
    final bottomInset =
        kBottomNavigationBarHeight + 16.0 + MediaQuery.of(context).padding.bottom;
    final fmt = NumberFormat('#,##0.00');

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: runStream,
      builder: (context, runSnap) {
        if (runSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final runData = runSnap.data?.data() ?? {};
        final status = (runData['status'] ?? 'draft').toString();

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Run summary card ──
              _buildSummaryCard(context, runData, fmt),
              const SizedBox(height: 16),

              // ── Action buttons ──
              if (status == 'draft') ...[
                _actionButton(
                  context,
                  'Approve Payroll',
                  Icons.thumb_up_outlined,
                  Colors.blue,
                  () => _approve(context),
                ),
                const SizedBox(height: 8),
              ],
              if (status == 'approved') ...[
                _actionButton(
                  context,
                  'Process Payroll',
                  Icons.play_circle_outline,
                  Colors.green,
                  () => _process(context),
                ),
                const SizedBox(height: 8),
              ],
              if (status == 'processed') ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _generatingAch ? null : _generateAch,
                    icon: _generatingAch
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2),
                          )
                        : const Icon(Icons.account_balance, size: 18),
                    label: Text(_generatingAch
                        ? 'Generating...'
                        : 'Generate ACH File (Direct Deposit)'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _emailing ? null : _emailPayStubs,
                    icon: _emailing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2),
                          )
                        : const Icon(Icons.email_outlined, size: 18),
                    label: Text(_emailing
                        ? 'Sending...'
                        : 'Email Pay Stubs to Employees'),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // ── Pay stubs ──
              Text(
                'Pay Stubs',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: stubStream,
                builder: (context, stubSnap) {
                  if (stubSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final stubs = stubSnap.data?.docs ?? [];
                  if (stubs.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No pay stubs generated yet.',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    );
                  }
                  return Column(
                    children: stubs.map((doc) {
                      final d = doc.data();
                      final name =
                          (d['memberName'] ?? 'Unknown').toString();
                      final gross = d['grossPay'] ?? 0;
                      final net = d['netPay'] ?? 0;
                      final payType =
                          (d['payType'] ?? '').toString();

                      return StandardTileSmallDart(
                        label: name,
                        secondaryText:
                            'Gross: \$${fmt.format(gross)} · Net: \$${fmt.format(net)} · $payType',
                        labelIcon: Icons.person_outline,
                        trailingIcon1: Icons.chevron_right,
                        onTap: () => context.push(
                          AppRoutePaths.financePayStubDetails,
                          extra: {
                            'runId': widget.runId,
                            'memberId': doc.id,
                            'memberName': name,
                          },
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(
      BuildContext context, Map<String, dynamic> data, NumberFormat fmt) {
    final status = (data['status'] ?? 'draft').toString();
    final payDate = data['payDate'];
    final periodStart = data['payPeriodStart'];
    final periodEnd = data['payPeriodEnd'];

    final payDateStr = payDate is Timestamp
        ? DateFormat('yMMMd').format(payDate.toDate())
        : '—';
    final periodStr = (periodStart is Timestamp && periodEnd is Timestamp)
        ? '${DateFormat('M/d/yy').format(periodStart.toDate())} – '
            '${DateFormat('M/d/yy').format(periodEnd.toDate())}'
        : '—';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_outlined, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Pay Period: $periodStr',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              _statusBadge(status),
            ],
          ),
          const SizedBox(height: 12),
          _summaryRow('Pay Date', payDateStr),
          _summaryRow('Employees', '${data['employeeCount'] ?? 0}'),
          const Divider(height: 16),
          _summaryRow('Total Gross', '\$${fmt.format(data['totalGross'] ?? 0)}'),
          _summaryRow('Total Taxes', '\$${fmt.format(data['totalTaxes'] ?? 0)}'),
          _summaryRow(
              'Total Deductions', '\$${fmt.format(data['totalDeductions'] ?? 0)}'),
          const Divider(height: 16),
          _summaryRow('Total Net Pay', '\$${fmt.format(data['totalNet'] ?? 0)}',
              bold: true),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
          Text(value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
              )),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final colors = {
      'draft': (Colors.orange, Colors.orange),
      'approved': (Colors.blue, Colors.blue),
      'processed': (Colors.green, Colors.green),
      'paid': (Colors.green, Colors.green),
    };
    final c = colors[status] ?? (Colors.grey, Colors.grey);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: c.$1[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.$2[300]!),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(
            fontSize: 12, color: c.$1[800], fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _actionButton(BuildContext context, String label, IconData icon,
      MaterialColor color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Future<void> _approve(BuildContext context) async {
    try {
      await PayrollService().approvePayrollRun(
        companyRef: widget.companyRef,
        runId: widget.runId,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to approve: $e')),
        );
      }
    }
  }

  Future<void> _process(BuildContext context) async {
    try {
      await PayrollService().processPayrollRun(
        companyRef: widget.companyRef,
        runId: widget.runId,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process: $e')),
        );
      }
    }
  }
}
