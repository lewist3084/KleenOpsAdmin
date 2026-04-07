// lib/features/finances/details/finance_pay_stub_details.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/features/finances/services/pay_stub_pdf_service.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';

class FinancePayStubDetailsScreen extends ConsumerWidget {
  final String runId;
  final String memberId;
  final String memberName;

  factory FinancePayStubDetailsScreen.fromExtra(Map<String, dynamic>? extra) {
    final e = extra ?? {};
    return FinancePayStubDetailsScreen(
      runId: e['runId'] as String? ?? '',
      memberId: e['memberId'] as String? ?? '',
      memberName: e['memberName'] as String? ?? '',
    );
  }

  const FinancePayStubDetailsScreen({
    super.key,
    required this.runId,
    required this.memberId,
    required this.memberName,
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
            title: memberName,
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
                  return _PayStubBody(
                    companyRef: companyRef,
                    runId: runId,
                    memberId: memberId,
                    memberName: memberName,
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

class _PayStubBody extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final String runId;
  final String memberId;
  final String memberName;

  const _PayStubBody({
    required this.companyRef,
    required this.runId,
    required this.memberId,
    required this.memberName,
  });

  @override
  State<_PayStubBody> createState() => _PayStubBodyState();
}

class _PayStubBodyState extends State<_PayStubBody> {
  bool _exporting = false;

  Future<void> _exportPdf(Map<String, dynamic> stubData) async {
    setState(() => _exporting = true);
    try {
      // Load the run data for period info
      final runSnap = await FirebaseFirestore.instance
          .collection('payrollRun')
          .doc(widget.runId)
          .get();
      final runData = runSnap.data() ?? {};

      // Convert Timestamps to DateTime for PDF
      final runDataForPdf = <String, dynamic>{};
      for (final e in runData.entries) {
        if (e.value is Timestamp) {
          runDataForPdf[e.key] = (e.value as Timestamp).toDate();
        } else {
          runDataForPdf[e.key] = e.value;
        }
      }

      final pdfBytes = PayStubPdfService().generatePayStubPdf(
        stubData: stubData,
        runData: runDataForPdf,
      );

      if (kIsWeb) {
        // Web: can't save file easily, show snackbar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('PDF export not available on web yet')),
          );
        }
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final file = File(
            '${dir.path}/paystub_${widget.memberName.replaceAll(' ', '_')}_${widget.runId.substring(0, 8)}.pdf');
        await file.writeAsBytes(pdfBytes);
        await OpenFilex.open(file.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF export error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stubStream = FirebaseFirestore.instance
        .collection('payrollRun')
        .doc(widget.runId)
        .collection('payStub')
        .doc(widget.memberId)
        .snapshots();
    final bottomInset =
        kBottomNavigationBarHeight + 16.0 + MediaQuery.of(context).padding.bottom;
    final fmt = NumberFormat('#,##0.00');

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: stubStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data?.data() ?? {};

        final payType = (data['payType'] ?? '').toString();
        final paymentMethod =
            (data['paymentMethod'] ?? 'direct_deposit').toString();

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Container(
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
                    Text(widget.memberName,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _chip(payType == 'salary' ? 'Salary' : 'Hourly',
                            Colors.blue),
                        const SizedBox(width: 6),
                        _chip(
                          paymentMethod == 'direct_deposit'
                              ? 'Direct Deposit'
                              : 'Paper Check',
                          Colors.grey,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Earnings ──
              _section('Earnings', [
                if (payType == 'hourly') ...[
                  _row('Regular Hours', '${data['regularHours'] ?? 0}'),
                  _row('Regular Rate',
                      '\$${fmt.format(data['regularRate'] ?? 0)}'),
                  _row('Regular Pay',
                      '\$${fmt.format(data['regularPay'] ?? 0)}'),
                  if ((data['overtimeHours'] ?? 0) > 0) ...[
                    _row('Overtime Hours', '${data['overtimeHours']}'),
                    _row('OT Multiplier', '${data['overtimeRate'] ?? 1.5}x'),
                    _row('Overtime Pay',
                        '\$${fmt.format(data['overtimePay'] ?? 0)}'),
                  ],
                ],
                _row('Gross Pay', '\$${fmt.format(data['grossPay'] ?? 0)}',
                    bold: true),
              ]),

              // ── Taxes ──
              _section('Taxes', [
                _row('Federal Income Tax',
                    '\$${fmt.format(data['federalIncomeTax'] ?? 0)}'),
                _row('State Income Tax',
                    '\$${fmt.format(data['stateIncomeTax'] ?? 0)}'),
                if ((data['localIncomeTax'] as num?)?.toDouble() != null &&
                    (data['localIncomeTax'] as num).toDouble() > 0) ...[
                  _row('Local Income Tax',
                      '\$${fmt.format(data['localIncomeTax'] ?? 0)}'),
                  // Show itemized local taxes if available
                  if (data['localTaxDetails'] is List)
                    ...(data['localTaxDetails'] as List).map((d) {
                      if (d is! Map) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(left: 24),
                        child: _row(
                          '${d['name'] ?? ''} (${d['type'] ?? ''})',
                          '\$${fmt.format(d['amount'] ?? 0)}',
                        ),
                      );
                    }),
                ],
                _row('Social Security',
                    '\$${fmt.format(data['socialSecurity'] ?? 0)}'),
                _row('Medicare',
                    '\$${fmt.format(data['medicare'] ?? 0)}'),
                if ((data['additionalMedicare'] ?? 0) > 0)
                  _row('Additional Medicare',
                      '\$${fmt.format(data['additionalMedicare'])}'),
                _row('Total Taxes',
                    '\$${fmt.format(data['totalTaxes'] ?? 0)}',
                    bold: true),
              ]),

              // ── Deductions ──
              if ((data['deductions'] as List?)?.isNotEmpty ?? false)
                _section('Deductions', [
                  ...(data['deductions'] as List).map((d) {
                    return _row(
                      (d['name'] ?? 'Deduction').toString(),
                      '\$${fmt.format(d['amount'] ?? 0)}',
                    );
                  }),
                  _row('Total Deductions',
                      '\$${fmt.format(data['totalDeductions'] ?? 0)}',
                      bold: true),
                ]),

              // ── Employer Taxes (informational) ──
              if ((data['totalEmployerTaxes'] as num?)?.toDouble() != null &&
                  (data['totalEmployerTaxes'] as num).toDouble() > 0)
                _section('Employer Taxes (not deducted from pay)', [
                  _row('Employer SS Match',
                      '\$${fmt.format(data['employerSocialSecurity'] ?? 0)}'),
                  _row('Employer Medicare Match',
                      '\$${fmt.format(data['employerMedicare'] ?? 0)}'),
                  if ((data['futa'] as num?)?.toDouble() != null &&
                      (data['futa'] as num).toDouble() > 0)
                    _row('FUTA', '\$${fmt.format(data['futa'] ?? 0)}'),
                  if ((data['suta'] as num?)?.toDouble() != null &&
                      (data['suta'] as num).toDouble() > 0)
                    _row('SUTA', '\$${fmt.format(data['suta'] ?? 0)}'),
                  _row('Total Employer Taxes',
                      '\$${fmt.format(data['totalEmployerTaxes'] ?? 0)}',
                      bold: true),
                ]),

              // ── Net Pay ──
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.payments_outlined,
                        color: Colors.green[700], size: 24),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Net Pay',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                    Text(
                      '\$${fmt.format(data['netPay'] ?? 0)}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── YTD Summary ──
              _section('Year-to-Date', [
                _row('YTD Gross',
                    '\$${fmt.format(data['ytdGross'] ?? 0)}'),
                _row('YTD Taxes',
                    '\$${fmt.format(data['ytdTaxes'] ?? 0)}'),
                _row('YTD Deductions',
                    '\$${fmt.format(data['ytdDeductions'] ?? 0)}'),
                _row('YTD Net',
                    '\$${fmt.format(data['ytdNet'] ?? 0)}',
                    bold: true),
              ]),

              // ── Export PDF ──
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _exporting ? null : () => _exportPdf(data),
                  icon: _exporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf, size: 18),
                  label: Text(
                      _exporting ? 'Generating...' : 'Export Pay Stub PDF'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _chip(String label, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color[200]!),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11, color: color[800])),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
                letterSpacing: 0.5,
              )),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
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
}
