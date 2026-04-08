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
  /// rebuild the funnel without waiting for the daily cron.
  Future<void> recomputeFunnelNow({int windowDays = 7}) async {
    final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
        .httpsCallable('recomputeFunnelOnDemand');
    await callable.call({'windowDays': windowDays});
  }
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

  factory OnboardingFunnel.fromMap(Map<String, dynamic> map) {
    final totals = (map['totals'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final screenTime = (map['screenTime'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};

    Map<String, int> intMap(dynamic raw) {
      if (raw is! Map) return const {};
      final out = <String, int>{};
      raw.forEach((k, v) {
        if (k is String && v is num) out[k] = v.toInt();
      });
      return out;
    }

    final stageCounts = <String, int>{};
    totals.forEach((k, v) {
      if (v is num) stageCounts[k] = v.toInt();
    });

    return OnboardingFunnel(
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      windowDays: (map['windowDays'] as num?)?.toInt() ?? 7,
      eventCount: (map['eventCount'] as num?)?.toInt() ?? 0,
      stageCounts: stageCounts,
      forkPickedByBranch: intMap(totals['forkPickedByBranch']),
      businessTypePickedByType: intMap(totals['businessTypePickedByType']),
      sectionOpened: intMap(totals['sectionOpened']),
      sectionCompleted: intMap(totals['sectionCompleted']),
      screenTimeAverageMs: intMap(screenTime['averageMs']),
      screenTimeMedianMs: intMap(screenTime['medianMs']),
      screenTimeSampleCount: intMap(screenTime['sampleCount']),
    );
  }
}
