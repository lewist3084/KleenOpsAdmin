import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_plugin/qr_plugin.dart';

import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';

/// Company-side screen to generate a customer portal invite QR code.
///
/// Calls the [generateCustomerTicket] Cloud Function, then displays
/// the resulting ticket ID as a QR code for the customer to scan.
class CustomerInviteScreen extends ConsumerStatefulWidget {
  final String customerId;

  const CustomerInviteScreen({super.key, required this.customerId});

  @override
  ConsumerState<CustomerInviteScreen> createState() =>
      _CustomerInviteScreenState();
}

class _CustomerInviteScreenState extends ConsumerState<CustomerInviteScreen> {
  String? _ticketId;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generateTicket();
  }

  Future<void> _generateTicket() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final companyRef = ref.read(companyIdProvider).asData?.value;
      if (companyRef == null) throw Exception('No company found');

      final callable =
          FirebaseFunctions.instanceFor(region: 'us-central1')
              .httpsCallable('generateCustomerTicket');
      final result = await callable.call<Map<String, dynamic>>({
        'companyId': companyRef.id,
        'customerId': widget.customerId,
      });

      final ticketId = result.data['ticketId'] as String?;
      if (ticketId == null || ticketId.isEmpty) {
        throw Exception('No ticket ID returned');
      }

      if (mounted) setState(() => _ticketId = ticketId);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invite Customer to Portal')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: _loading
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Generating invite...'),
                  ],
                )
              : _error != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline,
                            size: 48, color: Colors.red[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to generate invite',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: TextStyle(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _generateTicket,
                          child: const Text('Retry'),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Customer Portal Invite',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Have your customer scan this QR code\nwith the KleenOps app to link their account.',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(color: Colors.grey[600], height: 1.4),
                        ),
                        const SizedBox(height: 32),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: QrImageView(
                            data: _ticketId!,
                            version: QrVersions.auto,
                            size: 240,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.timer_outlined,
                                size: 16, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text(
                              'Expires in 24 hours',
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        OutlinedButton.icon(
                          onPressed: _generateTicket,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Generate New Code'),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}
