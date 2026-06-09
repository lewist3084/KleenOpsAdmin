import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/features/notes/services/call_transcription_hook.dart';
import 'package:kleenops_admin/repositories/communications_repository.dart';
import 'package:kleenops_admin/repositories/task_repository.dart';
import 'package:kleenops_admin/services/ice_servers.dart';
import 'package:kleenops_admin/services/screen_capture_service.dart';
import 'package:kleenops_admin/services/video_call_overlay_controller.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';

class VideoChatPanel extends ConsumerStatefulWidget {
  const VideoChatPanel({
    super.key,
    required this.companyId,
    required this.currentMemberId,
    required this.callType,
    this.taskId,
    this.participantMemberIds = const [],
    this.teamId,
    this.subject,
    this.roomId,
    this.initialPttEnabled = false,
    this.onHangUp,
    this.showControls = true,
    this.onToggleOverlay,
    this.onConnected,
    this.source,
    this.sourceContext,
  });

  final String companyId;
  final String currentMemberId;
  final VideoCallType callType;
  final String? taskId;
  final List<String> participantMemberIds;
  final String? teamId;
  final String? subject;
  final String? roomId;
  final bool initialPttEnabled;
  final VoidCallback? onHangUp;
  final bool showControls;
  final VoidCallback? onToggleOverlay;
  final VoidCallback? onConnected;
  final String? source;
  final String? sourceContext;

  @override
  ConsumerState<VideoChatPanel> createState() => _VideoChatPanelState();
}

class _VideoChatPanelState extends ConsumerState<VideoChatPanel>
    implements CallCommandSink {
  final _localRenderer = RTCVideoRenderer();
  final Map<String, RTCVideoRenderer> _remoteRenderersByMemberId = {};
  final List<RTCVideoRenderer> _remoteRenderers = [];
  final Map<String, VideoChatPeerSession> _peerSessions = {};
  static const Duration _ringTimeout = Duration(minutes: 2);

  // ---- Screen share --------------------------------------------------
  // Local share: the captured display stream plus a preview renderer the
  // sharer sees on their own presenter stage. Remote share: a single
  // dedicated renderer for whoever is currently sharing (one at a time).
  MediaStream? _screenStream;
  final RTCVideoRenderer _screenRenderer = RTCVideoRenderer();
  bool _screenRendererReady = false;
  bool _isScreenSharing = false;

  RTCVideoRenderer? _remoteScreenRenderer;
  String? _remoteScreenStreamId;

  // Stream bookkeeping so a screen-share stream can be re-routed correctly
  // regardless of whether the WebRTC track or the Firestore `screenShare`
  // field arrives first. Maps every remote stream by its id, and remembers
  // the first (camera/voice) stream seen per member.
  final Map<String, MediaStream> _remoteStreamById = {};
  final Map<String, String> _memberPrimaryStreamId = {};

  MediaStream? _localStream;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _participantsSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _roomSub;
  DocumentReference<Map<String, dynamic>>? _roomRef;
  String? _currentMemberId;
  List<Map<String, dynamic>> _iceServers = const [];

  bool _didCleanup = false;
  // Guards _hangUp against re-entry: the user tapping End and the
  // room-doc terminal-status listener can both fire it.
  bool _hangingUp = false;
  bool _micEnabled = true;
  bool _camEnabled = true;
  bool _frontCamera = true;
  bool _pttEnabled = false;
  // Whether call audio is routed to the loudspeaker. Seeded by
  // _configureAudioRouting (speaker for video, earpiece for voice) and
  // flipped by the control strip's speaker button via setSpeakerphone.
  bool _speakerphoneOn = false;
  bool _requestInFlight = false;
  bool _storedMicEnabled = true;
  bool _upgradingToVideo = false;
  bool _remoteVideoActive = false;
  String? _currentSpeakerMemberId;
  List<String> _unavailableMemberNames = const [];
  CallTranscriptionHook? _transcriptionHook;

  // Tracks the room's most recent host-issued mute-all stamp. We seed
  // this on first snapshot so freshly-joined peers aren't retro-muted;
  // only later increments trigger a local soft-mute.
  Timestamp? _lastMuteAllAt;

  bool get _isVideoCall => widget.callType == VideoCallType.video;
  // The local user created this room (no roomId was passed in). The
  // originator ending a voice call tears the room down for everyone.
  bool get _isCaller => widget.roomId == null;
  bool get _isCurrentSpeaker => _currentSpeakerMemberId == _currentMemberId;
  bool get _hasLocalVideoTrack =>
      (_localStream?.getVideoTracks() ?? const <MediaStreamTrack>[]).isNotEmpty;
  bool get _showVideoLayout =>
      _isVideoCall || _hasLocalVideoTrack || _remoteVideoActive;
  bool _didNotifyConnected = false;

  // Outgoing-call ringback. While the caller waits for someone to answer,
  // a looping ring tone plays so they know the call is dialing; it is
  // stopped the moment the first invitee joins (or the call ends).
  AudioPlayer? _ringbackPlayer;
  bool _ringbackStarted = false;

  CollectionReference<Map<String, dynamic>> get _roomCollection => ref
      .read(communicationsRepositoryProvider)
      .videoRoomCollection(widget.companyId);

  @override
  void initState() {
    super.initState();
    VideoCallOverlayController.instance.attachCommandSink(this);
    VideoCallOverlayController.instance.publishMediaState(
      micEnabled: _micEnabled,
      cameraEnabled: _camEnabled,
      pttEnabled: _pttEnabled,
      videoActive: _isVideoCall,
      clearSpeaker: true,
    );
    // The originator hears a ringback tone until someone answers.
    if (_isCaller) unawaited(_startRingback());
    unawaited(_bootstrap());
  }

  /// Plays a looping telephone ringback tone so the caller has audible
  /// feedback that the call is dialing. Stopped by [_stopRingback] the
  /// moment the first invitee joins or the call ends. No-op for a callee
  /// joining an existing room, and safe to call more than once.
  Future<void> _startRingback() async {
    if (_ringbackStarted) return;
    _ringbackStarted = true;
    final player = AudioPlayer();
    _ringbackPlayer = player;
    try {
      // Mix alongside the WebRTC audio session rather than seizing it:
      // playAndRecord + mixWithOthers on iOS, the dedicated in-call
      // signalling usage with no audio-focus grab on Android.
      await player.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playAndRecord,
            options: const {
              AVAudioSessionOptions.mixWithOthers,
              AVAudioSessionOptions.allowBluetooth,
              AVAudioSessionOptions.allowBluetoothA2DP,
            },
          ),
          android: const AudioContextAndroid(
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.voiceCommunicationSignalling,
            audioFocus: AndroidAudioFocus.none,
          ),
        ),
      );
      await player.setReleaseMode(ReleaseMode.loop);
      await player.play(AssetSource('audio/ringback.wav'));
    } catch (err) {
      debugPrint('[VideoCall][caller] ringback failed: $err');
    }
  }

  /// Stops and releases the ringback tone. Idempotent.
  Future<void> _stopRingback() async {
    final player = _ringbackPlayer;
    _ringbackPlayer = null;
    if (player == null) return;
    try {
      await player.stop();
    } catch (_) {
      // ignore — player may already be torn down
    }
    try {
      await player.dispose();
    } catch (_) {
      // ignore
    }
  }

  Future<MediaStream> _createMedia({required bool front}) {
    return navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video':
          _isVideoCall ? {'facingMode': front ? 'user' : 'environment'} : false,
    });
  }

  /// Configure the platform audio session so audio routes to a paired
  /// Bluetooth headset / wired earbuds when present, falling back to
  /// speakerphone (video) or earpiece (voice) when nothing is attached.
  ///
  /// Without this, flutter_webrtc on iOS opens AVAudioSession without
  /// the `allowBluetooth`/`allowBluetoothA2DP` options, so even when
  /// the OS reports earbuds as the active route the call grabs the
  /// built-in mic/speaker.
  Future<void> _configureAudioRouting() async {
    try {
      // iOS: playAndRecord + allowBluetooth + voiceChat/videoChat.
      // No-op on Android.
      await Helper.setAppleAudioIOMode(
        AppleAudioIOMode.localAndRemote,
        preferSpeakerOutput: _isVideoCall,
      );
    } catch (err) {
      debugPrint('[VideoCall] setAppleAudioIOMode failed: $err');
    }

    try {
      if (_isVideoCall) {
        // Speakerphone for video, but a connected BT/wired headset
        // takes precedence.
        await Helper.setSpeakerphoneOnButPreferBluetooth();
        _speakerphoneOn = true;
      } else {
        // Voice call: earpiece by default; AVAudioSession routes to
        // BT/wired automatically when one is connected.
        await Helper.setSpeakerphoneOn(false);
        _speakerphoneOn = false;
      }
    } catch (err) {
      debugPrint('[VideoCall] speakerphone routing failed: $err');
    }
    if (mounted) setState(() {});
    VideoCallOverlayController.instance
        .publishMediaState(speakerphoneOn: _speakerphoneOn);
  }

  Future<void> _bootstrap() async {
    debugPrint('[VideoCall][caller] _bootstrap start callType=${widget.callType} '
        'taskId=${widget.taskId} teamId=${widget.teamId} '
        'subject=${widget.subject} '
        'participantMemberIds=${widget.participantMemberIds} '
        'source=${widget.source}');
    try {
      await _localRenderer.initialize();
      await _configureAudioRouting();

      final memberId = widget.currentMemberId.trim();
      if (memberId.isEmpty) {
        throw StateError('Active member is required to start a call.');
      }
      _currentMemberId = memberId;
      debugPrint('[VideoCall][caller] memberId=$memberId');

      final isCaller = widget.roomId == null;
      String roomId;
      if (widget.roomId == null) {
        debugPrint('[VideoCall][caller] calling createVideoRoom cloud fn...');
        roomId = await _createRoom();
        debugPrint('[VideoCall][caller] createVideoRoom returned roomId=$roomId');
      } else {
        roomId = widget.roomId!;
        debugPrint('[VideoCall][caller] joining existing roomId=$roomId');
      }
      if (isCaller) {
        VideoCallOverlayController.instance.setSessionRoomId(roomId);
      }
    final roomRef = _roomCollection.doc(roomId);
    _roomRef = roomRef;
    _listenRoom(roomRef);

    if (!isCaller) {
      final roomSnap = await roomRef.get();
      if (!roomSnap.exists) {
        throw StateError('This call is no longer available.');
      }
      await _ensureRoomAccess(roomRef, roomSnap.data(), memberId);
      await _ensureRoomState(roomRef, roomSnap.data());
    }

    _localStream = await _createMedia(front: true);
    final lAudio = _localStream?.getAudioTracks() ?? const [];
    final lVideo = _localStream?.getVideoTracks() ?? const [];
    debugPrint('[VideoCall][caller] local media ready '
        'audioTracks=${lAudio.length} videoTracks=${lVideo.length} '
        'isVideoCall=$_isVideoCall isCaller=$isCaller memberId=$memberId');
    // Joiners enter muted so the existing call isn't disrupted by
    // background audio; the caller stays unmuted. The joiner can unmute
    // themselves from the control strip at any time.
    if (!isCaller) {
      _storedMicEnabled = false;
      _setMicEnabled(false);
    }
    _localRenderer.srcObject = _localStream;
    // Publish the local renderer so call chrome (the participant strip)
    // can show the user's own face alongside the other participants.
    VideoCallOverlayController.instance.publishLocalRenderer(_localRenderer);

    await _updateParticipantStatus(roomRef, memberId, 'joined');

    if (!isCaller) {
      await roomRef.update({
        'pendingMemberIds': FieldValue.arrayRemove([memberId]),
      });
    }

    await _markRoomActive(roomRef);

    try {
      _iceServers = await fetchIceServers();
      if (_iceServers.isEmpty) {
        _iceServers = fallbackIceServers();
      }
    } catch (_) {
      _iceServers = fallbackIceServers();
    }
    _listenParticipants(roomRef, memberId);

    // Transcription is no longer auto-prompted on connect — the user
    // explicitly toggles it via the in-call control strip. _listenRoom
    // watches the room's `transcription` field and starts/stops the hook
    // when any participant flips that toggle.
      debugPrint('[VideoCall][caller] _bootstrap done');
    } catch (err, st) {
      debugPrint('[VideoCall][caller] _bootstrap FAILED: $err\n$st');
      unawaited(_stopRingback());
      rethrow;
    }
  }

  Future<String> _createRoom() async {
    final Map<String, dynamic> createPayload = <String, dynamic>{
      'companyId': widget.companyId,
      'callType': _isVideoCall ? 'video' : 'voice',
    };
    if (widget.taskId != null && widget.taskId!.isNotEmpty) {
      createPayload['taskId'] = widget.taskId;
    }
    if (widget.participantMemberIds.isNotEmpty) {
      createPayload['participantMemberIds'] = widget.participantMemberIds;
    }
    if (widget.teamId != null && widget.teamId!.isNotEmpty) {
      createPayload['teamId'] = widget.teamId;
    }
    if (widget.subject != null && widget.subject!.trim().isNotEmpty) {
      createPayload['subject'] = widget.subject!.trim();
    }
    if (widget.source != null && widget.source!.trim().isNotEmpty) {
      createPayload['source'] = widget.source!.trim();
    }
    if (widget.sourceContext != null &&
        widget.sourceContext!.trim().isNotEmpty) {
      createPayload['sourceContext'] = widget.sourceContext!.trim();
    }
    if (widget.initialPttEnabled) {
      createPayload['pttEnabled'] = true;
    }

    debugPrint('[VideoCall][caller] _createRoom payload=$createPayload');
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('createVideoRoom')
          .call(createPayload);
      debugPrint('[VideoCall][caller] _createRoom result=${result.data}');
      return result.data as String;
    } catch (err) {
      debugPrint('[VideoCall][caller] _createRoom call FAILED: $err');
      rethrow;
    }
  }

  Future<void> _ensureRoomAccess(
    DocumentReference<Map<String, dynamic>> roomRef,
    Map<String, dynamic>? roomData,
    String memberId,
  ) async {
    final data = roomData ?? <String, dynamic>{};
    final createdBy = data['createdByMemberId'];
    if (createdBy is String && createdBy.trim() == memberId) return;
    if (_memberIdInList(data['pendingMemberIds'], memberId)) return;
    if (_memberIdInList(data['participantMemberIds'], memberId)) return;

    final participantSnap =
        await roomRef.collection('participants').doc(memberId).get();
    if (participantSnap.exists) return;

    throw StateError('You are not invited to this call.');
  }

  bool _memberIdInList(Object? raw, String memberId) {
    if (raw is! List) return false;
    for (final entry in raw) {
      if (entry is String && entry.trim() == memberId) {
        return true;
      }
    }
    return false;
  }

  String? _normalizeStatus(dynamic raw) {
    if (raw is! String) return null;
    final normalized = raw.trim().toLowerCase();
    return normalized.isEmpty ? null : normalized;
  }

  bool _isTerminalStatus(String? status) {
    return status == 'ended' ||
        status == 'cancelled' ||
        status == 'missed';
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

  DateTime? _resolveRingExpiry(Map<String, dynamic> data) {
    final expiresAt = _toDateTime(data['expiresAt']);
    if (expiresAt != null) return expiresAt;
    final createdAt = _toDateTime(data['createdAt']);
    final updatedAt = _toDateTime(data['updatedAt']);
    final base = createdAt ?? updatedAt;
    return base?.add(_ringTimeout);
  }

  bool _isRoomExpired(Map<String, dynamic> data) {
    final status = _normalizeStatus(data['status']);
    if (status == 'active') return false;
    final expiry = _resolveRingExpiry(data);
    if (expiry == null) return false;
    return expiry.isBefore(DateTime.now());
  }

  Future<void> _ensureRoomState(
    DocumentReference<Map<String, dynamic>> roomRef,
    Map<String, dynamic>? roomData,
  ) async {
    if (roomData == null) return;
    final status = _normalizeStatus(roomData['status']);
    if (_isTerminalStatus(status)) {
      throw StateError('This call has ended.');
    }
    if (_isRoomExpired(roomData)) {
      await _expireRoom(roomRef);
      throw StateError('This call is no longer available.');
    }
  }

  Future<void> _expireRoom(
    DocumentReference<Map<String, dynamic>> roomRef,
  ) async {
    try {
      await roomRef.set({
        'status': 'ended',
        'endedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'pendingMemberIds': [],
        'currentSpeakerMemberId': null,
        'currentSpeakerSince': FieldValue.delete(),
      }, SetOptions(merge: true));
    } catch (_) {
      // ignore expiration failures
    }
  }

  Future<void> _markRoomActive(
    DocumentReference<Map<String, dynamic>> roomRef,
  ) async {
    try {
      await ref
          .read(communicationsRepositoryProvider)
          .runTransaction((txn) async {
        final snap = await txn.get(roomRef);
        if (!snap.exists) return;
        final data = snap.data() ?? <String, dynamic>{};
        final status = _normalizeStatus(data['status']);
        if (_isTerminalStatus(status) || status == 'active') return;
        txn.set(
          roomRef,
          {
            'status': 'active',
            'startedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });
    } catch (_) {
      // ignore activation failures
    }
  }

  Future<void> _maybeEndRoom(
    DocumentReference<Map<String, dynamic>> roomRef,
  ) async {
    try {
      final joinedSnap = await roomRef
          .collection('participants')
          .where('status', isEqualTo: 'joined')
          .limit(1)
          .get();
      if (joinedSnap.docs.isEmpty) {
        await roomRef.set({
          'status': 'ended',
          'endedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'pendingMemberIds': [],
          'currentSpeakerMemberId': null,
          'currentSpeakerSince': FieldValue.delete(),
        }, SetOptions(merge: true));
      }
    } catch (_) {
      // ignore cleanup failures
    }
  }

  /// Force the room into a terminal state for every participant.
  /// Unlike [_maybeEndRoom] it does not wait for the room to empty
  /// out — every other client's [_listenRoom] sees the `ended` status
  /// and tears its own call down too.
  Future<void> _endRoomForAll() async {
    final roomRef = _roomRef;
    if (roomRef == null) return;
    try {
      await roomRef.set({
        'status': 'ended',
        'endedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'pendingMemberIds': [],
        'currentSpeakerMemberId': null,
        'currentSpeakerSince': FieldValue.delete(),
      }, SetOptions(merge: true));
    } catch (_) {
      // ignore — _cleanup's _maybeEndRoom is a best-effort fallback
    }
  }

  Future<void> _hangUp() async {
    if (_hangingUp) return;
    _hangingUp = true;

    // The originator hanging up a voice call ends it for everyone:
    // hanging up a "line" should drop the other lines too.
    if (_isCaller && !_isVideoCall) {
      await _endRoomForAll();
    }

    // Finalize transcription before cleanup disposes resources
    final hook = _transcriptionHook;
    _transcriptionHook = null;
    if (hook != null) {
      try {
        await hook.onCallEnded();
      } catch (_) {}
      await hook.dispose();
    }
    await _cleanup();
    widget.onHangUp?.call();

    if (widget.onHangUp == null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (GoRouter.of(context).canPop()) {
          GoRouter.of(context).pop();
        }
      });
    }
  }

  void _listenParticipants(
    DocumentReference<Map<String, dynamic>> roomRef,
    String localMemberId,
  ) {
    _participantsSub = roomRef
        .collection('participants')
        .snapshots()
        .listen((snapshot) {
      if (_didCleanup) return;

      final active = <String>{};
      for (final doc in snapshot.docs) {
        if (doc.id == localMemberId) continue;
        final data = doc.data();
        final status = (data['status'] as String?) ?? 'joined';
        if (status == 'joined') {
          active.add(doc.id);
        }
      }

      // First invitee to answer silences the caller's ringback tone.
      if (active.isNotEmpty) {
        unawaited(_stopRingback());
      }

      for (final remoteMemberId in active) {
        _ensurePeerSession(roomRef, remoteMemberId);
      }

      final toRemove = _peerSessions.keys
          .where((memberId) => !active.contains(memberId))
          .toList();
      for (final remoteMemberId in toRemove) {
        unawaited(_removePeerSession(remoteMemberId));
      }
    });
  }

  void _listenRoom(DocumentReference<Map<String, dynamic>> roomRef) {
    _roomSub = roomRef.snapshots().listen((snap) {
      if (_didCleanup || !snap.exists) return;
      final data = snap.data() ?? <String, dynamic>{};
      final status = _normalizeStatus(data['status']);
      if (_isTerminalStatus(status)) {
        unawaited(_hangUp());
        return;
      }
      final nextPtt = data['pttEnabled'] == true;
      final nextSpeaker = data['currentSpeakerMemberId'] as String?;
      final pttChanged = nextPtt != _pttEnabled;
      final speakerChanged = nextSpeaker != _currentSpeakerMemberId;

      if (pttChanged && nextPtt) {
        _storedMicEnabled = _micEnabled;
      }

      if (pttChanged || speakerChanged) {
        setState(() {
          _pttEnabled = nextPtt;
          _currentSpeakerMemberId = nextSpeaker;
        });
        VideoCallOverlayController.instance.publishMediaState(
          pttEnabled: nextPtt,
          isCurrentSpeaker: nextSpeaker == _currentMemberId,
          currentSpeakerMemberId: nextSpeaker,
          clearSpeaker: nextSpeaker == null,
        );
      }

      if (nextPtt) {
        _syncMicForPtt();
      } else if (pttChanged) {
        _setMicEnabled(_storedMicEnabled);
      }

      // Check for unavailable members
      final rawUnavailable = data['unavailableMemberIds'] as List<dynamic>?;
      if (rawUnavailable != null && rawUnavailable.isNotEmpty) {
        final ids = rawUnavailable.whereType<String>().toList();
        if (ids.isNotEmpty && _unavailableMemberNames.isEmpty) {
          unawaited(_resolveUnavailableNames(ids));
        }
      }

      // Transcription toggle: when any participant flips the room's
      // `transcription` field, every client should start/stop its own
      // utterance capture so the server-side summarizer gets all mics.
      _applyTranscriptionFromRoom(data['transcription']);

      // Screen share: route a sharer's stream to the presenter stage, or
      // tear it down when they stop.
      _applyRemoteScreenShare(data['screenShare']);

      // Host-issued mute-all: when the room's muteAllAt advances past
      // what we've seen, soft-mute the local mic unless we sent it.
      final muteAllAt = data['muteAllAt'];
      if (muteAllAt is Timestamp) {
        if (_lastMuteAllAt == null) {
          _lastMuteAllAt = muteAllAt;
        } else if (muteAllAt.compareTo(_lastMuteAllAt!) > 0) {
          _lastMuteAllAt = muteAllAt;
          final muter = data['muteAllBy'];
          if (muter != _currentMemberId && _micEnabled) {
            _setMicEnabled(false);
          }
        }
      }
    });
  }

  void _applyTranscriptionFromRoom(dynamic raw) {
    final roomRef = _roomRef;
    final memberId = _currentMemberId;
    if (roomRef == null || memberId == null) return;

    final active =
        raw is Map && raw['startedByMemberId'] is String;
    final startedByMemberId =
        active ? raw['startedByMemberId'] as String : null;
    final startedByName = active ? raw['startedByName'] as String? : null;

    final wasActive = _transcriptionHook?.isTranscribing ?? false;

    if (active && !wasActive) {
      final taskRepo = ref.read(taskRepositoryProvider);
      _transcriptionHook ??= CallTranscriptionHook(
        companyRef: taskRepo.companyDoc(widget.companyId),
        memberRef: taskRepo.memberDoc(widget.companyId, memberId),
        callType: _isVideoCall ? 'videoCall' : 'intercom_voice',
        participantIds: widget.participantMemberIds,
        source: widget.source,
        sourceContext: widget.sourceContext,
        roomRef: roomRef,
        currentMemberId: memberId,
      );
      _transcriptionHook!.startLive();
      _announceTranscriptionStarted(
        startedByMemberId: startedByMemberId,
        startedByName: startedByName,
      );
    } else if (!active && wasActive) {
      unawaited(_transcriptionHook!.dispose());
      _transcriptionHook = null;
      _announceTranscriptionStopped();
    }

    VideoCallOverlayController.instance.publishTranscriptionState(
      transcribing: active,
      startedByMemberId: startedByMemberId,
      startedByName: startedByName,
    );
  }

  void _announceTranscriptionStarted({
    required String? startedByMemberId,
    required String? startedByName,
  }) {
    final isMe = startedByMemberId == _currentMemberId;
    final message = isMe
        ? 'Transcription on. Everyone has been notified — a SUMMARY will be created when the call ends.'
        : '${(startedByName ?? '').trim().isEmpty ? 'A participant' : startedByName!.trim()} turned on transcription. A SUMMARY will be created when the call ends.';
    SnackbarService.instance.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _announceTranscriptionStopped() {
    SnackbarService.instance.showSnackBar(
      const SnackBar(
        content: Text('Transcription stopped.'),
        duration: Duration(seconds: 5),
      ),
    );
  }

  Future<void> _resolveUnavailableNames(List<String> memberIds) async {
    final taskRepo = ref.read(taskRepositoryProvider);
    final names = <String>[];
    for (final id in memberIds) {
      try {
        final snap = await taskRepo.memberDoc(widget.companyId, id).get();
        final data = snap.data() ?? {};
        final first = (data['firstName'] as String?) ?? '';
        final last = (data['lastName'] as String?) ?? '';
        final name = '$first $last'.trim();
        if (name.isNotEmpty) {
          names.add(name);
        }
      } catch (_) {
        // skip unresolvable members
      }
    }
    if (mounted && names.isNotEmpty) {
      setState(() {
        _unavailableMemberNames = names;
      });
    }
  }

  void _ensurePeerSession(
    DocumentReference<Map<String, dynamic>> roomRef,
    String remoteMemberId,
  ) {
    if (_peerSessions.containsKey(remoteMemberId)) return;
    final localMemberId = _currentMemberId;
    final stream = _localStream;
    if (localMemberId == null || stream == null) return;

    final isOfferer = localMemberId.compareTo(remoteMemberId) < 0;
    final pairId = _pairId(localMemberId, remoteMemberId);
    final connectionRef =
        roomRef.collection('connections').doc(pairId);

    final session = VideoChatPeerSession(
      localUid: localMemberId,
      remoteUid: remoteMemberId,
      connectionRef: connectionRef,
      localStream: stream,
      iceServers: _iceServers,
      isOfferer: isOfferer,
      onRemoteStream: (stream) =>
          _attachRemoteStream(stream, remoteMemberId),
      screenStream: _isScreenSharing ? _screenStream : null,
    );

    _peerSessions[remoteMemberId] = session;
    unawaited(session.start());
  }

  Future<void> _attachRemoteStream(
    MediaStream stream,
    String remoteUid,
  ) async {
    if (_didCleanup) return;

    // Track every remote stream so a screen share can be reconciled no
    // matter the arrival order of track vs Firestore field. The first
    // stream seen for a member is their camera/voice feed.
    _remoteStreamById[stream.id] = stream;
    _memberPrimaryStreamId.putIfAbsent(remoteUid, () => stream.id);

    // A screen-share stream routes to the dedicated presenter renderer
    // rather than the member's avatar bubble / grid tile.
    if (_remoteScreenStreamId != null && stream.id == _remoteScreenStreamId) {
      await _attachRemoteScreen(stream, remoteUid);
      return;
    }

    final hasVideo = stream.getVideoTracks().isNotEmpty;
    debugPrint('[VideoCall][attach] remoteUid=$remoteUid '
        'hasVideo=$hasVideo audioTracks=${stream.getAudioTracks().length} '
        'videoTracks=${stream.getVideoTracks().length} '
        'existing=${_remoteRenderersByMemberId.containsKey(remoteUid)}');

    final existing = _remoteRenderersByMemberId[remoteUid];
    if (existing != null) {
      existing.srcObject = stream;
      _notifyConnected();
      VideoCallOverlayController.instance
          .publishRemoteRenderer(remoteUid, existing);
      if (hasVideo && !_remoteVideoActive && mounted) {
        setState(() => _remoteVideoActive = true);
        VideoCallOverlayController.instance
            .publishMediaState(videoActive: true);
      }
      return;
    }

    final renderer = RTCVideoRenderer();
    await renderer.initialize();
    renderer.srcObject = stream;

    _remoteRenderersByMemberId[remoteUid] = renderer;
    _remoteRenderers.add(renderer);
    VideoCallOverlayController.instance
        .publishRemoteRenderer(remoteUid, renderer);
    _notifyConnected();
    if (mounted) {
      setState(() {
        if (hasVideo) _remoteVideoActive = true;
      });
      if (hasVideo) {
        VideoCallOverlayController.instance
            .publishMediaState(videoActive: true);
      }
    } else if (hasVideo) {
      _remoteVideoActive = true;
    }
  }

  void _notifyConnected() {
    if (_didNotifyConnected) return;
    _didNotifyConnected = true;
    widget.onConnected?.call();
  }

  Future<void> _removePeerSession(String remoteUid) async {
    final session = _peerSessions.remove(remoteUid);
    if (session != null) {
      await session.dispose();
    }
    await _detachRemoteStream(remoteUid);
  }

  Future<void> _detachRemoteStream(String remoteUid) async {
    final renderer = _remoteRenderersByMemberId.remove(remoteUid);
    if (renderer == null) return;

    _remoteRenderers.remove(renderer);
    VideoCallOverlayController.instance.clearRemoteRenderer(remoteUid);
    renderer.srcObject = null;
    await renderer.dispose();
    if (mounted) {
      setState(() {});
    }
  }

  // ---- Screen share: local -------------------------------------------

  @override
  Future<void> setScreenSharing(bool enabled) async {
    if (enabled) {
      await _startScreenShare();
    } else {
      await _stopScreenShare();
    }
  }

  Future<void> _startScreenShare() async {
    if (_isScreenSharing) return;
    final roomRef = _roomRef;
    final memberId = _currentMemberId;
    if (roomRef == null || memberId == null) return;

    // Android MediaProjection needs a mediaProjection foreground service
    // running before the projection token is acquired. No-op elsewhere.
    await ScreenCaptureService.start();

    MediaStream stream;
    try {
      stream = await navigator.mediaDevices.getDisplayMedia({
        'video': true,
        'audio': false,
      });
    } catch (err) {
      // User dismissed the picker, or the platform/browser denied it.
      debugPrint('[VideoCall][screen] getDisplayMedia failed: $err');
      await ScreenCaptureService.stop();
      return;
    }

    final tracks = stream.getVideoTracks();
    if (tracks.isEmpty) {
      try {
        await stream.dispose();
      } catch (_) {}
      await ScreenCaptureService.stop();
      return;
    }
    if (_didCleanup) {
      for (final t in tracks) {
        try {
          t.stop();
        } catch (_) {}
      }
      try {
        await stream.dispose();
      } catch (_) {}
      await ScreenCaptureService.stop();
      return;
    }

    _screenStream = stream;
    _isScreenSharing = true;

    // The browser/OS "Stop sharing" affordance ends the track directly;
    // mirror that into our own teardown so state stays consistent.
    tracks.first.onEnded = () {
      unawaited(_stopScreenShare());
    };

    if (!_screenRendererReady) {
      await _screenRenderer.initialize();
      _screenRendererReady = true;
    }
    _screenRenderer.srcObject = stream;

    // Announce to peers BEFORE adding the track so receivers already know
    // the stream id to route when the renegotiated track lands.
    String shareName = 'You';
    try {
      final snap = await ref
          .read(taskRepositoryProvider)
          .memberDoc(widget.companyId, memberId)
          .get();
      final data = snap.data() ?? <String, dynamic>{};
      final first = (data['firstName'] as String?) ?? '';
      final last = (data['lastName'] as String?) ?? '';
      final full = '$first $last'.trim();
      shareName = full.isNotEmpty
          ? full
          : ((data['displayName'] as String?)?.trim().isNotEmpty == true
              ? (data['displayName'] as String).trim()
              : 'You');
    } catch (_) {
      // best-effort label; receivers fall back to "A participant"
    }

    try {
      await roomRef.set({
        'screenShare': {
          'memberId': memberId,
          'streamId': stream.id,
          'startedByName': shareName,
          'startedAt': FieldValue.serverTimestamp(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (err) {
      debugPrint('[VideoCall][screen] announce failed: $err');
    }

    // Push the share track to every already-connected peer.
    for (final session in _peerSessions.values) {
      for (final track in tracks) {
        unawaited(session.addScreenTrack(track, stream));
      }
    }

    // Surface the share on the local user's own presenter stage so they
    // can see what they're sharing.
    VideoCallOverlayController.instance.publishScreenShare(
      renderer: _screenRenderer,
      memberId: memberId,
      name: 'You',
      isLocal: true,
    );
    if (mounted) setState(() {});
  }

  Future<void> _stopScreenShare() async {
    if (!_isScreenSharing) return;
    _isScreenSharing = false;

    final roomRef = _roomRef;
    if (roomRef != null) {
      try {
        await roomRef.set({
          'screenShare': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {
        // ignore — peers also tear down on the renegotiated track removal
      }
    }

    for (final session in _peerSessions.values) {
      unawaited(session.removeScreenTrack());
    }

    final stream = _screenStream;
    _screenStream = null;
    _screenRenderer.srcObject = null;
    if (stream != null) {
      for (final track in stream.getTracks()) {
        try {
          track.stop();
        } catch (_) {}
      }
      try {
        await stream.dispose();
      } catch (_) {}
    }

    await ScreenCaptureService.stop();

    // Only clear the controller's stage if it's showing OUR share — a
    // remote share (someone else) owns the slot independently.
    if (VideoCallOverlayController.instance.screenShareIsLocal) {
      VideoCallOverlayController.instance.clearScreenShare();
    }
    if (mounted) setState(() {});
  }

  // ---- Screen share: remote ------------------------------------------

  /// Reconcile the room's `screenShare` field into local state. Called on
  /// every room snapshot. Handles a remote share starting, stopping, or
  /// changing owner, and re-routes an already-arrived stream if needed.
  void _applyRemoteScreenShare(dynamic raw) {
    String? memberId;
    String? streamId;
    String? name;
    if (raw is Map) {
      memberId = (raw['memberId'] as String?)?.trim();
      streamId = (raw['streamId'] as String?)?.trim();
      name = (raw['startedByName'] as String?)?.trim();
    }

    // Our own share echoes back through the room doc — ignore it; the
    // local stage is driven directly by _startScreenShare.
    if (memberId != null && memberId == _currentMemberId) return;

    if (streamId == null || streamId.isEmpty || memberId == null) {
      // Sharing stopped (or never present).
      if (_remoteScreenStreamId != null) _clearRemoteScreen();
      return;
    }

    if (streamId == _remoteScreenStreamId) return; // unchanged

    _remoteScreenStreamId = streamId;

    // If the share stream already arrived (possibly mis-attached to the
    // member's camera renderer before the field landed), fix it up.
    _restoreMemberCamerasClobberedBy(streamId);
    final existing = _remoteStreamById[streamId];
    if (existing != null) {
      unawaited(_attachRemoteScreen(existing, memberId, name: name));
    }
  }

  Future<void> _attachRemoteScreen(
    MediaStream stream,
    String memberId, {
    String? name,
  }) async {
    if (_didCleanup) return;
    var renderer = _remoteScreenRenderer;
    if (renderer == null) {
      renderer = RTCVideoRenderer();
      await renderer.initialize();
      if (_didCleanup) {
        await renderer.dispose();
        return;
      }
      _remoteScreenRenderer = renderer;
    }
    renderer.srcObject = stream;

    VideoCallOverlayController.instance.publishScreenShare(
      renderer: renderer,
      memberId: memberId,
      name: name,
      isLocal: false,
    );
    if (mounted) setState(() {});
  }

  /// If a member's camera renderer is currently showing the screen stream
  /// (because the track landed before the field), point it back at that
  /// member's real camera stream.
  void _restoreMemberCamerasClobberedBy(String screenStreamId) {
    for (final entry in _remoteRenderersByMemberId.entries) {
      if (entry.value.srcObject?.id != screenStreamId) continue;
      final primaryId = _memberPrimaryStreamId[entry.key];
      final cam =
          (primaryId != null && primaryId != screenStreamId)
              ? _remoteStreamById[primaryId]
              : null;
      entry.value.srcObject = cam;
    }
  }

  void _clearRemoteScreen() {
    _remoteScreenStreamId = null;
    final renderer = _remoteScreenRenderer;
    _remoteScreenRenderer = null;
    if (renderer != null) {
      renderer.srcObject = null;
      unawaited(renderer.dispose());
    }
    if (!VideoCallOverlayController.instance.screenShareIsLocal) {
      VideoCallOverlayController.instance.clearScreenShare();
    }
    if (mounted) setState(() {});
  }

  Future<void> _upgradeToVideo(MediaStream stream) async {
    if (_upgradingToVideo) return;
    setState(() => _upgradingToVideo = true);

    MediaStream? videoStream;
    try {
      videoStream = await navigator.mediaDevices.getUserMedia({
        'audio': false,
        'video': {'facingMode': _frontCamera ? 'user' : 'environment'},
      });
    } catch (e) {
      if (mounted) {
        setState(() => _upgradingToVideo = false);
        SnackbarService.instance.showSnackBar(
          SnackBar(duration: const Duration(seconds: 5), content: Text('Camera unavailable: $e')),
        );
      }
      return;
    }

    final videoTracks = videoStream.getVideoTracks();
    if (videoTracks.isEmpty) {
      if (mounted) setState(() => _upgradingToVideo = false);
      return;
    }

    for (final track in videoTracks) {
      try {
        await stream.addTrack(track);
      } catch (_) {
        // ignore add failures; track may already be present
      }
    }

    _localRenderer.srcObject = stream;

    for (final session in _peerSessions.values) {
      for (final track in videoTracks) {
        unawaited(session.addLocalTrack(track, stream));
      }
    }

    if (mounted) {
      setState(() {
        _camEnabled = true;
        _upgradingToVideo = false;
      });
      VideoCallOverlayController.instance.publishMediaState(
        hasLocalCamera: true,
        videoActive: true,
        cameraEnabled: true,
      );
    }
  }

  Future<void> _cleanup() async {
    if (_didCleanup) return;
    _didCleanup = true;

    await _stopRingback();
    await _releaseTalk();
    await _participantsSub?.cancel();
    await _roomSub?.cancel();

    if (_transcriptionHook != null) {
      try {
        await _transcriptionHook!.dispose();
      } catch (_) {
        // ignore — server summarizer still has utterances written so far
      }
      _transcriptionHook = null;
    }

    final roomRef = _roomRef;
    final localUid = _currentMemberId;
    if (roomRef != null && localUid != null) {
      try {
        await _updateParticipantStatus(roomRef, localUid, 'left');
        await _maybeEndRoom(roomRef);
      } catch (_) {
        // ignore cleanup failures
      }
    }

    for (final session in _peerSessions.values) {
      await session.dispose();
    }
    _peerSessions.clear();

    for (final renderer in _remoteRenderers) {
      try {
        renderer.srcObject = null;
        await renderer.dispose();
      } catch (_) {
        // ignore
      }
    }
    _remoteRenderers.clear();
    _remoteRenderersByMemberId.clear();
    _remoteStreamById.clear();
    _memberPrimaryStreamId.clear();

    // Tear down screen-share resources (local capture + remote renderer).
    _isScreenSharing = false;
    final localScreen = _screenStream;
    _screenStream = null;
    if (localScreen != null) {
      for (final track in localScreen.getTracks()) {
        try {
          track.stop();
        } catch (_) {}
      }
      try {
        await localScreen.dispose();
      } catch (_) {}
      await ScreenCaptureService.stop();
    }
    _screenRenderer.srcObject = null;
    final remoteScreen = _remoteScreenRenderer;
    _remoteScreenRenderer = null;
    _remoteScreenStreamId = null;
    if (remoteScreen != null) {
      remoteScreen.srcObject = null;
      try {
        await remoteScreen.dispose();
      } catch (_) {}
    }
    VideoCallOverlayController.instance.clearScreenShare();

    // Drop the published local renderer before it gets disposed so the
    // participant strip stops drawing the (now dead) self-view.
    VideoCallOverlayController.instance.publishLocalRenderer(null);
    _localRenderer.srcObject = null;
    for (final track
        in _localStream?.getTracks() ?? const <MediaStreamTrack>[]) {
      try {
        track.stop();
      } catch (_) {
        // ignore
      }
    }
    try {
      await _localStream?.dispose();
    } catch (_) {
      // ignore
    }
    _localStream = null;
  }

  void _setMicEnabled(bool enabled) {
    final stream = _localStream;
    if (stream == null) return;
    if (_micEnabled == enabled) return;
    for (final t in stream.getAudioTracks()) {
      t.enabled = enabled;
    }
    if (mounted) {
      setState(() {
        _micEnabled = enabled;
      });
    } else {
      _micEnabled = enabled;
    }
    VideoCallOverlayController.instance
        .publishMediaState(micEnabled: enabled);
  }

  void _syncMicForPtt() {
    if (!_pttEnabled) return;
    _setMicEnabled(_isCurrentSpeaker);
  }

  Future<void> _requestToTalk() async {
    if (_requestInFlight) return;
    final roomRef = _roomRef;
    final localUid = _currentMemberId;
    if (roomRef == null || localUid == null) return;
    setState(() {
      _requestInFlight = true;
    });
    try {
      final success = await ref
          .read(communicationsRepositoryProvider)
          .runTransaction<bool>((txn) async {
        final snap = await txn.get(roomRef);
        final data = snap.data() ?? <String, dynamic>{};
        if (data['pttEnabled'] != true) return false;
        final speaker = data['currentSpeakerMemberId'] as String?;
        if (speaker != null &&
            speaker.isNotEmpty &&
            speaker != localUid) {
          return false;
        }
        txn.update(roomRef, {
          'currentSpeakerMemberId': localUid,
          'currentSpeakerSince': FieldValue.serverTimestamp(),
        });
        return true;
      });
      if (!success && mounted) {
        SnackbarService.instance.showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 5),
            content: Text('Someone else is talking.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _requestInFlight = false;
        });
      } else {
        _requestInFlight = false;
      }
    }
  }

  Future<void> _releaseTalk() async {
    final roomRef = _roomRef;
    final localMemberId = _currentMemberId;
    if (roomRef == null || localMemberId == null) return;
    try {
      await ref
          .read(communicationsRepositoryProvider)
          .runTransaction((txn) async {
        final snap = await txn.get(roomRef);
        final data = snap.data() ?? <String, dynamic>{};
        final speaker = data['currentSpeakerMemberId'] as String?;
        if (speaker == localMemberId) {
          txn.update(roomRef, {
            'currentSpeakerMemberId': null,
          });
        }
      });
    } catch (_) {
      // ignore release failures
    }
  }

  Future<void> _updateParticipantStatus(
    DocumentReference<Map<String, dynamic>> roomRef,
    String memberId,
    String status,
  ) async {
    final payload = {
      'memberId': memberId,
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (status == 'joined') {
      payload['joinedAt'] = FieldValue.serverTimestamp();
    } else if (status == 'left') {
      payload['leftAt'] = FieldValue.serverTimestamp();
    }
    await roomRef
        .collection('participants')
        .doc(memberId)
        .set(payload, SetOptions(merge: true));
  }

  @override
  void dispose() {
    VideoCallOverlayController.instance.detachCommandSink(this);
    unawaited(_cleanup());
    unawaited(_localRenderer.dispose());
    if (_screenRendererReady) unawaited(_screenRenderer.dispose());
    super.dispose();
  }

  // ---- CallCommandSink ------------------------------------------------

  @override
  Future<void> setMicEnabled(bool enabled) async {
    if (_pttEnabled) return; // mic is governed by speaker slot in PTT mode
    _setMicEnabled(enabled);
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async {
    final stream = _localStream;
    if (stream == null) return;
    final videoTracks = stream.getVideoTracks();
    if (videoTracks.isEmpty) {
      if (enabled) {
        await _upgradeToVideo(stream);
      }
      return;
    }
    if (_camEnabled == enabled) return;
    setState(() {
      _camEnabled = enabled;
      for (final t in videoTracks) {
        t.enabled = enabled;
      }
    });
    VideoCallOverlayController.instance.publishMediaState(
      cameraEnabled: enabled,
    );
  }

  @override
  Future<void> setTranscriptionEnabled(bool enabled) async {
    final roomRef = _roomRef;
    final memberId = _currentMemberId;
    if (roomRef == null || memberId == null) return;

    if (enabled) {
      String memberName = '';
      try {
        final snap = await ref
            .read(taskRepositoryProvider)
            .memberDoc(widget.companyId, memberId)
            .get();
        final data = snap.data() ?? <String, dynamic>{};
        final first = (data['firstName'] as String?) ?? '';
        final last = (data['lastName'] as String?) ?? '';
        memberName = '$first $last'.trim();
        if (memberName.isEmpty) {
          memberName = (data['displayName'] as String?) ?? '';
        }
      } catch (_) {
        // best-effort: name omitted, banner will say "A participant"
      }

      try {
        await roomRef.set({
          'transcription': {
            'startedByMemberId': memberId,
            'startedByName': memberName,
            'startedAt': FieldValue.serverTimestamp(),
          },
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (error) {
        SnackbarService.instance.showSnackBar(
          SnackBar(duration: const Duration(seconds: 5), content: Text('Unable to start transcription: $error')),
        );
      }
    } else {
      try {
        await roomRef.set({
          'transcription': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (error) {
        SnackbarService.instance.showSnackBar(
          SnackBar(duration: const Duration(seconds: 5), content: Text('Unable to stop transcription: $error')),
        );
      }
    }
  }

  @override
  Future<void> setPttEnabled(bool enabled) async {
    final roomRef = _roomRef;
    if (roomRef == null) return;
    if (_pttEnabled == enabled) return;
    try {
      await roomRef.set({
        'pttEnabled': enabled,
        'currentSpeakerMemberId': null,
        'currentSpeakerSince': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error) {
      if (!mounted) return;
      SnackbarService.instance.showSnackBar(
        SnackBar(duration: const Duration(seconds: 5), content: Text('Unable to update talk mode: $error')),
      );
    }
  }

  @override
  Future<void> setSpeakerphone(bool on) async {
    if (_speakerphoneOn == on) return;
    try {
      await Helper.setSpeakerphoneOn(on);
      _speakerphoneOn = on;
      if (mounted) {
        setState(() {});
      }
      VideoCallOverlayController.instance
          .publishMediaState(speakerphoneOn: on);
    } catch (err) {
      debugPrint('[VideoCall] setSpeakerphone($on) failed: $err');
      if (!mounted) return;
      SnackbarService.instance.showSnackBar(
        const SnackBar(duration: Duration(seconds: 5), content: Text('Unable to switch audio output.')),
      );
    }
  }

  @override
  Future<void> switchCamera() async {
    final stream = _localStream;
    if (stream == null) return;
    final tracks = stream.getVideoTracks();
    if (tracks.isEmpty) return;
    try {
      await Helper.switchCamera(tracks.first);
      if (mounted) {
        setState(() => _frontCamera = !_frontCamera);
      } else {
        _frontCamera = !_frontCamera;
      }
    } catch (_) {
      // Most desktops do not support camera switching.
    }
  }

  @override
  Future<void> upgradeToVideo() async {
    final stream = _localStream;
    if (stream == null) return;
    if (stream.getVideoTracks().isNotEmpty) return;
    await _upgradeToVideo(stream);
    if (mounted) {
      VideoCallOverlayController.instance.publishMediaState(
        videoActive: true,
        cameraEnabled: _camEnabled,
      );
    }
  }

  @override
  Future<void> pressTalk() async => _requestToTalk();

  @override
  Future<void> releaseTalk() async => _releaseTalk();

  @override
  Future<void> hangUp() async => _hangUp();

  @override
  Future<void> muteAll() async {
    final roomRef = _roomRef;
    final memberId = _currentMemberId;
    if (roomRef == null || memberId == null) return;
    try {
      await roomRef.set({
        'muteAllAt': FieldValue.serverTimestamp(),
        'muteAllBy': memberId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error) {
      if (!mounted) return;
      SnackbarService.instance.showSnackBar(
        SnackBar(duration: const Duration(seconds: 5), content: Text('Could not mute everyone: $error')),
      );
    }
  }

  @override
  Future<void> removeParticipant(String memberId) async {
    final roomRef = _roomRef;
    if (roomRef == null || memberId.isEmpty) return;
    try {
      await roomRef.set({
        'participantMemberIds': FieldValue.arrayRemove([memberId]),
        'pendingMemberIds': FieldValue.arrayRemove([memberId]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await roomRef.collection('participants').doc(memberId).set({
        'memberId': memberId,
        'status': 'removed',
        'removedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error) {
      if (!mounted) return;
      SnackbarService.instance.showSnackBar(
        SnackBar(duration: const Duration(seconds: 5), content: Text('Could not remove member: $error')),
      );
    }
  }

  Widget _videoTile(RTCVideoRenderer renderer, {bool mirror = false}) {
    return Container(
      color: Colors.black,
      child: RTCVideoView(renderer, mirror: mirror),
    );
  }

  int _gridColumnCount(int tileCount) {
    if (tileCount <= 1) return 1;
    if (tileCount <= 4) return 2;
    if (tileCount <= 9) return 3;
    return 4;
  }

  Widget _buildHiddenRenderers() {
    if (_remoteRenderers.isEmpty) return const SizedBox.shrink();
    return Offstage(
      offstage: true,
      child: Column(
        children: _remoteRenderers
            .map(
              (renderer) => SizedBox(
                width: 0,
                height: 0,
                child: RTCVideoView(renderer),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildVoiceCallBody(BuildContext context) {
    final totalParticipants = 1 + _peerSessions.length;
    final statusLabel =
        _pttEnabled ? 'Push-to-talk enabled' : 'Open mic';
    return Stack(
      children: [
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.phone_in_talk, size: 56, color: Colors.white),
              const SizedBox(height: 12),
              Text(
                'Voice call',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                '$totalParticipants participant${totalParticipants == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                statusLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                    ),
              ),
            ],
          ),
        ),
        _buildHiddenRenderers(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      _videoTile(_localRenderer, mirror: _frontCamera),
      ..._remoteRenderers.map((renderer) => _videoTile(renderer)),
    ];

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        children: [
          if (_showVideoLayout)
            GridView.count(
              crossAxisCount: _gridColumnCount(tiles.length),
              childAspectRatio: 16 / 9,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: tiles,
            )
          else
            _buildVoiceCallBody(context),
          if (widget.onToggleOverlay != null)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onToggleOverlay,
              ),
            ),

          // In-call controls are driven externally by the VoiceControlStrip
          // mounted above DetailsAppBar; the panel no longer renders its own
          // control bar or PTT button.
          if (_unavailableMemberNames.isNotEmpty)
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: Colors.orange.shade800),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_unavailableMemberNames.join(", ")} '
                        '${_unavailableMemberNames.length == 1 ? "is" : "are"} '
                        'off duty \u2013 will be notified when clocked in',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class VideoChatPeerSession {
  VideoChatPeerSession({
    required this.localUid,
    required this.remoteUid,
    required this.connectionRef,
    required this.localStream,
    required this.iceServers,
    required this.isOfferer,
    required this.onRemoteStream,
    this.screenStream,
  });

  final String localUid;
  final String remoteUid;
  final DocumentReference<Map<String, dynamic>> connectionRef;
  final MediaStream localStream;
  final List<Map<String, dynamic>> iceServers;
  final bool isOfferer;
  final void Function(MediaStream stream) onRemoteStream;

  /// When non-null, the local user is already screen-sharing as this peer
  /// connects, so the share track is added as part of the initial offer —
  /// no renegotiation needed for peers that join mid-share.
  final MediaStream? screenStream;

  RTCPeerConnection? _pc;
  RTCRtpSender? _screenSender;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _connectionSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _remoteCandidatesSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _renegotiationSub;

  final List<RTCIceCandidate> _pendingCandidates = [];
  final Set<String> _processedRenegotiationIds = {};
  String? _pendingLocalRenegotiationId;
  int _renegotiationSeq = 0;
  bool _remoteDescriptionSet = false;
  bool _disposed = false;

  Future<void> start() async {
    final pc = await createPeerConnection({
      'iceServers': iceServers,
      'sdpSemantics': 'unified-plan',
      'rtcpMuxPolicy': 'require',
    });
    _pc = pc;

    final localTracks = localStream.getTracks();
    debugPrint('[VideoCall][peer] addTrack count=${localTracks.length} '
        'kinds=${localTracks.map((t) => t.kind).toList()} '
        'isOfferer=$isOfferer remoteUid=$remoteUid');
    for (final track in localTracks) {
      pc.addTrack(track, localStream);
    }

    // If a screen share is already active when this peer connects, include
    // the share track in the initial negotiation so late joiners see it.
    final share = screenStream;
    if (share != null) {
      for (final track in share.getVideoTracks()) {
        try {
          _screenSender = await pc.addTrack(track, share);
        } catch (_) {
          // ignore — share will simply be absent for this peer
        }
      }
    }

    pc.onTrack = (event) {
      final stream =
          event.streams.isNotEmpty ? event.streams.first : null;
      debugPrint('[VideoCall][peer] onTrack kind=${event.track.kind} '
          'streamId=${stream?.id} '
          'streamAudio=${stream?.getAudioTracks().length} '
          'streamVideo=${stream?.getVideoTracks().length} '
          'remoteUid=$remoteUid');
      if (stream != null) {
        onRemoteStream(stream);
      }
    };

    final localCandidatesCol = connectionRef.collection(
      isOfferer ? 'callerCandidates' : 'calleeCandidates',
    );
    final remoteCandidatesCol = connectionRef.collection(
      isOfferer ? 'calleeCandidates' : 'callerCandidates',
    );

    pc.onIceCandidate = (candidate) async {
      if (_disposed || candidate.candidate == null) return;
      await localCandidatesCol.add({
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
        'createdAt': FieldValue.serverTimestamp(),
      });
    };

    await connectionRef.set({
      'initiatorUid': isOfferer ? localUid : remoteUid,
      'offererUid': isOfferer ? localUid : remoteUid,
      'answererUid': isOfferer ? remoteUid : localUid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (isOfferer) {
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      await connectionRef.set({
        'offer': offer.toMap(),
        'answer': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    _connectionSub = connectionRef.snapshots().listen((snap) async {
      if (_disposed) return;
      final data = snap.data() ?? <String, dynamic>{};

      if (isOfferer) {
        final answerMap = data['answer'];
        if (!_remoteDescriptionSet && answerMap is Map) {
          await _applyRemoteDescription(
            RTCSessionDescription(
              answerMap['sdp'] as String?,
              answerMap['type'] as String?,
            ),
          );
        }
      } else {
        final offerMap = data['offer'];
        if (!_remoteDescriptionSet && offerMap is Map) {
          await _applyRemoteDescription(
            RTCSessionDescription(
              offerMap['sdp'] as String?,
              offerMap['type'] as String?,
            ),
          );
          final answer = await pc.createAnswer();
          await pc.setLocalDescription(answer);
          await connectionRef.set({
            'answer': answer.toMap(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }
    });

    _remoteCandidatesSub =
        remoteCandidatesCol.snapshots().listen((candSnap) async {
      if (_disposed) return;
      for (final change in candSnap.docChanges) {
        final data = change.doc.data();
        if (data == null) continue;
        final candidateValue = data['candidate'] as String?;
        if (candidateValue == null) continue;
        final candidate = RTCIceCandidate(
          candidateValue,
          data['sdpMid'] as String?,
          data['sdpMLineIndex'] as int?,
        );
        if (_remoteDescriptionSet) {
          await _addCandidate(candidate);
        } else {
          _pendingCandidates.add(candidate);
        }
      }
    });

    _renegotiationSub = connectionRef
        .collection('renegotiations')
        .orderBy('seq')
        .snapshots()
        .listen((snap) async {
      if (_disposed) return;
      for (final change in snap.docChanges) {
        final data = change.doc.data();
        if (data == null) continue;
        final offererUid = data['offererUid'] as String?;
        if (offererUid == null) continue;

        final seqRaw = data['seq'];
        final seq = seqRaw is int ? seqRaw : (seqRaw is num ? seqRaw.toInt() : 0);
        if (seq > _renegotiationSeq) _renegotiationSeq = seq;

        if (offererUid == localUid) {
          if (_pendingLocalRenegotiationId != change.doc.id) continue;
          final answerMap = data['answer'];
          if (answerMap is! Map) continue;
          final pcLocal = _pc;
          if (pcLocal == null) continue;
          try {
            await pcLocal.setRemoteDescription(
              RTCSessionDescription(
                answerMap['sdp'] as String?,
                answerMap['type'] as String?,
              ),
            );
          } catch (_) {
            // ignore renegotiation failures; user can retry
          }
          _pendingLocalRenegotiationId = null;
          continue;
        }

        if (_processedRenegotiationIds.contains(change.doc.id)) continue;
        _processedRenegotiationIds.add(change.doc.id);
        final offerMap = data['offer'];
        if (offerMap is! Map) continue;
        final pcRemote = _pc;
        if (pcRemote == null) continue;
        try {
          await pcRemote.setRemoteDescription(
            RTCSessionDescription(
              offerMap['sdp'] as String?,
              offerMap['type'] as String?,
            ),
          );
          final answer = await pcRemote.createAnswer();
          await pcRemote.setLocalDescription(answer);
          await change.doc.reference.set({
            'answer': answer.toMap(),
            'answeredAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (_) {
          // ignore renegotiation failures; remote can retry
        }
      }
    });
  }

  Future<void> addLocalTrack(
    MediaStreamTrack track,
    MediaStream stream,
  ) async {
    if (_disposed) return;
    final pc = _pc;
    if (pc == null) return;
    if (_pendingLocalRenegotiationId != null) return;

    try {
      await pc.addTrack(track, stream);
    } catch (_) {
      return;
    }
    await _renegotiate();
  }

  /// Adds the local screen-share track to this peer and renegotiates.
  /// Used when sharing begins mid-call for peers that are already
  /// connected (late joiners get the track via [start] instead).
  Future<void> addScreenTrack(
    MediaStreamTrack track,
    MediaStream stream,
  ) async {
    if (_disposed) return;
    final pc = _pc;
    if (pc == null) return;
    if (_pendingLocalRenegotiationId != null) return;
    try {
      _screenSender = await pc.addTrack(track, stream);
    } catch (_) {
      return;
    }
    await _renegotiate();
  }

  /// Removes the local screen-share track from this peer and renegotiates
  /// so the remote tears down the screen m-line. No-op if not sharing.
  Future<void> removeScreenTrack() async {
    if (_disposed) return;
    final pc = _pc;
    final sender = _screenSender;
    if (pc == null || sender == null) return;
    _screenSender = null;
    try {
      await pc.removeTrack(sender);
    } catch (_) {
      return;
    }
    await _renegotiate();
  }

  /// Creates an offer for the current senders and publishes it to the
  /// `renegotiations` subcollection. Shared by track add/remove paths.
  Future<void> _renegotiate() async {
    final pc = _pc;
    if (pc == null) return;
    if (_pendingLocalRenegotiationId != null) return;

    final RTCSessionDescription offer;
    try {
      offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
    } catch (_) {
      return;
    }

    final docRef = connectionRef.collection('renegotiations').doc();
    _pendingLocalRenegotiationId = docRef.id;
    _processedRenegotiationIds.add(docRef.id);
    _renegotiationSeq += 1;
    try {
      await docRef.set({
        'seq': _renegotiationSeq,
        'offererUid': localUid,
        'offer': offer.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      _pendingLocalRenegotiationId = null;
    }
  }

  Future<void> _applyRemoteDescription(
      RTCSessionDescription description) async {
    final pc = _pc;
    if (pc == null) return;
    await pc.setRemoteDescription(description);
    _remoteDescriptionSet = true;
    await _flushPendingCandidates();
  }

  Future<void> _addCandidate(RTCIceCandidate candidate) async {
    try {
      await _pc?.addCandidate(candidate);
    } catch (_) {
      // ignore, candidate might be obsolete
    }
  }

  Future<void> _flushPendingCandidates() async {
    if (!_remoteDescriptionSet || _pendingCandidates.isEmpty) return;
    for (final candidate in _pendingCandidates) {
      await _addCandidate(candidate);
    }
    _pendingCandidates.clear();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    await _connectionSub?.cancel();
    await _remoteCandidatesSub?.cancel();
    await _renegotiationSub?.cancel();

    try {
      await _pc?.close();
    } catch (_) {
      // ignore
    }
  }
}

String _pairId(String a, String b) {
  return a.compareTo(b) <= 0 ? '${a}_$b' : '${b}_$a';
}
