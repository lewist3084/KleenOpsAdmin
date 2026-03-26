import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';

/// Company-side screen showing all service requests across all customers.
class CustomerPortalRequestsScreen extends ConsumerWidget {
  const CustomerPortalRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyRef = ref.watch(companyIdProvider).asData?.value;
    if (companyRef == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Customer Requests')),
      body: _AllRequestsList(companyRef: companyRef),
    );
  }
}

class _AllRequestsList extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;

  const _AllRequestsList({required this.companyRef});

  @override
  Widget build(BuildContext context) {
    // Query all customers, then for each, stream their requests.
    // For scalability, we use a collectionGroup query on serviceRequest.
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('customer')
          .orderBy('name')
          .snapshots(),
      builder: (context, custSnap) {
        if (custSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final customers = custSnap.data?.docs ?? [];
        if (customers.isEmpty) {
          return Center(
            child: Text(
              'No customers found.',
              style: TextStyle(color: Colors.grey[500]),
            ),
          );
        }

        return _AggregatedRequestsList(
          companyRef: companyRef,
          customers: customers,
        );
      },
    );
  }
}

class _AggregatedRequestsList extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> customers;

  const _AggregatedRequestsList({
    required this.companyRef,
    required this.customers,
  });

  @override
  Widget build(BuildContext context) {
    // Stream requests per customer and display grouped by customer.
    return ListView.builder(
      itemCount: customers.length,
      itemBuilder: (context, index) {
        final custDoc = customers[index];
        final custName = custDoc.data()['name'] as String? ?? 'Unknown';
        return _CustomerRequestSection(
          customerRef: custDoc.reference,
          customerName: custName,
          companyRef: companyRef,
        );
      },
    );
  }
}

class _CustomerRequestSection extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> customerRef;
  final String customerName;
  final DocumentReference<Map<String, dynamic>> companyRef;

  const _CustomerRequestSection({
    required this.customerRef,
    required this.customerName,
    required this.companyRef,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: customerRef
          .collection('serviceRequest')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();

        // Count open/urgent
        final openCount = docs.where((d) {
          final s = d.data()['status'] as String? ?? 'open';
          return s == 'open' || s == 'acknowledged';
        }).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Row(
                children: [
                  Text(
                    customerName,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (openCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$openCount open',
                        style: TextStyle(
                          color: Colors.red[700],
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ...docs.map((doc) => _CompanyRequestCard(
                  data: doc.data(),
                  requestRef: doc.reference,
                  customerName: customerName,
                )),
            const Divider(),
          ],
        );
      },
    );
  }
}

class _CompanyRequestCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final DocumentReference<Map<String, dynamic>> requestRef;
  final String customerName;

  const _CompanyRequestCard({
    required this.data,
    required this.requestRef,
    required this.customerName,
  });

  @override
  Widget build(BuildContext context) {
    final subject = data['subject'] as String? ?? 'No subject';
    final type = data['type'] as String? ?? '';
    final priority = data['priority'] as String? ?? '';
    final status = data['status'] as String? ?? 'open';

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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Icon(
          priority == 'urgent'
              ? Icons.priority_high
              : Icons.chat_bubble_outline,
          color: priority == 'urgent' ? Colors.red : null,
        ),
        title: Text(subject, maxLines: 1, overflow: TextOverflow.ellipsis),
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
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            border: Border.all(color: statusColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            status.replaceAll('_', ' '),
            style: TextStyle(color: statusColor, fontSize: 11),
          ),
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _CompanyRequestDetailScreen(
                requestRef: requestRef,
                customerName: customerName,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Company-side request detail with message thread and reply capability.
class _CompanyRequestDetailScreen extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> requestRef;
  final String customerName;

  const _CompanyRequestDetailScreen({
    required this.requestRef,
    required this.customerName,
  });

  @override
  State<_CompanyRequestDetailScreen> createState() =>
      _CompanyRequestDetailScreenState();
}

class _CompanyRequestDetailScreenState
    extends State<_CompanyRequestDetailScreen> {
  final _messageCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      await widget.requestRef.collection('portalMessage').add({
        'senderType': 'company',
        'senderName': user?.displayName ?? user?.email ?? 'Support',
        'message': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _messageCtrl.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    try {
      await widget.requestRef.update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Request — ${widget.customerName}'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: _updateStatus,
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: 'acknowledged', child: Text('Acknowledge')),
              const PopupMenuItem(
                  value: 'in_progress', child: Text('Start')),
              const PopupMenuItem(
                  value: 'resolved', child: Text('Resolve')),
              const PopupMenuItem(
                  value: 'closed', child: Text('Close')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Request header
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: widget.requestRef.snapshots(),
            builder: (context, snap) {
              if (!snap.hasData || !snap.data!.exists) {
                return const SizedBox.shrink();
              }
              final data = snap.data!.data() ?? {};
              return _RequestHeaderCompact(data: data);
            },
          ),
          const Divider(height: 1),
          // Messages
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: widget.requestRef
                  .collection('portalMessage')
                  .orderBy('createdAt', descending: false)
                  .snapshots(),
              builder: (context, snap) {
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages yet.\nReply below.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.grey[500]),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    return _CompanyMessageBubble(data: data);
                  },
                );
              },
            ),
          ),
          // Reply input
          const Divider(height: 1),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Type a reply...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendReply(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _sendReply,
                    icon: _sending
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestHeaderCompact extends StatelessWidget {
  final Map<String, dynamic> data;

  const _RequestHeaderCompact({required this.data});

  @override
  Widget build(BuildContext context) {
    final subject = data['subject'] as String? ?? 'No subject';
    final type = data['type'] as String? ?? '';
    final priority = data['priority'] as String? ?? '';
    final status = data['status'] as String? ?? 'open';
    final message = data['message'] as String? ?? '';

    final statusColor = switch (status) {
      'open' => Colors.blue,
      'acknowledged' => Colors.orange,
      'in_progress' => Colors.amber,
      'resolved' => Colors.green,
      'closed' => Colors.grey,
      _ => Colors.grey,
    };

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  subject,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
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
          if (type.isNotEmpty || priority == 'urgent') ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                if (type.isNotEmpty)
                  Text(type,
                      style:
                          TextStyle(color: Colors.grey[600], fontSize: 12)),
                if (priority == 'urgent')
                  Text('URGENT',
                      style: TextStyle(
                          color: Colors.red[700],
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
              ],
            ),
          ],
          if (message.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class _CompanyMessageBubble extends StatelessWidget {
  final Map<String, dynamic> data;

  const _CompanyMessageBubble({required this.data});

  @override
  Widget build(BuildContext context) {
    final senderType = data['senderType'] as String? ?? 'customer';
    final senderName = data['senderName'] as String? ?? '';
    final message = data['message'] as String? ?? '';
    final isCompany = senderType == 'company';

    final createdAt = data['createdAt'];
    String timeStr = '';
    if (createdAt is Timestamp) {
      timeStr = DateFormat.jm().format(createdAt.toDate());
    }

    return Align(
      alignment: isCompany ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isCompany
              ? Theme.of(context).primaryColor
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (senderName.isNotEmpty)
              Text(
                senderName,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: isCompany ? Colors.white70 : Colors.grey[700],
                ),
              ),
            Text(
              message,
              style: TextStyle(
                color: isCompany ? Colors.white : Colors.black87,
              ),
            ),
            if (timeStr.isNotEmpty)
              Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 10,
                    color: isCompany ? Colors.white60 : Colors.grey[500],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
