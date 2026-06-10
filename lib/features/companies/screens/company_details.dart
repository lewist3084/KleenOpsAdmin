// lib/features/companies/screens/company_details.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';

import '../../../features/admin/services/email_routing_service.dart';
import '../../../features/admin/widgets/phone_provisioning_dialog.dart';
import '../../../features/auth/widgets/mfa/mfa_gate.dart';
import '../../../features/sales/services/platform_catalog_service.dart';
import '../../../services/admin_firebase_service.dart';
import '../../../theme/palette.dart';

class CompanyDetails extends StatelessWidget {
  final String companyId;

  const CompanyDetails({super.key, required this.companyId});

  Future<void> _provision(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await PlatformCatalogService.instance.provisionCompany(companyId);
      messenger.showSnackBar(
          const SnackBar(content: Text('Services hardwired onto company.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  /// Dry-run, confirm, then auto-mint `first_last@domain` mailboxes for all
  /// active members on the company's active domain (companion to the
  /// `onMemberCreatedProvisionEmail` trigger for future members). Mailbox
  /// creation is free — no Stripe charge.
  Future<void> _provisionMailboxes(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final svc = EmailRoutingService.instance;
    try {
      final preview =
          await svc.backfillMemberEmails(companyId: companyId, dryRun: true);
      final domain = preview['domainName'] as String? ?? '(domain)';
      final toCreate = (preview['created'] as num?)?.toInt() ?? 0;
      final skipped = (preview['skipped'] as num?)?.toInt() ?? 0;
      final total = (preview['totalMembers'] as num?)?.toInt() ?? 0;

      if (!context.mounted) return;
      if (toCreate == 0) {
        messenger.showSnackBar(SnackBar(
          content: Text(
              'Nothing to provision on $domain — $skipped/$total members already have a mailbox.'),
        ));
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Provision member mailboxes'),
          content: Text(
            'Create $toCreate new mailbox(es) on $domain for active members '
            '($skipped already provisioned, $total total). No charge.',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Create $toCreate')),
          ],
        ),
      );
      if (confirmed != true) return;

      final result = await svc.backfillMemberEmails(companyId: companyId);
      final created = (result['created'] as num?)?.toInt() ?? 0;
      final errors = (result['errors'] as num?)?.toInt() ?? 0;
      messenger.showSnackBar(SnackBar(
        content: Text(
            'Provisioned $created mailbox(es) on $domain${errors > 0 ? ' ($errors errors)' : ''}.'),
      ));
    } catch (e) {
      final msg = e.toString().contains('failed-precondition')
          ? 'No active domain for this company — register one first.'
          : 'Failed: $e';
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    const palette = adminPalette;
    final svc = AdminFirebaseService.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Company Details'),
        backgroundColor: palette.primary1,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Provision member mailboxes on the company domain',
            icon: const Icon(Icons.alternate_email),
            onPressed: () => _provisionMailboxes(context),
          ),
          IconButton(
            tooltip: 'Hardwire platform services onto this company',
            icon: const Icon(Icons.cable_outlined),
            onPressed: () => _provision(context),
          ),
        ],
      ),
      // MFA gate: an admin must pass TOTP this session before viewing a
      // customer's books/consumer data in this internal tool.
      body: MfaGate(
        child: StandardCanvas(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: svc.companyStream(companyId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data!.data() ?? {};
            final name = data['name'] as String? ?? '(unnamed)';

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(name,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text('ID: $companyId',
                      style: Theme.of(context).textTheme.bodySmall),
                  const Divider(height: 32),

                  // Members section
                  Text('Members',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: svc.membersFor(companyId),
                    builder: (context, memberSnap) {
                      if (!memberSnap.hasData) {
                        return const CircularProgressIndicator();
                      }
                      final members = memberSnap.data!.docs;
                      return Column(
                        children: [
                          for (final m in members)
                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.person_outline),
                              title: Text(
                                  m.data()['name'] as String? ?? '(no name)'),
                              subtitle: Text(
                                  m.data()['email'] as String? ?? ''),
                              trailing: Icon(
                                Icons.circle,
                                size: 12,
                                color: m.data()['active'] == true
                                    ? palette.primary4
                                    : Colors.grey,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const Divider(height: 32),

                  // Services & subscriptions (platform products this company
                  // has purchased + the admin-side revenue invoices).
                  Text('Services & Subscriptions',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _CompanyServicesSection(companyId: companyId),
                  const Divider(height: 32),

                  // Finance — read-only oversight of this company's books.
                  Text('Finance',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _CompanyFinanceSection(companyId: companyId),
                  const Divider(height: 32),

                  // Recent activity
                  Text('Recent Activity',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: svc.timelineFor(companyId, limit: 10),
                    builder: (context, tlSnap) {
                      if (!tlSnap.hasData) {
                        return const CircularProgressIndicator();
                      }
                      final events = tlSnap.data!.docs;
                      if (events.isEmpty) {
                        return const Text('No recent activity.');
                      }
                      return Column(
                        children: [
                          for (final e in events)
                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.history),
                              title: Text(
                                  e.data()['title'] as String? ?? '(event)'),
                              subtitle: Text(
                                  e.data()['description'] as String? ?? ''),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
        ),
      ),
    );
  }
}

/// Surfaces the platform products/services a company has purchased — the
/// `platformPurchase`/`domain`/`phoneNumber` subcollections — plus the
/// admin-side revenue invoices (`invoice` where `companyId == this`) that the
/// dual-ledger `recordPlatformSale` writes on each purchase.
class _CompanyServicesSection extends StatelessWidget {
  const _CompanyServicesSection({required this.companyId});

  final String companyId;

  @override
  Widget build(BuildContext context) {
    final svc = AdminFirebaseService.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SubList(
          title: 'Hardwired services',
          stream: svc.companySubcollection(companyId, 'service'),
          builder: (d) => _HardwiredServiceTile(companyId: companyId, data: d),
        ),
        _SubList(
          title: 'Purchased products',
          stream: svc.companySubcollection(companyId, 'platformPurchase'),
          builder: (d) {
            final label = d['productLabel'] as String? ??
                d['productKey'] as String? ??
                'Product';
            final cents = (d['amountCents'] as num?)?.toInt();
            final status = d['status'] as String? ?? '';
            final price =
                cents != null ? '  ·  \$${(cents / 100).toStringAsFixed(2)}' : '';
            return _ServiceTile(
              icon: Icons.shopping_bag_outlined,
              title: '$label$price',
              status: status,
            );
          },
        ),
        _SubList(
          title: 'Domains',
          stream: svc.companySubcollection(companyId, 'domain'),
          builder: (d) => _ServiceTile(
            icon: Icons.language,
            title: d['domainName'] as String? ?? '(domain)',
            status: d['status'] as String? ?? '',
          ),
        ),
        _SubList(
          title: 'Phone numbers',
          stream: svc.companySubcollection(companyId, 'phoneNumber'),
          builder: (d) => _ServiceTile(
            icon: Icons.phone_outlined,
            title: d['phoneNumber'] as String? ?? '(number)',
            status: d['status'] as String? ?? '',
          ),
        ),
        _SubList(
          title: 'Revenue (admin invoices)',
          stream: FirebaseFirestore.instance
              .collection('invoice')
              .where('companyId', isEqualTo: companyId)
              .snapshots(),
          builder: (d) {
            final number = d['invoiceNumber']?.toString() ?? '—';
            final total = (d['total'] as num?)?.toDouble() ?? 0;
            return _ServiceTile(
              icon: Icons.receipt_long_outlined,
              title: 'Invoice #$number  ·  \$${total.toStringAsFixed(2)}',
              status: d['status'] as String? ?? '',
            );
          },
        ),
      ],
    );
  }
}

/// Read-only oversight of a company's own books: bank accounts (balances) and
/// recent transactions, read from `company/{companyId}` subcollections. The
/// overlord views but does not edit a customer's books.
class _CompanyFinanceSection extends StatelessWidget {
  const _CompanyFinanceSection({required this.companyId});

  final String companyId;

  CollectionReference<Map<String, dynamic>> _col(String name) =>
      FirebaseFirestore.instance
          .collection('company')
          .doc(companyId)
          .collection(name);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SubList(
          title: 'Bank accounts',
          stream: _col('bankAccount').where('active', isEqualTo: true).snapshots(),
          builder: (d) {
            final name = (d['name'] ?? '(account)').toString();
            final mask = (d['mask'] ?? '').toString();
            final bal = d['currentBalance'];
            final balStr =
                bal is num ? '\$${bal.toStringAsFixed(2)}' : '—';
            return _ServiceTile(
              icon: Icons.account_balance,
              title: '$name${mask.isNotEmpty ? ' ••$mask' : ''}  ·  $balStr',
              status: '',
            );
          },
        ),
        _SubList(
          title: 'Recent transactions',
          stream: _col('bankTransaction')
              .orderBy('date', descending: true)
              .limit(12)
              .snapshots(),
          builder: (d) {
            final merchant =
                (d['merchantName'] ?? d['name'] ?? 'Unknown').toString();
            final amount = (d['amount'] as num?)?.toDouble() ?? 0.0;
            final reconciled = d['reconciled'] == true;
            final isIncome = amount < 0;
            final amtStr =
                '${isIncome ? '+' : '-'}\$${amount.abs().toStringAsFixed(2)}';
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                reconciled ? Icons.check_circle : Icons.schedule,
                size: 18,
                color: reconciled ? Colors.green : Colors.orange,
              ),
              title: Text(merchant,
                  style: const TextStyle(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              trailing: Text(
                amtStr,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isIncome ? Colors.green.shade700 : Colors.black87,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SubList extends StatelessWidget {
  const _SubList({
    required this.title,
    required this.stream,
    required this.builder,
  });

  final String title;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final Widget Function(Map<String, dynamic> data) builder;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snap) {
              if (snap.hasError) {
                return Text('Error: ${snap.error}',
                    style: const TextStyle(fontSize: 12, color: Colors.red));
              }
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return Text('None',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade500));
              }
              return Column(
                children: [for (final d in docs) builder(d.data())],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.icon,
    required this.title,
    required this.status,
  });

  final IconData icon;
  final String title;
  final String status;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, size: 20),
      title: Text(title, style: const TextStyle(fontSize: 13)),
      trailing: status.isEmpty
          ? null
          : Text(
              status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: (status == 'active' || status == 'paid')
                    ? Colors.green
                    : Colors.orange,
              ),
            ),
    );
  }
}

/// A hardwired-service row with a per-service action menu. Every service can be
/// marked purchased (records the company-side cost + a `platformPurchase`).
/// Services with a real provisioning backend (phone) also offer "Provision",
/// which opens the provisioning dialog targeted at THIS company.
class _HardwiredServiceTile extends StatelessWidget {
  const _HardwiredServiceTile({required this.companyId, required this.data});

  final String companyId;
  final Map<String, dynamic> data;

  bool get _canProvision => (data['productKey'] as String?) == 'phone_number';

  Future<void> _markPurchased(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final productKey = data['productKey'] as String? ?? '';
    if (productKey.isEmpty) return;
    try {
      await PlatformCatalogService.instance
          .recordServicePurchase(companyId, productKey);
      messenger.showSnackBar(
          SnackBar(content: Text('Recorded purchase of $productKey.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  void _provision(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => PhoneProvisioningDialog(
        itemData: const {},
        companyOverride: AdminFirebaseService.instance.companyRef(companyId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final label =
        data['label'] as String? ?? data['productKey'] as String? ?? 'Service';
    final group = data['group'] as String? ?? '';
    final metered = (data['usageKey'] as String?)?.isNotEmpty == true;
    final accrued = (data['accruedCents'] as num?)?.toInt() ?? 0;
    final status = data['status'] as String? ?? '';
    final detail = [
      if (group.isNotEmpty) group,
      if (metered) 'metered' else 'flat',
      '\$${(accrued / 100).toStringAsFixed(2)} accrued',
    ].join('  ·  ');

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.cable_outlined, size: 20),
      title: Text('$label  —  $detail', style: const TextStyle(fontSize: 13)),
      subtitle: metered
          ? FutureBuilder<double>(
              future: AdminFirebaseService.instance
                  .estimatedServiceChargeCents(companyId, data),
              builder: (context, snap) {
                final cents = snap.data ?? 0;
                if (cents <= 0) return const SizedBox.shrink();
                return Text(
                  'Est. \$${(cents / 100).toStringAsFixed(2)} unbilled',
                  style: TextStyle(
                      fontSize: 11, color: Colors.green.shade700),
                );
              },
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status.isNotEmpty)
            Text(
              status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: (status == 'active' || status == 'paid')
                    ? Colors.green
                    : Colors.orange,
              ),
            ),
          PopupMenuButton<String>(
            tooltip: 'Service actions',
            icon: const Icon(Icons.more_vert, size: 18),
            onSelected: (v) {
              if (v == 'purchase') _markPurchased(context);
              if (v == 'provision') _provision(context);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'purchase',
                child: Text('Mark purchased'),
              ),
              if (_canProvision)
                const PopupMenuItem(
                  value: 'provision',
                  child: Text('Provision number'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
