// Finance Setup Wizard — Phase 2 onboarding.
// Triggered when the owner is ready to connect banking and payments.

import 'package:flutter/material.dart';
import 'package:kleenops_admin/features/admin/models/setup_wizard_data.dart';

const List<WizardCategory> kFinanceSetupCategories = [
  // 1 ── Bank Account
  WizardCategory(
    key: 'bank_account',
    label: 'Business Bank Account',
    icon: Icons.account_balance,
    position: 0,
    items: [
      WizardItem(
        key: 'open_bank_account',
        label: 'Open a Business Bank Account',
        description:
            'Separate your personal and business finances with a dedicated account.',
        icon: Icons.account_balance_outlined,
        position: 0,
        aiAssistAvailable: true,
      ),
      WizardItem(
        key: 'link_bank_plaid',
        label: 'Link Your Bank Account',
        description:
            'Connect your bank via Plaid for automatic transaction syncing.',
        icon: Icons.link,
        position: 1,
      ),
      WizardItem(
        key: 'verify_balances',
        label: 'Verify Account Balances',
        description:
            'Confirm your accounts are connected and balances are syncing.',
        icon: Icons.check_circle_outline,
        position: 2,
      ),
    ],
  ),

  // 2 ── Payment Processing
  WizardCategory(
    key: 'payment_processing',
    label: 'Payment Processing',
    icon: Icons.credit_card,
    position: 1,
    items: [
      WizardItem(
        key: 'setup_stripe',
        label: 'Set Up Stripe',
        description:
            'Accept credit cards, send payment links, and auto-bill clients.',
        icon: Icons.credit_card_outlined,
        position: 0,
        aiAssistAvailable: true,
      ),
      WizardItem(
        key: 'test_payment_link',
        label: 'Send a Test Payment Link',
        description: 'Create a test invoice and send a payment link to verify the flow.',
        icon: Icons.send_outlined,
        position: 1,
      ),
    ],
  ),

  // 3 ── Invoicing
  WizardCategory(
    key: 'invoicing',
    label: 'Invoicing',
    icon: Icons.receipt_long,
    position: 2,
    items: [
      WizardItem(
        key: 'create_first_customer',
        label: 'Add Your First Customer',
        description: 'Create a customer record with billing contact info.',
        icon: Icons.person_add_outlined,
        position: 0,
      ),
      WizardItem(
        key: 'create_first_invoice',
        label: 'Create Your First Invoice',
        description: 'Generate an invoice with line items and send it.',
        icon: Icons.receipt_outlined,
        position: 1,
      ),
      WizardItem(
        key: 'setup_payment_terms',
        label: 'Set Default Payment Terms',
        description: 'Net 15, Net 30, or due on receipt — set your standard terms.',
        icon: Icons.schedule_outlined,
        position: 2,
      ),
    ],
  ),

  // 4 ── Accounting
  WizardCategory(
    key: 'accounting',
    label: 'Accounting & Bookkeeping',
    icon: Icons.calculate,
    position: 3,
    items: [
      WizardItem(
        key: 'setup_chart_of_accounts',
        label: 'Set Up Chart of Accounts',
        description: 'Configure your GL accounts for income, expenses, and assets.',
        icon: Icons.account_tree_outlined,
        position: 0,
        aiAssistAvailable: true,
      ),
      WizardItem(
        key: 'configure_profit_loss',
        label: 'Configure Profit & Loss Sections',
        description: 'Organize your P&L categories for cleaning business reporting.',
        icon: Icons.bar_chart_outlined,
        position: 1,
        aiAssistAvailable: true,
      ),
      WizardItem(
        key: 'setup_payroll_account',
        label: 'Designate Payroll Account',
        description: 'Choose which bank account will be used for payroll disbursement.',
        icon: Icons.payments_outlined,
        position: 2,
      ),
    ],
  ),
];

int get kFinanceSetupTotalItems =>
    kFinanceSetupCategories.fold(0, (sum, c) => sum + c.items.length);
