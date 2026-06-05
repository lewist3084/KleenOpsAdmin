// Agent Tasks landing page — lists the signed-in user's recent agent-task
// runs (top-level `agentTaskRuns`). Mirrors the kleenops "Agent Tasks" drawer
// entry; built on the admin's existing agentTaskRun providers.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/features/occupancy/models/agent_task_run.dart';
import 'package:kleenops_admin/features/occupancy/providers/agent_task_run_provider.dart';

class AgentTasksListScreen extends ConsumerWidget {
  const AgentTasksListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runsAsync = ref.watch(activeAgentTaskRunsProvider);

    return Scaffold(
      body: SafeArea(
        child: runsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (runs) {
            if (runs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_outlined,
                        size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text('No agent tasks yet',
                        style: TextStyle(
                            fontSize: 15, color: Colors.grey.shade600)),
                  ],
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: runs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) => _AgentRunTile(run: runs[i]),
            );
          },
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          DetailsAppBar(title: 'Agent Tasks'),
          HomeNavBarAdapter(),
        ],
      ),
    );
  }
}

class _AgentRunTile extends StatelessWidget {
  const _AgentRunTile({required this.run});

  final AgentTaskRun run;

  ({IconData icon, Color color}) get _statusVisual {
    switch (run.status) {
      case AgentTaskRunStatus.running:
        return (icon: Icons.autorenew, color: const Color(0xFF1976D2));
      case AgentTaskRunStatus.readyForReview:
        return (icon: Icons.check_circle_outline, color: const Color(0xFF2E7D32));
      case AgentTaskRunStatus.failed:
        return (icon: Icons.error_outline, color: const Color(0xFFC62828));
      case AgentTaskRunStatus.unknown:
        return (icon: Icons.help_outline, color: Colors.grey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = _statusVisual;
    final when = run.completedAt ?? run.startedAt;
    final whenLabel =
        when == null ? '' : DateFormat('MMM d · h:mm a').format(when);
    return ListTile(
      leading: Icon(v.icon, color: v.color),
      title: Text(run.taskName?.isNotEmpty == true ? run.taskName! : 'Agent task',
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(run.progressLabel,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(whenLabel,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
    );
  }
}
