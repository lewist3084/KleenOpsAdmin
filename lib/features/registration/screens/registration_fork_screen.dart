// lib/features/registration/screens/registration_fork_screen.dart
//
// First step in the registration flow.
// User picks between joining an existing company (QR) or registering a
// new one (which leads to the business-type fork).

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../services/analytics_service.dart';
import '../../../theme/palette.dart';
import '../widgets/fork_card.dart';

class RegistrationForkScreen extends StatefulWidget {
  const RegistrationForkScreen({super.key});

  @override
  State<RegistrationForkScreen> createState() => _RegistrationForkScreenState();
}

class _RegistrationForkScreenState extends State<RegistrationForkScreen> {
  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logFunnelEvent(FunnelEvent.registrationForkViewed);
  }

  @override
  Widget build(BuildContext context) {
    const palette = adminPalette;

    return ForkCard(
      icon: Icons.alt_route,
      title: 'Welcome to KleenOps',
      body: 'To get started, let us know how you want to set up your account.',
      color: palette.primary1,
      options: [
        ForkOption(
          icon: Icons.qr_code_2,
          label: 'Join an Existing Company',
          subtitle: 'Show your QR code so an admin can add you.',
          color: palette.primary3,
          onTap: () {
            AnalyticsService.instance.logFunnelEvent(
              FunnelEvent.registrationForkPicked,
              params: {'branch': 'join'},
            );
            context.go(AppRoutePaths.registrationJoinQr);
          },
        ),
        ForkOption(
          icon: Icons.add_business,
          label: 'Register a New Company',
          subtitle: 'Create a brand-new company account.',
          color: palette.primary1,
          onTap: () {
            AnalyticsService.instance.logFunnelEvent(
              FunnelEvent.registrationForkPicked,
              params: {'branch': 'new'},
            );
            context.go(AppRoutePaths.registrationBusinessType);
          },
        ),
      ],
    );
  }
}
