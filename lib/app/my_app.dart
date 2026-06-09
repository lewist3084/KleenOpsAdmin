// lib/app/my_app.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_widgets/theme/app_fonts.dart';

import '../features/auth/providers/auth_provider.dart';
import '../features/communications/widgets/active_call_banner_host.dart';
import '../services/call_messaging_service.dart';
import '../services/video_call_service.dart';
import '../theme/palette.dart';
import '../widgets/viewers/video_call_overlay_host.dart';
import 'router.dart';

/// Global key for showing SnackBars via ScaffoldMessenger from anywhere
/// (services, providers) without needing a BuildContext.
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goRouter = ref.watch(goRouterProvider);
    const palette = adminPalette;

    // Calling identity = the overlord's membership in the tenant company
    // (where invitees ring). When it resolves, start the videoRooms listener
    // for incoming calls and register this device's FCM token; tear down when
    // the member is gone.
    ref.listen<AsyncValue<dynamic>>(mailboxMemberRefProvider, (_, next) {
      final memberRef = next.asData?.value;
      final companyRef = memberRef?.parent.parent;
      if (memberRef == null || companyRef == null) {
        VideoCallService.instance.dispose();
        return;
      }
      VideoCallService.instance
          .configure(companyId: companyRef.id, memberId: memberRef.id);
      CallMessagingService.instance.syncTokenForMember(memberRef);
    });

    return AppPaletteScope(
      palette: palette,
      child: MaterialApp.router(
        title: 'Kleenops Admin',
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: scaffoldMessengerKey,
        theme: ThemeData(
          colorScheme: ColorScheme.light(
            primary: palette.primary1,
            secondary: palette.primary2,
          ),
          floatingActionButtonTheme: FloatingActionButtonThemeData(
            backgroundColor: palette.primary2,
            foregroundColor: Colors.white,
          ),
          fontFamily: AppFonts.primary1,
          fontFamilyFallback: AppFonts.primaryFallbacks,
          primaryColor: palette.primary1,
          inputDecorationTheme: InputDecorationTheme(
            labelStyle: const TextStyle(color: Colors.grey),
            floatingLabelStyle: const TextStyle(color: Colors.grey),
            border: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey),
            ),
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: palette.primary1, width: 2.0),
            ),
          ),
        ),
        routerDelegate: goRouter.routerDelegate,
        routeInformationParser: goRouter.routeInformationParser,
        routeInformationProvider: goRouter.routeInformationProvider,
        builder: (context, child) {
          // Keep the WebRTC panel alive across navigation + surface the
          // incoming-call prompt and the active-call participant ribbon above
          // every route (mirrors the kleenops app shell).
          final resolved = child ?? const SizedBox.shrink();
          return VideoCallOverlayHost(
            child: ActiveCallBannerHost(child: resolved),
          );
        },
      ),
    );
  }
}
