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
///
///   • voice_video           — split earlier into voice_minutes + video_minutes.
///   • voice_minutes/video_minutes — internal WebRTC usage is FREE; only Twilio
///                             PSTN voice/SMS tied to a purchased number bills,
///                             via the new voice_local/voice_intl/text_* products.
///   • ai_usage              — replaced by per-model ai_input_tokens/ai_output_tokens.
const List<String> kRetiredPlatformProductKeys = <String>[
  'voice_video',
  'voice_minutes',
  'video_minutes',
  'ai_usage',
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
    this.hardwired = false,
    this.usageKey,
    this.usageMetric,
    this.unitPriceCents = 0,
    this.unitLabel,
    this.perModel = false,
    this.modelRatesCents,
    this.seatBilled = false,
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

  /// Whether this product is CONNECTED/hardwired to every company (auto-attached
  /// as a `company/{id}/service/{key}` doc and billed by measured consumption),
  /// versus an à-la-carte product sold on invoices (sales history from paid
  /// invoices). Subscriptions/AI/Telephony/Accounting are hardwired; Business
  /// Services are not.
  final bool hardwired;

  /// Usage rollup key for metered products: 'ai' | 'voice' | 'video' | 'pstn' |
  /// 'plaid'. Maps to the matching top-level totals collection server-side.
  final String? usageKey;

  /// Field on the rollup doc to charge against (e.g. totalInputTokens,
  /// localVoiceMinutes, syncCount).
  final String? usageMetric;

  /// Per-unit charge in cents for metered products. May be fractional (e.g.
  /// a per-token rate), so this is stored as a [num].
  final num unitPriceCents;

  /// Human unit label for metered products ('token', 'minute', 'message'…).
  final String? unitLabel;

  /// When true the product is billed PER MODEL: usage is tracked in a per-model
  /// map on the totals doc (e.g. inputTokensByModel) and each model is charged at
  /// its own rate from [modelRatesCents]. Used for AI token products.
  final bool perModel;

  /// Per-model unit rates in cents (model id → ¢ per unit) for [perModel]
  /// products. Editable in Sales → Products.
  final Map<String, num>? modelRatesCents;

  /// When true this recurring product is billed by the seat runner as
  /// (activeMemberCount × priceCents) rather than by the metered-usage engine.
  final bool seatBilled;

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
      'hardwired': hardwired,
      if (seatBilled) 'seatBilled': true,
      if (isMetered) ...{
        'usageKey': usageKey,
        'usageMetric': usageMetric,
        'unitPriceCents': unitPriceCents,
        'unitLabel': unitLabel,
        if (perModel) ...{
          'perModel': true,
          'modelRatesCents': modelRatesCents ?? <String, num>{},
        },
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
      'hardwired': hardwired,
      if (seatBilled) 'seatBilled': true,
      if (isMetered) ...{
        'usageKey': usageKey,
        'usageMetric': usageMetric,
        'unitPriceCents': unitPriceCents,
        'unitLabel': unitLabel,
        if (perModel) ...{
          'perModel': true,
          'modelRatesCents': modelRatesCents ?? <String, num>{},
        },
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
const int kPlatformCatalogSeedVersion = 8;

/// The full catalog, grouped by the sections shown in the Products tab.
const List<PlatformProductDef> kPlatformProductCatalog = <PlatformProductDef>[
  // ── Subscriptions (recurring platform + per-seat fees) ──────────────
  // Hardwired: connected to every company and billed by the recurring runner.
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
    hardwired: true,
  ),
  PlatformProductDef(
    key: 'user_seat',
    group: 'Subscriptions',
    label: 'Member Seat',
    description:
        'Per-member annual subscription. Each active member of a company costs '
        '\$10.00 / year; billed as (active members × price) by the recurring '
        'subscription runner.',
    priceCents: 1000,
    costCents: 1000,
    interval: 'year',
    billingType: 'recurring',
    provider: 'KleenOps',
    hardwired: true,
    seatBilled: true,
  ),

  // ── AI (metered Gemini token usage, per model) ──────────────────────
  // Tokens are read from firebase_ai usageMetadata and tracked per model, so
  // input/output can be priced separately at each model's real rate.
  PlatformProductDef(
    key: 'ai_input_tokens',
    group: 'AI',
    label: 'AI Input Tokens',
    description:
        'Prompt (input) tokens consumed by Gemini/Imagen/Veo across the company, '
        'tracked per model. Priced per token at each model\'s rate; set rates in '
        'the per-model editor.',
    billingType: 'metered',
    interval: 'month',
    provider: 'Gemini',
    hardwired: true,
    usageKey: 'ai',
    usageMetric: 'totalInputTokens',
    unitPriceCents: 0,
    unitLabel: 'token',
    perModel: true,
    // Cents per token (≈ $/1M ÷ 10,000). Placeholders — admin scales these.
    modelRatesCents: <String, num>{
      'gemini-2.5-flash': 0.00003, // ~$0.30 / 1M input tokens
      'gemini-2.5-pro': 0.000125, // ~$1.25 / 1M input tokens
    },
  ),
  PlatformProductDef(
    key: 'ai_output_tokens',
    group: 'AI',
    label: 'AI Output Tokens',
    description:
        'Generated (output) tokens produced by Gemini across the company, '
        'tracked per model. Priced per token at each model\'s rate; set rates in '
        'the per-model editor.',
    billingType: 'metered',
    interval: 'month',
    provider: 'Gemini',
    hardwired: true,
    usageKey: 'ai',
    usageMetric: 'totalOutputTokens',
    unitPriceCents: 0,
    unitLabel: 'token',
    perModel: true,
    modelRatesCents: <String, num>{
      'gemini-2.5-flash': 0.00025, // ~$2.50 / 1M output tokens
      'gemini-2.5-pro': 0.001, // ~$10.00 / 1M output tokens
    },
  ),

  // ── Telephony (phone line rental + metered PSTN voice/SMS) ──────────
  // Internal WebRTC voice/video is FREE. Only usage tied to a purchased Twilio
  // number bills: local/international voice (per minute) and text (per segment).
  PlatformProductDef(
    key: 'phone_number',
    group: 'Telephony',
    label: 'Phone Number',
    description:
        'A provisioned business phone line (Twilio), billed annually up front. '
        'US local number line rental is \$1.15 / month = \$13.80 / year; '
        'per-minute voice and per-message text usage are billed separately.',
    priceCents: 1380,
    costCents: 1380,
    interval: 'year',
    billingType: 'recurring',
    provider: 'Twilio',
    hardwired: true,
  ),
  PlatformProductDef(
    key: 'voice_local',
    group: 'Telephony',
    label: 'Local Calls',
    description:
        'Domestic (NANP / +1) PSTN voice minutes on a purchased number. Twilio '
        'base ≈ \$0.014 / min outbound, \$0.0085 / min inbound. Metered per minute.',
    billingType: 'metered',
    interval: 'month',
    provider: 'Twilio',
    hardwired: true,
    usageKey: 'pstn',
    usageMetric: 'localVoiceMinutes',
    unitPriceCents: 1.4,
    unitLabel: 'minute',
  ),
  PlatformProductDef(
    key: 'voice_intl',
    group: 'Telephony',
    label: 'International Calls',
    description:
        'International PSTN voice minutes on a purchased number. Twilio rates '
        'vary widely by destination (≈ \$0.01–\$0.10+ / min). Metered per minute; '
        'set your blended base rate.',
    billingType: 'metered',
    interval: 'month',
    provider: 'Twilio',
    hardwired: true,
    usageKey: 'pstn',
    usageMetric: 'intlVoiceMinutes',
    unitPriceCents: 5,
    unitLabel: 'minute',
  ),
  PlatformProductDef(
    key: 'text_local',
    group: 'Telephony',
    label: 'Local Text',
    description:
        'Domestic (US A2P) SMS/MMS segments on a purchased number. Twilio base '
        '≈ \$0.0079 / segment plus carrier fees. Metered per message segment.',
    billingType: 'metered',
    interval: 'month',
    provider: 'Twilio',
    hardwired: true,
    usageKey: 'pstn',
    usageMetric: 'localTextSegments',
    unitPriceCents: 0.79,
    unitLabel: 'message',
  ),
  PlatformProductDef(
    key: 'text_intl',
    group: 'Telephony',
    label: 'International Text',
    description:
        'International SMS/MMS segments on a purchased number. Twilio rates vary '
        'by destination. Metered per message segment; set your blended base rate.',
    billingType: 'metered',
    interval: 'month',
    provider: 'Twilio',
    hardwired: true,
    usageKey: 'pstn',
    usageMetric: 'intlTextSegments',
    unitPriceCents: 5,
    unitLabel: 'message',
  ),

  // ── Business Services (formation, EIN, agent, domain, address) ──────
  // À-la-carte: NOT hardwired; sold per company via invoices (sales history
  // aggregates from paid invoices, like the main app's product flow).
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
  // ── Accounting Services (Plaid; bookkeeping/payroll to follow) ──────
  // Hardwired + metered against per-company Plaid activity. Rates are
  // placeholders — set them once your Plaid contract terms are confirmed.
  PlatformProductDef(
    key: 'bank_connection',
    group: 'Accounting Services',
    label: 'Bank Connection',
    description:
        'A Plaid-linked bank connection (Item). Charged once per new bank '
        'institution a company links. Metered per connection.',
    billingType: 'metered',
    interval: 'month',
    provider: 'Plaid',
    hardwired: true,
    usageKey: 'plaid',
    usageMetric: 'connectionCount',
    unitPriceCents: 0,
    unitLabel: 'connection',
  ),
  PlatformProductDef(
    key: 'plaid_sync',
    group: 'Accounting Services',
    label: 'Transaction Sync',
    description:
        'Ongoing Plaid transaction pulls (webhook + on-demand syncs) that keep '
        'a company\'s books current. Metered per sync.',
    billingType: 'metered',
    interval: 'month',
    provider: 'Plaid',
    hardwired: true,
    usageKey: 'plaid',
    usageMetric: 'syncCount',
    unitPriceCents: 0,
    unitLabel: 'sync',
  ),
  PlatformProductDef(
    key: 'ach_payment',
    group: 'Accounting Services',
    label: 'ACH Payment',
    description:
        'Plaid-verified ACH bank payment setup / transfers. Metered per '
        'transfer.',
    billingType: 'metered',
    interval: 'month',
    provider: 'Plaid',
    hardwired: true,
    usageKey: 'plaid',
    usageMetric: 'achCount',
    unitPriceCents: 0,
    unitLabel: 'transfer',
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
  if (usageKey == 'voice' || usageKey == 'video' || usageKey == 'pstn') {
    return 'Telephony';
  }
  if (usageKey == 'plaid') return 'Accounting Services';
  return 'Other';
}

/// FieldValue.serverTimestamp() helper kept here so callers don't import
/// cloud_firestore just for the timestamp.
FieldValue catalogServerTimestamp() => FieldValue.serverTimestamp();
