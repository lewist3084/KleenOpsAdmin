import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';
import 'package:kleenops_admin/widgets/fields/counter_field.dart';

/// Form to edit company-standard settings like measurement system and
/// employee thresholds/intervals.
class AdminCompanyFormScreen extends ConsumerStatefulWidget {
  const AdminCompanyFormScreen({super.key});

  @override
  ConsumerState<AdminCompanyFormScreen> createState() => _AdminCompanyFormState();
}

class _AdminCompanyFormState extends ConsumerState<AdminCompanyFormScreen> {
  String _measurementSystem = 'Standard'; // 'Standard' | 'Metric'

  double _gracePeriod = 0;
  double _dependabilityMinimum = 0;
  double _dependabilityInterval = 0;
  double _contributionMinimum = 0;
  double _contributionInterval = 0;

  bool _loading = true;
  bool _saving = false;

  Future<void> _loadInitial(DocumentReference<Map<String, dynamic>> companyRef) async {
    final snap = await companyRef.get(const GetOptions(source: Source.serverAndCache));
    final data = snap.data() ?? {};
    setState(() {
      _measurementSystem = (data['measurementSystem'] as String?) ?? 'Standard';
      _gracePeriod = ((data['lateGracePeriod'] as num?) ?? 0).toDouble();
      _dependabilityMinimum = ((data['dependabilityMinimum'] as num?) ?? 0).toDouble();
      _dependabilityInterval = ((data['dependabilityInterval'] as num?) ?? 0).toDouble();
      _contributionMinimum = ((data['contributionMinimum'] as num?) ?? 0).toDouble();
      _contributionInterval = ((data['contributionInterval'] as num?) ?? 0).toDouble();
      _loading = false;
    });
  }

  Future<void> _save(DocumentReference<Map<String, dynamic>> companyRef) async {
    setState(() => _saving = true);
    try {
      await companyRef.update({
        'measurementSystem': _measurementSystem,
        'lateGracePeriod': _gracePeriod.round(),
        'dependabilityMinimum': _dependabilityMinimum.round(),
        'dependabilityInterval': _dependabilityInterval.round(),
        'contributionMinimum': _contributionMinimum.round(),
        'contributionInterval': _contributionInterval.round(),
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
          appBar: const StandardAppBar(title: 'Company Settings'),
          body: _loading || _saving
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

                      // Grace period
                      CounterField(
                        label: 'Grace Period',
                        initialValue: _gracePeriod,
                        onChanged: (v) => setState(() => _gracePeriod = v),
                      ),
                      const SizedBox(height: 12),

                      // Dependability Minimum
                      CounterField(
                        label: 'Dependability Minimum',
                        initialValue: _dependabilityMinimum,
                        onChanged: (v) => setState(() => _dependabilityMinimum = v),
                      ),
                      const SizedBox(height: 12),

                      // Dependability Interval
                      CounterField(
                        label: 'Dependability Interval',
                        initialValue: _dependabilityInterval,
                        onChanged: (v) => setState(() => _dependabilityInterval = v),
                      ),
                      const SizedBox(height: 12),

                      // Contribution Minimum
                      CounterField(
                        label: 'Contribution Minimum',
                        initialValue: _contributionMinimum,
                        onChanged: (v) => setState(() => _contributionMinimum = v),
                      ),
                      const SizedBox(height: 12),

                      // Contribution Interval
                      CounterField(
                        label: 'Contribution Interval',
                        initialValue: _contributionInterval,
                        onChanged: (v) => setState(() => _contributionInterval = v),
                      ),
                    ],
                  ),
                ),
          bottomNavigationBar: SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: 8),
            child: CancelSaveBar(
              onCancel: () => Navigator.of(context).pop(),
              onSave: _saving || _loading ? null : () => _save(companyRef),
            ),
          ),
        );
      },
    );
  }
}

