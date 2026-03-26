import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Company-side view of portal service requests from a customer.
class CustomerRequestsTab extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> customerRef;

  const CustomerRequestsTab({super.key, required this.customerRef});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: customerRef
          .collection('serviceRequest')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Text(
              'No service requests from this customer.',
              style: TextStyle(color: Colors.grey[500]),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 4),
          itemBuilder: (context, index) {
            final data = docs[index].data();
            final requestRef = docs[index].reference;
            return _CompanyRequestTile(
              data: data,
              requestRef: requestRef,
            );
          },
        );
      },
    );
  }
}

class _CompanyRequestTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final DocumentReference<Map<String, dynamic>> requestRef;

  const _CompanyRequestTile({
    required this.data,
    required this.requestRef,
  });

  @override
  Widget build(BuildContext context) {
    final subject = data['subject'] as String? ?? 'No subject';
    final type = data['type'] as String? ?? '';
    final priority = data['priority'] as String? ?? '';
    final status = data['status'] as String? ?? 'open';
    final message = data['message'] as String? ?? '';

    final createdAt = data['createdAt'];
    String dateStr = '';
    if (createdAt is Timestamp) {
      dateStr = DateFormat.yMMMd().add_jm().format(createdAt.toDate());
    }

    final statusColor = switch (status) {
      'open' => Colors.blue,
      'acknowledged' => Colors.orange,
      'in_progress' => Colors.amber,
      'resolved' => Colors.green,
      'closed' => Colors.grey,
      _ => Colors.grey,
    };

    return Card(
      child: ExpansionTile(
        leading: Icon(
          priority == 'urgent'
              ? Icons.priority_high
              : Icons.chat_bubble_outline,
          color: priority == 'urgent' ? Colors.red : null,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(subject,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: statusColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status.replaceAll('_', ' '),
                style: TextStyle(color: statusColor, fontSize: 11),
              ),
            ),
          ],
        ),
        subtitle: Row(
          children: [
            if (type.isNotEmpty)
              Text('$type  ',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            if (dateStr.isNotEmpty)
              Text(dateStr,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          ],
        ),
        children: [
          if (message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(message),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                if (status == 'open')
                  TextButton(
                    onPressed: () => _updateStatus(context, 'acknowledged'),
                    child: const Text('Acknowledge'),
                  ),
                if (status == 'acknowledged' || status == 'open')
                  TextButton(
                    onPressed: () => _updateStatus(context, 'in_progress'),
                    child: const Text('Start'),
                  ),
                if (status != 'resolved' && status != 'closed')
                  TextButton(
                    onPressed: () => _updateStatus(context, 'resolved'),
                    child: const Text('Resolve'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(BuildContext context, String newStatus) async {
    try {
      await requestRef.update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
