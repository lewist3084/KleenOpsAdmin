// lib/services/admin_firebase_service.dart
//
// Cross-company Firestore access for the platform admin.
// Queries across all companies rather than scoping to one.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../constants/firestore_paths.dart';

class AdminFirebaseService {
  AdminFirebaseService._();
  static final instance = AdminFirebaseService._();

  FirebaseFirestore get _fs => FirebaseFirestore.instance;

  // ── Company queries ──────────────────────────────────────────────────

  /// Stream of all company documents.
  Stream<QuerySnapshot<Map<String, dynamic>>> allCompanies() {
    return _fs.collection(colCompany).orderBy('name').snapshots();
  }

  /// Single company document.
  DocumentReference<Map<String, dynamic>> companyRef(String companyId) {
    return _fs.collection(colCompany).doc(companyId);
  }

  /// Stream a single company document.
  Stream<DocumentSnapshot<Map<String, dynamic>>> companyStream(
      String companyId) {
    return companyRef(companyId).snapshots();
  }

  // ── Member queries ───────────────────────────────────────────────────

  /// All members for a given company.
  Stream<QuerySnapshot<Map<String, dynamic>>> membersFor(String companyId) {
    return _fs
        .collection(colCompany)
        .doc(companyId)
        .collection(colMember)
        .orderBy('name')
        .snapshots();
  }

  /// Count of active members for a company.
  Future<int> activeMemberCount(String companyId) async {
    final snap = await _fs
        .collection(colCompany)
        .doc(companyId)
        .collection(colMember)
        .where('active', isEqualTo: true)
        .count()
        .get();
    return snap.count ?? 0;
  }

  // ── Cross-company aggregations ───────────────────────────────────────

  /// All users in the platform.
  Stream<QuerySnapshot<Map<String, dynamic>>> allUsers() {
    return _fs.collection(colUser).snapshots();
  }

  /// Timeline events for a company (useful for activity feeds).
  Stream<QuerySnapshot<Map<String, dynamic>>> timelineFor(
    String companyId, {
    int limit = 50,
  }) {
    return _fs
        .collection(colCompany)
        .doc(companyId)
        .collection(colTimeline)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  /// Bank accounts for a company.
  Stream<QuerySnapshot<Map<String, dynamic>>> bankAccountsFor(
      String companyId) {
    return _fs
        .collection(colCompany)
        .doc(companyId)
        .collection(colBankAccount)
        .snapshots();
  }

  // ── Cross-company platform metrics ───────────────────────────────────

  /// Count of all users on the platform.
  Future<int> totalUserCount() async {
    final snap = await _fs.collection(colUser).count().get();
    return snap.count ?? 0;
  }

  /// Count of all companies on the platform.
  Future<int> totalCompanyCount() async {
    final snap = await _fs.collection(colCompany).count().get();
    return snap.count ?? 0;
  }

  /// Count of active companies.
  Future<int> activeCompanyCount() async {
    final snap = await _fs
        .collection(colCompany)
        .where('active', isEqualTo: true)
        .count()
        .get();
    return snap.count ?? 0;
  }

  /// Aggregate members across ALL companies.
  /// Returns {total, active, inactive}.
  Future<Map<String, int>> aggregateMemberCounts() async {
    final companiesSnap = await _fs.collection(colCompany).get();
    int total = 0;
    int active = 0;

    for (final company in companiesSnap.docs) {
      final totalSnap = await _fs
          .collection(colCompany)
          .doc(company.id)
          .collection(colMember)
          .count()
          .get();
      final activeSnap = await _fs
          .collection(colCompany)
          .doc(company.id)
          .collection(colMember)
          .where('active', isEqualTo: true)
          .count()
          .get();
      total += totalSnap.count ?? 0;
      active += activeSnap.count ?? 0;
    }

    return {
      'total': total,
      'active': active,
      'inactive': total - active,
    };
  }

  /// Count companies that have at least one connected Plaid item.
  Future<int> companiesWithBankAccounts() async {
    final companiesSnap = await _fs.collection(colCompany).get();
    int count = 0;
    for (final company in companiesSnap.docs) {
      final plaidSnap = await _fs
          .collection(colCompany)
          .doc(company.id)
          .collection('plaidItem')
          .limit(1)
          .get();
      if (plaidSnap.docs.isNotEmpty) count++;
    }
    return count;
  }

  /// Count total connected bank accounts across all companies.
  Future<int> totalBankAccounts() async {
    final companiesSnap = await _fs.collection(colCompany).get();
    int total = 0;
    for (final company in companiesSnap.docs) {
      final snap = await _fs
          .collection(colCompany)
          .doc(company.id)
          .collection(colBankAccount)
          .count()
          .get();
      total += snap.count ?? 0;
    }
    return total;
  }

  /// Count companies that have at least one phone number.
  Future<int> companiesWithPhoneLines() async {
    final companiesSnap = await _fs.collection(colCompany).get();
    int count = 0;
    for (final company in companiesSnap.docs) {
      final phoneSnap = await _fs
          .collection(colCompany)
          .doc(company.id)
          .collection('phoneNumber')
          .limit(1)
          .get();
      if (phoneSnap.docs.isNotEmpty) count++;
    }
    return count;
  }

  /// Count total phone lines across all companies.
  Future<int> totalPhoneLines() async {
    final companiesSnap = await _fs.collection(colCompany).get();
    int total = 0;
    for (final company in companiesSnap.docs) {
      final snap = await _fs
          .collection(colCompany)
          .doc(company.id)
          .collection('phoneNumber')
          .count()
          .get();
      total += snap.count ?? 0;
    }
    return total;
  }

  /// Read usage doc for a company (e.g. 'voice', 'ai', 'storage').
  /// Path: company/{id}/usage/{usageKey}
  Future<Map<String, dynamic>?> companyUsage(
      String companyId, String usageKey) async {
    final snap = await _fs
        .collection(colCompany)
        .doc(companyId)
        .collection('usage')
        .doc(usageKey)
        .get();
    return snap.data();
  }

  /// Aggregate a numeric field from usage docs across all companies.
  /// E.g. sum 'totalCost' from company/{id}/usage/voice
  Future<double> aggregateUsageField(
      String usageKey, String fieldName) async {
    final companiesSnap = await _fs.collection(colCompany).get();
    double total = 0;
    for (final company in companiesSnap.docs) {
      final snap = await _fs
          .collection(colCompany)
          .doc(company.id)
          .collection('usage')
          .doc(usageKey)
          .get();
      if (snap.exists) {
        final val = snap.data()?[fieldName];
        if (val is num) total += val.toDouble();
      }
    }
    return total;
  }

  /// Aggregate voice interaction counts across all companies.
  /// Returns {voiceCalls, videoCalls, totalCost}.
  Future<Map<String, double>> aggregateVoiceMetrics() async {
    final companiesSnap = await _fs.collection(colCompany).get();
    double voiceCalls = 0;
    double videoCalls = 0;
    double totalCost = 0;
    for (final company in companiesSnap.docs) {
      final snap = await _fs
          .collection(colCompany)
          .doc(company.id)
          .collection('usage')
          .doc('voice')
          .get();
      if (snap.exists) {
        final data = snap.data()!;
        if (data['voiceCalls'] is num) {
          voiceCalls += (data['voiceCalls'] as num).toDouble();
        }
        if (data['videoCalls'] is num) {
          videoCalls += (data['videoCalls'] as num).toDouble();
        }
        if (data['totalCost'] is num) {
          totalCost += (data['totalCost'] as num).toDouble();
        }
      }
    }
    return {
      'voiceCalls': voiceCalls,
      'videoCalls': videoCalls,
      'totalCost': totalCost,
    };
  }

  /// Aggregate AI usage across all companies.
  /// Returns {totalCalls, totalTokens, totalCost}.
  Future<Map<String, double>> aggregateAiMetrics() async {
    final companiesSnap = await _fs.collection(colCompany).get();
    double totalCalls = 0;
    double totalTokens = 0;
    double totalCost = 0;
    for (final company in companiesSnap.docs) {
      final snap = await _fs
          .collection(colCompany)
          .doc(company.id)
          .collection('usage')
          .doc('ai')
          .get();
      if (snap.exists) {
        final data = snap.data()!;
        if (data['totalCalls'] is num) {
          totalCalls += (data['totalCalls'] as num).toDouble();
        }
        if (data['totalTokens'] is num) {
          totalTokens += (data['totalTokens'] as num).toDouble();
        }
        if (data['totalCost'] is num) {
          totalCost += (data['totalCost'] as num).toDouble();
        }
      }
    }
    return {
      'totalCalls': totalCalls,
      'totalTokens': totalTokens,
      'totalCost': totalCost,
    };
  }

  // ── Per-company usage (for platform usage-product charts) ────────────

  /// Per-company value of a cumulative usage metric, sorted descending.
  ///
  /// Usage is rolled up by usageTotals.js into TOP-LEVEL cumulative docs:
  ///   ai    → totalAiUsage/{companyId}    (totalRequestCount, totalInputChars…)
  ///   voice → totalVoiceUsage/{companyId} (totalDurationSeconds, totalCallCount…)
  ///   video → totalVideoUsage/{companyId} (totalDurationSeconds, totalCallCount…)
  /// so [usageKey] selects the collection and [metricField] the field to chart.
  /// Two reads (companies for names + the rollup collection), not N+1.
  Future<List<CompanyUsageDatum>> usageByCompany({
    required String usageKey,
    required String metricField,
  }) async {
    const collectionByKey = {
      'ai': 'totalAiUsage',
      'voice': 'totalVoiceUsage',
      'video': 'totalVideoUsage',
    };
    final collection = collectionByKey[usageKey];
    if (collection == null) return const [];

    final companies = await _fs.collection(colCompany).get();
    final names = {
      for (final c in companies.docs)
        c.id: (c.data()['name'] as String?) ?? c.id,
    };

    final totals = await _fs.collection(collection).get();
    final out = <CompanyUsageDatum>[];
    for (final d in totals.docs) {
      final raw = d.data()[metricField];
      out.add(CompanyUsageDatum(
        companyId: d.id,
        companyName: names[d.id] ?? d.id,
        value: raw is num ? raw.toDouble() : 0.0,
      ));
    }
    out.sort((a, b) => b.value.compareTo(a.value));
    return out;
  }

  // ── Generic sub-collection helper ────────────────────────────────────

  /// Stream any sub-collection under a company.
  Stream<QuerySnapshot<Map<String, dynamic>>> companySubcollection(
    String companyId,
    String subcollection, {
    int? limit,
  }) {
    Query<Map<String, dynamic>> query = _fs
        .collection(colCompany)
        .doc(companyId)
        .collection(subcollection);
    if (limit != null) query = query.limit(limit);
    return query.snapshots();
  }

  // ── Onboarding funnel ───────────────────────────────────────────────

  /// One-shot read of the rolled-up onboarding funnel doc that
  /// `aggregateFunnelDaily` writes. Returns null when the rollup has never
  /// run yet (so the dashboard can show an empty state).
  Future<OnboardingFunnel?> loadOnboardingFunnel() async {
    final snap = await _fs.collection('funnelTotals').doc('onboarding').get();
    if (!snap.exists) return null;
    return OnboardingFunnel.fromMap(snap.data() ?? const {});
  }

  /// Live stream of the same doc — handy for refresh-on-click without a
  /// manual reload, since `recomputeFunnelOnDemand` writes the same doc.
  Stream<OnboardingFunnel?> onboardingFunnelStream() {
    return _fs
        .collection('funnelTotals')
        .doc('onboarding')
        .snapshots()
        .map((snap) =>
            snap.exists ? OnboardingFunnel.fromMap(snap.data() ?? const {}) : null);
  }

  /// Trigger the on-demand callable so the dashboard refresh button can
  /// rebuild the funnel without waiting for the daily cron. The same callable
  /// also rebuilds the engagement-sections doc, so a single refresh updates
  /// both surfaces.
  Future<void> recomputeFunnelNow({int windowDays = 7}) async {
    final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
        .httpsCallable('recomputeFunnelOnDemand');
    await callable.call({'windowDays': windowDays});
  }

  // ── Engagement (navigation / time-in-app) ────────────────────────────

  /// Live stream of the rolled-up `engagementTotals/sections` doc that
  /// `_runEngagementRollup` writes. Null until the rollup first runs.
  Stream<EngagementSections?> engagementSectionsStream() {
    return _fs
        .collection('engagementTotals')
        .doc('sections')
        .snapshots()
        .map((snap) => snap.exists
            ? EngagementSections.fromMap(snap.data() ?? const {})
            : null);
  }
}

// ── Per-company usage datum ───────────────────────────────────────────

/// One company's value for a usage metric, used by platform-product charts.
class CompanyUsageDatum {
  const CompanyUsageDatum({
    required this.companyId,
    required this.companyName,
    required this.value,
  });

  final String companyId;
  final String companyName;
  final double value;
}

// ── Funnel model ──────────────────────────────────────────────────────

/// Typed view of the `funnelTotals/onboarding` doc written by
/// `funnelTotals.js → aggregateFunnelDaily`.
class OnboardingFunnel {
  const OnboardingFunnel({
    required this.updatedAt,
    required this.windowDays,
    required this.eventCount,
    required this.stageCounts,
    required this.forkPickedByBranch,
    required this.businessTypePickedByType,
    required this.sectionOpened,
    required this.sectionCompleted,
    required this.screenTimeAverageMs,
    required this.screenTimeMedianMs,
    required this.screenTimeSampleCount,
    this.byPlatform = const {},
    this.byCohort = const {},
    this.experiments = const {},
  });

  /// When the rollup ran. Null if the doc has no `updatedAt`.
  final DateTime? updatedAt;

  /// How many days back the rollup looked.
  final int windowDays;

  /// Total events scanned during the rollup.
  final int eventCount;

  /// Top-level funnel stage counts. Keys are the snake_case event names
  /// from `funnelTotals.js → ORDERED_FUNNEL_STAGES`.
  final Map<String, int> stageCounts;

  /// Breakdown of `registration_fork_picked` by `branch`. Keys: 'join', 'new'.
  final Map<String, int> forkPickedByBranch;

  /// Breakdown of `business_type_picked` by `type`. Keys: 'internal',
  /// 'facilities'.
  final Map<String, int> businessTypePickedByType;

  /// Per-section open counts. Keys match `setup_dashboard_screen.dart`'s
  /// `_Section.key` values (e.g. 'company_info', 'domain', 'phone').
  final Map<String, int> sectionOpened;
  final Map<String, int> sectionCompleted;

  /// Average / median time on each onboarding route, in milliseconds.
  final Map<String, int> screenTimeAverageMs;
  final Map<String, int> screenTimeMedianMs;
  final Map<String, int> screenTimeSampleCount;

  /// Per-platform slice of the funnel. Keys: 'web', 'mobile'. Each slice
  /// carries the same stage/section/screen-time shape as the overall funnel,
  /// scoped to events fired from that platform. Powers the Mobile/Web tabs.
  final Map<String, FunnelSlice> byPlatform;

  /// Per-cohort slice. Keys: 'new' (company has not fired onboarding_complete)
  /// and 'existing'. Lets us see where new vs returning users drop off.
  final Map<String, FunnelSlice> byCohort;

  /// A/B experiment buckets: experimentKey -> variant -> stage counts. Sourced
  /// from the `experiment`/`variant` params stamped on funnel events by the
  /// client's Remote Config integration.
  final Map<String, Map<String, Map<String, int>>> experiments;

  /// Convenience accessor: the slice for [platform] ('web'/'mobile'), or the
  /// overall funnel as a slice when [platform] is null or absent.
  FunnelSlice sliceFor(String? platform) {
    if (platform == null) return _overallSlice;
    return byPlatform[platform] ?? FunnelSlice.empty;
  }

  FunnelSlice get _overallSlice => FunnelSlice(
        stageCounts: stageCounts,
        sectionOpened: sectionOpened,
        sectionCompleted: sectionCompleted,
        screenTimeAverageMs: screenTimeAverageMs,
        screenTimeMedianMs: screenTimeMedianMs,
        screenTimeSampleCount: screenTimeSampleCount,
      );

  factory OnboardingFunnel.fromMap(Map<String, dynamic> map) {
    final totals = (map['totals'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final screenTime = (map['screenTime'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};

    final stageCounts = <String, int>{};
    totals.forEach((k, v) {
      if (v is num) stageCounts[k] = v.toInt();
    });

    // byPlatform / byCohort each hold a { web|mobile|new|existing: slice } map.
    Map<String, FunnelSlice> sliceMap(dynamic raw) {
      if (raw is! Map) return const {};
      final out = <String, FunnelSlice>{};
      raw.forEach((k, v) {
        if (k is String && v is Map) {
          out[k] = FunnelSlice.fromMap(v.cast<String, dynamic>());
        }
      });
      return out;
    }

    // experiments: experimentKey -> variant -> { stage: count }
    final experiments = <String, Map<String, Map<String, int>>>{};
    final rawExp = map['experiments'];
    if (rawExp is Map) {
      rawExp.forEach((expKey, variants) {
        if (expKey is String && variants is Map) {
          final perVariant = <String, Map<String, int>>{};
          variants.forEach((variant, counts) {
            if (variant is String) {
              final t = (counts is Map && counts['totals'] is Map)
                  ? counts['totals']
                  : counts;
              perVariant[variant] = intMapOf(t);
            }
          });
          experiments[expKey] = perVariant;
        }
      });
    }

    return OnboardingFunnel(
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      windowDays: (map['windowDays'] as num?)?.toInt() ?? 7,
      eventCount: (map['eventCount'] as num?)?.toInt() ?? 0,
      stageCounts: stageCounts,
      forkPickedByBranch: intMapOf(totals['forkPickedByBranch']),
      businessTypePickedByType: intMapOf(totals['businessTypePickedByType']),
      sectionOpened: intMapOf(totals['sectionOpened']),
      sectionCompleted: intMapOf(totals['sectionCompleted']),
      screenTimeAverageMs: intMapOf(screenTime['averageMs']),
      screenTimeMedianMs: intMapOf(screenTime['medianMs']),
      screenTimeSampleCount: intMapOf(screenTime['sampleCount']),
      byPlatform: sliceMap(map['byPlatform']),
      byCohort: sliceMap(map['byCohort']),
      experiments: experiments,
    );
  }
}

/// Coerce a Firestore `{String: num}` map into a typed `{String: int}` map.
/// Top-level so both [OnboardingFunnel] and [FunnelSlice] share it.
Map<String, int> intMapOf(dynamic raw) {
  if (raw is! Map) return const {};
  final out = <String, int>{};
  raw.forEach((k, v) {
    if (k is String && v is num) out[k] = v.toInt();
  });
  return out;
}

/// A platform- or cohort-scoped view of the onboarding funnel. Same shape as
/// the overall funnel's stage/section/screen-time fields, parsed from a
/// `{ totals: {...}, screenTime: {...} }` sub-map in `funnelTotals/onboarding`.
class FunnelSlice {
  const FunnelSlice({
    required this.stageCounts,
    required this.sectionOpened,
    required this.sectionCompleted,
    required this.screenTimeAverageMs,
    required this.screenTimeMedianMs,
    required this.screenTimeSampleCount,
  });

  final Map<String, int> stageCounts;
  final Map<String, int> sectionOpened;
  final Map<String, int> sectionCompleted;
  final Map<String, int> screenTimeAverageMs;
  final Map<String, int> screenTimeMedianMs;
  final Map<String, int> screenTimeSampleCount;

  static const empty = FunnelSlice(
    stageCounts: {},
    sectionOpened: {},
    sectionCompleted: {},
    screenTimeAverageMs: {},
    screenTimeMedianMs: {},
    screenTimeSampleCount: {},
  );

  factory FunnelSlice.fromMap(Map<String, dynamic> map) {
    final totals = (map['totals'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final screenTime = (map['screenTime'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final stageCounts = <String, int>{};
    totals.forEach((k, v) {
      if (v is num) stageCounts[k] = v.toInt();
    });
    return FunnelSlice(
      stageCounts: stageCounts,
      sectionOpened: intMapOf(totals['sectionOpened']),
      sectionCompleted: intMapOf(totals['sectionCompleted']),
      screenTimeAverageMs: intMapOf(screenTime['averageMs']),
      screenTimeMedianMs: intMapOf(screenTime['medianMs']),
      screenTimeSampleCount: intMapOf(screenTime['sampleCount']),
    );
  }
}

// ── Engagement (navigation / time-in-app) model ───────────────────────
//
// Typed view of the `engagementTotals/sections` doc written by
// `funnelTotals.js → _runEngagementRollup`. Sourced from the per-session
// `sessionRollup` docs the customer app flushes on background/logout, so this
// answers "how engaged are people, and where do they spend their time" rather
// than the discrete onboarding funnel.

/// One top-level app section's usage within a slice.
class SectionUsage {
  const SectionUsage({
    required this.section,
    required this.totalMs,
    required this.visits,
    required this.sessions,
  });

  /// Section key derived from the route (e.g. 'tasks', 'scheduling', 'hr').
  final String section;

  /// Total dwell time across all sessions, in milliseconds.
  final int totalMs;

  /// Number of times the section was entered.
  final int visits;

  /// Number of distinct sessions that touched the section.
  final int sessions;

  int get avgMsPerSession => sessions == 0 ? 0 : (totalMs / sessions).round();
}

/// A platform- or cohort-scoped engagement slice.
class EngagementSlice {
  const EngagementSlice({
    required this.sessionCount,
    required this.totalSessionMs,
    required this.sections,
  });

  final int sessionCount;
  final int totalSessionMs;

  /// Per-section usage, sorted descending by [SectionUsage.totalMs].
  final List<SectionUsage> sections;

  /// Average session length across the window, in milliseconds.
  int get avgSessionMs =>
      sessionCount == 0 ? 0 : (totalSessionMs / sessionCount).round();

  static const empty =
      EngagementSlice(sessionCount: 0, totalSessionMs: 0, sections: []);

  factory EngagementSlice.fromMap(Map<String, dynamic> map) {
    final rawSections = map['sections'];
    final sections = <SectionUsage>[];
    if (rawSections is Map) {
      rawSections.forEach((k, v) {
        if (k is String && v is Map) {
          final m = v.cast<String, dynamic>();
          sections.add(SectionUsage(
            section: k,
            totalMs: (m['totalMs'] as num?)?.toInt() ?? 0,
            visits: (m['visits'] as num?)?.toInt() ?? 0,
            sessions: (m['sessions'] as num?)?.toInt() ?? 0,
          ));
        }
      });
    }
    sections.sort((a, b) => b.totalMs.compareTo(a.totalMs));
    return EngagementSlice(
      sessionCount: (map['sessionCount'] as num?)?.toInt() ?? 0,
      totalSessionMs: (map['totalSessionMs'] as num?)?.toInt() ?? 0,
      sections: sections,
    );
  }
}

/// One calendar day of engagement totals, for the time-per-day chart.
class EngagementDay {
  const EngagementDay({
    required this.date,
    required this.sessionCount,
    required this.totalSessionMs,
    required this.sessionCountByPlatform,
  });

  final DateTime date;
  final int sessionCount;
  final int totalSessionMs;

  /// Session count split by platform key ('web'/'mobile') for stacked bars.
  final Map<String, int> sessionCountByPlatform;

  int get avgSessionMs =>
      sessionCount == 0 ? 0 : (totalSessionMs / sessionCount).round();
}

class EngagementSections {
  const EngagementSections({
    required this.updatedAt,
    required this.windowDays,
    required this.byPlatform,
    required this.byCohort,
    required this.perDay,
  });

  final DateTime? updatedAt;
  final int windowDays;
  final Map<String, EngagementSlice> byPlatform;
  final Map<String, EngagementSlice> byCohort;

  /// Daily buckets sorted ascending by date.
  final List<EngagementDay> perDay;

  /// Slice for [platform] ('web'/'mobile'), or empty when absent.
  EngagementSlice sliceFor(String platform) =>
      byPlatform[platform] ?? EngagementSlice.empty;

  factory EngagementSections.fromMap(Map<String, dynamic> map) {
    Map<String, EngagementSlice> sliceMap(dynamic raw) {
      if (raw is! Map) return const {};
      final out = <String, EngagementSlice>{};
      raw.forEach((k, v) {
        if (k is String && v is Map) {
          out[k] = EngagementSlice.fromMap(v.cast<String, dynamic>());
        }
      });
      return out;
    }

    final perDay = <EngagementDay>[];
    final rawDays = map['perDay'];
    if (rawDays is Map) {
      rawDays.forEach((k, v) {
        if (k is String && v is Map) {
          final m = v.cast<String, dynamic>();
          final parsed = DateTime.tryParse(k);
          if (parsed != null) {
            perDay.add(EngagementDay(
              date: parsed,
              sessionCount: (m['sessionCount'] as num?)?.toInt() ?? 0,
              totalSessionMs: (m['totalSessionMs'] as num?)?.toInt() ?? 0,
              sessionCountByPlatform: intMapOf(m['sessionCountByPlatform']),
            ));
          }
        }
      });
    }
    perDay.sort((a, b) => a.date.compareTo(b.date));

    return EngagementSections(
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      windowDays: (map['windowDays'] as num?)?.toInt() ?? 7,
      byPlatform: sliceMap(map['byPlatform']),
      byCohort: sliceMap(map['byCohort']),
      perDay: perDay,
    );
  }
}
