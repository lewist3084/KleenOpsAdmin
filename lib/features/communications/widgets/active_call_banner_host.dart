// Top-of-app host for the ActiveParticipantsBanner. When the active
// call list is non-empty, prepends the banner above the route content
// and removes the route's top safe-area padding so existing screen
// chrome (CanvasTopBookend etc.) lays out directly under the banner.
//
// Mounted once via MaterialApp.builder so every screen gets the
// banner for free without per-screen wiring.
//
// The banner is also kept in sync with the in-call session: when a
// call ends (controller.session becomes null) the participants list
// is cleared. The X-out badge on each bubble is only wired for the
// call initiator (controller.isCaller); for everyone else the X is
// suppressed because only the initiator can disconnect members.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/features/communications/providers/active_call_provider.dart';
import 'package:kleenops_admin/features/hr/utils/member_file_images.dart';
import 'package:kleenops_admin/services/video_call_overlay_controller.dart';
import 'package:shared_widgets/avatars/avatar_bubble.dart';
import 'package:shared_widgets/banners/active_participants_banner.dart';

class ActiveCallBannerHost extends ConsumerStatefulWidget {
  const ActiveCallBannerHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ActiveCallBannerHost> createState() =>
      _ActiveCallBannerHostState();
}

class _ActiveCallBannerHostState extends ConsumerState<ActiveCallBannerHost> {
  final VideoCallOverlayController _controller =
      VideoCallOverlayController.instance;
  bool _hadSession = false;
  // True once we've resolved + published participant bubbles for the
  // current call session, so controller ticks don't re-fetch members.
  bool _bannerSynced = false;
  // Per-roomId Firestore subscriptions feeding participant connection state
  // into the provider. Both caller and receiver subscribe so they see the
  // same bubbles update from ringing → connected.
  String? _listeningRoomId;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _roomSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _participantsSub;
  Set<String> _roomPendingIds = const <String>{};
  Set<String> _roomUnavailableIds = const <String>{};
  Map<String, String> _participantStatusById = const <String, String>{};
  // The local user's own bubble, shown at the far left of the strip
  // during a video call so the user can see their own face. Null for
  // voice calls and outside of calls.
  BannerParticipant? _selfParticipant;

  @override
  void initState() {
    super.initState();
    _hadSession = _controller.session != null;
    _controller.addListener(_onControllerChange);
    if (_hadSession) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _maybeSyncBanner());
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _maybeStartStateListener());
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _maybeResolveSelf());
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChange);
    _stopStateListener();
    super.dispose();
  }

  void _onControllerChange() {
    final hasSession = _controller.session != null;
    if (_hadSession && !hasSession) {
      ref.read(activeCallProvider.notifier).clear();
      _bannerSynced = false;
      _selfParticipant = null;
      _stopStateListener();
    }
    _hadSession = hasSession;
    if (hasSession) {
      _maybeSyncBanner();
      _maybeStartStateListener();
      unawaited(_maybeResolveSelf());
    }
    if (mounted) setState(() {});
  }

  /// Resolve the local user as a banner bubble. During a video call the
  /// user's own face is pinned to the far left of the strip (left of
  /// the vertical divider) so they can see themselves alongside
  /// everyone else. No-op for voice calls — there's no self-view.
  Future<void> _maybeResolveSelf() async {
    final session = _controller.session;
    if (session == null) return;
    // Covers both native video calls and voice calls upgraded to video.
    if (!_controller.videoActive) return;
    if (_selfParticipant != null) return;

    final selfId = session.currentMemberId.trim();
    if (selfId.isEmpty) return;

    final companyRef = ref.read(mailboxMemberRefProvider).asData?.value?.parent.parent;
    if (companyRef == null) return;

    String name = 'You';
    try {
      final snap = await companyRef.collection('member').doc(selfId).get();
      final candidate = (snap.data()?['name'] as String?)?.trim();
      if (candidate != null && candidate.isNotEmpty) name = candidate;
    } catch (_) {
      // Keep "You" as the fallback label.
    }

    String? imageUrl;
    try {
      final url = await MemberFileImages.primaryProfileImageUrl(
        companyRef: companyRef,
        memberId: selfId,
      );
      imageUrl = url.isEmpty ? null : url;
    } catch (_) {
      imageUrl = null;
    }

    if (!mounted || _controller.session != session) return;
    setState(() {
      _selfParticipant = BannerParticipant(
        id: selfId,
        name: name,
        imageUrl: imageUrl,
        // Self needs no connection ring — the user is trivially in the
        // call. The vertical divider already sets them apart.
        state: ParticipantConnectionState.idle,
      );
    });
  }

  /// Make sure the banner has a bubble for everyone on the call.
  ///
  /// Some launch sites (the new-conversation screen) populate
  /// [activeCallProvider] themselves; others (the video-conference
  /// launcher, task calls) don't, and recipients never go through the
  /// caller-side picker at all. Whenever the provider is empty we
  /// resolve caller + invitees from the session and fill it — without
  /// bubbles the banner can't show ringing/answered for anyone.
  void _maybeSyncBanner() {
    final session = _controller.session;
    if (session == null) return;
    if (_bannerSynced) return;

    final notifier = ref.read(activeCallProvider.notifier);
    if (ref.read(activeCallProvider).isNotEmpty) {
      // Banner already populated by the launch site — don't stomp it.
      _bannerSynced = true;
      return;
    }

    _bannerSynced = true;
    unawaited(_resolveAndPublishBanner(session, notifier));
  }

  Future<void> _resolveAndPublishBanner(
    VideoCallSession session,
    ActiveCallNotifier notifier,
  ) async {
    try {
      final companyRef = ref.read(mailboxMemberRefProvider).asData?.value?.parent.parent;
      if (companyRef == null) return;

      final selfId = session.currentMemberId.trim();
      final orderedIds = <String>[];
      final caller = session.callerMemberId?.trim();
      if (caller != null && caller.isNotEmpty && caller != selfId) {
        orderedIds.add(caller);
      }
      for (final raw in session.participantMemberIds) {
        final id = raw.trim();
        if (id.isEmpty) continue;
        if (id == selfId) continue;
        if (orderedIds.contains(id)) continue;
        orderedIds.add(id);
      }
      if (orderedIds.isEmpty) return;

      for (final id in orderedIds) {
        final memberRef = companyRef.collection('member').doc(id).withConverter(
              fromFirestore: (s, _) => s.data() ?? <String, dynamic>{},
              toFirestore: (Map<String, dynamic> m, _) => m,
            );

        String name = id;
        try {
          final snap = await memberRef.get();
          final data = snap.data();
          final candidate = (data?['name'] as String?)?.trim();
          if (candidate != null && candidate.isNotEmpty) name = candidate;
        } catch (_) {
          // Keep id as fallback.
        }

        String? imageUrl;
        try {
          final url = await MemberFileImages.primaryProfileImageUrl(
            companyRef: companyRef,
            memberId: id,
          );
          imageUrl = url.isEmpty ? null : url;
        } catch (_) {
          imageUrl = null;
        }

        if (_controller.session != session) return; // call ended/changed
        if (!mounted) return;
        notifier.add(ActiveCallParticipant(
          id: id,
          name: name,
          imageUrl: imageUrl,
          memberRef: memberRef,
        ));
      }
      // Now that bubbles exist, fold in whatever state we already have
      // from the Firestore room/participants snapshots so receivers see
      // pending/connected immediately instead of after the next snap.
      _publishStates();
    } catch (err, st) {
      debugPrint('[ActiveCallBannerHost] recipient sync failed: $err\n$st');
    }
  }

  /// Subscribe to the active room doc + its `participants` subcollection
  /// so we can flip each bubble between `pending`/`connected`/`declined`/
  /// `unavailable` as the call progresses. Both caller and receiver run
  /// this — they see the same animation.
  void _maybeStartStateListener() {
    final session = _controller.session;
    if (session == null) {
      _stopStateListener();
      return;
    }
    final roomId = session.roomId;
    if (roomId == null) return; // caller may not have a roomId yet
    if (_listeningRoomId == roomId) return;

    _stopStateListener();
    _listeningRoomId = roomId;

    final companyRef = ref.read(mailboxMemberRefProvider).asData?.value?.parent.parent;
    if (companyRef == null) return;
    final roomRef =
        companyRef.collection('videoRooms').doc(roomId).withConverter(
              fromFirestore: (s, _) => s.data() ?? <String, dynamic>{},
              toFirestore: (Map<String, dynamic> m, _) => m,
            );

    _roomSub = roomRef.snapshots().listen((snap) {
      final data = snap.data() ?? const <String, dynamic>{};
      _roomPendingIds = (data['pendingMemberIds'] as List?)
              ?.whereType<String>()
              .toSet() ??
          const <String>{};
      _roomUnavailableIds = (data['unavailableMemberIds'] as List?)
              ?.whereType<String>()
              .toSet() ??
          const <String>{};
      _publishStates();
    });

    _participantsSub =
        roomRef.collection('participants').snapshots().listen((snap) {
      final next = <String, String>{};
      for (final doc in snap.docs) {
        final raw = doc.data()['status'];
        if (raw is String && raw.isNotEmpty) {
          next[doc.id] = raw;
        }
      }
      _participantStatusById = next;
      _publishStates();
    });
  }

  void _stopStateListener() {
    _roomSub?.cancel();
    _participantsSub?.cancel();
    _roomSub = null;
    _participantsSub = null;
    _listeningRoomId = null;
    _roomPendingIds = const <String>{};
    _roomUnavailableIds = const <String>{};
    _participantStatusById = const <String, String>{};
  }

  /// Compute the connection state for every participant currently in the
  /// banner and push the bulk update into the provider.
  void _publishStates() {
    if (!mounted) return;
    final current = ref.read(activeCallProvider);
    if (current.isEmpty) return;

    final states = <String, ParticipantConnectionState>{};
    for (final p in current) {
      states[p.id] = _resolveStateFor(p.id);
    }
    ref.read(activeCallProvider.notifier).applyStates(states);
  }

  ParticipantConnectionState _resolveStateFor(String memberId) {
    // Subcollection status wins when present.
    final sub = _participantStatusById[memberId];
    switch (sub) {
      case 'joined':
        return ParticipantConnectionState.connected;
      case 'declined':
      case 'removed':
      case 'left':
        return ParticipantConnectionState.declined;
    }
    if (_roomUnavailableIds.contains(memberId)) {
      return ParticipantConnectionState.unavailable;
    }
    if (_roomPendingIds.contains(memberId)) {
      return ParticipantConnectionState.pending;
    }
    // Before the room doc lands client-side we default to ringing — the
    // call is active by definition (banner is up), so showing them as
    // ringing is the right hint until the subcollection updates.
    return ParticipantConnectionState.pending;
  }

  Future<void> _handleRemove(BannerParticipant participant) async {
    final notifier = ref.read(activeCallProvider.notifier);
    if (_controller.hasActiveCall) {
      await _controller.requestRemoveParticipant(participant.id);
    }
    notifier.remove(participant.id);
  }

  @override
  Widget build(BuildContext context) {
    final participants = ref.watch(activeCallProvider);
    final self = _selfParticipant;
    final screenRenderer = _controller.screenShareRenderer;
    if (participants.isEmpty && self == null && screenRenderer == null) {
      return widget.child;
    }

    // Only the call initiator can disconnect members. When no call is
    // active (banner reflects pre-call picks), the picker owner keeps
    // the X so they can edit their own selection.
    final canRemove = !_controller.hasActiveCall || _controller.isCaller;
    // Tap-to-enlarge only makes sense once a video call is live — there's
    // nothing to put on the stage before then (or on a voice call).
    final canEnlarge = _controller.hasActiveCall && _controller.videoActive;

    // A live screen share owns the presenter stage (even on a voice call),
    // taking priority over a tapped participant.
    final Widget? stage;
    if (screenRenderer != null) {
      stage = _buildScreenShareStage(screenRenderer);
    } else if (canEnlarge) {
      stage = _buildPresenterStage(participants, self);
    } else {
      stage = null;
    }

    return Column(
      children: [
        SafeArea(
          top: true,
          bottom: false,
          child: ActiveParticipantsBanner(
            participants: participants,
            selfParticipant: self,
            onRemove: canRemove ? _handleRemove : null,
            overlayBuilder: _buildBubbleOverlay,
            onParticipantTap: canEnlarge ? _handleParticipantTap : null,
            selectedParticipantId: _controller.enlargedMemberId,
          ),
        ),
        // The enlarged presenter grows in/out smoothly so the ribbon
        // area "just enlarges" rather than snapping.
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: stage ?? const SizedBox(width: double.infinity, height: 0),
        ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: widget.child,
          ),
        ),
      ],
    );
  }

  /// Tapping a bubble enlarges that participant; tapping the bubble
  /// that's already enlarged collapses the stage again.
  void _handleParticipantTap(BannerParticipant participant) {
    final current = _controller.enlargedMemberId;
    final next = current == participant.id ? null : participant.id;
    _controller.setEnlargedParticipant(next);
  }

  /// Builds the full-width presenter panel showing the live screen share.
  /// Local shares are mirrored from the sharer's own capture; remote
  /// shares carry a `<name> is sharing` label and no stop control.
  Widget _buildScreenShareStage(RTCVideoRenderer renderer) {
    final isLocal = _controller.screenShareIsLocal;
    final name = _controller.screenShareName?.trim();
    final label = isLocal
        ? 'You are sharing your screen'
        : '${(name != null && name.isNotEmpty) ? name : 'A participant'} is sharing their screen';
    return _ScreenShareStage(
      renderer: renderer,
      label: label,
      onStop: isLocal
          ? () => _controller.requestScreenSharing(false)
          : null,
    );
  }

  /// Builds the full-width 16:9 presenter panel for the enlarged
  /// participant, or null when no one is selected. The selected member
  /// stays in the ribbon throughout — this is an additive panel.
  Widget? _buildPresenterStage(
    List<BannerParticipant> participants,
    BannerParticipant? self,
  ) {
    final selectedId = _controller.enlargedMemberId;
    if (selectedId == null) return null;

    final bool isSelf = self != null && self.id == selectedId;
    BannerParticipant? participant;
    if (isSelf) {
      participant = self;
    } else {
      for (final p in participants) {
        if (p.id == selectedId) {
          participant = p;
          break;
        }
      }
    }

    // The enlarged member left the call (or was removed) — collapse the
    // stage on the next frame instead of stranding a dead panel.
    if (participant == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.enlargedMemberId == selectedId) {
          _controller.setEnlargedParticipant(null);
        }
      });
      return null;
    }

    final renderer = isSelf
        ? _controller.localRenderer
        : _controller.remoteRendererFor(selectedId);
    final stream = renderer?.srcObject;
    final hasVideo = stream != null && stream.getVideoTracks().isNotEmpty;

    return _PresenterStage(
      participant: participant,
      renderer: hasVideo ? renderer : null,
      mirror: isSelf,
      onClose: () => _controller.setEnlargedParticipant(null),
    );
  }

  Widget? _buildBubbleOverlay(BannerParticipant p, double size) {
    if (!_controller.hasActiveCall) return null;

    // The self bubble shows the local camera feed, mirrored like a
    // front-facing self-view; everyone else shows their remote feed.
    final isSelf = _selfParticipant != null && p.id == _selfParticipant!.id;
    final renderer = isSelf
        ? _controller.localRenderer
        : _controller.remoteRendererFor(p.id);
    if (renderer == null) return null;
    final stream = renderer.srcObject;
    if (stream == null) return null;
    if (stream.getVideoTracks().isEmpty) return null;
    return ClipOval(
      child: SizedBox.expand(
        child: RTCVideoView(
          renderer,
          mirror: isSelf,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        ),
      ),
    );
  }
}

/// Full-width 16:9 video panel shown directly under the call ribbon
/// when a participant bubble is tapped. The participant stays in the
/// ribbon the whole time; tapping the X collapses this panel.
class _PresenterStage extends StatelessWidget {
  const _PresenterStage({
    required this.participant,
    required this.renderer,
    required this.mirror,
    required this.onClose,
  });

  final BannerParticipant participant;

  /// The live video renderer, or null when the participant has no video
  /// yet (camera off / still ringing) — then a large avatar is shown.
  final RTCVideoRenderer? renderer;
  final bool mirror;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screen = MediaQuery.sizeOf(context);
    // 16:9 by width, but never taller than half the screen so the stage
    // can't crowd out the app content on short or very wide displays.
    final stageHeight = (screen.width * 9 / 16)
        .clamp(140.0, screen.height * 0.5)
        .toDouble();

    final Widget content;
    final liveRenderer = renderer;
    if (liveRenderer != null) {
      content = RTCVideoView(
        liveRenderer,
        mirror: mirror,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
      );
    } else {
      // No live video (camera off / still ringing): show a large avatar.
      content = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AvatarBubble(
              imageUrl: participant.imageUrl,
              name: participant.name,
              size: 96,
            ),
            const SizedBox(height: 12),
            Text(
              participant.state == ParticipantConnectionState.pending
                  ? 'Ringing…'
                  : 'Camera off',
              style:
                  theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: screen.width,
      height: stageHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black, child: content),
          // Name chip, bottom-left.
          Positioned(
            left: 12,
            bottom: 12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                participant.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          // Close (X) button, top-right — returns the bubble to the ribbon.
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.black.withValues(alpha: 0.55),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onClose,
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.close, color: Colors.white, size: 22),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-width panel showing a live screen share below the call ribbon.
/// Unlike [_PresenterStage] this is fit-to-contain (a shared screen is
/// rarely 16:9 and must never be cropped), carries a sharer label, and
/// offers a "Stop sharing" button only to the local sharer.
class _ScreenShareStage extends StatelessWidget {
  const _ScreenShareStage({
    required this.renderer,
    required this.label,
    required this.onStop,
  });

  final RTCVideoRenderer renderer;
  final String label;

  /// Non-null only for the local sharer; tapping it stops the share.
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    // A shade taller than a video tile — shared screens are usually
    // portrait-ish or 16:10 — but still clamped so it can't swallow the
    // route content beneath it.
    final stageHeight = (screen.width * 9 / 16)
        .clamp(160.0, screen.height * 0.5)
        .toDouble();

    return SizedBox(
      width: screen.width,
      height: stageHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: Colors.black,
            child: RTCVideoView(
              renderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
            ),
          ),
          // Sharer label, bottom-left.
          Positioned(
            left: 12,
            bottom: 12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.screen_share,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Stop-sharing control, top-right — local sharer only.
          if (onStop != null)
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.red.withValues(alpha: 0.85),
                shape: const StadiumBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onStop,
                  child: const Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.stop_screen_share,
                            color: Colors.white, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Stop sharing',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
