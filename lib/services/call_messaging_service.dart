// lib/services/call_messaging_service.dart
//
// FCM + incoming-call plumbing for the admin app's ported voice/video calling.
// Mirrors the videoCall slice of the kleenops BootService dispatcher (other
// modalities — task alerts, open channels, Twilio — are not ported here).
//
// Responsibilities:
//   • Register the CallKit/full-screen-intent bridge (IncomingCallService).
//   • Register the FCM background handler so a terminated/backgrounded app
//     still rings on an incoming `videoCall` data push.
//   • Route foreground `videoCall` pushes to the CallKit UI + in-app prompt.
//   • Sync the device FCM token onto the current member doc so the backend
//     (createVideoRoom) can ring this device.
//
// NOTE: incoming-call delivery also depends on native config that cannot be
// verified in analysis (Android full-screen-intent + FGS perms, iOS CallKit
// entitlements + a VoIP push certificate). See the native scaffolding.

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import 'incoming_call_service.dart';
import 'video_call_overlay_controller.dart';
import 'video_call_service.dart';

/// Background isolate handler — fires when the app is terminated/backgrounded
/// and a data-only `videoCall` FCM arrives. Must be a top-level function with
/// the vm:entry-point pragma so the background isolate can find it.
@pragma('vm:entry-point')
Future<void> callMessagingBackgroundHandler(RemoteMessage msg) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // Likely already initialized in this isolate — safe to ignore.
  }

  if (msg.data['type'] != 'videoCall') return;
  final companyId = msg.data['companyId'] as String?;
  final roomId = msg.data['roomId'] as String?;
  if (companyId == null || roomId == null) return;

  await IncomingCallService.showIncomingCall(
    companyId: companyId,
    roomId: roomId,
    callType: (msg.data['callType'] as String?) ?? 'video',
    subject: msg.data['subject'] as String?,
    callerName:
        (msg.data['callerName'] as String?) ?? msg.notification?.title,
    taskId: msg.data['taskId'] as String?,
    teamId: msg.data['teamId'] as String?,
    participantMemberIds: _extractParticipants(msg.data['participantMemberIds']),
    pushType: 'videoCall',
  );
}

List<String> _extractParticipants(dynamic raw) {
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

class CallMessagingService {
  CallMessagingService._();
  static final instance = CallMessagingService._();

  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedAppSub;
  StreamSubscription<String>? _onTokenRefreshSub;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // CallKit / full-screen-intent event bridge — ready before any FCM
    // video-call data message can arrive.
    await IncomingCallService.instance.init();

    // Ask for notification permission (no-op where already granted).
    try {
      await FirebaseMessaging.instance.requestPermission();
    } catch (e) {
      debugPrint('[CallMessaging] requestPermission failed: $e');
    }

    // iOS: surface foreground pushes through onMessage (and draw a native
    // banner) — otherwise the in-app prompt never fires with the app open.
    if (!kIsWeb && Platform.isIOS) {
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    FirebaseMessaging.onBackgroundMessage(callMessagingBackgroundHandler);

    _onMessageSub =
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    _onMessageOpenedAppSub =
        FirebaseMessaging.onMessageOpenedApp.listen(_handleForegroundMessage);

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      await _handleForegroundMessage(initial);
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage msg) async {
    if (msg.data['type'] != 'videoCall') return;

    final companyId = msg.data['companyId'] as String?;
    final roomId = msg.data['roomId'] as String?;
    if (companyId == null || roomId == null) return;

    // Suppress the in-app prompt while CallKit shows for the same room.
    IncomingCallService.instance.markCallKitHandled(roomId);
    VideoCallOverlayController.instance.dismissIncomingIfMatches(roomId);

    await IncomingCallService.showIncomingCall(
      companyId: companyId,
      roomId: roomId,
      callType: (msg.data['callType'] as String?) ?? 'video',
      subject: msg.data['subject'] as String?,
      callerName:
          (msg.data['callerName'] as String?) ?? msg.notification?.title,
      taskId: msg.data['taskId'] as String?,
      teamId: msg.data['teamId'] as String?,
      participantMemberIds:
          _extractParticipants(msg.data['participantMemberIds']),
      pushType: 'videoCall',
    );

    final rawCallType = msg.data['callType'];
    await VideoCallService.instance.handleIncomingPush(
      companyId: companyId,
      roomId: roomId,
      taskId: msg.data['taskId'] as String?,
      subject: msg.data['subject'] as String?,
      teamId: msg.data['teamId'] as String?,
      participantMemberIds:
          _extractParticipants(msg.data['participantMemberIds']),
      callType:
          rawCallType == 'voice' ? VideoCallType.voice : VideoCallType.video,
    );
  }

  /// Writes this device's FCM token onto [memberRef] so the backend can ring
  /// it, and keeps it fresh on rotation. Call when the mailbox member resolves.
  Future<void> syncTokenForMember(
      DocumentReference<Map<String, dynamic>> memberRef) async {
    Future<void> write(String token) async {
      try {
        await memberRef.set({
          'fcmToken': token,
          'fcmTokens': FieldValue.arrayUnion([token]),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('[CallMessaging] token write failed: $e');
      }
    }

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await write(token);
    } catch (e) {
      debugPrint('[CallMessaging] getToken failed: $e');
    }

    await _onTokenRefreshSub?.cancel();
    _onTokenRefreshSub =
        FirebaseMessaging.instance.onTokenRefresh.listen(write);
  }

  Future<void> dispose() async {
    await _onMessageSub?.cancel();
    await _onMessageOpenedAppSub?.cancel();
    await _onTokenRefreshSub?.cancel();
    _onMessageSub = null;
    _onMessageOpenedAppSub = null;
    _onTokenRefreshSub = null;
  }
}
