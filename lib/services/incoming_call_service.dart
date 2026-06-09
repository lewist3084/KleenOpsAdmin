import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';


import 'video_call_overlay_controller.dart' show VideoCallType;
import 'video_call_service.dart';

/// Bridges native CallKit (iOS) / full-screen-intent (Android) UI with the
/// in-app call services. FCM data messages of type `videoCall` trigger
/// [showIncomingCall]; CallKit Accept / Decline / Timeout events feed back
/// into [VideoCallService] via `acceptCallFromCallKit` / `declineCallFromCallKit`.
class IncomingCallService {
  IncomingCallService._();
  static final IncomingCallService instance = IncomingCallService._();

  StreamSubscription<CallEvent?>? _eventSub;
  bool _initialized = false;

  /// Room/channel ids whose CallKit / system incoming-call UI is currently
  /// showing in the foreground. Both [OpenChannelInviteService] and
  /// [VideoCallService] check this set before showing their in-app prompts
  /// so the recipient doesn't see two stacked UIs for the same call.
  /// Foreground-only — the background isolate that shows CallKit on
  /// cold-start has its own memory, but the in-app dialog can't fire there
  /// anyway, so the race doesn't apply.
  final Set<String> _activeCallKitRoomIds = <String>{};

  bool isCallKitHandled(String roomId) =>
      _activeCallKitRoomIds.contains(roomId);

  void markCallKitHandled(String roomId) {
    _activeCallKitRoomIds.add(roomId);
  }

  void clearCallKitHandled(String roomId) {
    _activeCallKitRoomIds.remove(roomId);
  }

  // ── Back-compat shims ────────────────────────────────────────────────
  // Older call sites still reference the open-channel-specific names; these
  // forward to the generic implementation so both videoCall and openChannel
  // can share one dedup set.
  bool isOpenChannelHandled(String channelId) => isCallKitHandled(channelId);
  void markOpenChannelHandled(String channelId) => markCallKitHandled(channelId);
  void clearOpenChannelHandled(String channelId) =>
      clearCallKitHandled(channelId);

  /// Emits the iOS PushKit VoIP token whenever it's issued or refreshed.
  /// Empty string means the token was invalidated.
  final StreamController<String> _voipTokenCtrl =
      StreamController<String>.broadcast();
  Stream<String> get voipTokenStream => _voipTokenCtrl.stream;
  String? _lastVoipToken;
  String? get lastVoipToken => _lastVoipToken;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    _eventSub = FlutterCallkitIncoming.onEvent.listen(_handleEvent);
  }

  Future<void> dispose() async {
    await _eventSub?.cancel();
    _eventSub = null;
    _initialized = false;
    await _voipTokenCtrl.close();
  }

  /// Renders the native incoming-call UI. Safe to call from a background
  /// isolate (e.g. the FCM background handler) — CallKit takes over from
  /// there until the user taps Accept/Decline.
  static Future<void> showIncomingCall({
    required String roomId,
    required String companyId,
    required String callType,
    String? subject,
    String? callerName,
    String? taskId,
    String? teamId,
    List<String> participantMemberIds = const [],
    String pushType = 'videoCall',
    String? channelLabel,
  }) async {
    final isVideo = callType != 'voice';
    final params = CallKitParams(
      id: roomId,
      nameCaller: callerName ?? 'Kleenops',
      handle: subject ?? (isVideo ? 'Incoming video call' : 'Incoming call'),
      type: isVideo ? 1 : 0,
      duration: 30000,
      textAccept: 'Accept',
      textDecline: 'Decline',
      missedCallNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: false,
        subtitle: 'Missed call',
      ),
      extra: <String, dynamic>{
        'type': pushType,
        'companyId': companyId,
        if (pushType == 'openChannel') 'channelId': roomId else 'roomId': roomId,
        'callType': callType,
        if (taskId != null) 'taskId': taskId,
        if (teamId != null) 'teamId': teamId,
        if (subject != null) 'subject': subject,
        if (channelLabel != null) 'channelLabel': channelLabel,
        'participantMemberIds': jsonEncode(participantMemberIds),
      },
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#0955fa',
        actionColor: '#4CAF50',
        textColor: '#ffffff',
        incomingCallNotificationChannelName: 'Incoming Calls',
        missedCallNotificationChannelName: 'Missed Calls',
        isShowCallID: false,
      ),
      ios: IOSParams(
        iconName: 'CallKitLogo',
        handleType: 'generic',
        supportsVideo: isVideo,
        ringtonePath: 'system_ringtone_default',
      ),
    );
    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  /// Dismisses the CallKit / full-screen notification for [roomId]. Called
  /// when the underlying call ends or is accepted/declined inside the app.
  static Future<void> dismiss(String roomId) async {
    try {
      await FlutterCallkitIncoming.endCall(roomId);
    } catch (e) {
      debugPrint('IncomingCallService: failed to end call $roomId: $e');
    }
  }

  Future<void> _handleEvent(CallEvent? event) async {
    if (event == null) return;

    final body = event.body is Map
        ? Map<String, dynamic>.from(event.body as Map)
        : <String, dynamic>{};
    final extra = body['extra'] is Map
        ? Map<String, dynamic>.from(body['extra'] as Map)
        : <String, dynamic>{};

    if (event.event == Event.actionDidUpdateDevicePushTokenVoip) {
      final token = (body['deviceTokenVoIP'] as String?) ??
          (body['deviceToken'] as String?) ??
          '';
      _lastVoipToken = token;
      if (!_voipTokenCtrl.isClosed) _voipTokenCtrl.add(token);
      return;
    }

    final companyId = extra['companyId'] as String?;
    // For videoCall payloads the entity is `roomId`. For openChannel payloads
    // it's `channelId` in extras (and `id` on the outer body); fall back
    // through both shapes so a single switch handles either.
    final entityId = (extra['roomId'] as String?) ??
        (extra['channelId'] as String?) ??
        body['id'] as String?;
    final isOpenChannel = (extra['type'] as String?) == 'openChannel';

    final taskId = extra['taskId'] as String?;
    final teamId = extra['teamId'] as String?;
    final subject = extra['subject'] as String?;
    final rawCallType = extra['callType'] as String?;
    final callType =
        rawCallType == 'voice' ? VideoCallType.voice : VideoCallType.video;
    final participantMemberIds =
        _decodeParticipants(extra['participantMemberIds']);

    // Admin handles videoCall/voiceCall pushes only — the open-channel
    // (walkie-talkie) modality is not ported here, so its push type is ignored.
    if (isOpenChannel) return;

    switch (event.event) {
      case Event.actionCallAccept:
        if (companyId == null || entityId == null) return;
        await VideoCallService.instance.acceptCallFromCallKit(
          companyId: companyId,
          roomId: entityId,
          taskId: taskId,
          teamId: teamId,
          subject: subject,
          callType: callType,
          participantMemberIds: participantMemberIds,
        );
        break;
      case Event.actionCallDecline:
      case Event.actionCallTimeout:
        if (companyId == null || entityId == null) return;
        await VideoCallService.instance.declineCallFromCallKit(
          companyId: companyId,
          roomId: entityId,
        );
        break;
      default:
        break;
    }

    // After any final-state CallKit event, the room is no longer active
    // in the system UI — drop the suppression marker so a future invite
    // for the same room can prompt normally. Applies to both videoCall
    // and openChannel since they share one dedup set.
    if (entityId != null) {
      switch (event.event) {
        case Event.actionCallAccept:
        case Event.actionCallDecline:
        case Event.actionCallTimeout:
        case Event.actionCallEnded:
          _activeCallKitRoomIds.remove(entityId);
          break;
        default:
          break;
      }
    }
  }

  static List<String> _decodeParticipants(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) return raw.whereType<String>().toList();
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return const [];
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) return decoded.whereType<String>().toList();
      } catch (_) {
        return trimmed
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    }
    return const [];
  }
}
