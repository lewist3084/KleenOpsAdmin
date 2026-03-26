import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

const String _androidApiKey = 'AIzaSyBUXyYoeCPLMc6JhpptzQ0qmv5R1fIcKZA';
const String _iosApiKey = 'AIzaSyC7oh95zlm2jCbrzB28LcgEpTGia4mmSL0';
const String _webApiKey = 'AIzaSyCtSTULakEwgfIt5i8Bogr6J6agJKpS8Ss';

String get kGoogleApiKey {
  if (kIsWeb) return _webApiKey;
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return _iosApiKey;
    case TargetPlatform.android:
      return _androidApiKey;
    default:
      return _androidApiKey;
  }
}
