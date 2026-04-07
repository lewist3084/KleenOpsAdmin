// lib/features/hr/screens/hr_time_entry.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/theme/palette.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';

/// Time entry screen for hourly employees. Shows a weekly timesheet
/// grid and stores entries in `company/{id}/timeEntry/{entryId}`.
class HrTimeEntryScreen extends StatelessWidget {
  const HrTimeEntryScreen({super.key});

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
          Consumer(
            builder: (context, ref, _) {
              return ref.watch(companyIdProvider).when(
                    data: (companyRef) {
                      if (companyRef == null) {
                        return const Center(child: Text('No company'));
                      }
                      return _TimeEntryContent(companyRef: companyRef);
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
                title: 'Time Entry',
              ),
              const HomeNavBarAdapter(),
            ],
          );
        },
      ),
    );
  }
}

class _TimeEntryContent extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;

  const _TimeEntryContent({required this.companyRef});

  @override
  State<_TimeEntryContent> createState() => _TimeEntryContentState();
}

class _TimeEntryContentState extends State<_TimeEntryContent> {
  late DateTime _weekStart;
  bool _saving = false;

  // memberId → dayIndex (0=Mon..6=Sun) → hours
  final Map<String, List<double>> _hours = {};
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _members = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // Start on the most recent Monday
    final now = DateTime.now();
    _weekStart = now.subtract(Duration(days: now.weekday - 1));
    _weekStart = DateTime(_weekStart.year, _weekStart.month, _weekStart.day);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    // Load active hourly employees
    final snap = await FirebaseFirestore.instance
        .collection('member')
        .where('active', isEqualTo: true)
        .orderBy('name')
        .get();

    _members = snap.docs
        .where((d) => (d.data()['payType'] ?? 'hourly') == 'hourly')
        .toList();

    // Initialize hours grid
    for (final doc in _members) {
      _hours[doc.id] = List.filled(7, 0.0);
    }

    // Load existing time entries for this week
    final entriesSnap = await FirebaseFirestore.instance
        .collection('timeEntry')
        .where('weekStart',
            isEqualTo: Timestamp.fromDate(_weekStart))
        .get();

    for (final doc in entriesSnap.docs) {
      final data = doc.data();
      final memberId = (data['memberId'] ?? '').toString();
      final daily = data['dailyHours'];
      if (memberId.isNotEmpty && daily is List && _hours.containsKey(memberId)) {
        for (int i = 0; i < 7 && i < daily.length; i++) {
          _hours[memberId]![i] = (daily[i] as num?)?.toDouble() ?? 0;
        }
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  void _changeWeek(int delta) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: 7 * delta));
    });
    _loadData();
  }

  double _totalForMember(String memberId) {
    return _hours[memberId]?.fold<double>(0.0, (acc, h) => acc + h) ?? 0;
  }

  double _totalForDay(int dayIndex) {
    double total = 0;
    for (final entry in _hours.values) {
      if (dayIndex < entry.length) total += entry[dayIndex];
    }
    return total;
  }

  Future<void> _saveAll() async {
    setState(() => _saving = true);
    try {
      final batch = FirebaseFirestore.instance.batch();

      for (final doc in _members) {
        final memberId = doc.id;
        final daily = _hours[memberId] ?? List.filled(7, 0.0);
        final total = daily.fold(0.0, (sum, h) => sum + h);

        // Use composite key: memberId_weekStart
        final entryId =
            '${memberId}_${_weekStart.toIso8601String().split('T').first}';
        final ref =
            FirebaseFirestore.instance.collection('timeEntry').doc(entryId);

        batch.set(ref, {
          'memberId': memberId,
          'memberName': (doc.data()['name'] ?? '').toString(),
          'weekStart': Timestamp.fromDate(_weekStart),
          'dailyHours': daily,
          'totalHours': total,
          'regularHours': total > 40 ? 40.0 : total,
          'overtimeHours': total > 40 ? total - 40 : 0.0,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Timesheet saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteScope.of(context);
    final bottomInset = kBottomNavigationBarHeight +
        16.0 +
        MediaQuery.of(context).padding.bottom;
    final dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekEndDate = _weekStart.add(const Duration(days: 6));
    final weekLabel =
        '${DateFormat('MMM d').format(_weekStart)} – ${DateFormat('MMM d, yyyy').format(weekEndDate)}';

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Week navigator
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _changeWeek(-1),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    weekLabel,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _changeWeek(1),
              ),
            ],
          ),
        ),

        // Timesheet grid
        Expanded(
          child: _members.isEmpty
              ? Center(
                  child: Text(
                    'No hourly employees found.',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: bottomInset),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 12,
                      headingRowHeight: 40,
                      dataRowMinHeight: 44,
                      dataRowMaxHeight: 48,
                      columns: [
                        const DataColumn(
                          label: Text('Employee',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        ...dayLabels.map((d) => DataColumn(
                              label: Text(d,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12)),
                            )),
                        const DataColumn(
                          label: Text('Total',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                      rows: [
                        ..._members.map((doc) {
                          final memberId = doc.id;
                          final name =
                              (doc.data()['name'] ?? '').toString();
                          final total = _totalForMember(memberId);

                          return DataRow(
                            cells: [
                              DataCell(SizedBox(
                                width: 120,
                                child: Text(name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13)),
                              )),
                              ...List.generate(7, (dayIdx) {
                                return DataCell(
                                  SizedBox(
                                    width: 48,
                                    child: TextFormField(
                                      initialValue: _hours[memberId]![dayIdx] > 0
                                          ? _hours[memberId]![dayIdx]
                                              .toString()
                                          : '',
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        contentPadding:
                                            EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 8),
                                        border: OutlineInputBorder(),
                                      ),
                                      keyboardType:
                                          const TextInputType
                                              .numberWithOptions(
                                              decimal: true),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                            RegExp(r'[\d.]')),
                                      ],
                                      style: const TextStyle(fontSize: 13),
                                      onChanged: (val) {
                                        final hours =
                                            double.tryParse(val) ?? 0;
                                        setState(() {
                                          _hours[memberId]![dayIdx] =
                                              hours;
                                        });
                                      },
                                    ),
                                  ),
                                );
                              }),
                              DataCell(
                                Text(
                                  total.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: total > 40
                                        ? Colors.orange[700]
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                        // Totals row
                        DataRow(
                          color: WidgetStatePropertyAll(Colors.grey[100]),
                          cells: [
                            const DataCell(Text('Daily Total',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12))),
                            ...List.generate(7, (dayIdx) {
                              return DataCell(Text(
                                _totalForDay(dayIdx).toStringAsFixed(1),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12),
                              ));
                            }),
                            DataCell(Text(
                              _hours.values
                                  .fold(
                                      0.0,
                                      (sum, list) =>
                                          sum +
                                          list.fold(
                                              0.0, (s, h) => s + h))
                                  .toStringAsFixed(1),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            )),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
        ),

        // Save button
        Container(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            8 + MediaQuery.of(context).padding.bottom,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey[300]!)),
          ),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _saveAll,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child:
                          CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save, size: 18),
              label:
                  Text(_saving ? 'Saving...' : 'Save Timesheet'),
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.primary1,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
