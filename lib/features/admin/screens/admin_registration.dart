import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:kleenops_admin/widgets/labels/text_value_inline.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';

/// Content widget for the Registration tab within Admin Company tabs.
class AdminRegistrationContent extends ConsumerWidget {
  const AdminRegistrationContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyAsync = ref.watch(companyIdProvider);

    return companyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (companyRef) {
        if (companyRef == null) {
          return const Center(child: Text('No company found'));
        }
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: companyRef.snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data?.data() ?? {};
            return _RegistrationBody(data: data);
          },
        );
      },
    );
  }
}

class _RegistrationBody extends StatelessWidget {
  final Map<String, dynamic> data;

  const _RegistrationBody({required this.data});

  String _field(String key) {
    final v = (data[key] ?? '').toString().trim();
    return v.isEmpty ? 'Not set' : v;
  }

  @override
  Widget build(BuildContext context) {
    final licenses = (data['businessLicenses'] as List<dynamic>?) ?? [];
    final contractorLicenses =
        (data['contractorLicenses'] as List<dynamic>?) ?? [];
    final stateRegistrations =
        (data['stateRegistrations'] as List<dynamic>?) ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ContainerActionWidget(
            title: 'Business Identity',
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextValueInline(
                  header: 'EIN / Tax ID',
                  value: _field('ein'),
                  icon: Icons.badge,
                  boldHeader: false,
                ),
                const SizedBox(height: 8),
                TextValueInline(
                  header: 'Entity Type',
                  value: _field('entityType'),
                  icon: Icons.account_balance,
                  boldHeader: false,
                ),
                const SizedBox(height: 8),
                TextValueInline(
                  header: 'State of Incorporation',
                  value: _field('stateOfIncorporation'),
                  icon: Icons.location_city,
                  boldHeader: false,
                ),
                const SizedBox(height: 8),
                TextValueInline(
                  header: 'Date Incorporated',
                  value: _field('dateIncorporated'),
                  icon: Icons.calendar_today,
                  boldHeader: false,
                ),
                const SizedBox(height: 8),
                TextValueInline(
                  header: 'Website',
                  value: _field('website'),
                  icon: Icons.language,
                  boldHeader: false,
                ),
              ],
            ),
            actionText: '',
          ),
          ContainerActionWidget(
            title: 'Identification Numbers',
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextValueInline(
                  header: 'DUNS Number',
                  value: _field('dunsNumber'),
                  icon: Icons.numbers,
                  boldHeader: false,
                ),
                const SizedBox(height: 8),
                TextValueInline(
                  header: 'SIC Code',
                  value: _field('sicCode'),
                  icon: Icons.category,
                  boldHeader: false,
                ),
                const SizedBox(height: 8),
                TextValueInline(
                  header: 'NAICS Code',
                  value: _field('naicsCode'),
                  icon: Icons.category_outlined,
                  boldHeader: false,
                ),
              ],
            ),
            actionText: '',
          ),
          ContainerActionWidget(
            title: 'Business Licenses',
            content: licenses.isEmpty
                ? const Text('No business licenses added',
                    style: TextStyle(color: Colors.grey))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final l in licenses) ...[
                        _LicenseRow(l as Map<String, dynamic>),
                        if (l != licenses.last) const SizedBox(height: 8),
                      ],
                    ],
                  ),
            actionText: '',
          ),
          ContainerActionWidget(
            title: 'Contractor Licenses',
            content: contractorLicenses.isEmpty
                ? const Text('No contractor licenses added',
                    style: TextStyle(color: Colors.grey))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final l in contractorLicenses) ...[
                        _LicenseRow(l as Map<String, dynamic>),
                        if (l != contractorLicenses.last)
                          const SizedBox(height: 8),
                      ],
                    ],
                  ),
            actionText: '',
          ),
          ContainerActionWidget(
            title: 'State Registrations',
            content: stateRegistrations.isEmpty
                ? const Text('No state registrations added',
                    style: TextStyle(color: Colors.grey))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final l in stateRegistrations) ...[
                        _LicenseRow(l as Map<String, dynamic>),
                        if (l != stateRegistrations.last)
                          const SizedBox(height: 8),
                      ],
                    ],
                  ),
            actionText: '',
          ),
        ],
      ),
    );
  }
}

class _LicenseRow extends StatelessWidget {
  final Map<String, dynamic> m;
  const _LicenseRow(this.m);

  @override
  Widget build(BuildContext context) {
    final type = (m['type'] ?? 'License').toString();
    final number = (m['number'] ?? '').toString();
    final state = (m['state'] ?? '').toString();
    final exp = (m['expirationDate'] ?? 'N/A').toString();
    return TextValueInline(
      header: type,
      value: '$number • $state • Exp: $exp',
      icon: Icons.verified,
      boldHeader: false,
    );
  }
}
