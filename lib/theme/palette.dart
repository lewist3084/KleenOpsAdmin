import 'package:flutter/material.dart';
import 'package:shared_widgets/theme/app_palette.dart';

export 'package:shared_widgets/theme/app_palette.dart'
    show AppPalette, AppPaletteScope, kDefaultAppPalette;

/// Admin palette — darker slate primary with amber accent to visually
/// distinguish from the client Kleenops app.
const AppPalette adminPalette = AppPalette(
  primary1: Color(0xFF1E293B), // slate 800
  primary2: Color(0xFFF59E0B), // amber 500
  primary3: Color(0xFFE2E8F0), // slate 200
  primary4: Color(0xFF10B981), // mint (shared)
);
