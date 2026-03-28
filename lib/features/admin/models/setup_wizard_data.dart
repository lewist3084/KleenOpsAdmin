/// Categories and items for the Business Setup Wizard.
///
/// Each category groups related checklist items. Items are ordered to build
/// momentum (easiest/most exciting first).

import 'package:flutter/material.dart';

// ── Item status ────────────────────────────────────────────────────────────

enum WizardItemStatus { notStarted, inProgress, complete, skipped }

String wizardStatusLabel(WizardItemStatus s) {
  switch (s) {
    case WizardItemStatus.notStarted:
      return 'Start';
    case WizardItemStatus.inProgress:
      return 'Continue';
    case WizardItemStatus.complete:
      return 'Done';
    case WizardItemStatus.skipped:
      return 'Skipped';
  }
}

Color wizardStatusColor(WizardItemStatus s) {
  switch (s) {
    case WizardItemStatus.notStarted:
      return Colors.grey.shade300;
    case WizardItemStatus.inProgress:
      return Colors.amber.shade200;
    case WizardItemStatus.complete:
      return Colors.green.shade300;
    case WizardItemStatus.skipped:
      return Colors.grey.shade200;
  }
}

WizardItemStatus parseWizardStatus(String? raw) {
  switch (raw) {
    case 'in_progress':
      return WizardItemStatus.inProgress;
    case 'complete':
      return WizardItemStatus.complete;
    case 'skipped':
      return WizardItemStatus.skipped;
    default:
      return WizardItemStatus.notStarted;
  }
}

String wizardStatusToString(WizardItemStatus s) {
  switch (s) {
    case WizardItemStatus.notStarted:
      return 'not_started';
    case WizardItemStatus.inProgress:
      return 'in_progress';
    case WizardItemStatus.complete:
      return 'complete';
    case WizardItemStatus.skipped:
      return 'skipped';
  }
}

// ── Category definition ────────────────────────────────────────────────────

class WizardCategory {
  final String key;
  final String label;
  final IconData icon;
  final int position;
  final List<WizardItem> items;

  const WizardCategory({
    required this.key,
    required this.label,
    required this.icon,
    required this.position,
    required this.items,
  });
}

// ── Item definition ────────────────────────────────────────────────────────

class WizardItem {
  final String key;
  final String label;
  final String description;
  final IconData icon;
  final int position;
  final bool aiAssistAvailable;

  const WizardItem({
    required this.key,
    required this.label,
    required this.description,
    required this.icon,
    required this.position,
    this.aiAssistAvailable = false,
  });
}

// ── Admin Setup Wizard ─────────────────────────────────────────────────────
//
// Phase 1: Get the business legally formed and operational.
// No employees required. No bank account required.
// Banking/Plaid setup lives in the Finance section.
// Employee-related compliance triggers when first employee is added in HR.

const List<WizardCategory> kSetupWizardCategories = [
  // 1 ── Business Identity
  WizardCategory(
    key: 'business_identity',
    label: 'Business Identity',
    icon: Icons.storefront,
    position: 0,
    items: [
      WizardItem(
        key: 'business_name',
        label: 'Choose Your Business Name',
        description: 'Pick a name and check availability in your state.',
        icon: Icons.label_outline,
        position: 0,
        aiAssistAvailable: true,
      ),
      WizardItem(
        key: 'business_logo',
        label: 'Upload or Create a Logo',
        description: 'Upload your logo or let AI generate concepts.',
        icon: Icons.image_outlined,
        position: 1,
        aiAssistAvailable: true,
      ),
      WizardItem(
        key: 'business_tagline',
        label: 'Create a Tagline / Mission',
        description: 'A short statement that defines your business.',
        icon: Icons.format_quote,
        position: 2,
        aiAssistAvailable: true,
      ),
    ],
  ),

  // 2 ── Location & Contact
  WizardCategory(
    key: 'business_location',
    label: 'Business Location & Contact',
    icon: Icons.location_on,
    position: 1,
    items: [
      WizardItem(
        key: 'primary_address',
        label: 'Set Business Address',
        description: 'Your primary business or mailing address.',
        icon: Icons.home_work_outlined,
        position: 0,
      ),
      WizardItem(
        key: 'business_phone',
        label: 'Get a Business Phone Number',
        description: 'Enter your number or get a new one.',
        icon: Icons.phone_outlined,
        position: 1,
        aiAssistAvailable: true,
      ),
      WizardItem(
        key: 'business_email',
        label: 'Set Up Business Email',
        description: 'Professional email with your own domain.',
        icon: Icons.email_outlined,
        position: 2,
        aiAssistAvailable: true,
      ),
      WizardItem(
        key: 'business_website',
        label: 'Set Up a Website / Domain',
        description: 'Register a domain and create a landing page.',
        icon: Icons.language,
        position: 3,
        aiAssistAvailable: true,
      ),
    ],
  ),

  // 3 ── Business Formation
  WizardCategory(
    key: 'business_formation',
    label: 'Business Formation',
    icon: Icons.account_balance,
    position: 2,
    items: [
      WizardItem(
        key: 'entity_type',
        label: 'Choose Your Entity Type',
        description: 'LLC, S-Corp, C-Corp, Sole Proprietorship, or Partnership.',
        icon: Icons.account_tree_outlined,
        position: 0,
        aiAssistAvailable: true,
      ),
      WizardItem(
        key: 'state_of_incorporation',
        label: 'Select State of Incorporation',
        description: 'Which state will you file in?',
        icon: Icons.flag_outlined,
        position: 1,
        aiAssistAvailable: true,
      ),
      WizardItem(
        key: 'file_formation_docs',
        label: 'File Formation Documents',
        description: 'Articles of Organization / Incorporation.',
        icon: Icons.description_outlined,
        position: 2,
        aiAssistAvailable: true,
      ),
      WizardItem(
        key: 'operating_agreement',
        label: 'Create Operating Agreement',
        description: 'Defines ownership structure and responsibilities.',
        icon: Icons.handshake_outlined,
        position: 3,
        aiAssistAvailable: true,
      ),
    ],
  ),

  // 4 ── Tax IDs & Federal
  WizardCategory(
    key: 'tax_ids',
    label: 'Tax IDs & Federal Registration',
    icon: Icons.badge,
    position: 3,
    items: [
      WizardItem(
        key: 'ein_application',
        label: 'Apply for EIN (Tax ID)',
        description: 'Your federal Employer Identification Number.',
        icon: Icons.badge_outlined,
        position: 0,
        aiAssistAvailable: true,
      ),
      WizardItem(
        key: 'naics_sic_codes',
        label: 'Set Industry Classification Codes',
        description: 'NAICS 561720 (Janitorial Services) and SIC 7349.',
        icon: Icons.category_outlined,
        position: 1,
        aiAssistAvailable: true,
      ),
      WizardItem(
        key: 'duns_number',
        label: 'Get a DUNS Number (Optional)',
        description: 'Needed for government contracts.',
        icon: Icons.numbers,
        position: 2,
      ),
    ],
  ),

  // 5 ── State Registrations & Licenses
  WizardCategory(
    key: 'state_registrations',
    label: 'State Registrations & Licenses',
    icon: Icons.verified,
    position: 4,
    items: [
      WizardItem(
        key: 'state_business_registration',
        label: 'Register with Secretary of State',
        description: 'File your business with the state.',
        icon: Icons.how_to_reg_outlined,
        position: 0,
        aiAssistAvailable: true,
      ),
      WizardItem(
        key: 'state_tax_registration',
        label: 'Register for State Taxes',
        description: 'Sales tax registration for your state.',
        icon: Icons.receipt_outlined,
        position: 1,
        aiAssistAvailable: true,
      ),
      WizardItem(
        key: 'local_business_license',
        label: 'Get Local Business License(s)',
        description: 'City or county licenses for your area.',
        icon: Icons.location_city_outlined,
        position: 2,
        aiAssistAvailable: true,
      ),
      WizardItem(
        key: 'janitorial_license',
        label: 'Janitorial Contractor License',
        description: 'Required in some states for cleaning businesses.',
        icon: Icons.cleaning_services_outlined,
        position: 3,
        aiAssistAvailable: true,
      ),
      WizardItem(
        key: 'janitorial_bond',
        label: 'Surety / Janitorial Bond',
        description: 'Required in some states for bonded cleaning services.',
        icon: Icons.verified_user_outlined,
        position: 4,
        aiAssistAvailable: true,
      ),
    ],
  ),

  // 6 ── Insurance (solo operator — no workers' comp yet)
  WizardCategory(
    key: 'insurance',
    label: 'Insurance',
    icon: Icons.shield,
    position: 5,
    items: [
      WizardItem(
        key: 'general_liability',
        label: 'General Liability Insurance',
        description: 'Protects against property damage and injury claims.',
        icon: Icons.shield_outlined,
        position: 0,
        aiAssistAvailable: true,
      ),
      WizardItem(
        key: 'commercial_auto',
        label: 'Commercial Auto Insurance',
        description: 'If your business uses vehicles.',
        icon: Icons.directions_car_outlined,
        position: 1,
      ),
      WizardItem(
        key: 'umbrella_policy',
        label: 'Umbrella / Excess Liability (Optional)',
        description: 'Additional coverage above your other policies.',
        icon: Icons.umbrella_outlined,
        position: 2,
      ),
    ],
  ),

  // 7 ── Policies & Agreements (what you need to start serving clients)
  WizardCategory(
    key: 'policies_procedures',
    label: 'Policies & Agreements',
    icon: Icons.policy,
    position: 6,
    items: [
      WizardItem(
        key: 'service_agreement',
        label: 'Create Client Service Agreement',
        description: 'Scope of work, pricing, and terms for your clients.',
        icon: Icons.article_outlined,
        position: 0,
        aiAssistAvailable: true,
      ),
      WizardItem(
        key: 'pricing_structure',
        label: 'Define Your Pricing Structure',
        description: 'Hourly, per-sqft, or flat rate pricing.',
        icon: Icons.attach_money,
        position: 1,
        aiAssistAvailable: true,
      ),
      WizardItem(
        key: 'cancellation_policy',
        label: 'Set Cancellation Policy',
        description: 'Notice period, fees, and terms.',
        icon: Icons.event_busy_outlined,
        position: 2,
        aiAssistAvailable: true,
      ),
      WizardItem(
        key: 'safety_plan',
        label: 'Create a Safety Plan',
        description: 'Chemical handling, PPE, and emergency procedures.',
        icon: Icons.health_and_safety,
        position: 3,
        aiAssistAvailable: true,
      ),
    ],
  ),
];

/// Total count of all wizard items.
int get kSetupWizardTotalItems =>
    kSetupWizardCategories.fold(0, (sum, c) => sum + c.items.length);
