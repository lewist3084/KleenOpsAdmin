// lib/features/finances/screens/financeW2Generation.dart

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/features/finances/services/w2_pdf_service.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';

class FinanceW2GenerationScreen extends StatelessWidget {
  const FinanceW2GenerationScreen({super.key});

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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: null,
      body: _wrapCanvas(
          Consumer(
            builder: (context, ref, _) {
              return ref.watch(companyIdProvider).when(
                    data: (companyRef) {
                      if (companyRef == null) {
                        return const Center(child: Text('No company'));
                      }
                      return _W2Content(companyRef: companyRef);
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                  );
            },
          ),
        ),
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DetailsAppBar(
                title: 'W-2 Generation',
              ),
              const HomeNavBarAdapter(),
            ],
          );
        },
      ),
    );
  }
}

class _W2Content extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;

  const _W2Content({required this.companyRef});

  @override
  State<_W2Content> createState() => _W2ContentState();
}

class _W2ContentState extends State<_W2Content> {
  final _w2Service = W2PdfService();
  int _selectedYear = DateTime.now().year;
  bool _loading = true;
  bool _generating = false;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _members = [];
  Map<String, dynamic>? _companyData;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final memberSnap = await FirebaseFirestore.instance
          .collection('member')
          .where('active', isEqualTo: true)
          .orderBy('name')
          .get();
      final companySnap = await widget.companyRef.get();

      if (mounted) {
        setState(() {
          _members = memberSnap.docs;
          _companyData = companySnap.data();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generateW2(String memberId, String memberName) async {
    setState(() => _generating = true);
    try {
      final w2Data = await _w2Service.aggregateW2Data(
        companyRef: widget.companyRef,
        memberId: memberId,
        taxYear: _selectedYear,
      );

      if ((w2Data['totalGross'] as num?)?.toDouble() == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'No payroll data found for $memberName in $_selectedYear')),
          );
        }
        return;
      }

      // Load member data for the PDF
      final memberSnap = await FirebaseFirestore.instance
          .collection('member')
          .doc(memberId)
          .get();

      final pdfBytes = _w2Service.generateW2Pdf(
        w2Data: w2Data,
        memberData: memberSnap.data() ?? {},
        companyData: _companyData ?? {},
      );

      if (!kIsWeb) {
        final dir = await getApplicationDocumentsDirectory();
        final file = File(
            '${dir.path}/w2_${_selectedYear}_${memberName.replaceAll(' ', '_')}.pdf');
        await file.writeAsBytes(pdfBytes);
        await OpenFilex.open(file.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('W-2 error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = kBottomNavigationBarHeight +
        16.0 +
        MediaQuery.of(context).padding.bottom;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Year selector
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.description_outlined, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'W-2 Wage & Tax Statements',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Generate W-2 summary PDFs for year-end tax reporting.',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                DropdownButton<int>(
                  value: _selectedYear,
                  items: List.generate(3, (i) {
                    final year = DateTime.now().year - i;
                    return DropdownMenuItem(
                      value: year,
                      child: Text('$year'),
                    );
                  }),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedYear = v);
                  },
                ),
              ],
            ),
          ),

          // Info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                border: Border.all(color: Colors.amber[200]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.amber[800], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'These are informational W-2 summaries generated from payroll data. '
                      'Use official IRS Form W-2 for actual filing. '
                      'W-2s must be furnished to employees by January 31.',
                      style: TextStyle(
                          fontSize: 13, color: Colors.amber[900]),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Employee list
          ContainerActionWidget(
            title: 'Employees (${_members.length})',
            actionText: '',
            content: Column(
              children: _members.map((doc) {
                final data = doc.data();
                final name = (data['name'] ?? '').toString();
                final payType = (data['payType'] ?? 'hourly').toString();

                return StandardTileSmallDart(
                  label: name,
                  secondaryText: payType == 'salary' ? 'Salary' : 'Hourly',
                  labelIcon: Icons.person_outline,
                  trailingIcon1: _generating
                      ? Icons.hourglass_empty
                      : Icons.picture_as_pdf,
                  onTrailing1Tap:
                      _generating ? null : () => _generateW2(doc.id, name),
                  onTap:
                      _generating ? null : () => _generateW2(doc.id, name),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
