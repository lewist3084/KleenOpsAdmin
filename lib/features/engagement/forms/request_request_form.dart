// features\engagement\forms\request_request_form.dart
//
// SKIPPED in the kleenops_admin port: this file's primary purpose is built on
// kleenops infrastructure that is intentionally stripped from the admin app
// (AI canvas / repositories / lookup-selector / portal / files / google docs
// /  AITextField, etc). Restoring it would mean porting whole subsystems that
// are out of scope. The stub below keeps the import graph buildable so that
// callers (which import it but do not necessarily render it) continue to
// compile; the actual UI/logic should be revisited if/when the admin app
// grows the matching infrastructure.

import 'package:flutter/material.dart';

class _SkippedStub extends StatelessWidget {
  const _SkippedStub({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'This screen has not been ported to the admin app yet.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
