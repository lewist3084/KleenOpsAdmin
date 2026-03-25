// lib/app/my_app.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_widgets/theme/app_fonts.dart';

import '../theme/palette.dart';
import 'router.dart';

class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goRouter = ref.watch(goRouterProvider);
    const palette = adminPalette;

    return AppPaletteScope(
      palette: palette,
      child: MaterialApp.router(
        title: 'Kleenops Admin',
        debugShowCheckedModeBanner: false,
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
      ),
    );
  }
}
