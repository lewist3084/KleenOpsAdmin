// plaid_oauth_screen.dart
//
// Landing page for the Plaid OAuth redirect (kleenops-admin.web.app/plaid-oauth
// ?oauth_state_id=...). When an OAuth bank (e.g. Chase) sends the browser back
// here after login, we finish the Link session via resumePlaidOauthIfPending()
// (which re-opens Link with receivedRedirectUri and completes the exchange),
// then return to the Banking screen.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/features/finances/services/plaid_service.dart';

class PlaidOauthScreen extends StatefulWidget {
  const PlaidOauthScreen({super.key});

  @override
  State<PlaidOauthScreen> createState() => _PlaidOauthScreenState();
}

class _PlaidOauthScreenState extends State<PlaidOauthScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resume());
  }

  Future<void> _resume() async {
    try {
      await PlaidService.resumePlaidOauthIfPending();
    } catch (_) {
      // Swallow — we return to Banking regardless; the user can retry there.
    }
    if (!mounted) return;
    context.go(AppRoutePaths.financeBanking);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Finishing bank connection…'),
          ],
        ),
      ),
    );
  }
}
