// lib/features/notes/services/call_transcription_hook.dart
//
// Admin no-op stub. In the kleenops app this hook streams live call audio to
// Google STT and writes a per-call transcript + auto-notes. The admin app
// omits live in-call transcription (it pulls in call_transcription_service +
// the notes streaming stack), but calls still get summarized server-side by
// the shared `summarizeVideoRoom` Cloud Function. The constructor + API are
// kept identical so VideoChatPanel compiles and runs unchanged.

import 'package:cloud_firestore/cloud_firestore.dart';

class CallTranscriptionHook {
  CallTranscriptionHook({
    required this.companyRef,
    required this.memberRef,
    required this.callType,
    required this.participantIds,
    this.source,
    this.sourceContext,
    required this.roomRef,
    required this.currentMemberId,
  });

  final DocumentReference<Map<String, dynamic>> companyRef;
  final DocumentReference<Map<String, dynamic>> memberRef;
  final String callType;
  final List<String> participantIds;
  final String? source;
  final String? sourceContext;
  final DocumentReference<Map<String, dynamic>> roomRef;
  final String currentMemberId;

  bool _active = false;

  bool get isTranscribing => _active;

  /// No-op in admin — live transcription is not wired here.
  void startLive() {
    _active = false;
  }

  /// No-op in admin. In kleenops this flushes the accumulated transcript and
  /// saves auto-notes; here call summaries come from the server-side
  /// `summarizeVideoRoom` function instead.
  Future<void> onCallEnded() async {
    _active = false;
  }

  Future<void> dispose() async {
    _active = false;
  }
}
