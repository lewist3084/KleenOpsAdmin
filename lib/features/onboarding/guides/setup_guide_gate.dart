/* ────────────────────────────────────────────────────────────
   lib/features/onboarding/guides/setup_guide_gate.dart
   – Wraps a section screen. On first build, if the guide for
     this section hasn't been dismissed (session or permanent),
     shows the guide sheet automatically.
   – Usage:
       SetupGuideGate(
         guide: hrGuide,
         child: const HrHomeScreen(),
       )
   ──────────────────────────────────────────────────────────── */
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'setup_guide_data.dart';
import 'setup_guide_sheet.dart';
import 'guide_dismissal_provider.dart';

class SetupGuideGate extends ConsumerStatefulWidget {
  const SetupGuideGate({
    required this.guide,
    required this.child,
    super.key,
  });

  final SetupGuide guide;
  final Widget child;

  @override
  ConsumerState<SetupGuideGate> createState() => _SetupGuideGateState();
}

class _SetupGuideGateState extends ConsumerState<SetupGuideGate> {
  bool _checked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_checked) {
      _checked = true;
      _maybeShowGuide();
    }
  }

  Future<void> _maybeShowGuide() async {
    // Wait for the permanent-dismissals stream to load before checking.
    // Without this, the StreamProvider is still in AsyncLoading on the
    // first frame and asData?.value falls back to {} — which would re-show
    // a guide the user previously tapped "Don't show again" on.
    try {
      await ref.read(permanentDismissedGuidesProvider.future);
    } catch (_) {
      // Stream errored; fall through to session-only check.
    }
    if (!mounted) return;

    final shouldShow = ref.read(shouldShowGuideProvider(widget.guide.key));
    if (shouldShow) {
      showSetupGuide(context, ref, widget.guide);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
