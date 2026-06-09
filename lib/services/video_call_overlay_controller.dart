import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

enum VideoCallWindowSize { minimized, medium, maximized }

enum VideoCallType { voice, video }

/// Implemented by [VideoChatPanel] so the in-call control strip can drive
/// the active session without holding a direct reference to it.
abstract class CallCommandSink {
  Future<void> setMicEnabled(bool enabled);
  Future<void> setCameraEnabled(bool enabled);
  Future<void> setScreenSharing(bool enabled);
  Future<void> setSpeakerphone(bool on);
  Future<void> setPttEnabled(bool enabled);
  Future<void> setTranscriptionEnabled(bool enabled);
  Future<void> upgradeToVideo();
  Future<void> switchCamera();
  Future<void> pressTalk();
  Future<void> releaseTalk();
  Future<void> removeParticipant(String memberId);
  Future<void> muteAll();
  Future<void> hangUp();
}

class VideoCallSession {
  VideoCallSession({
    required this.companyId,
    required this.currentMemberId,
    this.taskId,
    this.roomId,
    this.participantMemberIds = const [],
    this.callerMemberId,
    this.teamId,
    this.subject,
    this.callType = VideoCallType.video,
    this.isCaller = false,
    this.pttEnabled = false,
    this.source,
    this.sourceContext,
    this.onEnded,
  });

  final String companyId;
  final String currentMemberId;
  final String? taskId;
  // Mutable: the caller's session starts without a roomId; once
  // VideoChatPanel creates the room the controller flips this in place
  // so chrome (Add-member button, etc.) can react.
  String? roomId;
  final List<String> participantMemberIds;
  // Populated on the recipient side from the room doc's
  // createdByMemberId so the in-call banner can show the caller
  // alongside the other invitees. Null when the local user is the
  // caller (their own identity is already in currentMemberId).
  final String? callerMemberId;
  final String? teamId;
  final String? subject;
  final VideoCallType callType;
  final bool isCaller;
  final bool pttEnabled;
  final String? source;
  final String? sourceContext;
  final VoidCallback? onEnded;
}

class IncomingVideoCall {
  IncomingVideoCall({
    required this.companyId,
    required this.roomId,
    required this.currentMemberId,
    this.taskId,
    this.participantMemberIds = const [],
    this.callerMemberId,
    this.teamId,
    this.subject,
    this.callType = VideoCallType.video,
    this.source,
    this.sourceContext,
    this.onAccept,
    this.onDecline,
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
  final Future<void> Function()? onAccept;
  final Future<void> Function()? onDecline;
}

class VideoCallOverlayController extends ChangeNotifier {
  VideoCallOverlayController._();

  static final VideoCallOverlayController instance =
      VideoCallOverlayController._();

  VideoCallSession? get session => _session;
  IncomingVideoCall? get incomingCall => _incomingCall;
  IncomingVideoCall? get waitingCall => _waitingCall;
  VideoCallWindowSize get windowSize => _windowSize;
  Offset? get anchor => _anchor;

  VideoCallSession? _session;
  IncomingVideoCall? _incomingCall;
  // A second call that arrived while [_session] is active — surfaced as a
  // compact "call waiting" banner rather than a full incoming-call prompt.
  IncomingVideoCall? _waitingCall;
  VideoCallWindowSize _windowSize = VideoCallWindowSize.medium;
  Offset? _anchor;
  Offset? _lastWindowAnchor;

  // Media state mirrored from the active VideoChatPanel. The control
  // strip and PTT dialog read these; the panel publishes via
  // [publishMediaState] whenever its own state changes.
  bool _micEnabled = true;
  bool _cameraEnabled = true;
  // Whether audio is routed to the loudspeaker (true) or the earpiece /
  // headset (false). Mirrored from the active VideoChatPanel.
  bool _speakerphoneOn = false;
  bool _pttEnabled = false;
  bool _videoActive = false;
  bool _hasLocalCamera = false;
  bool _isCurrentSpeaker = false;
  String? _currentSpeakerMemberId;
  bool _transcribing = false;
  String? _transcriptionStartedByMemberId;
  String? _transcriptionStartedByName;
  // memberId of the participant currently enlarged into the presenter
  // stage beneath the call ribbon. Null collapses the stage.
  String? _enlargedMemberId;
  CallCommandSink? _sink;

  /// Remote video renderers indexed by memberId. Published by
  /// [VideoChatPanel] as remote streams attach/detach so chrome like
  /// [ActiveParticipantsBanner] can render each participant's live feed
  /// inside their avatar bubble without depending on the panel.
  final Map<String, RTCVideoRenderer> _remoteRenderers =
      <String, RTCVideoRenderer>{};
  Map<String, RTCVideoRenderer> get remoteRenderers =>
      Map.unmodifiable(_remoteRenderers);

  RTCVideoRenderer? remoteRendererFor(String memberId) =>
      _remoteRenderers[memberId];

  void publishRemoteRenderer(String memberId, RTCVideoRenderer renderer) {
    if (memberId.isEmpty) return;
    if (_remoteRenderers[memberId] == renderer) return;
    _remoteRenderers[memberId] = renderer;
    notifyListeners();
  }

  void clearRemoteRenderer(String memberId) {
    if (memberId.isEmpty) return;
    if (_remoteRenderers.remove(memberId) != null) {
      notifyListeners();
    }
  }

  void _clearAllRemoteRenderers() {
    if (_remoteRenderers.isEmpty) return;
    _remoteRenderers.clear();
  }

  /// The local user's own video renderer, published by [VideoChatPanel]
  /// so call chrome (the [ActiveParticipantsBanner]) can show the user's
  /// own face alongside the other participants.
  RTCVideoRenderer? _localRenderer;
  RTCVideoRenderer? get localRenderer => _localRenderer;

  void publishLocalRenderer(RTCVideoRenderer? renderer) {
    if (_localRenderer == renderer) return;
    _localRenderer = renderer;
    notifyListeners();
  }

  // ---- Screen share --------------------------------------------------
  // A single active screen share at a time. The renderer is owned by
  // [VideoChatPanel] (local or remote); chrome (the presenter stage)
  // reads it here to surface the shared screen below the call ribbon.
  RTCVideoRenderer? _screenShareRenderer;
  String? _screenShareMemberId;
  String? _screenShareName;
  bool _screenShareIsLocal = false;

  RTCVideoRenderer? get screenShareRenderer => _screenShareRenderer;
  String? get screenShareMemberId => _screenShareMemberId;
  String? get screenShareName => _screenShareName;

  /// True when the local user is the one sharing their screen. Drives the
  /// control strip toggle's active state.
  bool get screenShareIsLocal => _screenShareIsLocal;

  /// True when any screen share (local or remote) is on the stage.
  bool get hasScreenShare => _screenShareRenderer != null;

  void publishScreenShare({
    required RTCVideoRenderer renderer,
    required String memberId,
    String? name,
    required bool isLocal,
  }) {
    _screenShareRenderer = renderer;
    _screenShareMemberId = memberId;
    _screenShareName = name;
    _screenShareIsLocal = isLocal;
    notifyListeners();
  }

  void clearScreenShare() {
    if (_screenShareRenderer == null && !_screenShareIsLocal) return;
    _screenShareRenderer = null;
    _screenShareMemberId = null;
    _screenShareName = null;
    _screenShareIsLocal = false;
    notifyListeners();
  }

  bool get micEnabled => _micEnabled;
  bool get cameraEnabled => _cameraEnabled;
  bool get speakerphoneOn => _speakerphoneOn;
  bool get pttEnabled => _pttEnabled;
  bool get videoActive => _videoActive;
  bool get hasLocalCamera => _hasLocalCamera;
  bool get isCurrentSpeaker => _isCurrentSpeaker;
  String? get currentSpeakerMemberId => _currentSpeakerMemberId;
  bool get transcribing => _transcribing;
  String? get transcriptionStartedByMemberId => _transcriptionStartedByMemberId;
  String? get transcriptionStartedByName => _transcriptionStartedByName;
  String? get enlargedMemberId => _enlargedMemberId;
  bool get someoneElseSpeaking =>
      _currentSpeakerMemberId != null && !_isCurrentSpeaker;
  bool get isCaller => _session?.isCaller ?? false;
  bool get hasActiveCall => _session != null;

  /// Whether the PTT mini-dialog should be visible. Mirrors [_pttEnabled]
  /// today but kept separate so callers can suppress the dialog (e.g. on
  /// screens that don't host it) without flipping the room-wide PTT mode.
  bool get pttDialogVisible => _pttEnabled;

  void attachCommandSink(CallCommandSink sink) {
    _sink = sink;
  }

  void detachCommandSink(CallCommandSink sink) {
    if (_sink == sink) _sink = null;
  }

  void publishMediaState({
    bool? micEnabled,
    bool? cameraEnabled,
    bool? speakerphoneOn,
    bool? pttEnabled,
    bool? videoActive,
    bool? hasLocalCamera,
    bool? isCurrentSpeaker,
    String? currentSpeakerMemberId,
    bool clearSpeaker = false,
  }) {
    bool changed = false;
    if (micEnabled != null && micEnabled != _micEnabled) {
      _micEnabled = micEnabled;
      changed = true;
    }
    if (cameraEnabled != null && cameraEnabled != _cameraEnabled) {
      _cameraEnabled = cameraEnabled;
      changed = true;
    }
    if (speakerphoneOn != null && speakerphoneOn != _speakerphoneOn) {
      _speakerphoneOn = speakerphoneOn;
      changed = true;
    }
    if (pttEnabled != null && pttEnabled != _pttEnabled) {
      _pttEnabled = pttEnabled;
      changed = true;
    }
    if (videoActive != null && videoActive != _videoActive) {
      _videoActive = videoActive;
      changed = true;
    }
    if (hasLocalCamera != null && hasLocalCamera != _hasLocalCamera) {
      _hasLocalCamera = hasLocalCamera;
      changed = true;
    }
    if (isCurrentSpeaker != null && isCurrentSpeaker != _isCurrentSpeaker) {
      _isCurrentSpeaker = isCurrentSpeaker;
      changed = true;
    }
    if (clearSpeaker) {
      if (_currentSpeakerMemberId != null) {
        _currentSpeakerMemberId = null;
        changed = true;
      }
    } else if (currentSpeakerMemberId != null &&
        currentSpeakerMemberId != _currentSpeakerMemberId) {
      _currentSpeakerMemberId = currentSpeakerMemberId;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  void publishTranscriptionState({
    required bool transcribing,
    String? startedByMemberId,
    String? startedByName,
  }) {
    bool changed = false;
    if (transcribing != _transcribing) {
      _transcribing = transcribing;
      changed = true;
    }
    final nextMember = transcribing ? startedByMemberId : null;
    final nextName = transcribing ? startedByName : null;
    if (nextMember != _transcriptionStartedByMemberId) {
      _transcriptionStartedByMemberId = nextMember;
      changed = true;
    }
    if (nextName != _transcriptionStartedByName) {
      _transcriptionStartedByName = nextName;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  // Commands invoked by the in-call control strip + PTT dialog.
  Future<void> requestMicEnabled(bool enabled) async =>
      _sink?.setMicEnabled(enabled);
  Future<void> requestCameraEnabled(bool enabled) async =>
      _sink?.setCameraEnabled(enabled);
  Future<void> requestScreenSharing(bool enabled) async =>
      _sink?.setScreenSharing(enabled);
  Future<void> requestSpeakerphone(bool on) async =>
      _sink?.setSpeakerphone(on);
  Future<void> requestPttEnabled(bool enabled) async =>
      _sink?.setPttEnabled(enabled);
  Future<void> requestUpgradeToVideo() async => _sink?.upgradeToVideo();
  Future<void> requestSwitchCamera() async => _sink?.switchCamera();
  Future<void> requestTalkPress() async => _sink?.pressTalk();
  Future<void> requestTalkRelease() async => _sink?.releaseTalk();
  Future<void> requestRemoveParticipant(String memberId) async =>
      _sink?.removeParticipant(memberId);
  Future<void> requestMuteAll() async => _sink?.muteAll();
  Future<void> requestTranscriptionEnabled(bool enabled) async =>
      _sink?.setTranscriptionEnabled(enabled);
  Future<void> requestHangUp() async {
    final sink = _sink;
    if (sink != null) {
      await sink.hangUp();
    } else {
      endSession();
    }
  }

  void _resetMediaState() {
    _micEnabled = true;
    _cameraEnabled = true;
    _speakerphoneOn = false;
    _pttEnabled = false;
    _videoActive = false;
    _hasLocalCamera = false;
    _isCurrentSpeaker = false;
    _currentSpeakerMemberId = null;
    _transcribing = false;
    _transcriptionStartedByMemberId = null;
    _transcriptionStartedByName = null;
    _enlargedMemberId = null;
    _localRenderer = null;
    _screenShareRenderer = null;
    _screenShareMemberId = null;
    _screenShareName = null;
    _screenShareIsLocal = false;
    _clearAllRemoteRenderers();
  }

  void startSession(VideoCallSession session, {Offset? initialAnchor}) {
    _session = session;
    _windowSize = VideoCallWindowSize.medium;
    if (initialAnchor != null) {
      _anchor = initialAnchor;
    }
    notifyListeners();
  }

  /// Called by [VideoChatPanel] once a brand-new room doc has been created
  /// (caller-side). Lets in-call UI like the Add-member button become
  /// available even though the original VideoCallSession had no roomId.
  void setSessionRoomId(String roomId) {
    final s = _session;
    if (s == null || s.roomId == roomId) return;
    s.roomId = roomId;
    notifyListeners();
  }

  void endSession() {
    final ended = _session?.onEnded;
    _session = null;
    // Drop any "call waiting" banner — with no active call behind it the
    // queue will re-present that call as a normal incoming-call prompt.
    _waitingCall = null;
    _anchor = null;
    _lastWindowAnchor = null;
    _windowSize = VideoCallWindowSize.medium;
    _resetMediaState();
    notifyListeners();
    ended?.call();
  }

  void showIncoming(IncomingVideoCall incoming) {
    _incomingCall = incoming;
    notifyListeners();
  }

  /// Silently dismiss the in-app prompt if it matches [roomId]. Does NOT
  /// fire onAccept/onDecline — used when CallKit takes over the same room
  /// and the in-app dialog needs to disappear without affecting call state.
  void dismissIncomingIfMatches(String roomId) {
    final incoming = _incomingCall;
    if (incoming == null) return;
    if (incoming.roomId != roomId) return;
    _incomingCall = null;
    notifyListeners();
  }

  Future<void> acceptIncoming() async {
    final incoming = _incomingCall;
    if (incoming == null) return;
    _incomingCall = null;
    notifyListeners();
    await incoming.onAccept?.call();
  }

  Future<void> declineIncoming() async {
    final incoming = _incomingCall;
    if (incoming == null) return;
    _incomingCall = null;
    notifyListeners();
    await incoming.onDecline?.call();
  }

  /// Shows the "call waiting" banner for a call that arrived mid-session.
  void showWaiting(IncomingVideoCall waiting) {
    _waitingCall = waiting;
    notifyListeners();
  }

  /// Silently dismisses the call-waiting banner (no accept/decline) — used
  /// when the waiting call's room ends or is taken over elsewhere.
  void clearWaiting() {
    if (_waitingCall == null) return;
    _waitingCall = null;
    notifyListeners();
  }

  /// User tapped Switch on the banner: runs [IncomingVideoCall.onAccept],
  /// which leaves the current call and joins the waiting one.
  Future<void> acceptWaiting() async {
    final waiting = _waitingCall;
    if (waiting == null) return;
    _waitingCall = null;
    notifyListeners();
    await waiting.onAccept?.call();
  }

  /// User tapped Ignore on the banner: declines the waiting call.
  Future<void> declineWaiting() async {
    final waiting = _waitingCall;
    if (waiting == null) return;
    _waitingCall = null;
    notifyListeners();
    await waiting.onDecline?.call();
  }

  void setWindowSize(VideoCallWindowSize size) {
    if (_windowSize == size) return;
    if (size == VideoCallWindowSize.maximized) {
      // Save current position before maximizing
      _lastWindowAnchor = _anchor;
    } else if (_windowSize == VideoCallWindowSize.maximized) {
      // Always restore saved position when exiting maximized mode
      if (_lastWindowAnchor != null) {
        _anchor = _lastWindowAnchor;
      }
    }
    _windowSize = size;
    notifyListeners();
  }

  void updateAnchor(Offset value) {
    if (_windowSize == VideoCallWindowSize.maximized) return;
    if (_anchor == value) return;
    _anchor = value;
    notifyListeners();
  }

  /// Select (or clear) the participant shown in the enlarged presenter
  /// stage under the call ribbon. Passing the already-selected memberId
  /// or null collapses the stage.
  void setEnlargedParticipant(String? memberId) {
    final next =
        (memberId != null && memberId.trim().isEmpty) ? null : memberId;
    if (_enlargedMemberId == next) return;
    _enlargedMemberId = next;
    notifyListeners();
  }
}
