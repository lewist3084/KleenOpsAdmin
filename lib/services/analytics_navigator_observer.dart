// lib/services/analytics_navigator_observer.dart
//
// NavigatorObserver that times users on onboarding routes and emits a
// `screen_time` FunnelEvent when they leave. Filtered to onboarding-prefixed
// routes only (per the analytics scope decision in the plan):
//
//   /registration/*
//   /welcome
//   /setup/*
//
// To extend to other areas of the app later, just relax the `_isTracked`
// filter — no per-screen instrumentation needed elsewhere.

import 'package:flutter/widgets.dart';

import 'analytics_service.dart';

class AnalyticsNavigatorObserver extends NavigatorObserver {
  final Map<String, DateTime> _enterTimes = <String, DateTime>{};

  bool _isTracked(String? name) {
    if (name == null || name.isEmpty) return false;
    return name.startsWith('/registration') ||
        name == '/welcome' ||
        name.startsWith('/setup');
  }

  String? _routeName(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name == null || name.isEmpty) return null;
    return name;
  }

  void _start(Route<dynamic>? route) {
    final name = _routeName(route);
    if (!_isTracked(name)) return;
    _enterTimes[name!] = DateTime.now();
  }

  void _stop(Route<dynamic>? route) {
    final name = _routeName(route);
    if (!_isTracked(name)) return;
    final start = _enterTimes.remove(name!);
    if (start == null) return;
    final durationMs = DateTime.now().difference(start).inMilliseconds;
    if (durationMs <= 0) return;
    AnalyticsService.instance.logFunnelEvent(
      FunnelEvent.screenTime,
      params: {
        'screen_name': name,
        'duration_ms': durationMs,
      },
    );
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _start(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _stop(oldRoute);
    _start(newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _stop(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _stop(route);
  }
}
