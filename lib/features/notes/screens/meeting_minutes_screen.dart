import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/features/notes/services/transcription_to_notes_service.dart';
import 'package:kleenops_admin/features/notes/services/gemini_transcript_formatter.dart';
import 'package:kleenops_admin/features/notes/services/live_chunked_transcriber.dart';
import 'package:kleenops_admin/features/notes/services/notes_streaming_transcriber.dart';
import 'package:kleenops_admin/services/ai/ai_context_service.dart';
import 'package:kleenops_admin/widgets/layout/bookended_canvas.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';

enum _ViewTab { transcript, formatted, bullets, actions }

class MeetingMinutesScreen extends ConsumerStatefulWidget {
  const MeetingMinutesScreen({super.key});

  @override
  ConsumerState<MeetingMinutesScreen> createState() =>
      _MeetingMinutesScreenState();
}

class _MeetingMinutesScreenState extends ConsumerState<MeetingMinutesScreen>
    with WidgetsBindingObserver {
  final StringBuffer _rawTranscript = StringBuffer();
  String _displayTranscript = '';
  final ScrollController _scrollController = ScrollController();

  late LiveChunkedTranscriber _transcriber;
  StreamSubscription<String>? _transcriptionSub;

  bool _isRecording = false;
  bool _sessionActive = false;
  bool _saving = false;

  _ViewTab _currentTab = _ViewTab.transcript;
  bool _loadingView = false;
  String _formattedText = '';
  List<String> _bulletItems = const [];
  List<String> _actionItems = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _transcriber = GoogleStreamingTranscriber();
    _transcriptionSub = _transcriber.transcriptStream.listen(
      _handleDelta,
      onError: (_, __) {
        if (mounted) {
          SnackbarService.instance.showSnackBar(
            const SnackBar(duration: Duration(seconds: 5), content: Text('Transcription stream error.')),
          );
        }
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _transcriptionSub?.cancel();
    _transcriber.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_isRecording) {
        unawaited(_pauseRecording());
      }
    }
  }

  void _handleDelta(String delta) {
    if (!mounted) return;
    setState(() {
      _rawTranscript.write(delta);
      _displayTranscript = _rawTranscript.toString();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _startRecording() async {
    final freshSession = !_sessionActive;
    await _transcriber.start(freshSession: freshSession);
    setState(() {
      _sessionActive = true;
      _isRecording = true;
    });
  }

  Future<void> _pauseRecording() async {
    await _transcriber.pause();
    setState(() => _isRecording = false);
  }

  Future<void> _endRecording() async {
    await _transcriber.stop();
    setState(() {
      _isRecording = false;
      _sessionActive = false;
    });
  }

  Future<void> _switchTab(_ViewTab tab) async {
    if (tab == _currentTab) return;
    setState(() {
      _currentTab = tab;
      _loadingView = true;
    });

    try {
      final raw = _rawTranscript.toString().trim();
      switch (tab) {
        case _ViewTab.transcript:
          break;
        case _ViewTab.formatted:
          if (_formattedText.isEmpty && raw.isNotEmpty) {
            _formattedText =
                await GeminiTranscriptFormatter.formatFullTranscript(raw);
          }
          break;
        case _ViewTab.bullets:
          final source = _formattedText.isNotEmpty ? _formattedText : raw;
          if (_bulletItems.isEmpty && source.isNotEmpty) {
            _bulletItems =
                await GeminiTranscriptFormatter.extractBullets(source);
          }
          break;
        case _ViewTab.actions:
          final source = _formattedText.isNotEmpty ? _formattedText : raw;
          if (_actionItems.isEmpty && source.isNotEmpty) {
            _actionItems =
                await GeminiTranscriptFormatter.extractActionItems(source);
          }
          break;
      }
    } catch (e) {
      if (mounted) {
        SnackbarService.instance.showSnackBar(
          SnackBar(duration: const Duration(seconds: 5), content: Text('Processing failed: $e')),
        );
      }
    }

    if (mounted) setState(() => _loadingView = false);
  }

  Future<void> _handleSave() async {
    await _endRecording();

    final transcript = _formattedText.isNotEmpty
        ? _formattedText
        : _displayTranscript;

    if (transcript.trim().isEmpty) {
      if (mounted) {
        SnackbarService.instance.showSnackBar(
          const SnackBar(duration: Duration(seconds: 5), content: Text('Nothing to save.')),
        );
      }
      return;
    }

    setState(() => _saving = true);

    final companyRef = ref.read(companyIdProvider).value;
    final userData = ref.read(userDocumentProvider).value;

    if (companyRef == null || userData == null) {
      setState(() => _saving = false);
      return;
    }

    final memberRef =
        userData['memberRef'] as DocumentReference<Map<String, dynamic>>?;
    if (memberRef == null) {
      setState(() => _saving = false);
      return;
    }

    if (!mounted) return;
    final saved = await TranscriptionToNotesService.instance.promptSaveTranscript(
      context,
      companyRef: companyRef,
      memberRef: memberRef,
      fullText: transcript,
      callType: 'meeting_minutes',
      participantIds: [memberRef.id],
      startTime: null,
      endTime: null,
    );

    if (mounted) {
      setState(() => _saving = false);
      if (saved) {
        SnackbarService.instance.showSnackBar(
          const SnackBar(duration: Duration(seconds: 5), content: Text('Meeting minutes saved.')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final aiController = ref.read(aiCanvasControllerProvider);

    return Scaffold(
      body: BookendedCanvas(
        child: Column(
          children: [
            // Status bar
            _StatusBar(
              isRecording: _isRecording,
              sessionActive: _sessionActive,
            ),

            // Tab selector
            _TabSelector(
              current: _currentTab,
              onChanged: _switchTab,
            ),

            // Content area
            Expanded(
              child: _loadingView
                  ? const Center(child: CircularProgressIndicator())
                  : _buildContent(),
            ),

            // Control bar
            if (_saving)
              const LinearProgressIndicator(minHeight: 2),
            _ControlBar(
              isRecording: _isRecording,
              sessionActive: _sessionActive,
              saving: _saving,
              hasContent: _rawTranscript.isNotEmpty,
              onStart: _startRecording,
              onPause: _pauseRecording,
              onEnd: _endRecording,
              onSave: _handleSave,
            ),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: 'Meeting Minutes',
            onAiPressed: aiController.toggle,
          ),
          const HomeNavBarAdapter(),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_currentTab) {
      case _ViewTab.transcript:
        return _TranscriptView(
          text: _displayTranscript,
          scrollController: _scrollController,
        );
      case _ViewTab.formatted:
        return _TranscriptView(text: _formattedText);
      case _ViewTab.bullets:
        return _BulletList(items: _bulletItems);
      case _ViewTab.actions:
        return _BulletList(items: _actionItems, icon: Icons.check_circle_outline);
    }
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ──────────────────────────────────────────────────────────────────────────────

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.isRecording, required this.sessionActive});
  final bool isRecording;
  final bool sessionActive;

  @override
  Widget build(BuildContext context) {
    final text = isRecording
        ? 'Recording in progress'
        : sessionActive
            ? 'Paused'
            : 'Ready to capture';
    final color = isRecording ? Colors.red : Colors.grey;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: color.withValues(alpha: 0.1),
      child: Row(
        children: [
          if (isRecording)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.fiber_manual_record, color: Colors.red, size: 12),
            ),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _TabSelector extends StatelessWidget {
  const _TabSelector({required this.current, required this.onChanged});
  final _ViewTab current;
  final ValueChanged<_ViewTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: _ViewTab.values.map((tab) {
          final selected = tab == current;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(_label(tab)),
              selected: selected,
              onSelected: (_) => onChanged(tab),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _label(_ViewTab tab) {
    switch (tab) {
      case _ViewTab.transcript:
        return 'Transcript';
      case _ViewTab.formatted:
        return 'Formatted';
      case _ViewTab.bullets:
        return 'Key Points';
      case _ViewTab.actions:
        return 'Action Items';
    }
  }
}

class _ControlBar extends StatelessWidget {
  const _ControlBar({
    required this.isRecording,
    required this.sessionActive,
    required this.saving,
    required this.hasContent,
    required this.onStart,
    required this.onPause,
    required this.onEnd,
    required this.onSave,
  });

  final bool isRecording;
  final bool sessionActive;
  final bool saving;
  final bool hasContent;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onEnd;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!sessionActive) ...[
            // Start button
            FilledButton.icon(
              onPressed: saving ? null : onStart,
              icon: const Icon(Icons.mic),
              label: const Text('Start'),
            ),
          ] else ...[
            // Pause / Resume
            if (isRecording)
              OutlinedButton.icon(
                onPressed: onPause,
                icon: const Icon(Icons.pause),
                label: const Text('Pause'),
              )
            else
              OutlinedButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.mic),
                label: const Text('Resume'),
              ),
            const SizedBox(width: 12),
            // End
            OutlinedButton.icon(
              onPressed: onEnd,
              icon: const Icon(Icons.stop),
              label: const Text('End'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
          if (hasContent && !isRecording) ...[
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: saving ? null : onSave,
              icon: const Icon(Icons.save),
              label: const Text('Save'),
            ),
          ],
        ],
      ),
    );
  }
}

class _TranscriptView extends StatelessWidget {
  const _TranscriptView({required this.text, this.scrollController});
  final String text;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) {
      return const Center(
        child: Text(
          'Tap Start to begin recording.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        text,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.items, this.icon = Icons.circle});
  final List<String> items;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Text('No items yet.', style: TextStyle(color: Colors.grey)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 14, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(child: Text(items[i])),
          ],
        ),
      ),
    );
  }
}
