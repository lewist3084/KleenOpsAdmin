// lib/features/registration/widgets/fork_card.dart
//
// Reusable carousel-style "fork" card used in the registration flow.
// Shows a circular icon, title, body text, and a list of large option
// buttons. Optionally renders a back arrow in the top-left.

import 'package:flutter/material.dart';

class ForkOption {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color? color;
  final VoidCallback onTap;

  const ForkOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.color,
  });
}

class ForkCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color color;
  final List<ForkOption> options;
  final VoidCallback? onBack;

  const ForkCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
    required this.options,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    /* ─── Circular icon ─── */
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 56, color: color),
                    ),
                    const SizedBox(height: 32),

                    /* ─── Title ─── */
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    /* ─── Body ─── */
                    Text(
                      body,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.grey.shade700,
                            height: 1.5,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),

                    /* ─── Option buttons ─── */
                    ...options.map((opt) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _ForkOptionButton(
                            option: opt,
                            defaultColor: color,
                          ),
                        )),
                  ],
                ),
              ),
            ),
            // Back arrow last so it sits on top of the scroll view
            // and receives taps even when the content fills the screen.
            if (onBack != null)
              Positioned(
                top: 8,
                left: 8,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: onBack,
                  tooltip: 'Back',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ForkOptionButton extends StatelessWidget {
  final ForkOption option;
  final Color defaultColor;

  const _ForkOptionButton({
    required this.option,
    required this.defaultColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = option.color ?? defaultColor;

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.white,
        elevation: 1,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: option.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(option.icon, size: 26, color: color),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.label,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (option.subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          option.subtitle!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios,
                    size: 16, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
