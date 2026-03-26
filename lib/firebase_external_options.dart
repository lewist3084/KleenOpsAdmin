// firebase_external_options.dart
// Placeholder — replace with real Firebase project options when external
// tenant support is wired up for the admin app.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class ExternalFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    // TODO: Configure external Firebase project options for the admin app.
    throw UnsupportedError(
      'ExternalFirebaseOptions have not been configured yet. '
      'Register a Firebase app for the external tenant and fill in these options.',
    );
  }
}
