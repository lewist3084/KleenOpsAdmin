import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';

import 'package:kleenops_admin/repositories/communications_repository.dart';
import 'package:kleenops_admin/repositories/task_repository.dart';
import 'package:kleenops_admin/services/incoming_call_service.dart';
import 'package:kleenops_admin/services/video_call_overlay_controller.dart';

class VideoCallService {
  VideoCallService._({
    CommunicationsRepository? communicationsRepo,
    TaskRepository? taskRepo,
  })  : _communicationsRepo = communicationsRepo ?? CommunicationsRepository(),
        _taskRepo = taskRepo ?? TaskRepository();

  static final VideoCallService instance = VideoCallService._();

  final CommunicationsRepository _communicationsRepo;
  final TaskRepository _taskRepo;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AudioPlayer _player = AudioPlayer();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  String? _listeningCompanyId;
  String? _currentMemberId;
  String? _activeIncomingRoomId;
  bool _isRinging = false;
  Timer? _vibrationTimer;
  final List<_QueuedIncomingCall> _callQueue = [];
  static const Duration _ringTimeout = Duration(minutes: 2);

  VideoCallType _parseCallType(dynamic raw) {
    if (raw is String) {
      final normalized = raw.trim().toLowerCase();
      if (normalized == 'voice') return VideoCallType.voice;
    }
    return VideoCallType.video;
  }

  Future<String?> _resolveCurrentMemberId(String companyId) async {
    final cached = _currentMemberId;
    if (cached != null && cached.isNotEmpty) return cached;
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    try {
      final snap = await _taskRepo.memberByUidDoc(companyId, uid).get();
      final data = snap.data();
      final memberId = data?['memberId'];
      if (memberId is String && memberId.trim().isNotEmpty) {
        _currentMemberId = memberId.trim();
        return _currentMemberId;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  void configure({required String companyId, required String memberId}) {
    if (_listeningCompanyId == companyId &&
        _currentMemberId == memberId &&
        _subscription != null) {
      return;
    }
    _subscription?.cancel();

    _listeningCompanyId = companyId;
    _currentMemberId = memberId;
    if (memberId.isEmpty) return;

    _subscription = _communicationsRepo
        .videoRoomCollection(companyId)
        .where('pendingMemberIds', arrayContains: memberId)
        .snapshots()
        .listen((snapshot) {
      unawaited(_handleRoomSnapshot(snapshot, companyId, memberId));
    });
  }

  void startTaskCall({
    required String companyId,
    required String currentMemberId,
    required String taskId,
    String? subject,
    String? roomId,
    List<String> participantMemberIds = const [],
    String? teamId,
    VideoCallType callType = VideoCallType.video,
    bool pttEnabled = false,
    String? source,
    String? sourceContext,
  }) {
    VideoCallOverlayController.instance.startSession(
      VideoCallSession(
        companyId: companyId,
        currentMemberId: currentMemberId,
        taskId: taskId,
        roomId: roomId,
        participantMemberIds: participantMemberIds,
        teamId: teamId,
        subject: subject,
        callType: callType,
        isCaller: true,
        pttEnabled: pttEnabled,
        source: source,
        sourceContext: sourceContext,
      ),
    );
  }

  void startAdHocCall({
    required String companyId,
    required String currentMemberId,
    required List<String> participantMemberIds,
    String? teamId,
    String? subject,
    VideoCallType callType = VideoCallType.video,
    bool pttEnabled = false,
    String? source,
    String? sourceContext,
  }) {
    VideoCallOverlayController.instance.startSession(
      VideoCallSession(
        companyId: companyId,
        currentMemberId: currentMemberId,
        participantMemberIds: participantMemberIds,
        teamId: teamId,
        subject: subject,
        callType: callType,
        isCaller: true,
        pttEnabled: pttEnabled,
        source: source,
        sourceContext: sourceContext,
      ),
    );
  }

  /// Adds members to an existing live room and rings them. Routes through
  /// the `createVideoRoom` callable — passing an existing `roomId` switches
  /// that function to invite mode — so the request lands on createVideoRoom's
  /// instance (warm for the duration of a call) instead of cold-starting a
  /// separate function under the us-central1 CPU cap. Transient
  /// `internal` / `unavailable` errors are retried a couple of times.
  Future<void> inviteMembers({
    required String companyId,
    required String roomId,
    required List<String> memberIds,
  }) async {
    if (memberIds.isEmpty) return;
    final callable =
        FirebaseFunctions.instance.httpsCallable('createVideoRoom');
    const maxAttempts = 3;
    for (var attempt = 1;; attempt++) {
      try {
        await callable.call(<String, dynamic>{
          'companyId': companyId,
          'roomId': roomId,
          'participantMemberIds': memberIds,
        });
        return;
      } on FirebaseFunctionsException catch (e) {
        final transient = e.code == 'internal' ||
            e.code == 'unavailable' ||
            e.code == 'deadline-exceeded';
        if (!transient || attempt >= maxAttempts) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
      }
    }
  }

  /// Called when the user taps Accept in the native CallKit / full-screen
  /// notification. Validates the room is still ringing and starts the session
  /// directly — bypasses the in-app accept prompt.
  Future<void> acceptCallFromCallKit({
    required String companyId,
    required String roomId,
    String? taskId,
    String? teamId,
    String? subject,
    VideoCallType callType = VideoCallType.video,
    List<String> participantMemberIds = const [],
  }) async {
    final memberId = await _resolveCurrentMemberId(companyId);
    if (memberId == null || memberId.isEmpty) return;

    final roomRef = _communicationsRepo.videoRoomDoc(companyId, roomId);
    final roomSnap = await roomRef.get();
    if (!roomSnap.exists) return;

    final data = roomSnap.data() ?? <String, dynamic>{};
    if (_isRoomExpired(data)) {
      await _removeCurrentUserFromPending(companyId, roomId, memberId);
      return;
    }
    if (!_isPendingParticipant(data, memberId)) return;

    final controller = VideoCallOverlayController.instance;
    if (controller.session?.roomId == roomId) return;

    await _stopRing();
    _callQueue.removeWhere((c) => c.roomId == roomId);
    _activeIncomingRoomId = null;
    if (controller.incomingCall?.roomId == roomId) {
      // Clear any pending in-app overlay for the same room.
      controller.declineIncoming();
    }

    final resolvedTaskId = (data['taskId'] as String?) ?? taskId;
    final resolvedSubject = (data['subject'] as String?) ?? subject;
    final resolvedTeamId = (data['teamId'] as String?) ?? teamId;
    final resolvedCallType = data.containsKey('callType')
        ? _parseCallType(data['callType'])
        : callType;
    final resolvedParticipantMemberIds =
        (data['participantMemberIds'] as List?)?.whereType<String>().toList() ??
            participantMemberIds;
    final resolvedSource = data['source'] as String?;
    final resolvedSourceContext = data['sourceContext'] as String?;
    final resolvedCallerMemberId = (data['createdByMemberId'] as String?)
        ?.trim();

    controller.startSession(
      VideoCallSession(
        companyId: companyId,
        currentMemberId: memberId,
        taskId: resolvedTaskId,
        roomId: roomId,
        participantMemberIds: resolvedParticipantMemberIds,
        callerMemberId:
            (resolvedCallerMemberId == null || resolvedCallerMemberId.isEmpty)
                ? null
                : resolvedCallerMemberId,
        teamId: resolvedTeamId,
        subject: resolvedSubject,
        callType: resolvedCallType,
        isCaller: false,
        source: resolvedSource,
        sourceContext: resolvedSourceContext,
        onEnded: () {
          unawaited(IncomingCallService.dismiss(roomId));
        },
      ),
    );
  }

  /// Called when the user taps Decline (or CallKit times out) in the native
  /// incoming-call UI. Removes the user from `pendingMemberIds`.
  Future<void> declineCallFromCallKit({
    required String companyId,
    required String roomId,
  }) async {
    final memberId = await _resolveCurrentMemberId(companyId);
    if (memberId == null || memberId.isEmpty) return;

    await _stopRing();
    _callQueue.removeWhere((c) => c.roomId == roomId);
    if (_activeIncomingRoomId == roomId) _activeIncomingRoomId = null;

    final controller = VideoCallOverlayController.instance;
    if (controller.incomingCall?.roomId == roomId) {
      await controller.declineIncoming();
    }

    await _removeCurrentUserFromPending(companyId, roomId, memberId);
  }

  Future<void> handleIncomingPush({
    required String companyId,
    required String roomId,
    String? taskId,
    String? subject,
    List<String> participantMemberIds = const [],
    String? teamId,
    VideoCallType callType = VideoCallType.video,
  }) async {
    final memberId = await _resolveCurrentMemberId(companyId);
    if (memberId == null || memberId.isEmpty) return;

    final roomRef = _communicationsRepo.videoRoomDoc(companyId, roomId);
    final roomSnap = await roomRef.get();
    if (!roomSnap.exists) return;

    final data = roomSnap.data() ?? <String, dynamic>{};
    if (!_isPendingParticipant(data, memberId)) return;
    if (_isRoomExpired(data)) {
      await _removeCurrentUserFromPending(companyId, roomId, memberId);
      return;
    }

    final controller = VideoCallOverlayController.instance;
    if (controller.session != null) return;
    if (controller.incomingCall?.roomId == roomId) return;
    if (_activeIncomingRoomId == roomId) return;

    final resolvedTaskId = data['taskId'] as String? ?? taskId;
    final resolvedSubject = data['subject'] as String? ?? subject;
    final resolvedTeamId = data['teamId'] as String? ?? teamId;
    final resolvedCallType = data.containsKey('callType')
        ? _parseCallType(data['callType'])
        : callType;
    final resolvedSource = data['source'] as String?;
    final resolvedSourceContext = data['sourceContext'] as String?;
    final resolvedParticipantMemberIds =
        (data['participantMemberIds'] as List?)?.whereType<String>().toList() ??
            participantMemberIds;

    _presentIncomingCall(
      companyId: companyId,
      roomId: roomId,
      currentMemberId: memberId,
      taskId: resolvedTaskId,
      participantMemberIds: resolvedParticipantMemberIds,
      teamId: resolvedTeamId,
      subject: resolvedSubject,
      callType: resolvedCallType,
      source: resolvedSource,
      sourceContext: resolvedSourceContext,
    );
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
    _player.dispose();
  }

  void _presentIncomingCall({
    required String companyId,
    required String roomId,
    required String currentMemberId,
    String? taskId,
    List<String> participantMemberIds = const [],
    String? callerMemberId,
    String? teamId,
    String? subject,
    VideoCallType callType = VideoCallType.video,
    String? source,
    String? sourceContext,
  }) {
    _addToCallQueue(
      companyId: companyId,
      roomId: roomId,
      currentMemberId: currentMemberId,
      taskId: taskId,
      participantMemberIds: participantMemberIds,
      callerMemberId: callerMemberId,
      teamId: teamId,
      subject: subject,
      callType: callType,
      source: source,
      sourceContext: sourceContext,
    );
  }

  Future<void> _removeCurrentUserFromPending(
    String companyId,
    String roomId,
    String memberId,
  ) async {
    if (memberId.isEmpty) return;

    final roomRef = _communicationsRepo.videoRoomDoc(companyId, roomId);

    try {
      await _communicationsRepo.runTransaction((txn) async {
        final snap = await txn.get(roomRef);
        if (!snap.exists) return;
        final data = snap.data() ?? <String, dynamic>{};
        final pending = _extractPendingParticipants(data);
        if (!pending.contains(memberId)) return;

        final nextPending =
            pending.where((entry) => entry != memberId).toList();
        final status = _normalizeStatus(data['status']);
        final updates = <String, dynamic>{
          'pendingMemberIds': nextPending,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (nextPending.isEmpty && status != 'active') {
          updates['status'] = 'ended';
          updates['endedAt'] = FieldValue.serverTimestamp();
          updates['currentSpeakerMemberId'] = null;
          updates['currentSpeakerSince'] = FieldValue.delete();
        }

        txn.set(roomRef, updates, SetOptions(merge: true));
      });
    } catch (_) {
      // Ignore cleanup failures; room may already be cleared.
    }
  }

  Future<void> _ring() async {
    if (_isRinging) return;
    _isRinging = true;

    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(1.0);
      await _player.play(AssetSource('audio/ringtone.mp3'));
      debugPrint('VideoCallService: Ringtone playing successfully');
    } catch (error) {
      debugPrint('VideoCallService: Failed to play ringtone: $error');
      _startVibrationFallback();
    }
  }

  void _startVibrationFallback() {
    _vibrationTimer?.cancel();
    _vibrationTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) {
      try {
        HapticFeedback.vibrate();
      } catch (error) {
        debugPrint('VideoCallService: Vibration failed: $error');
      }
    });
  }

  Future<void> _stopRing() async {
    _isRinging = false;
    _vibrationTimer?.cancel();
    _vibrationTimer = null;

    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.release);
    } catch (error) {
      debugPrint('VideoCallService: Failed to stop ringtone: $error');
    }
  }

  Future<void> _handleRoomSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    String companyId,
    String memberId,
  ) async {
    if (memberId.isEmpty) return;

    final controller = VideoCallOverlayController.instance;
    final incoming = controller.incomingCall;

    if (snapshot.docs.isEmpty) {
      _callQueue.clear();
      if (incoming != null) {
        await _stopRing();
        await controller.declineIncoming();
      }
      if (controller.waitingCall != null) controller.clearWaiting();
      return;
    }

    final docs = snapshot.docs.toList();
    docs.sort(
      (a, b) => _compareRoomRecency(a.data(), b.data()),
    );

    final validRoomIds = <String>{};
    for (final doc in docs) {
      final data = doc.data();
      if (!_isPendingParticipant(data, memberId)) continue;
      if (_isRoomExpired(data)) {
        await _removeCurrentUserFromPending(companyId, doc.id, memberId);
        _removeFromCallQueue(doc.id);
        if (incoming?.roomId == doc.id) {
          await _stopRing();
          await controller.declineIncoming();
          _processCallQueue(); // Show next call in queue
        }
        if (controller.waitingCall?.roomId == doc.id) {
          controller.clearWaiting();
          _processCallQueue();
        }
        continue;
      }

      validRoomIds.add(doc.id);

      final taskId = data['taskId'] as String?;
      final subject = data['subject'] as String?;
      final teamId = data['teamId'] as String?;
      final callType = _parseCallType(data['callType']);
      final source = data['source'] as String?;
      final sourceContext = data['sourceContext'] as String?;
      final participantMemberIds = (data['participantMemberIds'] as List?)
              ?.whereType<String>()
              .toList() ??
          const <String>[];
      final callerMemberId =
          (data['createdByMemberId'] as String?)?.trim();

      _presentIncomingCall(
        companyId: companyId,
        roomId: doc.id,
        currentMemberId: memberId,
        taskId: taskId,
        participantMemberIds: participantMemberIds,
        callerMemberId:
            (callerMemberId == null || callerMemberId.isEmpty)
                ? null
                : callerMemberId,
        teamId: teamId,
        subject: subject,
        callType: callType,
        source: source,
        sourceContext: sourceContext,
      );
    }

    // Remove any queued calls that are no longer in pending
    _callQueue.removeWhere((call) => !validRoomIds.contains(call.roomId));
  }

  bool _isPendingParticipant(Map<String, dynamic> data, String memberId) {
    final pending = data['pendingMemberIds'];
    if (pending is! List) return false;
    return pending.any((entry) => entry is String && entry == memberId);
  }

  List<String> _extractPendingParticipants(Map<String, dynamic> data) {
    final pending = data['pendingMemberIds'];
    if (pending is! List) return const <String>[];
    return pending.whereType<String>().toList();
  }

  int _compareRoomRecency(
    Map<String, dynamic> first,
    Map<String, dynamic> second,
  ) {
    final firstTime = _resolveRoomTimestamp(first);
    final secondTime = _resolveRoomTimestamp(second);
    return secondTime.compareTo(firstTime);
  }

  DateTime _resolveRoomTimestamp(Map<String, dynamic> data) {
    return _toDateTime(data['updatedAt']) ??
        _toDateTime(data['createdAt']) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  bool _isRoomExpired(Map<String, dynamic> data) {
    final status = _normalizeStatus(data['status']);
    if (_isTerminalStatus(status)) return true;
    if (status == 'active') return false;

    final expiry = _resolveRingExpiry(data);
    if (expiry == null) return false;
    return expiry.isBefore(DateTime.now());
  }

  DateTime? _resolveRingExpiry(Map<String, dynamic> data) {
    final expiresAt = _toDateTime(data['expiresAt']);
    if (expiresAt != null) return expiresAt;
    final createdAt = _toDateTime(data['createdAt']);
    final updatedAt = _toDateTime(data['updatedAt']);
    final base = createdAt ?? updatedAt;
    return base?.add(_ringTimeout);
  }

  bool _isTerminalStatus(String? status) {
    return status == 'ended' ||
        status == 'cancelled' ||
        status == 'missed';
  }

  String? _normalizeStatus(dynamic raw) {
    if (raw is! String) return null;
    final normalized = raw.trim().toLowerCase();
    return normalized.isEmpty ? null : normalized;
  }

  DateTime? _toDateTime(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw);
    }
    if (raw is double) {
      return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
    }
    return null;
  }

  void _addToCallQueue({
    required String companyId,
    required String roomId,
    required String currentMemberId,
    String? taskId,
    List<String> participantMemberIds = const [],
    String? callerMemberId,
    String? teamId,
    String? subject,
    VideoCallType callType = VideoCallType.video,
    String? source,
    String? sourceContext,
  }) {
    // Check if already in queue
    if (_callQueue.any((call) => call.roomId == roomId)) return;

    _callQueue.add(_QueuedIncomingCall(
      companyId: companyId,
      roomId: roomId,
      currentMemberId: currentMemberId,
      taskId: taskId,
      participantMemberIds: participantMemberIds,
      callerMemberId: callerMemberId,
      teamId: teamId,
      subject: subject,
      callType: callType,
      source: source,
      sourceContext: sourceContext,
      timestamp: DateTime.now(),
    ));

    _processCallQueue();
  }

  void _processCallQueue() {
    final controller = VideoCallOverlayController.instance;

    // Drop expired entries, and any whose CallKit ring is already showing
    // for the same room — otherwise the recipient sees the system banner
    // AND an in-app prompt stacked together.
    _callQueue.removeWhere((call) =>
        DateTime.now().difference(call.timestamp) > _ringTimeout);
    _callQueue.removeWhere((call) =>
        IncomingCallService.instance.isCallKitHandled(call.roomId));
    if (_callQueue.isEmpty) return;

    // Most recent first.
    _callQueue.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final nextCall = _callQueue.first;

    // Already in a call → surface the next call as a compact "call waiting"
    // banner instead of a full-screen incoming prompt.
    if (controller.session != null) {
      if (controller.waitingCall != null) return; // banner already up
      if (nextCall.roomId == controller.session!.roomId) return;
      _presentWaitingCall(nextCall);
      return;
    }

    // Not in a call → full incoming-call prompt.
    if (controller.incomingCall != null) return;
    _presentIncomingCallFromQueue(nextCall);
  }

  /// Shows a "call waiting" banner for [call] while another call is active.
  /// Switch → leaves the current call and joins this one; Ignore → declines.
  void _presentWaitingCall(_QueuedIncomingCall call) {
    final controller = VideoCallOverlayController.instance;
    try {
      HapticFeedback.vibrate();
    } catch (_) {}
    controller.showWaiting(
      IncomingVideoCall(
        companyId: call.companyId,
        roomId: call.roomId,
        currentMemberId: call.currentMemberId,
        taskId: call.taskId,
        participantMemberIds: call.participantMemberIds,
        callerMemberId: call.callerMemberId,
        teamId: call.teamId,
        subject: call.subject,
        callType: call.callType,
        source: call.source,
        sourceContext: call.sourceContext,
        onAccept: () async {
          _callQueue.removeWhere((c) => c.roomId == call.roomId);
          unawaited(IncomingCallService.dismiss(call.roomId));
          // Leave the current call first. hangUp → endSession clears the
          // session (and the waiting banner); pause briefly so the old
          // panel fully tears down its WebRTC + audio session before the
          // new one starts — avoids an iOS audio-route clash.
          if (controller.session != null) {
            await controller.requestHangUp();
            await Future<void>.delayed(const Duration(milliseconds: 300));
          }
          controller.startSession(
            VideoCallSession(
              companyId: call.companyId,
              currentMemberId: call.currentMemberId,
              taskId: call.taskId,
              roomId: call.roomId,
              participantMemberIds: call.participantMemberIds,
              callerMemberId: call.callerMemberId,
              teamId: call.teamId,
              subject: call.subject,
              callType: call.callType,
              isCaller: false,
              source: call.source,
              sourceContext: call.sourceContext,
              onEnded: () {
                _activeIncomingRoomId = null;
                unawaited(IncomingCallService.dismiss(call.roomId));
                _processCallQueue();
              },
            ),
          );
        },
        onDecline: () async {
          _callQueue.removeWhere((c) => c.roomId == call.roomId);
          unawaited(IncomingCallService.dismiss(call.roomId));
          await _removeCurrentUserFromPending(
            call.companyId,
            call.roomId,
            call.currentMemberId,
          );
          _processCallQueue();
        },
      ),
    );
  }

  void _presentIncomingCallFromQueue(_QueuedIncomingCall call) {
    _activeIncomingRoomId = call.roomId;
    _ring();

    final controller = VideoCallOverlayController.instance;
    controller.showIncoming(
      IncomingVideoCall(
        companyId: call.companyId,
        roomId: call.roomId,
        currentMemberId: call.currentMemberId,
        taskId: call.taskId,
        participantMemberIds: call.participantMemberIds,
        callerMemberId: call.callerMemberId,
        teamId: call.teamId,
        subject: call.subject,
        callType: call.callType,
        source: call.source,
        sourceContext: call.sourceContext,
        onAccept: () async {
          await _stopRing();
          unawaited(IncomingCallService.dismiss(call.roomId));
          _callQueue.removeWhere((c) => c.roomId == call.roomId);
          controller.startSession(
            VideoCallSession(
              companyId: call.companyId,
              currentMemberId: call.currentMemberId,
              taskId: call.taskId,
              roomId: call.roomId,
              participantMemberIds: call.participantMemberIds,
              callerMemberId: call.callerMemberId,
              teamId: call.teamId,
              subject: call.subject,
              callType: call.callType,
              isCaller: false,
              source: call.source,
              sourceContext: call.sourceContext,
              onEnded: () {
                _activeIncomingRoomId = null;
                unawaited(IncomingCallService.dismiss(call.roomId));
                _processCallQueue(); // Process next call in queue
              },
            ),
          );
        },
        onDecline: () async {
          await _stopRing();
          unawaited(IncomingCallService.dismiss(call.roomId));
          await _removeCurrentUserFromPending(
            call.companyId,
            call.roomId,
            call.currentMemberId,
          );
          _callQueue.removeWhere((c) => c.roomId == call.roomId);
          _activeIncomingRoomId = null;
          _processCallQueue(); // Process next call in queue
        },
      ),
    );
  }

  void _removeFromCallQueue(String roomId) {
    _callQueue.removeWhere((call) => call.roomId == roomId);
  }
}

class _QueuedIncomingCall {
  const _QueuedIncomingCall({
    required this.companyId,
    required this.roomId,
    required this.currentMemberId,
    this.taskId,
    this.participantMemberIds = const [],
    this.callerMemberId,
    this.teamId,
    this.subject,
    required this.callType,
    this.source,
    this.sourceContext,
    required this.timestamp,
  });

  final String companyId;
  final String roomId;
  final String currentMemberId;
  final String? taskId;
  final List<String> participantMemberIds;
  final String? callerMemberId;
  final String? teamId;
  final String? subject;
  final VideoCallType callType;
  final String? source;
  final String? sourceContext;
  final DateTime timestamp;
}
