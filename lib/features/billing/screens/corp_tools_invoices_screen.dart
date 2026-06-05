// lib/features/billing/screens/corp_tools_invoices_screen.dart
//
// Wholesale invoices Northwest Registered Agent bills the KleenOps partner
// account (our cost side of the registered-agent / filing resale). platformAdmin
// only. Lists invoices and lets an admin pay outstanding ones against the
// card-on-file at Corporate Tools.

import 'package:flutter/material.dart';

import '../../../theme/palette.dart';
import '../services/corp_tools_invoices_service.dart';

class CorpToolsInvoicesScreen extends StatefulWidget {
  const CorpToolsInvoicesScreen({super.key});

  static const _palette = adminPalette;

  @override
  State<CorpToolsInvoicesScreen> createState() => _CorpToolsInvoicesScreenState();
}

class _CorpToolsInvoicesScreenState extends State<CorpToolsInvoicesScreen> {
  final _service = CorpToolsInvoicesService.instance;

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _invoices = const [];
  final Set<String> _paying = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _service.list();
      setState(() {
        _invoices = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  bool _isUnpaid(Map<String, dynamic> inv) {
    final s = (inv['status'] ?? '').toString().toLowerCase();
    return s.isNotEmpty && s != 'paid' && s != 'cancelled' && s != 'void';
  }

  String _id(Map<String, dynamic> inv) =>
      (inv['id'] ?? inv['invoice_id'] ?? '').toString();

  Future<void> _pay(Map<String, dynamic> inv) async {
    final id = _id(inv);
    if (id.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _paying.add(id));
    try {
      await _service.pay([id]);
      messenger.showSnackBar(const SnackBar(content: Text('Invoice paid.')));
      await _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Payment failed: $e')));
    } finally {
      if (mounted) setState(() => _paying.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wholesale Invoices'),
        backgroundColor: CorpToolsInvoicesScreen._palette.primary1,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Couldn\'t load invoices:\n$_error',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red.shade700)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_invoices.isEmpty) {
      return const Center(child: Text('No wholesale invoices on the account.'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _invoices.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final inv = _invoices[i];
          final id = _id(inv);
          return _InvoiceTile(
            invoice: inv,
            unpaid: _isUnpaid(inv),
            paying: _paying.contains(id),
            onPay: () => _pay(inv),
          );
        },
      ),
    );
  }
}

class _InvoiceTile extends StatelessWidget {
  const _InvoiceTile({
    required this.invoice,
    required this.unpaid,
    required this.paying,
    required this.onPay,
  });
  final Map<String, dynamic> invoice;
  final bool unpaid;
  final bool paying;
  final VoidCallback onPay;

  String _amount() {
    final raw = invoice['total'] ?? invoice['amount'] ?? invoice['amount_due'];
    if (raw is num) return '\$${raw.toStringAsFixed(2)}';
    return (raw ?? '').toString();
  }

  @override
  Widget build(BuildContext context) {
    final number =
        (invoice['number'] ?? invoice['invoice_number'] ?? invoice['id'] ?? 'Invoice').toString();
    final company = (invoice['company'] ?? invoice['company_name'] ?? '').toString();
    final status = (invoice['status'] ?? '').toString();
    final due = (invoice['due_date'] ?? invoice['created_at'] ?? '').toString();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('#$number',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (company.isNotEmpty) company,
                      if (status.isNotEmpty) status,
                      if (due.isNotEmpty) 'due ${due.split('T').first}',
                    ].join(' · '),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(_amount(), style: const TextStyle(fontWeight: FontWeight.w700)),
            if (unpaid) ...[
              const SizedBox(width: 10),
              paying
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : OutlinedButton(onPressed: onPay, child: const Text('Pay')),
            ],
          ],
        ),
      ),
    );
  }
}
