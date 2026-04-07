import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:kleenops_admin/widgets/labels/text_value_inline.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/features/admin/forms/admin_insurance_form.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';

/// Content widget for the Insurance tab within Admin Company tabs.
class AdminInsuranceContent extends ConsumerWidget {
  const AdminInsuranceContent({super.key});

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
        return _InsuranceBody(companyRef: companyRef);
      },
    );
  }
}

class _InsuranceBody extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  const _InsuranceBody({required this.companyRef});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('insurancePolicy')
          .orderBy('type')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No insurance policies added yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your general liability, workers\' comp, bonding, and other policies.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final type = (data['type'] ?? 'Policy').toString();
            final carrier = (data['carrier'] ?? '').toString();
            final policyNumber = (data['policyNumber'] ?? '').toString();
            final expDate = (data['expirationDate'] ?? '').toString();
            final status = _resolveStatus(data);

            return StandardTileSmallDart(
              label: type,
              secondaryText: carrier.isNotEmpty
                  ? '$carrier • #$policyNumber'
                  : policyNumber,
              leadingIcon: _iconForType(type),
              leadingIconColor: _colorForStatus(status),
              trailingIcon1: Icons.chevron_right,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AdminInsuranceFormScreen(
                      companyRef: companyRef,
                      docId: doc.id,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  String _resolveStatus(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString().toLowerCase();
    if (status.isNotEmpty) return status;
    final expStr = (data['expirationDate'] ?? '').toString();
    if (expStr.isEmpty) return 'unknown';
    final exp = DateTime.tryParse(expStr);
    if (exp == null) return 'unknown';
    return exp.isBefore(DateTime.now()) ? 'expired' : 'active';
  }

  IconData _iconForType(String type) {
    final t = type.toLowerCase();
    if (t.contains('general liability')) return Icons.shield;
    if (t.contains('workers')) return Icons.health_and_safety;
    if (t.contains('auto')) return Icons.directions_car;
    if (t.contains('bond')) return Icons.verified_user;
    if (t.contains('umbrella')) return Icons.umbrella;
    if (t.contains('property') || t.contains('equipment')) return Icons.home_work;
    if (t.contains('cyber')) return Icons.security;
    if (t.contains('professional') || t.contains('e&o')) return Icons.gavel;
    return Icons.policy;
  }

  Color _colorForStatus(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'expired':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
