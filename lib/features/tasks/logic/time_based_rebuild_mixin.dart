import 'dart:async';

import 'package:flutter/widgets.dart';

/// Forces a rebuild at known upcoming time boundaries (and immediately on
/// app resume), so screens whose `build()` reads `DateTime.now()` stay in
/// sync with reality without polling.
///
/// **Why:** iOS aggressively suspends background apps and pauses
/// `Timer.periodic`. A purely poll-based refresh also produces visible
/// drift between teammates (one device ticks at :02, another at :04, so
/// the same blackout window "ends" at different wall-clock times). With
/// this mixin a screen schedules a precise one-off Timer at each known
/// boundary — blackout end, priority-delay completion, training
/// expiry, etc. — so all devices flip state within their local
/// clock-sync tolerance (typically <500ms on NTP-synced phones).
///
/// A 5-minute safety-net periodic Timer also runs so any boundary the
/// screen didn't enumerate still gets picked up reasonably soon.
///
/// Usage:
/// ```dart
/// class _MyScreenState extends State<MyScreen>
///     with WidgetsBindingObserver, TimeBasedRebuildMixin<MyScreen> {
///   @override
///   Widget build(BuildContext context) {
///     // ... compute visible items ...
///     scheduleRebuildAt(earliestUpcomingBoundary(visibleData, now));
///     return ...;
///   }
/// }
/// ```
mixin TimeBasedRebuildMixin<T extends StatefulWidget>
    on State<T>, WidgetsBindingObserver {
  Timer? _periodicTimer;
  Timer? _boundaryTimer;
  DateTime? _boundaryScheduledFor;
  // ignore: unused_field
  int _rebuildTick = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _periodicTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _triggerRebuild(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _periodicTimer?.cancel();
    _boundaryTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _triggerRebuild();
    super.didChangeAppLifecycleState(state);
  }

  /// Subclass hook fired right before each rebuild triggered by this
  /// mixin — useful for refreshing dependent providers (e.g. an
  /// hour-truncated window anchor) before the build sees them.
  void onTimeBoundaryReached() {}

  void _triggerRebuild() {
    if (!mounted) return;
    onTimeBoundaryReached();
    setState(() => _rebuildTick++);
  }

  /// Call from `build()` (after computing visible items) with the
  /// earliest known upcoming boundary, or `null` to clear the precise
  /// timer. Idempotent — passing the same target again no-ops. The
  /// 5-minute safety-net timer continues to run in parallel.
  void scheduleRebuildAt(DateTime? next) {
    if (next == null) {
      _boundaryTimer?.cancel();
      _boundaryTimer = null;
      _boundaryScheduledFor = null;
      return;
    }
    if (_boundaryScheduledFor == next &&
        (_boundaryTimer?.isActive ?? false)) {
      return;
    }
    final delay = next.difference(DateTime.now());
    if (delay.isNegative || delay == Duration.zero) return;
    _boundaryTimer?.cancel();
    _boundaryScheduledFor = next;
    _boundaryTimer = Timer(delay, _triggerRebuild);
  }
}
