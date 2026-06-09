// lib/common/communications/phone/screens/call_history_screen.dart
//
// Ported from the main KleenOps app to mirror its look & workflow exactly.
// Generic call-log screen powering both the Phone and Video Call menu-drawer
// entries by reading the overlord member timeline
// (`kleenops/{id}/member/{mid}/timeline`) filtered to the requested call type,
// newest-first. The AI canvas chrome (AiScreenContext + BookendedCanvas) is a
// no-op stub in admin but keeps the identical bookend/home-nav-bar look. Real
// call placement (Twilio/WebRTC) is the one backend the admin app lacks, so the
// place-a-call FAB is omitted.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/common/communications/comm_menu.dart';
import 'package:kleenops_admin/common/communications/phone/screens/call_detail_screen.dart';
import 'package:kleenops_admin/common/communications/video_conferencing/video_conference_launcher.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/services/ai/ai_context_service.dart';
import 'package:kleenops_admin/services/notification_badge_service.dart';
import 'package:kleenops_admin/services/video_call_overlay_controller.dart';
import 'package:kleenops_admin/widgets/ai/ai_screen_context.dart';
import 'package:kleenops_admin/widgets/layout/bookended_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:shared_widgets/tiles/standard_bubble_tile.dart';

enum CallHistoryKind { voice, video }

class AdminCallHistoryScreen extends ConsumerStatefulWidget {
  const AdminCallHistoryScreen({super.key, required this.kind});

  final CallHistoryKind kind;

  @override
  ConsumerState<AdminCallHistoryScreen> createState() =>
      _AdminCallHistoryScreenState();
}

class _AdminCallHistoryScreenState
    extends ConsumerState<AdminCallHistoryScreen> {
  CallHistoryKind get kind => widget.kind;

  String get _firestoreType =>
      kind == CallHistoryKind.video ? 'video_call' : 'voice_call';

  String get _screenTitle =>
      kind == CallHistoryKind.video ? 'Video calls' : 'Phone calls';

  IconData get _emptyIcon => kind == CallHistoryKind.video
      ? Icons.videocam_off_outlined
      : Icons.phone_disabled_outlined;

  String get _emptyText => kind == CallHistoryKind.video
      ? 'No video calls yet'
      : 'No phone calls yet';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final memberRef = ref.read(mailboxMemberRefProvider).value;
      if (kind == CallHistoryKind.video) {
        NotificationBadgeService.instance.clearVideoCallBadge(memberRef);
      } else {
        NotificationBadgeService.instance.clearVoiceCallBadge(memberRef);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Calls are tenant-company-scoped (the only scope the createVideoRoom backend
    // supports, and where summarizeVideoRoom logs each call's timeline entry), so
    // read history from the mailbox member: company = member.parent.parent.
    final memberRef = ref.watch(mailboxMemberRefProvider).value;
    final companyRef = memberRef?.parent.parent;
    final controller = ref.read(aiCanvasControllerProvider);

    final menuSections = MenuDrawerSections(
      communications: buildAdminCommunicationMenuItems(context),
    );

    final body = (companyRef == null || memberRef == null)
        ? const Center(child: CircularProgressIndicator())
        : _CallList(
            stream: companyRef
                .collection('member')
                .doc(memberRef.id)
                .collection('timeline')
                .where('type', isEqualTo: _firestoreType)
                .orderBy('timestamp', descending: true)
                .limit(100)
                .snapshots(),
            emptyIcon: _emptyIcon,
            emptyText: _emptyText,
            kind: kind,
          );

    return Scaffold(
      body: AiScreenContext(
        context: AiContextState(
          key: 'callHistory_${kind.name}',
          sectionKey: 'communications',
          screenType: 'callHistory',
          label: _screenTitle,
        ),
        child: BookendedCanvas(child: body),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: _screenTitle,
            onAiPressed: controller.toggle,
            menuSections: menuSections,
          ),
          const HomeNavBarAdapter(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'callHistoryPlaceCallFab',
        onPressed: () => VideoConferenceLauncher.show(
          context,
          callType: kind == CallHistoryKind.video
              ? VideoCallType.video
              : VideoCallType.voice,
          source: 'call_history',
          sourceContext: kind == CallHistoryKind.video
              ? 'call_history_video'
              : 'call_history_voice',
        ),
        tooltip: kind == CallHistoryKind.video ? 'Start video call' : 'Make a call',
        child: Icon(kind == CallHistoryKind.video ? Icons.videocam : Icons.phone),
      ),
    );
  }
}

class _CallList extends StatelessWidget {
  const _CallList({
    required this.stream,
    required this.emptyIcon,
    required this.emptyText,
    required this.kind,
  });

  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final IconData emptyIcon;
  final String emptyText;
  final CallHistoryKind kind;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(emptyIcon, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(emptyText,
                    style:
                        TextStyle(fontSize: 15, color: Colors.grey.shade600)),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 4),
          itemBuilder: (context, i) => _CallRow(doc: docs[i], kind: kind),
        );
      },
    );
  }
}

class _CallRow extends StatelessWidget {
  const _CallRow({required this.doc, required this.kind});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final CallHistoryKind kind;

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final title = (data['title'] as String?) ??
        (kind == CallHistoryKind.video ? 'Video call' : 'Phone call');
    final summary = (data['summary'] as String?) ?? '';
    final durationMin = (data['durationMinutes'] as num?)?.toInt();
    final when = (data['timestamp'] as Timestamp?)?.toDate() ??
        (data['createdAt'] as Timestamp?)?.toDate() ??
        (data['loggedAt'] as Timestamp?)?.toDate();
    final loggedBy = (data['loggedByName'] as String?) ??
        (data['createdByName'] as String?);

    final accent = kind == CallHistoryKind.video
        ? const Color(0xFF5E35B1)
        : const Color(0xFF43A047);
    final icon = kind == CallHistoryKind.video
        ? Icons.videocam_outlined
        : Icons.phone_outlined;

    final hasLoggedBy = loggedBy != null && loggedBy.isNotEmpty;
    final hasSummary = summary.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: StandardBubbleTile(
        title: title,
        description: hasLoggedBy && hasSummary
            ? '$loggedBy\n$summary'
            : (hasLoggedBy ? loggedBy : (hasSummary ? summary : null)),
        leadingIcon: icon,
        leadingIconColor: accent,
        leadingBackgroundColor: accent.withAlpha(28),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CallDetailScreen(data: data, kind: kind),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              when == null ? '' : _shortDate(when),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            ),
            if (durationMin != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '$durationMin min',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _shortDate(DateTime t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tDay = DateTime(t.year, t.month, t.day);
    if (tDay == today) return DateFormat.jm().format(t);
    final daysAgo = today.difference(tDay).inDays;
    if (daysAgo == 1) return 'Yesterday';
    if (daysAgo < 7) return DateFormat.E().format(t);
    if (tDay.year == today.year) return DateFormat.MMMd().format(t);
    return DateFormat.yMMMd().format(t);
  }
}
