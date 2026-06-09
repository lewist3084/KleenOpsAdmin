// Global call host. Keeps the WebRTC session alive while the user
// navigates between screens by mounting [VideoChatPanel] offstage —
// in-call chrome is rendered by the [VoiceControlStrip] above each
// screen's DetailsAppBar, not by a floating window here.
//
// This host also overlays:
//  - the [VoicePttDialog] (small draggable press-to-talk button) when
//    PTT mode is on for the active room
//  - the [_IncomingCallPrompt] when a new call is ringing

import 'package:flutter/material.dart';

import 'package:kleenops_admin/services/video_call_overlay_controller.dart';
import 'package:kleenops_admin/widgets/viewers/video_chat_panel.dart';
import 'package:shared_widgets/dialogs/voice_ptt_dialog.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';

class VideoCallOverlayHost extends StatelessWidget {
  const VideoCallOverlayHost({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final controller = VideoCallOverlayController.instance;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final session = controller.session;
        final incoming = controller.incomingCall;

        return Stack(
          children: [
            child,
            if (session != null)
              Offstage(
                offstage: true,
                child: SizedBox(
                  width: 1,
                  height: 1,
                  child: VideoChatPanel(
                    // Keyed on the session object so switching calls
                    // (one session → another) tears down the old panel
                    // and builds a fresh one, rather than reusing State.
                    key: ObjectKey(session),
                    companyId: session.companyId,
                    currentMemberId: session.currentMemberId,
                    taskId: session.taskId,
                    participantMemberIds: session.participantMemberIds,
                    teamId: session.teamId,
                    subject: session.subject,
                    callType: session.callType,
                    roomId: session.roomId,
                    initialPttEnabled: session.pttEnabled,
                    source: session.source,
                    sourceContext: session.sourceContext,
                    onHangUp: controller.endSession,
                    showControls: false,
                  ),
                ),
              ),
            if (session != null && controller.pttDialogVisible)
              VoicePttDialog(
                isCurrentSpeaker: controller.isCurrentSpeaker,
                someoneElseSpeaking: controller.someoneElseSpeaking,
                onTalkPressed: controller.requestTalkPress,
                onTalkReleased: controller.requestTalkRelease,
              ),
            if (incoming != null)
              _IncomingCallPrompt(
                controller: controller,
                incoming: incoming,
              ),
            if (session != null && controller.waitingCall != null)
              _CallWaitingBanner(
                controller: controller,
                waiting: controller.waitingCall!,
              ),
          ],
        );
      },
    );
  }
}

class _IncomingCallPrompt extends StatefulWidget {
  const _IncomingCallPrompt({
    required this.controller,
    required this.incoming,
  });

  final VideoCallOverlayController controller;
  final IncomingVideoCall incoming;

  @override
  State<_IncomingCallPrompt> createState() => _IncomingCallPromptState();
}

class _IncomingCallPromptState extends State<_IncomingCallPrompt> {
  bool _isAccepting = false;

  Future<void> _handleAccept() async {
    if (_isAccepting) return;
    setState(() => _isAccepting = true);

    try {
      await widget.controller.acceptIncoming();
    } catch (error) {
      if (mounted) {
        setState(() => _isAccepting = false);
        SnackbarService.instance.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 5),
            content: Text('Failed to join call: $error'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isVoice = widget.incoming.callType == VideoCallType.voice;
    final title = widget.incoming.subject?.trim().isNotEmpty == true
        ? widget.incoming.subject!.trim()
        : (isVoice ? 'Incoming voice call' : 'Incoming video call');
    final acceptIcon = isVoice ? Icons.phone : Icons.videocam;

    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Card(
            elevation: 16,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 260, maxWidth: 320),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      acceptIcon,
                      size: 40,
                      color: Colors.black87,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isAccepting
                          ? 'Connecting...'
                          : 'Tap accept to join the call.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: _isAccepting ? Colors.blue : Colors.black54,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_isAccepting) ...[
                      const SizedBox(height: 12),
                      const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: _isAccepting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Icon(acceptIcon),
                      label: Text(_isAccepting ? 'Connecting...' : 'Accept'),
                      onPressed: _isAccepting ? null : _handleAccept,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.green.shade400,
                        disabledForegroundColor: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      icon: const Icon(Icons.call_end),
                      label: const Text('Decline'),
                      onPressed: _isAccepting
                          ? null
                          : () => widget.controller.declineIncoming(),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact top banner shown when a second call arrives during an active
/// call. Switch leaves the current call and joins the new one; Ignore
/// declines it. (True hold — keeping both calls alive — is a later phase.)
class _CallWaitingBanner extends StatefulWidget {
  const _CallWaitingBanner({
    required this.controller,
    required this.waiting,
  });

  final VideoCallOverlayController controller;
  final IncomingVideoCall waiting;

  @override
  State<_CallWaitingBanner> createState() => _CallWaitingBannerState();
}

class _CallWaitingBannerState extends State<_CallWaitingBanner> {
  bool _busy = false;

  Future<void> _switch() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.controller.acceptWaiting();
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        SnackbarService.instance.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 5),
            content: Text('Failed to switch calls: $error'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVoice = widget.waiting.callType == VideoCallType.voice;
    final subject = widget.waiting.subject?.trim();
    final label = (subject != null && subject.isNotEmpty)
        ? subject
        : (isVoice ? 'Incoming voice call' : 'Incoming video call');

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(14),
            color: const Color(0xFF1F2937),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    isVoice ? Icons.phone_callback : Icons.video_call,
                    color: Colors.amber,
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Call waiting',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_busy)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else ...[
                    TextButton(
                      onPressed: () => widget.controller.declineWaiting(),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text('Ignore'),
                    ),
                    const SizedBox(width: 4),
                    ElevatedButton(
                      onPressed: _switch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('Switch'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
