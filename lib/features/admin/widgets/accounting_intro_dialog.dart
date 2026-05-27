import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:shared_widgets/theme/app_palette.dart';
import '../services/setup_wizard_service.dart';

/// Intro dialog for the built-in accounting (Plaid-backed) wizard step.
class AccountingIntroDialog extends StatefulWidget {
  final SetupWizardService service;

  /// Optional company reference kept for call-site compatibility. Admin uses
  /// top-level collections, so the value is not used internally.
  final DocumentReference<Map<String, dynamic>>? companyRef;

  const AccountingIntroDialog({
    super.key,
    required this.service,
    this.companyRef,
  });

  @override
  State<AccountingIntroDialog> createState() => _AccountingIntroDialogState();
}

class _AccountingIntroDialogState extends State<AccountingIntroDialog> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteScope.of(context);
    return DialogAction(
      title: 'Free Built-in Accounting',
      cancelText: 'Later',
      onCancel: () => Navigator.pop(context),
      actionText: _saving ? 'Saving…' : 'Got it',
      onAction: _saving
          ? null
          : () async {
              setState(() => _saving = true);
              await widget.service
                  .completeItem('accounting_intro', data: {'acknowledged': true});
              if (!mounted) return;
              if (context.mounted) Navigator.pop(context);
            },
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'You don\'t need QuickBooks.',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your software already includes a full general ledger, invoicing, '
            'expense tracking, and bank reconciliation — at no extra cost.',
            style: TextStyle(fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 14),
          _benefitRow(palette.primary1, Icons.sync,
              'Transactions auto-import from your bank and cards.'),
          _benefitRow(palette.primary1, Icons.category_outlined,
              'AI auto-categorizes expenses and matches them to invoices.'),
          _benefitRow(palette.primary1, Icons.receipt_long_outlined,
              'Invoices, bills, and reports (P&L, Balance Sheet) ready to go.'),
          _benefitRow(palette.primary1, Icons.lock_outline,
              'Bank credentials never touch our servers — secured via Plaid.'),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline,
                    size: 18, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Next: link your bank account and credit card so '
                    'transactions start flowing in right away.',
                    style: TextStyle(fontSize: 12, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _benefitRow(Color accent, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 13, height: 1.3)),
          ),
        ],
      ),
    );
  }
}
