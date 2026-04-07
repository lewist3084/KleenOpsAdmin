import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:qr_plugin/qr_plugin.dart';
import 'package:shared_widgets/containers/container_header.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';

class SalesCustomerDetails extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> customerRef;
  const SalesCustomerDetails({super.key, required this.customerRef});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: customerRef.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!.data() ?? {};
        final name = data['name'] as String? ?? '';
        final portalUid = data['portalUid'] as String?;
        final hasPortal = portalUid != null && portalUid.isNotEmpty;

        return SingleChildScrollView(
          child: Column(
            children: [
              ContainerHeader(
                showImage: false,
                titleHeader: 'Customer',
                title: name,
                descriptionHeader: '',
                description: '',
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: hasPortal
                    ? Card(
                        child: ListTile(
                          leading: const Icon(Icons.check_circle,
                              color: Colors.green),
                          title: const Text('Portal Linked'),
                          subtitle: const Text(
                              'This customer has access to the portal.'),
                        ),
                      )
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.qr_code),
                          label: const Text('Generate Portal Link'),
                          onPressed: () => _generatePortalLink(context),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _generatePortalLink(BuildContext context) async {
    // Extract companyId and customerId from the reference path
    // Path: company/{companyId}/customer/{customerId}
    final segments = customerRef.path.split('/');
    if (segments.length < 4) return;
    final companyId = segments[1];
    final customerId = customerRef.id;

    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('generateCustomerTicket')
          .call({
        'companyId': companyId,
        'customerId': customerId,
      });

      final ticketId = result.data['ticketId'] as String?;
      if (ticketId == null) throw Exception('No ticketId returned');

      if (!context.mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => DialogAction(
          title: 'Customer Portal Invite',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Have your customer scan this QR code '
                'to link their account to your company.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              QrImageView(data: ticketId, size: 200),
              const SizedBox(height: 8),
              Text(
                'Expires in 24 hours',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[500],
                    ),
              ),
            ],
          ),
          cancelText: 'Close',
          onCancel: () => Navigator.pop(ctx),
          actionText: '',
          onAction: () {},
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.message ?? e.code}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
