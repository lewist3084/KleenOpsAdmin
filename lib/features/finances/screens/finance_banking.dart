// finance_banking.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/features/finances/services/plaid_service.dart';
import 'package:kleenops_admin/theme/palette.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';

class FinanceBankingScreen extends StatelessWidget {
  const FinanceBankingScreen({super.key});

  Widget _wrapCanvas(Widget child) {
    return StandardCanvas(
      child: SafeArea(
        top: true,
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(child: child),
            const Positioned(
              left: 0, right: 0, top: 0,
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
      body: _wrapCanvas(const FinanceBankingContent()),
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final menuSections = MenuDrawerSections(
            actions: [
              ContentMenuItem(
                icon: Icons.home_outlined,
                label: 'Finances Home',
                onTap: () => context.push(AppRoutePaths.financeHome),
              ),
              ContentMenuItem(
                icon: Icons.list_alt_outlined,
                label: 'Ledger',
                onTap: () => context.push(AppRoutePaths.financeLedger),
              ),
              ContentMenuItem(
                icon: Icons.account_balance_outlined,
                label: 'Accounts',
                onTap: () => context.push(AppRoutePaths.financeAccounts),
              ),
            ],
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DetailsAppBar(
                title: 'Banking',
                menuSections: menuSections,
              ),
              const HomeNavBarAdapter(),
            ],
          );
        },
      ),
    );
  }
}

class FinanceBankingContent extends ConsumerStatefulWidget {
  const FinanceBankingContent({super.key});

  @override
  ConsumerState<FinanceBankingContent> createState() =>
      _FinanceBankingContentState();
}

class _FinanceBankingContentState extends ConsumerState<FinanceBankingContent> {
  bool _connecting = false;
  bool _syncing = false;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteScope.of(context);
    final companyAsync = ref.watch(companyIdProvider);

    return companyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (companyRef) {
        if (companyRef == null) {
          return const Center(child: Text('No company found'));
        }

        final plaidService = PlaidService(companyRef: companyRef);

        return Column(
          children: [
            // Connect Bank button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _connecting
                      ? null
                      : () => _connectBank(plaidService),
                  icon: _connecting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_business),
                  label: Text(_connecting
                      ? 'Connecting...'
                      : 'Connect Bank Account'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.primary1,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),

            // Connected Institutions
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: plaidService.watchPlaidItems(),
                builder: (context, itemsSnap) {
                  if (itemsSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final items = itemsSnap.data?.docs ?? [];

                  if (items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.account_balance,
                              size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No bank accounts connected',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap "Connect Bank Account" to get started',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final data = item.data();
                      return _InstitutionCard(
                        itemId: item.id,
                        data: data,
                        plaidService: plaidService,
                        companyRef: companyRef,
                        syncing: _syncing,
                        onSync: () => _syncItem(plaidService, item.id),
                        onRemove: () => _removeItem(
                          context,
                          plaidService,
                          item.id,
                          data['institutionName'] ?? 'this institution',
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _connectBank(PlaidService service) async {
    setState(() => _connecting = true);
    try {
      final success = await service.openPlaidLink();
      if (mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bank account connected successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error connecting bank: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _syncItem(PlaidService service, String itemId) async {
    setState(() => _syncing = true);
    try {
      final result = await service.syncTransactions(itemId);
      await service.getBalances(itemId);
      if (mounted) {
        final added = result['added'] ?? 0;
        final modified = result['modified'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Synced: $added new, $modified updated transactions'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _removeItem(
    BuildContext context,
    PlaidService service,
    String itemId,
    String institutionName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect Institution'),
        content: Text(
            'Are you sure you want to disconnect $institutionName? '
            'This will deactivate all linked accounts.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await service.removeInstitution(itemId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$institutionName disconnected')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error disconnecting: $e')),
          );
        }
      }
    }
  }
}

class _InstitutionCard extends StatelessWidget {
  const _InstitutionCard({
    required this.itemId,
    required this.data,
    required this.plaidService,
    required this.companyRef,
    required this.syncing,
    required this.onSync,
    required this.onRemove,
  });

  final String itemId;
  final Map<String, dynamic> data;
  final PlaidService plaidService;
  final DocumentReference<Map<String, dynamic>> companyRef;
  final bool syncing;
  final VoidCallback onSync;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final institutionName = data['institutionName'] ?? 'Unknown Institution';
    final status = data['status'] ?? 'unknown';
    final lastSynced = data['lastSynced'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Institution header
          ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.account_balance),
            ),
            title: Text(
              institutionName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              status == 'active'
                  ? (lastSynced != null
                      ? 'Last synced: ${_formatDate(lastSynced)}'
                      : 'Never synced')
                  : 'Status: $status',
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'sync') onSync();
                if (value == 'remove') onRemove();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'sync',
                  child: ListTile(
                    leading: Icon(Icons.sync),
                    title: Text('Sync Now'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'remove',
                  child: ListTile(
                    leading: Icon(Icons.link_off, color: Colors.red),
                    title: Text('Disconnect',
                        style: TextStyle(color: Colors.red)),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),

          // Bank accounts under this institution
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('bankAccount')
                .where('plaidItemId', isEqualTo: itemId)
                .where('active', isEqualTo: true)
                .snapshots(),
            builder: (context, snap) {
              final accounts = snap.data?.docs ?? [];
              if (accounts.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text('No accounts found',
                      style: TextStyle(color: Colors.grey)),
                );
              }

              return Column(
                children: [
                  const Divider(height: 1),
                  ...accounts.map((acctDoc) {
                    final acct = acctDoc.data();
                    final name = acct['name'] ?? '';
                    final mask = acct['mask'] ?? '';
                    final type = acct['subtype'] ?? acct['type'] ?? '';
                    final balance = acct['currentBalance'];
                    final balanceStr = balance != null
                        ? '\$${balance.toStringAsFixed(2)}'
                        : '--';
                    final isPayroll = acct['isPayrollAccount'] == true;

                    return ListTile(
                      dense: true,
                      leading: Icon(
                        _accountIcon(acct['type'] ?? ''),
                        size: 20,
                        color: Colors.grey[700],
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                                '$name${mask.isNotEmpty ? ' ••$mask' : ''}'),
                          ),
                          if (isPayroll) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: Colors.green[300]!),
                              ),
                              child: Text(
                                'PAYROLL',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green[800],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(type),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            balanceStr,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          if (!isPayroll) ...[
                            const SizedBox(width: 4),
                            PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              iconSize: 18,
                              onSelected: (value) {
                                if (value == 'payroll') {
                                  plaidService
                                      .setPayrollAccount(acctDoc.id);
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'payroll',
                                  child: Text('Set as Payroll Account',
                                      style: TextStyle(fontSize: 13)),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  IconData _accountIcon(String type) {
    switch (type) {
      case 'depository':
        return Icons.savings;
      case 'credit':
        return Icons.credit_card;
      case 'loan':
        return Icons.money_off;
      case 'investment':
        return Icons.trending_up;
      default:
        return Icons.account_balance_wallet;
    }
  }

  String _formatDate(Timestamp ts) {
    final date = ts.toDate();
    return '${date.month}/${date.day}/${date.year} '
        '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
