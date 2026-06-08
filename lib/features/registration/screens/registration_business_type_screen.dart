// lib/features/registration/screens/registration_business_type_screen.dart
//
// Second registration fork. Reached after the user picks "Register a
// New Company" on the first fork. Asks whether the company is using
// KleenOps internally or selling cleaning services to others.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../services/analytics_service.dart';
import '../../../theme/palette.dart';
import '../widgets/fork_card.dart';

class RegistrationBusinessTypeScreen extends StatefulWidget {
  const RegistrationBusinessTypeScreen({super.key});

  @override
  State<RegistrationBusinessTypeScreen> createState() =>
      _RegistrationBusinessTypeScreenState();
}

class _RegistrationBusinessTypeScreenState
    extends State<RegistrationBusinessTypeScreen> {
  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logFunnelEvent(FunnelEvent.businessTypeViewed);
  }

  @override
  Widget build(BuildContext context) {
    const palette = adminPalette;

    return ForkCard(
      icon: Icons.alt_route,
      title: 'How will you use KleenOps?',
      body: 'Tell us a bit about your business so we can tailor the setup.',
      color: palette.primary1,
      onBack: () => context.go(AppRoutePaths.registrationFork),
      options: [
        ForkOption(
          icon: Icons.apartment,
          label: 'Internal Use',
          subtitle: 'For organizations managing their own facilities.',
          color: palette.primary3,
          onTap: () {
            AnalyticsService.instance.logFunnelEvent(
              FunnelEvent.businessTypePicked,
              params: {'type': 'internal'},
            );
            context.go(AppRoutePaths.registrationInternalSetup);
          },
        ),
        ForkOption(
          icon: Icons.cleaning_services,
          label: 'Facilities Maintenance Business',
          subtitle:
              'For companies selling cleaning/maintenance services to '
              'other businesses.',
          color: palette.primary1,
          onTap: () {
            AnalyticsService.instance.logFunnelEvent(
              FunnelEvent.businessTypePicked,
              params: {'type': 'facilities'},
            );
            context.go(AppRoutePaths.setupDashboard);
          },
        ),
      ],
    );
  }
}
