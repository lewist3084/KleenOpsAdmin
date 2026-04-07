/* ────────────────────────────────────────────────────────────
   lib/features/onboarding/guides/setup_guide_sheet.dart
   – Reusable carousel bottom sheet for setup guides.
   – Shows slides with Skip (session) and Don't Show Again
     (permanent) options.
   ──────────────────────────────────────────────────────────── */
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'setup_guide_data.dart';
import 'guide_dismissal_provider.dart';

/// Shows a setup guide as a modal bottom sheet.
Future<void> showSetupGuide(
  BuildContext context,
  WidgetRef ref,
  SetupGuide guide,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => _SetupGuideSheetBody(guide: guide),
  );
}

class _SetupGuideSheetBody extends ConsumerStatefulWidget {
  const _SetupGuideSheetBody({required this.guide});
  final SetupGuide guide;

  @override
  ConsumerState<_SetupGuideSheetBody> createState() =>
      _SetupGuideSheetBodyState();
}

class _SetupGuideSheetBodyState
    extends ConsumerState<_SetupGuideSheetBody> {
  final _controller = PageController();
  int _currentPage = 0;
  bool _dontShowAgain = false;

  List<GuideSlide> get _slides => widget.guide.slides;

  void _dismiss() {
    if (_dontShowAgain) {
      dismissGuidePermanently(widget.guide.key);
    } else {
      dismissGuideForSession(ref, widget.guide.key);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _slides.length - 1;
    final slide = _slides[_currentPage];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            /* ─── Handle bar ─── */
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            /* ─── Skip button ─── */
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _dismiss,
                child: const Text('Skip'),
              ),
            ),

            /* ─── Slide content ─── */
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (_, i) {
                  final s = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: s.color.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(s.icon, size: 48, color: s.color),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          s.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: s.color,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          s.body,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: Colors.grey.shade700,
                                height: 1.5,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            /* ─── Dots ─── */
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_slides.length, (i) {
                  final active = i == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active ? slide.color : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),

            /* ─── Next / Get Started button ─── */
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLast
                      ? _dismiss
                      : () => _controller.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: slide.color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(isLast ? 'Get Started' : 'Next'),
                ),
              ),
            ),

            /* ─── Don't show again checkbox ─── */
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _dontShowAgain,
                      onChanged: (v) =>
                          setState(() => _dontShowAgain = v ?? false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () =>
                        setState(() => _dontShowAgain = !_dontShowAgain),
                    child: Text(
                      'Don\'t show this again',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
