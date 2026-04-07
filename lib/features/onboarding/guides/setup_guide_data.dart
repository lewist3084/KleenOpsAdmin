/* ────────────────────────────────────────────────────────────
   lib/features/onboarding/guides/setup_guide_data.dart
   – Data model and definitions for contextual setup guides.
   – Each guide has a unique key, a set of slides, and belongs
     to a section of the app.
   ──────────────────────────────────────────────────────────── */
import 'package:flutter/material.dart';

/* ─── Slide model ─────────────────────────────────────────── */

class GuideSlide {
  const GuideSlide({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });
  final IconData icon;
  final String title;
  final String body;
  final Color color;
}

/* ─── Guide model ─────────────────────────────────────────── */

class SetupGuide {
  const SetupGuide({
    required this.key,
    required this.title,
    required this.slides,
  });

  /// Unique key stored in Firestore for permanent dismissal.
  final String key;

  /// Display title (shown in menu drawer).
  final String title;

  /// Ordered slides for the carousel.
  final List<GuideSlide> slides;
}

/* ═══════════════════════════════════════════════════════════
   Guide definitions — KleenOps Admin (platform operator)
   ═══════════════════════════════════════════════════════════ */

const mainGuide = SetupGuide(
  key: 'main',
  title: 'Getting Started',
  slides: [
    GuideSlide(
      icon: Icons.admin_panel_settings,
      title: 'Welcome to KleenOps Admin',
      body: 'Your command center for managing the KleenOps platform. '
          'Set up your business operations, oversee client companies, '
          'and keep everything running smoothly.',
      color: Color(0xFF002E5D),
    ),
    GuideSlide(
      icon: Icons.business,
      title: 'Set Up Your Business',
      body: 'Configure your platform company identity, register your '
          'domain, and complete your business formation — all from '
          'the Admin section.',
      color: Color(0xFF1565C0),
    ),
    GuideSlide(
      icon: Icons.account_balance,
      title: 'Connect Your Finances',
      body: 'Link your bank accounts with Plaid, set up payment '
          'processing with Stripe, and manage invoicing and payroll.',
      color: Color(0xFF6A1B9A),
    ),
    GuideSlide(
      icon: Icons.people,
      title: 'Build Your Team',
      body: 'Add employees, assign roles, set up benefits, and '
          'manage onboarding workflows for your platform team.',
      color: Color(0xFFC62828),
    ),
    GuideSlide(
      icon: Icons.gavel,
      title: 'Stay Compliant',
      body: 'Upload legal documents, track insurance expirations, '
          'and manage contracts — the Legal section keeps you covered.',
      color: Color(0xFF2E7D32),
    ),
  ],
);

const financeGuide = SetupGuide(
  key: 'finance',
  title: 'Finance Setup',
  slides: [
    GuideSlide(
      icon: Icons.account_balance,
      title: 'Connect Your Bank',
      body: 'Link your platform business bank account securely '
          'with Plaid for automated reconciliation and reporting.',
      color: Color(0xFFE65100),
    ),
    GuideSlide(
      icon: Icons.credit_card,
      title: 'Payment Processing',
      body: 'Stripe is pre-configured for your platform. Accept '
          'payments from client companies and manage billing '
          'with no additional setup fees.',
      color: Color(0xFF1565C0),
    ),
    GuideSlide(
      icon: Icons.receipt_long,
      title: 'Invoicing & Bills',
      body: 'Create invoices for client companies, track bills '
          'from vendors, and manage all payment flows from one place.',
      color: Color(0xFF2E7D32),
    ),
    GuideSlide(
      icon: Icons.account_balance_wallet,
      title: 'Payroll & Reporting',
      body: 'Run payroll for your platform team, generate W-2s, '
          'and track revenue, expenses, and profitability.',
      color: Color(0xFF6A1B9A),
    ),
  ],
);

const hrGuide = SetupGuide(
  key: 'hr',
  title: 'HR Setup',
  slides: [
    GuideSlide(
      icon: Icons.person_add,
      title: 'Add Your Team',
      body: 'Invite platform team members, assign roles '
          '(admin, support, operations), and set up your '
          'organizational structure.',
      color: Color(0xFFC62828),
    ),
    GuideSlide(
      icon: Icons.badge,
      title: 'Onboarding Workflows',
      body: 'Create customizable onboarding templates with '
          'tax forms, direct deposit, I-9 verification, '
          'and policy acknowledgements.',
      color: Color(0xFF1565C0),
    ),
    GuideSlide(
      icon: Icons.health_and_safety,
      title: 'Benefits & Time Off',
      body: 'Set up benefit plans, manage enrollments, and '
          'configure time-off policies for your platform employees.',
      color: Color(0xFF2E7D32),
    ),
    GuideSlide(
      icon: Icons.schedule,
      title: 'Time Tracking & Documents',
      body: 'Track employee hours, manage HR documents, '
          'and maintain a complete employee record system.',
      color: Color(0xFF6A1B9A),
    ),
  ],
);

const adminGuide = SetupGuide(
  key: 'admin',
  title: 'Admin Setup',
  slides: [
    GuideSlide(
      icon: Icons.apartment,
      title: 'Business Identity',
      body: 'Set your platform company name, logo, and tagline. '
          'This is the identity that client companies will see.',
      color: Color(0xFF002E5D),
    ),
    GuideSlide(
      icon: Icons.description,
      title: 'Formation & Tax IDs',
      body: 'Complete your business formation, upload incorporation '
          'documents, and register your EIN, NAICS codes, and DUNS number.',
      color: Color(0xFF1565C0),
    ),
    GuideSlide(
      icon: Icons.verified_user,
      title: 'Licenses & Insurance',
      body: 'Register with the Secretary of State, obtain required '
          'licenses, and upload your insurance certificates.',
      color: Color(0xFF2E7D32),
    ),
    GuideSlide(
      icon: Icons.policy,
      title: 'Policies & Compliance',
      body: 'Create service agreements, set pricing policies, '
          'and establish your safety plan. The Setup Wizard '
          'walks you through everything step by step.',
      color: Color(0xFF6A1B9A),
    ),
  ],
);

const legalGuide = SetupGuide(
  key: 'legal',
  title: 'Legal Setup',
  slides: [
    GuideSlide(
      icon: Icons.description,
      title: 'Business Documents',
      body: 'Upload your EIN letter, business license, articles of '
          'incorporation, and operating agreement to keep everything '
          'in one secure place.',
      color: Color(0xFF6A1B9A),
    ),
    GuideSlide(
      icon: Icons.verified_user,
      title: 'Insurance & Bonding',
      body: 'Add your general liability, commercial auto, workers\' comp, '
          'and umbrella policies. We\'ll track expiration dates for you.',
      color: Color(0xFF2E7D32),
    ),
    GuideSlide(
      icon: Icons.gavel,
      title: 'Compliance Tracking',
      body: 'Track federal and state compliance requirements. '
          'Each state has different rules — the compliance dashboard '
          'keeps you on top of deadlines.',
      color: Color(0xFF1565C0),
    ),
    GuideSlide(
      icon: Icons.handshake,
      title: 'Contracts',
      body: 'Manage service contracts with client companies, vendor '
          'agreements, and any other legal documents your platform needs.',
      color: Color(0xFFE65100),
    ),
  ],
);

const salesGuide = SetupGuide(
  key: 'sales',
  title: 'Sales Setup',
  slides: [
    GuideSlide(
      icon: Icons.sell,
      title: 'Track Your Sales',
      body: 'Manage your sales pipeline, track deals, and monitor '
          'revenue across all your client companies.',
      color: Color(0xFFE65100),
    ),
    GuideSlide(
      icon: Icons.campaign,
      title: 'Marketing',
      body: 'Create and manage marketing campaigns, track ad '
          'performance, and measure your return on investment.',
      color: Color(0xFF1565C0),
    ),
    GuideSlide(
      icon: Icons.receipt_long,
      title: 'Quotes & Proposals',
      body: 'Generate professional quotes for prospective clients. '
          'Convert accepted quotes into active contracts seamlessly.',
      color: Color(0xFF2E7D32),
    ),
    GuideSlide(
      icon: Icons.bar_chart,
      title: 'Sales Analytics',
      body: 'Visualize sales trends, conversion rates, and revenue '
          'growth with built-in dashboards and reports.',
      color: Color(0xFF6A1B9A),
    ),
  ],
);

const purchasingGuide = SetupGuide(
  key: 'purchasing',
  title: 'Purchasing Setup',
  slides: [
    GuideSlide(
      icon: Icons.receipt_long,
      title: 'Purchase Orders',
      body: 'Create and track purchase orders for supplies, '
          'equipment, and services your platform needs.',
      color: Color(0xFF1565C0),
    ),
    GuideSlide(
      icon: Icons.inventory_2,
      title: 'Objects & Assets',
      body: 'Manage your catalog of objects and assets. Track '
          'what you have, what you need, and where it all is.',
      color: Color(0xFFE65100),
    ),
    GuideSlide(
      icon: Icons.store,
      title: 'Vendors',
      body: 'Maintain a directory of your vendors and suppliers. '
          'Compare pricing, track performance, and manage relationships.',
      color: Color(0xFF2E7D32),
    ),
    GuideSlide(
      icon: Icons.bar_chart,
      title: 'Spending Analytics',
      body: 'Monitor purchasing trends, track spending by category, '
          'and identify opportunities to reduce costs.',
      color: Color(0xFF6A1B9A),
    ),
  ],
);

const inventoryGuide = SetupGuide(
  key: 'inventory',
  title: 'Inventory Setup',
  slides: [
    GuideSlide(
      icon: Icons.inventory_2,
      title: 'Stock Management',
      body: 'Track cleaning supplies, equipment, and materials '
          'across all your locations and client sites.',
      color: Color(0xFFE65100),
    ),
    GuideSlide(
      icon: Icons.playlist_add,
      title: 'Inventory Requests',
      body: 'Submit and manage requests for new supplies. '
          'Teams can request what they need directly from the app.',
      color: Color(0xFF1565C0),
    ),
    GuideSlide(
      icon: Icons.local_shipping,
      title: 'Fulfillment',
      body: 'Track fulfillment of inventory requests. See what\'s '
          'been shipped, delivered, and what\'s still pending.',
      color: Color(0xFF2E7D32),
    ),
    GuideSlide(
      icon: Icons.bar_chart,
      title: 'Inventory Analytics',
      body: 'Monitor stock levels, usage rates, and reorder points. '
          'Never run out of critical supplies again.',
      color: Color(0xFF6A1B9A),
    ),
  ],
);

/// All guides, for listing in the menu drawer.
const allGuides = [
  mainGuide,
  financeGuide,
  hrGuide,
  adminGuide,
  legalGuide,
  salesGuide,
  purchasingGuide,
  inventoryGuide,
];

/// Lookup by key.
SetupGuide? guideForKey(String key) {
  for (final g in allGuides) {
    if (g.key == key) return g;
  }
  return null;
}
