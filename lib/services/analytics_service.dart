// lib/services/analytics_service.dart
//
// Single source of truth for funnel + screen-time analytics in the kleenops_admin
// app. Logs each event to BOTH Firebase Analytics (free auto-aggregation,
// Firebase A/B Testing hookpoint, BigQuery export) AND a Firestore mirror at
// `analyticsEvent/{autoId}` so the kleenops_admin_admin dashboard can read raw
// counts directly without depending on BigQuery.
//
// Auto-tracked Firebase Analytics events (first_open, session_start, etc.)
// are NOT mirrored to Firestore — they stay in Firebase Analytics only. Only
// the explicit FunnelEvent values defined below are mirrored.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;

/// Discrete funnel + screen-time event types. The enum name is used as the
/// event name in both Firebase Analytics and the Firestore mirror — keep it
/// snake_case-friendly so the rollup query is straightforward.
enum FunnelEvent {
  // ── Auth ─────────────────────────────────────────
  authSignupStarted,
  authSignupCompleted,

  // ── Registration fork ────────────────────────────
  registrationForkViewed,
  /// params: `{ branch: 'join' | 'new' }`
  registrationForkPicked,

  // ── Business type fork ───────────────────────────
  businessTypeViewed,
  /// params: `{ type: 'internal' | 'facilities' }`
  businessTypePicked,

  // ── Cleaning company name ────────────────────────
  cleaningSetupViewed,
  cleaningSetupCompanyNamed,

  // ── Welcome carousel ─────────────────────────────
  welcomeCarouselViewed,
  welcomeCarouselSkipped,
  welcomeCarouselCompleted,

  // ── Setup dashboard ──────────────────────────────
  setupDashboardViewed,
  /// params: `{ section_key }`
  setupSectionOpened,
  /// params: `{ section_key }`
  setupSectionCompleted,
  setupReviewReached,
  setupPaid,
  onboardingComplete,

  // ── Generic screen-time (NavigatorObserver) ──────
  /// params: `{ screen_name, duration_ms }`
  screenTime,
}

/// Event-name string suitable for Firebase Analytics + Firestore.
String _eventName(FunnelEvent e) {
  switch (e) {
    case FunnelEvent.authSignupStarted:
      return 'auth_signup_started';
    case FunnelEvent.authSignupCompleted:
      return 'auth_signup_completed';
    case FunnelEvent.registrationForkViewed:
      return 'registration_fork_viewed';
    case FunnelEvent.registrationForkPicked:
      return 'registration_fork_picked';
    case FunnelEvent.businessTypeViewed:
      return 'business_type_viewed';
    case FunnelEvent.businessTypePicked:
      return 'business_type_picked';
    case FunnelEvent.cleaningSetupViewed:
      return 'cleaning_setup_viewed';
    case FunnelEvent.cleaningSetupCompanyNamed:
      return 'cleaning_setup_company_named';
    case FunnelEvent.welcomeCarouselViewed:
      return 'welcome_carousel_viewed';
    case FunnelEvent.welcomeCarouselSkipped:
      return 'welcome_carousel_skipped';
    case FunnelEvent.welcomeCarouselCompleted:
      return 'welcome_carousel_completed';
    case FunnelEvent.setupDashboardViewed:
      return 'setup_dashboard_viewed';
    case FunnelEvent.setupSectionOpened:
      return 'setup_section_opened';
    case FunnelEvent.setupSectionCompleted:
      return 'setup_section_completed';
    case FunnelEvent.setupReviewReached:
      return 'setup_review_reached';
    case FunnelEvent.setupPaid:
      return 'setup_paid';
    case FunnelEvent.onboardingComplete:
      return 'onboarding_complete';
    case FunnelEvent.screenTime:
      return 'screen_time';
  }
}

class AnalyticsService {
  AnalyticsService._();
  static final instance = AnalyticsService._();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Log a funnel event. Fires both:
  ///   1. `FirebaseAnalytics.logEvent` (for the free Firebase console UI +
  ///      future Firebase A/B Testing experiments)
  ///   2. A doc in the root `analyticsEvent` collection so the admin
  ///      dashboard rollup function can read it without BigQuery.
  ///
  /// Failures are swallowed and logged via `debugPrint` — analytics never
  /// blocks the user flow.
  Future<void> logFunnelEvent(
    FunnelEvent event, {
    Map<String, Object?>? params,
  }) async {
    final name = _eventName(event);
    final cleanedParams = _stringify(params);

    // Fire and forget Firebase Analytics — no await on the second branch is
    // intentional, but we await the first so test mode can synchronize.
    try {
      await _analytics.logEvent(name: name, parameters: cleanedParams);
    } catch (e) {
      debugPrint('[Analytics] logEvent failed for $name: $e');
    }

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      await FirebaseFirestore.instance.collection('analyticsEvent').add({
        'eventName': name,
        if (uid != null) 'uid': uid,
        if (params != null && params.isNotEmpty) 'params': params,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[Analytics] Firestore mirror failed for $name: $e');
    }
  }

  /// Firebase Analytics requires param values to be String/num/bool. Drop
  /// nulls and coerce everything else to a primitive.
  Map<String, Object>? _stringify(Map<String, Object?>? params) {
    if (params == null || params.isEmpty) return null;
    final out = <String, Object>{};
    for (final entry in params.entries) {
      final v = entry.value;
      if (v == null) continue;
      if (v is num || v is bool || v is String) {
        out[entry.key] = v;
      } else {
        out[entry.key] = v.toString();
      }
    }
    return out.isEmpty ? null : out;
  }
}
