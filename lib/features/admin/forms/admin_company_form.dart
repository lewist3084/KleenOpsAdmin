import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';
import 'package:kleenops_admin/widgets/fields/counter_field.dart';
import 'package:kleenops_admin/widgets/layout/bookended_canvas.dart';

/// Form to edit company-standard settings like measurement system and
/// employee thresholds/intervals.
class AdminCompanyFormScreen extends ConsumerStatefulWidget {
  const AdminCompanyFormScreen({super.key});

  @override
  ConsumerState<AdminCompanyFormScreen> createState() => _AdminCompanyFormState();
}

class _AdminCompanyFormState extends ConsumerState<AdminCompanyFormScreen> {
  String _measurementSystem = 'Standard'; // 'Standard' | 'Metric'

  double _earlyArrivalGrace = 0;
  double _lateArrivalGrace = 0;
  double _earlyDepartureGrace = 0;
  double _lateDepartureGrace = 0;
  double _dependabilityMinimum = 0;
  double _contributionMinimum = 0;
  double _evaluationInterval = 0;

  static const List<String> _evaluationIntervalKeys = <String>[
    'evaluationInterval',
    'EvaluationInterval',
    'evaluationIntervalCamelText',
    'EvaluationIntervalCamelText',
    'evaluationIntervalCamelTex',
    'EvaluationIntervalCamelTex',
    'evaluationIntervalText',
    'EvaluationIntervalText',
  ];

  double _readEvaluationInterval(Map<String, dynamic> data) {
    for (final key in _evaluationIntervalKeys) {
      final value = data[key];
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
    }
    return 0;
  }

  /// Reads the first numeric value found among [keys], falling back to 0.
  double _readNum(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
    }
    return 0;
  }

  bool _loading = true;
  bool _saving = false;

  Future<void> _loadInitial(DocumentReference<Map<String, dynamic>> companyRef) async {
    final snap = await companyRef.get(const GetOptions(source: Source.serverAndCache));
    final data = snap.data() ?? {};
    setState(() {
      _measurementSystem = (data['measurementSystem'] as String?) ?? 'Standard';
      _earlyArrivalGrace = _readNum(
          data, const ['earlyArrivalGracePeriod', 'earlyGracePeriod']);
      _lateArrivalGrace = _readNum(
          data, const ['lateArrivalGracePeriod', 'lateGracePeriod']);
      _earlyDepartureGrace = _readNum(data, const [
        'earlyDepartureGracePeriod',
        'departureGracePeriod',
        'earlyGracePeriod',
      ]);
      _lateDepartureGrace = _readNum(data, const [
        'lateDepartureGracePeriod',
        'departureGracePeriod',
        'lateGracePeriod',
      ]);
      _dependabilityMinimum = ((data['dependabilityMinimum'] as num?) ?? 0).toDouble();
      _contributionMinimum = ((data['contributionMinimum'] as num?) ?? 0).toDouble();
      _evaluationInterval = _readEvaluationInterval(data);
      _loading = false;
    });
  }

  Future<void> _save(DocumentReference<Map<String, dynamic>> companyRef) async {
    setState(() => _saving = true);
    try {
      await companyRef.update({
        'measurementSystem': _measurementSystem,
        'earlyArrivalGracePeriod': _earlyArrivalGrace.round(),
        'lateArrivalGracePeriod': _lateArrivalGrace.round(),
        'earlyDepartureGracePeriod': _earlyDepartureGrace.round(),
        'lateDepartureGracePeriod': _lateDepartureGrace.round(),
        'dependabilityMinimum': _dependabilityMinimum.round(),
        'contributionMinimum': _contributionMinimum.round(),
        'evaluationInterval': _evaluationInterval.round(),
      });
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final companyAsync = ref.watch(companyIdProvider);

    return companyAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (companyRef) {
        if (companyRef == null) {
          return const Scaffold(
            body: Center(child: Text('No company found.')),
          );
        }

        if (_loading) {
          // kick off initial load once
          _loadInitial(companyRef);
        }

        return Scaffold(
          body: BookendedCanvas(
            child: _loading || _saving
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Measurement System selector
                        Text(
                          'Measurements',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _measurementSystem,
                          decoration: const InputDecoration(
                            labelText: 'Measurement System',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Standard', child: Text('Standard')),
                            DropdownMenuItem(value: 'Metric', child: Text('Metric')),
                          ],
                          onChanged: (v) => setState(() => _measurementSystem = v ?? 'Standard'),
                        ),

                        const SizedBox(height: 24),
                        Text(
                          'Employees',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),

                        // Clock-in window: grace minutes around the scheduled start
                        Text(
                          'Clock-In Window',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        CounterField(
                          label: 'Early Arrival Grace (min)',
                          initialValue: _earlyArrivalGrace,
                          onChanged: (v) =>
                              setState(() => _earlyArrivalGrace = v),
                        ),
                        const SizedBox(height: 8),
                        CounterField(
                          label: 'Late Arrival Grace (min)',
                          initialValue: _lateArrivalGrace,
                          onChanged: (v) =>
                              setState(() => _lateArrivalGrace = v),
                        ),
                        const SizedBox(height: 16),

                        // Clock-out window: grace minutes around the scheduled end
                        Text(
                          'Clock-Out Window',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        CounterField(
                          label: 'Early Departure Grace (min)',
                          initialValue: _earlyDepartureGrace,
                          onChanged: (v) =>
                              setState(() => _earlyDepartureGrace = v),
                        ),
                        const SizedBox(height: 8),
                        CounterField(
                          label: 'Late Departure Grace (min)',
                          initialValue: _lateDepartureGrace,
                          onChanged: (v) =>
                              setState(() => _lateDepartureGrace = v),
                        ),
                        const SizedBox(height: 12),

                        // Dependability Minimum
                        CounterField(
                          label: 'Dependability Minimum',
                          initialValue: _dependabilityMinimum,
                          onChanged: (v) => setState(() => _dependabilityMinimum = v),
                        ),
                        const SizedBox(height: 12),

                        // Contribution Minimum
                        CounterField(
                          label: 'Contribution Minimum',
                          initialValue: _contributionMinimum,
                          onChanged: (v) => setState(() => _contributionMinimum = v),
                        ),

                        const SizedBox(height: 24),
                        Text(
                          'Evaluation',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),

                        // Evaluation Interval
                        CounterField(
                          label: 'Evaluation Interval',
                          initialValue: _evaluationInterval,
                          onChanged: (v) => setState(() => _evaluationInterval = v),
                        ),
                      ],
                    ),
                  ),
          ),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CancelSaveBar(
                onCancel: () => Navigator.of(context).pop(),
                onSave: _saving || _loading ? null : () => _save(companyRef),
                reserveNavBarSpace: false,
              ),
              const DetailsAppBar(title: 'Company Settings'),
              const HomeNavBarAdapter(),
            ],
          ),
        );
      },
    );
  }
}

