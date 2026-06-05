// lib/features/me/screens/reminders_screen.dart
//
// Global "Reminders" list. Shows scheduled (and history of fired) reminders
// for the signed-in member. Each row supports cancel and edit-time via a
// trailing menu; snooze/postpone is handled by the same edit flow.
//
// The doc shape and firing sweep live in
// `functions/src/modules/reminders.js`; this screen is purely a viewer +
// mutator for the same `company/{cid}/reminder/{id}` collection that
// `_scheduleReminder` writes from `comm_executors.dart`.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/services/ai/ai_context_service.dart';
import 'package:kleenops_admin/widgets/layout/bookended_canvas.dart';

class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(aiCanvasControllerProvider);
    final companyAsync = ref.watch(companyIdProvider);
    final memberAsync = ref.watch(memberDocRefProvider);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: 'Reminders',
            onAiPressed: controller.toggle,
          ),
          const HomeNavBarAdapter(highlightSelected: false),
        ],
      ),
      body: BookendedCanvas(
        child: companyAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (companyRef) {
            if (companyRef == null) {
              return const Center(child: Text('No company selected.'));
            }
            return memberAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (memberRef) {
                if (memberRef == null) {
                  return const Center(child: Text('No member found.'));
                }
                return _RemindersBody(
                  companyRef: companyRef,
                  memberRef: memberRef,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _RemindersBody extends StatelessWidget {
  const _RemindersBody({
    required this.companyRef,
    required this.memberRef,
  });

  final DocumentReference<Map<String, dynamic>> companyRef;
  final DocumentReference<Map<String, dynamic>> memberRef;

  @override
  Widget build(BuildContext context) {
    final collection = companyRef.collection('reminder');
    final scheduled = collection
        .where('ownerMemberId', isEqualTo: memberRef.id)
        .where('status', isEqualTo: 'scheduled')
        .orderBy('triggerAt')
        .snapshots();
    final fired = collection
        .where('ownerMemberId', isEqualTo: memberRef.id)
        .where('status', isEqualTo: 'fired')
        .orderBy('firedAt', descending: true)
        .limit(20)
        .snapshots();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        const _SectionHeader('Upcoming'),
        _StreamSection(
          stream: scheduled,
          emptyLabel: 'No upcoming reminders.',
          buildRow: (docRef, data) => _ReminderRow(
            docRef: docRef,
            data: data,
            isFired: false,
          ),
        ),
        const SizedBox(height: 16),
        const _SectionHeader('Recently fired'),
        _StreamSection(
          stream: fired,
          emptyLabel: 'Nothing has fired yet.',
          buildRow: (docRef, data) => _ReminderRow(
            docRef: docRef,
            data: data,
            isFired: true,
          ),
        ),
      ],
    );
  }
}

class _StreamSection extends StatelessWidget {
  const _StreamSection({
    required this.stream,
    required this.emptyLabel,
    required this.buildRow,
  });

  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final String emptyLabel;
  final Widget Function(
    DocumentReference<Map<String, dynamic>> docRef,
    Map<String, dynamic> data,
  ) buildRow;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Error: ${snap.error}'),
          );
        }
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              emptyLabel,
              style: const TextStyle(color: Colors.grey),
            ),
          );
        }
        return Column(
          children: [
            for (final doc in docs) buildRow(doc.reference, doc.data()),
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({
    required this.docRef,
    required this.data,
    required this.isFired,
  });

  final DocumentReference<Map<String, dynamic>> docRef;
  final Map<String, dynamic> data;
  final bool isFired;

  String _whenLabel() {
    final raw = isFired ? data['firedAt'] : data['triggerAt'];
    if (raw is! Timestamp) return '';
    final local = raw.toDate().toLocal();
    return DateFormat.yMMMd().add_jm().format(local);
  }

  String _bodyLabel() {
    final msg = (data['message'] ?? '').toString().trim();
    final title = (data['title'] ?? '').toString().trim();
    if (msg.isNotEmpty) return msg;
    if (title.isNotEmpty) return title;
    return 'Reminder';
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: Icon(
          isFired
              ? Icons.notifications_none_outlined
              : Icons.notifications_active_outlined,
          color: isFired ? Colors.grey : accent,
        ),
        title: Text(_bodyLabel()),
        subtitle: Text(_whenLabel()),
        trailing: isFired
            ? const SizedBox.shrink()
            : _UpcomingMenu(docRef: docRef, data: data),
      ),
    );
  }
}

class _UpcomingMenu extends StatelessWidget {
  const _UpcomingMenu({required this.docRef, required this.data});

  final DocumentReference<Map<String, dynamic>> docRef;
  final Map<String, dynamic> data;

  Future<void> _cancel(BuildContext context) async {
    await docRef.set(
      {
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reminder cancelled')),
    );
  }

  Future<void> _postpone(BuildContext context, Duration by) async {
    final raw = data['triggerAt'];
    if (raw is! Timestamp) return;
    final next = raw.toDate().add(by);
    await docRef.set(
      {'triggerAt': Timestamp.fromDate(next)},
      SetOptions(merge: true),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Postponed by ${_formatBy(by)}')),
    );
  }

  Future<void> _editTime(BuildContext context) async {
    final raw = data['triggerAt'];
    if (raw is! Timestamp) return;
    final current = raw.toDate().toLocal();

    final newDate = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (newDate == null || !context.mounted) return;
    final newTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (newTime == null || !context.mounted) return;
    final next = DateTime(
      newDate.year,
      newDate.month,
      newDate.day,
      newTime.hour,
      newTime.minute,
    );
    if (next.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a time in the future.')),
      );
      return;
    }
    await docRef.set(
      {'triggerAt': Timestamp.fromDate(next.toUtc())},
      SetOptions(merge: true),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reminder time updated')),
    );
  }

  String _formatBy(Duration d) {
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Reminder options',
      onSelected: (value) async {
        switch (value) {
          case 'snooze_5':
            await _postpone(context, const Duration(minutes: 5));
            break;
          case 'snooze_60':
            await _postpone(context, const Duration(hours: 1));
            break;
          case 'edit':
            await _editTime(context);
            break;
          case 'cancel':
            await _cancel(context);
            break;
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'snooze_5', child: Text('Snooze 5 min')),
        PopupMenuItem(value: 'snooze_60', child: Text('Snooze 1 hour')),
        PopupMenuItem(value: 'edit', child: Text('Edit time...')),
        PopupMenuDivider(),
        PopupMenuItem(value: 'cancel', child: Text('Cancel reminder')),
      ],
    );
  }
}

