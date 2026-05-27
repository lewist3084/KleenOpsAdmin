// lib/features/processes/screens/processes_processes.dart
// SKIPPED (615 lines): primary kleenops source depends on
// `kleenops/widgets/tiles/image_rows_expand.dart` which has no admin equivalent.
// This is a stub so dependents (processes_tabs.dart) compile. Replace with the
// full port once ImageRowsExpand is ported to admin's widgets/tiles tree.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProcessesProcessesContent extends ConsumerStatefulWidget {
  const ProcessesProcessesContent({super.key});

  @override
  ConsumerState<ProcessesProcessesContent> createState() =>
      _ProcessesProcessesContentState();
}

class _ProcessesProcessesContentState
    extends ConsumerState<ProcessesProcessesContent> {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Processes list — pending port (depends on ImageRowsExpand).',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
