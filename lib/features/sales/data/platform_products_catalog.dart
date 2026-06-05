// lib/features/sales/data/platform_products_catalog.dart
//
// Canonical definition of every product KleenOps sells to a company. This is
// the single source of truth used by:
//   • the platformProduct catalog seed (Sales → Products),
//   • the per-company service hardwiring (company/{id}/service/{productKey}),
//   • the onCompanyCreated cloud trigger (mirror of the same keys/groups).
//
// The dashboard tiles that used to live on the admin Home screen (Companies &
// Users, Members, Service Adoption, Voice/Video, AI Usage) are modelled here
// as products grouped by those same sections, so the Products tab IS the old
// dashboard, reframed as a sellable catalog.
//
// Products with a [usageKey] are usage-metered: they cost nothing while a
// company stays internal and accrue per-unit charges against the company's
// rolled-up usage docs (totalAiUsage / totalVoiceUsage / totalVideoUsage).
// Products without one are flat (zero-cost platform/seat) or recurring
// (phone numbers — an actual annual cost).

import 'package:cloud_firestore/cloud_firestore.dart';

/// Product group keys — these become the `group` field on each product and the
/// section headers in the grouped Products tab. Ordered as they should appear.
///
///   • Subscriptions    — recurring platform/seat fees (company + user).
///   • AI               — metered Gemini token/request usage.
///   • Telephony         — phone line rental + metered voice/video.
///   • Business Services — formation filing, EIN, registered agent, domain,
///                         virtual address.
///   • Accounting Services — bank connection (and future bookkeeping/payroll).
const List<String> kPlatformProductGroupOrder = <String>[
  'Subscriptions',
  'AI',
  'Telephony',
  'Business Services',
  'Accounting Services',
];

/// Legacy `platformProduct` doc ids that earlier seeds created but the current
/// catalog has retired. The version-gated seed deletes these so they stop
/// showing up under an "Other" group (e.g. the combined `voice_video` doc that
/// the split `voice_minutes` + `video_minutes` products replaced).
const List<String> kRetiredPlatformProductKeys = <String>[
  'voice_video',
];

/// A single sellable platform product. Field names mirror the `platformProduct`
/// Firestore doc shape already read by [PlatformCatalogBody].
class PlatformProductDef {
  const PlatformProductDef({
    required this.key,
    required this.group,
    required this.label,
    required this.description,
    this.priceCents = 0,
    this.costCents = 0,
    this.interval = 'month',
    this.billingType = 'one_time',
    this.provider = '',
    this.active = true,
    this.usageKey,
    this.usageMetric,
    this.unitPriceCents = 0,
    this.unitLabel,
  });

  final String key;
  final String group;
  final String label;
  final String description;

  /// Flat/recurring RETAIL price in cents — what the company is charged.
  final int priceCents;

  /// Our wholesale/base COST in cents — what we pay the upstream provider.
  /// The margin/markup is (priceCents - costCents). Seeded to the wholesale
  /// rate (so markup starts at 0%); editable in Sales → Products.
  final int costCents;

  /// 'month' | 'year' | 'once'.
  final String interval;

  /// 'one_time' | 'recurring' | 'metered'.
  final String billingType;

  /// Upstream provider we actually pay (Plaid, Twilio, Gemini…), if any.
  final String provider;

  final bool active;

  /// Usage rollup key for metered products: 'ai' | 'voice' | 'video'.
  final String? usageKey;

  /// Field on the rollup doc to charge against (e.g. totalRequestCount).
  final String? usageMetric;

  /// Per-unit charge in cents for metered products.
  final int unitPriceCents;

  /// Human unit label for metered products ('request', 'second'…).
  final String? unitLabel;

  bool get isMetered => (usageKey ?? '').isNotEmpty;

  /// Firestore payload for the top-level `platformProduct/{key}` catalog doc.
  Map<String, dynamic> toCatalogPayload() {
    return <String, dynamic>{
      'productKey': key,
      'group': group,
      'label': label,
      'description': description,
      'priceCents': priceCents,
      'costCents': costCents,
      'currency': 'usd',
      'interval': interval,
      'billingType': billingType,
      'provider': provider,
      'active': active,
      if (isMetered) ...{
        'usageKey': usageKey,
        'usageMetric': usageMetric,
        'unitPriceCents': unitPriceCents,
        'unitLabel': unitLabel,
      },
    };
  }

  /// Firestore payload for a company's hardwired `service/{key}` doc — the
  /// per-company record that accrues cost. Created with zeroed usage so the
  /// service exists (and shows on the company) from the moment they join.
  Map<String, dynamic> toCompanyServicePayload() {
    return <String, dynamic>{
      'productKey': key,
      'group': group,
      'label': label,
      'provider': provider,
      'billingType': billingType,
      'interval': interval,
      'priceCents': priceCents,
      if (isMetered) ...{
        'usageKey': usageKey,
        'usageMetric': usageMetric,
        'unitPriceCents': unitPriceCents,
        'unitLabel': unitLabel,
      },
      // Lifecycle: every joining company gets the baseline platform + the
      // usage-metered services wired up; provisioned add-ons (phone numbers)
      // start inactive until actually purchased.
      'status': active ? 'active' : 'available',
      'accruedCents': 0,
    };
  }
}

/// Schema version of the catalog — bump when the product set changes so the
/// auto-seed knows to re-write docs (mirrors the `_seedVersion` pattern used
/// elsewhere in these apps).
const int kPlatformCatalogSeedVersion = 7;

/// The full catalog, grouped by the sections shown in the Products tab.
const List<PlatformProductDef> kPlatformProductCatalog = <PlatformProductDef>[
  // ── Subscriptions (recurring platform + per-seat fees) ──────────────
  PlatformProductDef(
    key: 'company_platform',
    group: 'Subscriptions',
    label: 'Company Subscription',
    description:
        'The complete KleenOps platform for one company. Provisioned when a '
        'company is created — currently no charge.',
    priceCents: 0,
    interval: 'month',
    billingType: 'recurring',
    provider: 'KleenOps',
  ),
  PlatformProductDef(
    key: 'user_seat',
    group: 'Subscriptions',
    label: 'User Seat',
    description:
        'A platform user / member seat. Currently no charge; metered seat '
        'billing can be turned on later.',
    priceCents: 0,
    interval: 'month',
    billingType: 'recurring',
    provider: 'KleenOps',
  ),

  // ── AI (metered Gemini usage) ───────────────────────────────────────
  PlatformProductDef(
    key: 'ai_usage',
    group: 'AI',
    label: 'AI Usage',
    description:
        'Gemini AI requests across the company. Metered per request against '
        'the company\'s rolled-up AI usage.',
    billingType: 'metered',
    interval: 'month',
    provider: 'Gemini',
    usageKey: 'ai',
    usageMetric: 'totalRequestCount',
    unitPriceCents: 0,
    unitLabel: 'request',
  ),

  // ── Telephony (phone line rental + metered voice/video) ─────────────
  PlatformProductDef(
    key: 'phone_number',
    group: 'Telephony',
    label: 'Phone Number',
    description:
        'A provisioned business phone line (Twilio). Base line rental \$1.15 / '
        'month for a US local number (toll-free is \$2.15); per-minute voice '
        'and SMS usage are billed separately. No upcharge.',
    priceCents: 115,
    costCents: 115,
    interval: 'month',
    billingType: 'recurring',
    provider: 'Twilio',
  ),
  PlatformProductDef(
    key: 'voice_minutes',
    group: 'Telephony',
    label: 'Voice Calls',
    description:
        'PSTN voice usage. Zero while calls stay internal; charged per second '
        'of outbound/inbound carrier time.',
    billingType: 'metered',
    interval: 'month',
    provider: 'Twilio',
    usageKey: 'voice',
    usageMetric: 'totalDurationSeconds',
    unitPriceCents: 0,
    unitLabel: 'second',
  ),
  PlatformProductDef(
    key: 'video_minutes',
    group: 'Telephony',
    label: 'Video Calls',
    description:
        'Video room usage. Zero while internal; charged per second of metered '
        'video time.',
    billingType: 'metered',
    interval: 'month',
    provider: 'WebRTC',
    usageKey: 'video',
    usageMetric: 'totalDurationSeconds',
    unitPriceCents: 0,
    unitLabel: 'second',
  ),

  // ── Business Services (formation, EIN, agent, domain, address) ──────
  PlatformProductDef(
    key: 'business_formation_filing',
    group: 'Business Services',
    label: 'Business Formation Filing',
    description:
        'File the company\'s formation papers (Articles of Organization / '
        'Incorporation). Cost = a \$75 filing fee + the state\'s filing fee, '
        'which varies by jurisdiction — priced per state via API at purchase '
        'time, so the catalog price stays \$0.',
    priceCents: 0,
    costCents: 7500, // our $75 NWRA filing fee; the state fee is added per-state at purchase
    interval: 'once',
    billingType: 'one_time',
    provider: 'Northwest Registered Agent',
  ),
  PlatformProductDef(
    key: 'ein_registration',
    group: 'Business Services',
    label: 'EIN Registration',
    description:
        'Obtain the company\'s federal Employer Identification Number from '
        'the IRS. One-time service fee.',
    priceCents: 0,
    interval: 'once',
    billingType: 'one_time',
    provider: 'IRS',
  ),
  PlatformProductDef(
    key: 'registered_agent',
    group: 'Business Services',
    label: 'Registered Agent',
    description:
        'Registered-agent service (receives legal/state correspondence) via '
        'Northwest Registered Agent. Wholesale base rate \$65 per entity, per '
        'state, per year; auto-renews annually.',
    priceCents: 6500,
    costCents: 6500,
    interval: 'year',
    billingType: 'recurring',
    provider: 'Northwest Registered Agent',
  ),
  PlatformProductDef(
    key: 'domain_registration',
    group: 'Business Services',
    label: 'Domain Registration',
    description:
        'Annual domain registration via Cloudflare Registrar. The customer '
        'remains the registrant of record (WHOIS); auto-renews annually.',
    priceCents: 999,
    costCents: 999,
    interval: 'year',
    billingType: 'one_time',
    provider: 'Cloudflare',
  ),
  PlatformProductDef(
    key: 'virtual_address',
    group: 'Business Services',
    label: 'Virtual Business Address',
    description:
        'Non-legal business mailing address for invoices, the website and '
        'bank applications. Mail is scanned and forwarded on request.',
    priceCents: 2900,
    costCents: 2900,
    interval: 'month',
    billingType: 'recurring',
    provider: 'Northwest Registered Agent',
  ),
  // ── Accounting Services (banking; bookkeeping/payroll to follow) ────
  PlatformProductDef(
    key: 'bank_connection',
    group: 'Accounting Services',
    label: 'Bank Connection',
    description:
        'Plaid-backed bank account connection. No charge to connect; a place '
        'to track linked-account costs as they appear.',
    priceCents: 0,
    interval: 'month',
    billingType: 'recurring',
    provider: 'Plaid',
  ),
];

/// Stable ordering index for a group key (groups not in the canonical order
/// sort last, alphabetically).
int platformGroupSortIndex(String group) {
  final i = kPlatformProductGroupOrder.indexOf(group);
  return i < 0 ? kPlatformProductGroupOrder.length : i;
}

/// Resolve the catalog group for a product doc, falling back to a sensible
/// bucket for legacy/hand-added products that predate the `group` field.
String resolveProductGroup(Map<String, dynamic> data) {
  final explicit = (data['group'] as String?)?.trim();
  if (explicit != null && explicit.isNotEmpty) return explicit;
  // Legacy fallback: bucket by what we can infer from the doc.
  final usageKey = (data['usageKey'] as String?)?.trim() ?? '';
  if (usageKey == 'ai') return 'AI';
  if (usageKey == 'voice' || usageKey == 'video') return 'Telephony';
  return 'Other';
}

/// FieldValue.serverTimestamp() helper kept here so callers don't import
/// cloud_firestore just for the timestamp.
FieldValue catalogServerTimestamp() => FieldValue.serverTimestamp();
