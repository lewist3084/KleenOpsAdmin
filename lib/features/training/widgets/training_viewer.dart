import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/tiles/selectable_row_tile.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import 'package:shared_widgets/buttons/training_navigation_bar.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/containers/container_header.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/fields/signature_field.dart';
import 'package:shared_widgets/services/tts_service.dart';
import 'package:shared_widgets/theme/app_palette.dart';
import 'package:shared_widgets/tiles/choice_survey_tile.dart';
import 'package:shared_widgets/tiles/ranking_survey_tile.dart';
import 'package:shared_widgets/viewers/file_carousel_viewer.dart';
import 'package:shared_widgets/viewers/training_file_viewer.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';

typedef TrainingViewerDecorator = Widget Function(
  BuildContext context,
  TrainingViewerData detail,
  Widget child,
);

class TrainingViewerScreen extends StatefulWidget {
  final String companyId;
  final String? assignedTrainingId;
  final DocumentReference<Map<String, dynamic>>? trainingRefOverride;
  final bool previewMode;
  final Future<DocumentReference<Map<String, dynamic>>?> Function()?
      memberRefLoader;
  final TrainingViewerDecorator? decorator;
  final VoidCallback? onExit;

  const TrainingViewerScreen({
    super.key,
    required this.companyId,
    this.assignedTrainingId,
    this.trainingRefOverride,
    this.previewMode = false,
    this.memberRefLoader,
    this.decorator,
    this.onExit,
  }) : assert(
          previewMode ||
              (assignedTrainingId != null && assignedTrainingId != ''),
        );

  @override
  State<TrainingViewerScreen> createState() => _TrainingViewerScreenState();
}

class _TrainingViewerScreenState extends State<TrainingViewerScreen> {
  static const List<String> _imageExtensions = <String>[
    'jpg',
    'jpeg',
    'png',
    'gif',
    'bmp',
    'webp',
  ];
  static const List<String> _videoExtensions = <String>[
    'mp4',
    'mov',
    'avi',
    'mkv',
    'wmv',
    'webm',
  ];

  late final DocumentReference<Map<String, dynamic>> _companyRef;
  DocumentReference<Map<String, dynamic>>? _assignedRef;
  late final Future<TrainingViewerData> _viewerFuture;
  late final AudioPlayer _ttsPlayer;

  int _activeIndex = -1;
  bool _showSignature = false;
  bool _hasSignature = false;
  String _signatureData = '';
  DocumentReference<Map<String, dynamic>>? _cachedMemberRef;
  final Map<String, List<String>> _responsesByElementPath = {};
  final Map<String, _QuizResult> _quizResultsById = {};
  final Map<String, int> _quizAttemptsById = {};
  final Set<String> _savedResultIds = {};
  String? _lastNarratedKey;
  int _narrationRequestId = 0;
  bool _audioCompleted = false;
  bool _isPlayingAudio = false;
  bool _isPreparingAudio = false;
  final Map<String, Uint8List> _prefetchedAudio = {};
  int _elementVoiceIndex = 0;
  ScrollController? _elementTextScrollController;
  bool _isScrollingText = false;
  Timer? _scrollResumeTimer;
  double _scrollDurationMs = 0;
  double _scrollMaxExtent = 0;
  String _currentScrollText = '';
  bool _userIsTouchingScroll = false;

  void _logNarration(String message) {
    if (kDebugMode) {
      debugPrint('[TrainingViewer][narration] $message');
    }
  }

  @override
  void initState() {
    super.initState();
    _ttsPlayer = AudioPlayer();
    unawaited(_ttsPlayer.setPlayerMode(PlayerMode.mediaPlayer));
    _elementTextScrollController = ScrollController();
    _companyRef =
        FirebaseFirestore.instance.collection('company').doc(widget.companyId);
    if (!widget.previewMode &&
        widget.assignedTrainingId != null &&
        widget.assignedTrainingId!.trim().isNotEmpty) {
      _assignedRef = _companyRef
          .collection('assignedTraining')
          .doc(widget.assignedTrainingId);
    }
    _viewerFuture = _loadViewerData();
  }

  @override
  void dispose() {
    unawaited(_ttsPlayer.stop());
    unawaited(_ttsPlayer.dispose());
    _elementTextScrollController?.dispose();
    _scrollResumeTimer?.cancel();
    super.dispose();
  }

  /// Start auto-scrolling the element description text.
  /// Estimates scroll duration based on text length.
  void _startTextAutoScroll(String text) {
    _scrollResumeTimer?.cancel();
    _currentScrollText = text;

    final controller = _elementTextScrollController;
    if (controller == null || !controller.hasClients) return;

    // Reset scroll position
    controller.jumpTo(0);

    // Estimate reading time: ~150 words per minute for TTS
    // Average word length ~5 chars, so ~750 chars per minute
    final charCount = text.length;
    final estimatedSeconds = (charCount / 750 * 60).clamp(3.0, 60.0);
    _scrollDurationMs = estimatedSeconds * 1000;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || controller != _elementTextScrollController) return;
      if (!controller.hasClients) return;

      final maxScroll = controller.position.maxScrollExtent;
      if (maxScroll <= 0) return;
      _scrollMaxExtent = maxScroll;

      _isScrollingText = true;
      controller
          .animateTo(
            maxScroll,
            duration: Duration(milliseconds: _scrollDurationMs.toInt()),
            curve: Curves.linear,
          )
          .then((_) {
        _isScrollingText = false;
      }).catchError((_) {
        _isScrollingText = false;
      });
    });
  }

  /// Resume auto-scrolling from current position after user interaction.
  void _resumeTextAutoScroll() {
    final controller = _elementTextScrollController;
    if (controller == null || !controller.hasClients) return;
    if (_scrollMaxExtent <= 0 || _scrollDurationMs <= 0) return;
    if (_userIsTouchingScroll) return;

    final currentOffset = controller.offset;
    final remainingDistance = _scrollMaxExtent - currentOffset;
    if (remainingDistance <= 0) {
      _isScrollingText = false;
      return;
    }

    // Calculate remaining time based on scroll rate (pixels per ms)
    final scrollRate = _scrollMaxExtent / _scrollDurationMs;
    final remainingMs = (remainingDistance / scrollRate).clamp(100.0, 60000.0);

    _isScrollingText = true;
    controller
        .animateTo(
          _scrollMaxExtent,
          duration: Duration(milliseconds: remainingMs.toInt()),
          curve: Curves.linear,
        )
        .then((_) {
      _isScrollingText = false;
    }).catchError((_) {
      _isScrollingText = false;
    });
  }

  /// Called when user starts touching the scroll area.
  void _onScrollTouchStart() {
    _userIsTouchingScroll = true;
    _scrollResumeTimer?.cancel();
    _stopTextAutoScroll();
  }

  /// Called when user stops touching the scroll area.
  void _onScrollTouchEnd() {
    _userIsTouchingScroll = false;
    _scrollResumeTimer?.cancel();
    // Resume scrolling after 1.5 seconds of no touch
    _scrollResumeTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted && !_userIsTouchingScroll) {
        _resumeTextAutoScroll();
      }
    });
  }

  /// Stop any ongoing text scroll animation.
  void _stopTextAutoScroll() {
    _scrollResumeTimer?.cancel();
    final controller = _elementTextScrollController;
    if (controller == null || !controller.hasClients) return;
    if (_isScrollingText) {
      // Stop at current position by jumping to it
      try {
        controller.jumpTo(controller.offset);
      } catch (_) {}
      _isScrollingText = false;
    }
  }

  String? _stringFromData(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty) return trimmed;
      }
    }
    return null;
  }

  int? _intFromData(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
    }
    return null;
  }

  String _extensionFromUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return '';
    final path = Uri.tryParse(trimmed)?.path ?? trimmed;
    final ext = p.extension(path).toLowerCase();
    if (ext.isEmpty) return '';
    return ext.startsWith('.') ? ext.substring(1) : ext;
  }

  String? _thumbnailFromData(Map<String, dynamic> data) {
    return _stringFromData(data, const [
      'thumbnailUrl',
      'videoThumbnail',
      'thumbUrl',
      'thumbnail',
    ]);
  }

  String? _titleFromData(Map<String, dynamic> data, String url) {
    final candidate = _stringFromData(data, const [
      'name',
      'sourceFileName',
      'fileName',
      'title',
    ]);
    if (candidate != null && candidate.isNotEmpty) return candidate;
    final path = Uri.tryParse(url)?.path ?? url;
    final base = p.basename(path);
    return base.isNotEmpty ? base : null;
  }

  static const String _defaultLocaleCode = 'en';

  String _normalizeLocaleCode(String code) {
    return code.trim().toLowerCase().replaceAll('_', '-');
  }

  Map<String, dynamic>? _normalizeLocalizedField(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return <String, dynamic>{
        'source': trimmed,
        'lang': _defaultLocaleCode,
        _defaultLocaleCode: trimmed,
      };
    }
    if (value is! Map) return null;

    final normalized = <String, dynamic>{};
    final sourceMetaKeys = <String>{
      'source',
      'sourcetext',
      'source_text',
    };
    final langMetaKeys = <String>{
      'lang',
      'language',
      'sourcelang',
      'source_language',
    };

    void captureTranslation(String key, dynamic raw) {
      final text = raw is String ? raw.trim() : '';
      if (text.isEmpty) return;
      final localeKey = _normalizeLocaleCode(key);
      if (localeKey.isEmpty) return;
      normalized[localeKey] = text;
    }

    for (final entry in value.entries) {
      final key = entry.key.toString();
      final loweredKey = key.toLowerCase();
      final raw = entry.value;
      if (sourceMetaKeys.contains(loweredKey)) {
        if (raw is String && raw.trim().isNotEmpty) {
          normalized['source'] = raw.trim();
        }
        continue;
      }
      if (langMetaKeys.contains(loweredKey)) {
        if (raw is String && raw.trim().isNotEmpty) {
          final normalizedLang = _normalizeLocaleCode(raw);
          if (normalizedLang.isNotEmpty) {
            normalized['lang'] = normalizedLang;
          }
        }
        continue;
      }
      if (loweredKey == 'values' || loweredKey == 'translations') {
        if (raw is Map) {
          for (final nested in raw.entries) {
            captureTranslation(nested.key.toString(), nested.value);
          }
        }
        continue;
      }
      captureTranslation(key, raw);
    }

    if (!normalized.containsKey('lang')) {
      normalized['lang'] = _defaultLocaleCode;
    }

    return normalized.isEmpty ? null : normalized;
  }

  String _resolveLocalizedText(BuildContext context, dynamic value) {
    if (value == null) return '';
    if (value is String) return value.trim();

    final normalized = _normalizeLocalizedField(value);
    if (normalized == null || normalized.isEmpty) return '';

    String? attempt(String code) {
      final normalizedCode = _normalizeLocaleCode(code);
      if (normalizedCode.isEmpty) return null;
      final raw = normalized[normalizedCode];
      if (raw is String) {
        final trimmed = raw.trim();
        if (trimmed.isNotEmpty) return trimmed;
      }
      return null;
    }

    final localeCodeRaw = _normalizeLocaleCode(
      Localizations.localeOf(context).toString(),
    );
    final detectedRaw =
        normalized['lang'] is String ? normalized['lang'] as String : null;
    final detected =
        detectedRaw == null ? null : _normalizeLocaleCode(detectedRaw);

    for (final code in <String>[
      localeCodeRaw,
      if (detected != null) detected,
      _defaultLocaleCode,
    ]) {
      final candidate = attempt(code);
      if (candidate != null) return candidate;
    }

    final source = normalized['source'];
    if (source is String && source.trim().isNotEmpty) {
      return source.trim();
    }

    for (final entry in normalized.entries) {
      final val = entry.value;
      if (val is String) {
        final trimmed = val.trim();
        if (trimmed.isNotEmpty) return trimmed;
      }
    }

    return '';
  }

  void _scheduleNarration(TrainingViewerData detail) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _logNarration(
        'schedule: index=$_activeIndex steps=${detail.steps.length} narration=${detail.narration}',
      );
      if (_activeIndex < 0) {
        _narrateIntro(detail);
        return;
      }
      if (_activeIndex >= detail.steps.length) return;
      _narrateStep(detail, detail.steps[_activeIndex]);
    });
  }

  void _setActiveIndex(int nextIndex, TrainingViewerData detail) {
    _stopTextAutoScroll();
    // Reset scroll position for new element
    final scrollCtrl = _elementTextScrollController;
    if (scrollCtrl != null && scrollCtrl.hasClients) {
      scrollCtrl.jumpTo(0);
    }
    setState(() {
      _activeIndex = nextIndex;
      _audioCompleted = false;
      _isPlayingAudio = false;
    });
    if (nextIndex < 0 || nextIndex >= detail.steps.length) {
      unawaited(_ttsPlayer.stop());
      if (nextIndex < 0) {
        _scheduleNarration(detail);
      }
      return;
    }
    _scheduleNarration(detail);
  }

  Future<void> _narrateIntro(TrainingViewerData detail) async {
    if (!detail.narration) {
      _logNarration('intro: narration disabled');
      return;
    }
    final name = _resolveLocalizedText(context, detail.name).trim();
    final description = _resolveLocalizedText(context, detail.description).trim();
    final subjectStatement = _resolveLocalizedText(context, detail.subjectStatement).trim();

    final textParts = <String>[];
    if (name.isNotEmpty) textParts.add(name);
    if (description.isNotEmpty) textParts.add(description);
    if (subjectStatement.isNotEmpty) textParts.add(subjectStatement);

    final text = textParts.join('. ');
    if (text.isEmpty) {
      _logNarration('intro: empty text after localization');
      return;
    }

    final locale = Localizations.localeOf(context);
    final langTag = locale.toLanguageTag();
    final key = 'intro|$langTag|$text';
    if (_lastNarratedKey == key) {
      _logNarration('intro: skipped (duplicate key)');
      return;
    }
    _lastNarratedKey = key;
    final requestId = ++_narrationRequestId;
    _elementVoiceIndex = 0; // Reset voice alternation for elements

    // No Google voice for this locale — display text but skip narration so
    // the user can advance manually rather than waiting on a non-existent
    // playback completion.
    if (!TtsService.hasVoiceForLanguage(langTag)) {
      _logNarration('intro: no voice for $langTag, skipping narration');
      try {
        await _ttsPlayer.stop();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _audioCompleted = true;
        _isPlayingAudio = false;
        _isPreparingAudio = false;
      });
      return;
    }

    try {
      await _ttsPlayer.stop();
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _isPlayingAudio = true;
      _audioCompleted = false;
      _isPreparingAudio = true;
    });
    _logNarration('intro: synthesize request id=$requestId lang=$langTag');

    try {
      // Use female voice for intro
      final voice = TtsService.femaleVoiceForLanguage(langTag);
      final bytes = await TtsService.synthesize(
        text,
        voice: voice,
        language: langTag,
      );
      if (!mounted || requestId != _narrationRequestId) return;
      _logNarration('intro: synthesized ${bytes.length} bytes');

      setState(() {
        _isPreparingAudio = false;
      });

      // Prefetch first element's audio
      _prefetchNextElement(detail, 0, langTag);

      _ttsPlayer.onPlayerComplete.listen((_) {
        if (!mounted || requestId != _narrationRequestId) return;
        setState(() {
          _audioCompleted = true;
          _isPlayingAudio = false;
        });
        _logNarration('intro: playback complete');
      });

      await _ttsPlayer.play(BytesSource(bytes));
      _logNarration('intro: playback started');
    } catch (e) {
      _logNarration('intro: playback failed: $e');
      if (!mounted) return;
      setState(() {
        _audioCompleted = true;
        _isPlayingAudio = false;
        _isPreparingAudio = false;
      });
    }
  }

  /// Prefetch audio for the next element in the background.
  Future<void> _prefetchNextElement(
    TrainingViewerData detail,
    int elementIndex,
    String langTag,
  ) async {
    // Find the next element step
    int nextElementIdx = -1;
    for (int i = elementIndex; i < detail.steps.length; i++) {
      if (detail.steps[i].kind == _TrainingViewerStepKind.element) {
        nextElementIdx = i;
        break;
      }
    }
    if (nextElementIdx < 0) return;

    final step = detail.steps[nextElementIdx];
    final elementDoc = step.elementDoc;
    if (elementDoc == null) return;

    final data = elementDoc.data();
    final description = _resolveLocalizedText(context, data['description']).trim();
    if (description.isEmpty) return;

    if (!TtsService.hasVoiceForLanguage(langTag)) return;

    final key = '${elementDoc.reference.path}|$langTag';
    if (_prefetchedAudio.containsKey(key)) return;

    _logNarration('prefetch: starting for element $nextElementIdx');
    try {
      // Determine voice index for this element (count elements before it)
      int voiceIdx = 0;
      for (int i = 0; i < nextElementIdx; i++) {
        if (detail.steps[i].kind == _TrainingViewerStepKind.element) voiceIdx++;
      }
      final voice = TtsService.alternatingVoiceForLanguage(langTag, voiceIdx);
      final bytes = await TtsService.synthesize(
        description,
        voice: voice,
        language: langTag,
      );
      if (!mounted) return;
      _prefetchedAudio[key] = bytes;
      _logNarration('prefetch: cached ${bytes.length} bytes for element $nextElementIdx');
    } catch (e) {
      _logNarration('prefetch: failed for element $nextElementIdx: $e');
    }
  }

  Future<void> _narrateStep(
    TrainingViewerData detail,
    _TrainingViewerStep step,
  ) async {
    if (!detail.narration) {
      _logNarration('step: narration disabled');
      return;
    }
    if (step.kind != _TrainingViewerStepKind.element) {
      _logNarration('step: non-element (${step.kind.name})');
      try {
        await _ttsPlayer.stop();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _audioCompleted = true;
        _isPlayingAudio = false;
      });
      return;
    }
    final elementDoc = step.elementDoc;
    if (elementDoc == null) {
      _logNarration('step: missing element doc');
      return;
    }
    final data = elementDoc.data();
    // Only read description, skip the name
    final description =
        _resolveLocalizedText(context, data['description']).trim();
    if (description.isEmpty) {
      _logNarration('step: empty description (element ${elementDoc.reference.path})');
      if (!mounted) return;
      setState(() {
        _audioCompleted = true;
        _isPlayingAudio = false;
      });
      return;
    }

    final locale = Localizations.localeOf(context);
    final langTag = locale.toLanguageTag();
    final cacheKey = '${elementDoc.reference.path}|$langTag';
    final narrationKey = '$cacheKey|$description';
    if (_lastNarratedKey == narrationKey) {
      _logNarration('step: skipped (duplicate key)');
      return;
    }
    _lastNarratedKey = narrationKey;
    final requestId = ++_narrationRequestId;

    // No Google voice for this locale — show the card but skip narration and
    // let the user advance manually.
    if (!TtsService.hasVoiceForLanguage(langTag)) {
      _logNarration('step: no voice for $langTag, skipping narration');
      try {
        await _ttsPlayer.stop();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _audioCompleted = true;
        _isPlayingAudio = false;
      });
      return;
    }

    try {
      await _ttsPlayer.stop();
    } catch (_) {}

    // Wait for image to load before starting TTS
    try {
      final mediaItems = await _loadElementMediaItems(elementDoc.reference, data);
      if (!mounted || requestId != _narrationRequestId) return;
      if (mediaItems.isNotEmpty) {
        final primaryItem = mediaItems.first;
        final imageUrl = primaryItem.url.trim();
        if (imageUrl.isNotEmpty) {
          _logNarration('step: preloading image $imageUrl');
          await precacheImage(NetworkImage(imageUrl), context);
          _logNarration('step: image preloaded');
        }
      }
    } catch (e) {
      _logNarration('step: image preload failed: $e');
    }
    if (!mounted || requestId != _narrationRequestId) return;

    if (!mounted) return;
    setState(() {
      _isPlayingAudio = true;
      _audioCompleted = false;
    });

    // Use alternating voice based on element index
    final voice = TtsService.alternatingVoiceForLanguage(langTag, _elementVoiceIndex);
    _elementVoiceIndex++;

    _logNarration(
      'step: element=${elementDoc.reference.path} voice=$voice voiceIdx=${_elementVoiceIndex - 1}',
    );

    try {
      // Check if we have prefetched audio
      Uint8List bytes;
      if (_prefetchedAudio.containsKey(cacheKey)) {
        bytes = _prefetchedAudio.remove(cacheKey)!;
        _logNarration('step: using prefetched audio ${bytes.length} bytes');
      } else {
        bytes = await TtsService.synthesize(
          description,
          voice: voice,
          language: langTag,
        );
        _logNarration('step: synthesized ${bytes.length} bytes');
      }
      if (!mounted || requestId != _narrationRequestId) return;

      // Prefetch next element's audio
      final currentStepIdx = detail.steps.indexOf(step);
      if (currentStepIdx >= 0) {
        _prefetchNextElement(detail, currentStepIdx + 1, langTag);
      }

      _ttsPlayer.onPlayerComplete.listen((_) {
        if (!mounted || requestId != _narrationRequestId) return;
        _stopTextAutoScroll();
        setState(() {
          _audioCompleted = true;
          _isPlayingAudio = false;
        });
        _logNarration('step: playback complete');
      });

      await _ttsPlayer.play(BytesSource(bytes));
      _logNarration('step: playback started');
      _startTextAutoScroll(description);
    } catch (e) {
      _logNarration('step: playback failed: $e');
      _stopTextAutoScroll();
      if (!mounted) return;
      setState(() {
        _audioCompleted = true;
        _isPlayingAudio = false;
      });
    }
  }

  String _resolveFileType(Map<String, dynamic> data, String url) {
    final fileType = (data['fileType'] ?? '').toString().toLowerCase();
    if (fileType.isNotEmpty) {
      if (fileType == 'document') {
        final ext = _extensionFromUrl(url);
        return ext == 'pdf' ? 'pdf' : 'document';
      }
      return fileType;
    }
    final mediaType = (data['mediaType'] ?? '').toString().toLowerCase();
    if (mediaType == 'image') return 'image';
    if (mediaType == 'video') return 'video';
    if (mediaType == 'document') {
      final ext = _extensionFromUrl(url);
      return ext == 'pdf' ? 'pdf' : 'document';
    }
    final ext = _extensionFromUrl(url);
    if (_imageExtensions.contains(ext)) return 'image';
    if (_videoExtensions.contains(ext)) return 'video';
    if (ext == 'pdf') return 'pdf';
    return 'document';
  }

  FileCarouselItem? _carouselItemForFile({
    required String url,
    required String fileType,
    String? thumbnailUrl,
    String? title,
  }) {
    switch (fileType) {
      case 'video':
        return FileCarouselItem.video(
          videoUrl: url,
          thumbnailUrl: thumbnailUrl,
        );
      case 'pdf':
        return FileCarouselItem.pdf(
          pdfUrl: url,
          thumbnailUrl: thumbnailUrl,
          title: title,
        );
      case 'document':
        return FileCarouselItem.document(
          fileUrl: url,
          thumbnailUrl: thumbnailUrl,
          title: title,
        );
      case 'image':
      default:
        return FileCarouselItem.image(imageUrl: url);
    }
  }

  List<FileCarouselItem> _fileDocsToItems(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final ordered = <_OrderedMediaItem>[];
    var fallbackOrder = 0;
    for (final doc in docs) {
      final data = doc.data();
      final url = _stringFromData(data, const [
        'downloadUrl',
        'url',
        'fileUrl',
        'videoUrl',
        'imageUrl',
      ]);
      if (url == null || url.isEmpty) continue;
      final fileType = _resolveFileType(data, url);
      final thumb = _thumbnailFromData(data);
      final title = _titleFromData(data, url);
      final item = _carouselItemForFile(
        url: url,
        fileType: fileType,
        thumbnailUrl: thumb,
        title: title,
      );
      if (item == null) continue;
      final order = _intFromData(data, const ['order']) ?? fallbackOrder;
      ordered.add(_OrderedMediaItem(order: order, item: item));
      fallbackOrder += 1;
    }

    ordered.sort((a, b) => a.order.compareTo(b.order));
    return ordered.map((entry) => entry.item).toList();
  }

  List<FileCarouselItem> _legacyMediaItems(Map<String, dynamic> data) {
    final items = <FileCarouselItem>[];
    final images = _galleryImageUrls(
      data['images'],
      fallbacks: [
        data['imageUrl'] as String?,
      ],
    );
    for (final url in images) {
      final ext = _extensionFromUrl(url);
      if (ext == 'pdf') {
        items.add(FileCarouselItem.pdf(pdfUrl: url));
      } else {
        items.add(FileCarouselItem.image(imageUrl: url));
      }
    }
    return items;
  }

  Future<List<FileCarouselItem>> _loadMediaItems(
    DocumentReference<Map<String, dynamic>> trainingRef,
    Map<String, dynamic> data,
  ) async {
    try {
      final snap = await _companyRef
          .collection('file')
          .where('trainingId', isEqualTo: trainingRef)
          .get();
      final items = _fileDocsToItems(
        snap.docs.where((doc) => doc.data()['trainingElementId'] == null).toList(),
      );
      if (items.isNotEmpty) return items;
    } catch (_) {}
    return _legacyMediaItems(data);
  }

  Future<List<FileCarouselItem>> _loadElementMediaItems(
    DocumentReference<Map<String, dynamic>> elementRef,
    Map<String, dynamic> data,
  ) async {
    try {
      final snap = await _companyRef
          .collection('file')
          .where('trainingElementId', isEqualTo: elementRef)
          .get();
      final items = _fileDocsToItems(snap.docs);
      if (items.isNotEmpty) return items;
    } catch (_) {}
    return _legacyMediaItems(data);
  }

  Future<TrainingViewerData> _loadViewerData() async {
    final assignedRef = _assignedRef;
    DocumentReference<Map<String, dynamic>> trainingRef;
    if (widget.trainingRefOverride != null) {
      trainingRef = widget.trainingRefOverride!;
    } else {
      if (assignedRef == null) {
        throw ('Missing training reference');
      }
      final assignedSnap = await assignedRef.get();
      final assignedData = assignedSnap.data() ?? {};
      final resolved = assignedData['trainingId']
          as DocumentReference<Map<String, dynamic>>?;
      if (resolved == null) {
        throw ('Missing training reference');
      }
      trainingRef = resolved;
    }

    final trainingSnap = await trainingRef.get();
    final data = trainingSnap.data() ?? {};
    final mediaItems = await _loadMediaItems(trainingRef, data);
    final elementSnap = await _companyRef
        .collection('trainingElement')
        .where('trainingId', isEqualTo: trainingRef)
        .get();
    final quizSnap = await _companyRef
        .collection('trainingQuiz')
        .where('trainingId', isEqualTo: trainingRef)
        .get();
    final contentItems = _buildContentItems(
      elementDocs: elementSnap.docs,
      quizDocs: quizSnap.docs,
    );
    final quizElementsByQuizId = await _loadQuizElements(quizSnap.docs);
    final steps = _buildViewerSteps(contentItems, quizElementsByQuizId);

    return TrainingViewerData(
      companyId: widget.companyId,
      assignedTrainingId: widget.assignedTrainingId,
      assignedRef: assignedRef,
      trainingRef: trainingRef,
      name: data['name'],
      description: data['description'],
      acknowledgement: data['acknowledgement'],
      subjectStatement: data['subjectStatement'],
      narration: data['narration'] as bool? ?? false,
      revision: data['revision'] as int? ?? 0,
      mediaItems: mediaItems,
      contentItems: contentItems,
      quizDocs: quizSnap.docs,
      steps: steps,
    );
  }

  List<_TrainingViewerContentItem> _buildContentItems({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> elementDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> quizDocs,
  }) {
    final items = <_TrainingViewerContentItem>[];
    for (final doc in elementDocs) {
      final data = doc.data();
      items.add(
        _TrainingViewerContentItem(
          kind: _TrainingViewerContentKind.element,
          doc: doc,
          order: _orderFromData(data),
          createdAt: _timestampFromData(data),
        ),
      );
    }
    for (final doc in quizDocs) {
      final data = doc.data();
      items.add(
        _TrainingViewerContentItem(
          kind: _TrainingViewerContentKind.quiz,
          doc: doc,
          order: _orderFromData(data),
          createdAt: _timestampFromData(data),
        ),
      );
    }
    items.sort(_compareContentItems);
    return items;
  }

  int _compareContentItems(
    _TrainingViewerContentItem a,
    _TrainingViewerContentItem b,
  ) {
    final aOrder = a.order;
    final bOrder = b.order;
    if (aOrder != null && bOrder != null) {
      return aOrder.compareTo(bOrder);
    }
    if (aOrder != null) return -1;
    if (bOrder != null) return 1;
    final aTimestamp = a.createdAt?.millisecondsSinceEpoch ?? 0;
    final bTimestamp = b.createdAt?.millisecondsSinceEpoch ?? 0;
    final timestampComparison = aTimestamp.compareTo(bTimestamp);
    if (timestampComparison != 0) return timestampComparison;
    return a.doc.id.compareTo(b.doc.id);
  }

  int? _orderFromData(Map<String, dynamic> data) {
    final order = data['order'];
    if (order is num) return order.toInt();
    return null;
  }

  Timestamp? _timestampFromData(Map<String, dynamic> data) {
    final createdAt = data['createdAt'];
    if (createdAt is Timestamp) return createdAt;
    return null;
  }

  Future<Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>>
      _loadQuizElements(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> quizDocs,
  ) async {
    final elementsByQuizId =
        <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    for (final quizDoc in quizDocs) {
      try {
        final snap = await _companyRef
            .collection('trainingQuizElement')
            .where('trainingQuizId', isEqualTo: quizDoc.reference)
            .orderBy('createdAt', descending: false)
            .get();
        elementsByQuizId[quizDoc.id] = snap.docs;
      } catch (_) {
        elementsByQuizId[quizDoc.id] =
            <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      }
    }
    return elementsByQuizId;
  }

  List<_TrainingViewerStep> _buildViewerSteps(
    List<_TrainingViewerContentItem> items,
    Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
        quizElementsByQuizId,
  ) {
    final steps = <_TrainingViewerStep>[];
    for (final item in items) {
      switch (item.kind) {
        case _TrainingViewerContentKind.element:
          steps.add(
            _TrainingViewerStep.element(item.doc),
          );
        case _TrainingViewerContentKind.quiz:
          steps.add(
            _TrainingViewerStep.quizIntro(item.doc),
          );
          final quizElements =
              quizElementsByQuizId[item.doc.id] ??
                  <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          for (var i = 0; i < quizElements.length; i++) {
            steps.add(
              _TrainingViewerStep.quizQuestion(
                quizDoc: item.doc,
                elementDoc: quizElements[i],
                questionIndex: i + 1,
              ),
            );
          }
          steps.add(
            _TrainingViewerStep.quizResult(item.doc),
          );
      }
    }
    return steps;
  }

  Future<DocumentReference<Map<String, dynamic>>?> _resolveMemberRef() async {
    if (_cachedMemberRef != null) return _cachedMemberRef;
    final loader = widget.memberRefLoader;
    if (loader == null) return null;
    final ref = await loader();
    _cachedMemberRef = ref;
    return ref;
  }

  List<String> _normalizeList(dynamic raw) {
    if (raw is Iterable) {
      return raw
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    if (raw is String) {
      final trimmed = raw.trim();
      return trimmed.isEmpty ? const [] : [trimmed];
    }
    return const <String>[];
  }

  List<int> _normalizeIndexList(dynamic raw) {
    if (raw is Iterable) {
      return raw
          .map((item) {
            if (item is int) return item;
            if (item is num) return item.toInt();
            final parsed = int.tryParse(item?.toString() ?? '');
            return parsed;
          })
          .whereType<int>()
          .where((value) => value >= 0)
          .toList(growable: false);
    }
    if (raw is num) {
      final value = raw.toInt();
      return value >= 0 ? [value] : const [];
    }
    if (raw is String) {
      final parsed = int.tryParse(raw.trim());
      return parsed != null && parsed >= 0 ? [parsed] : const [];
    }
    return const <int>[];
  }

  Map<String, List<String>> _normalizeLocalizedListMap(dynamic raw) {
    if (raw is! Map) return const <String, List<String>>{};
    final normalized = <String, List<String>>{};
    for (final entry in raw.entries) {
      final key = entry.key.toString().trim().toLowerCase();
      if (key.isEmpty) continue;
      final list = _normalizeList(entry.value);
      if (list.isEmpty) continue;
      normalized[key] = list;
    }
    return normalized;
  }

  String _localeCodeFromContext(BuildContext context) {
    final raw =
        _normalizeLocaleCode(Localizations.localeOf(context).toString());
    return raw.isNotEmpty ? raw : 'en';
  }

  List<String> _resolveLocalizedListForLocale(
    BuildContext context,
    List<String> base,
    dynamic rawLocalized,
  ) {
    final localizedMap = _normalizeLocalizedListMap(rawLocalized);
    if (localizedMap.isEmpty) return base;
    final localeCode = _localeCodeFromContext(context);
    final fallback = localizedMap['en'] ?? const <String>[];
    final candidate =
        localizedMap[localeCode] ?? localizedMap[localeCode.split('-').first];
    if (candidate != null && candidate.isNotEmpty) {
      if (base.isEmpty || candidate.length == base.length) {
        return candidate;
      }
    }
    if (fallback.isNotEmpty && (base.isEmpty || fallback.length == base.length)) {
      return fallback;
    }
    return base;
  }

  Map<String, String> _buildLabelMapForLocale(
    BuildContext context,
    List<String> base,
    dynamic rawLocalized,
  ) {
    if (base.isEmpty) return const <String, String>{};
    final localizedList =
        _resolveLocalizedListForLocale(context, base, rawLocalized);
    if (localizedList.length != base.length) {
      return const <String, String>{};
    }
    final labels = <String, String>{};
    for (var i = 0; i < base.length; i++) {
      final label = localizedList[i].trim();
      if (label.isEmpty || label == base[i]) continue;
      labels[base[i]] = label;
    }
    return labels;
  }

  List<int> _indexesForResponse(List<String> response, List<String> base) {
    if (response.isEmpty || base.isEmpty) return const <int>[];
    final indexMap = <String, int>{};
    for (var i = 0; i < base.length; i++) {
      indexMap[base[i]] = i;
    }
    final indexes = <int>[];
    for (final value in response) {
      final index = indexMap[value];
      if (index != null) {
        indexes.add(index);
      }
    }
    return indexes;
  }

  bool _boolFromData(Map<String, dynamic> data, String key,
      {bool fallback = false}) {
    final value = data[key];
    if (value is bool) return value;
    return fallback;
  }

  String _responseKey(DocumentReference<Map<String, dynamic>> ref) {
    return ref.path;
  }

  List<String> _responseFor(
    DocumentReference<Map<String, dynamic>> ref,
  ) {
    return _responsesByElementPath[_responseKey(ref)] ?? const <String>[];
  }

  void _setResponse(
    DocumentReference<Map<String, dynamic>> ref,
    List<String> response,
  ) {
    final key = _responseKey(ref);
    if (mounted) {
      setState(() => _responsesByElementPath[key] = response);
    } else {
      _responsesByElementPath[key] = response;
    }
  }

  _QuestionScore _scoreQuestion(
    Map<String, dynamic> data,
    List<String> response,
  ) {
    final type = (data['type'] as String?)?.toLowerCase();
    if (type == 'ranking') {
      final baseItems = _normalizeList(data['items']);
      final resolvedItems =
          _resolveLocalizedListForLocale(context, baseItems, data['itemsLocalized']);
      final correctIndexes = _normalizeIndexList(
        data['correctOrderIndexes'] ?? data['correctOrderIndex'],
      );
      if (correctIndexes.isNotEmpty) {
        final responseIndexes = _indexesForResponse(response, resolvedItems);
        if (responseIndexes.length != correctIndexes.length) {
          return const _QuestionScore(isScorable: true, isCorrect: false);
        }
        final isCorrect = Iterable<int>.generate(correctIndexes.length, (i) => i)
            .every((index) => responseIndexes[index] == correctIndexes[index]);
        return _QuestionScore(isScorable: true, isCorrect: isCorrect);
      }
      final correctOrder = _normalizeList(
        data['correctOrder'] ?? data['correctItems'] ?? data['answer'],
      );
      if (correctOrder.isEmpty) {
        return const _QuestionScore(isScorable: false);
      }
      final isCorrect = response.length == correctOrder.length &&
          List.generate(
            correctOrder.length,
            (index) => response[index] == correctOrder[index],
          ).every((match) => match);
      return _QuestionScore(isScorable: true, isCorrect: isCorrect);
    }

    final baseOptions = _normalizeList(data['options']);
    final resolvedOptions =
        _resolveLocalizedListForLocale(context, baseOptions, data['optionsLocalized']);
    final correctIndexes = _normalizeIndexList(
      data['correctOptionIndexes'] ??
          data['correctOptionsIndexes'] ??
          data['correctOptionIndex'],
    );
    if (correctIndexes.isNotEmpty) {
      final responseIndexes = _indexesForResponse(response, resolvedOptions);
      if (responseIndexes.isEmpty) {
        return const _QuestionScore(isScorable: true, isCorrect: false);
      }
      final correctSet = correctIndexes.toSet();
      final responseSet = responseIndexes.toSet();
      final allowsMultiple =
          (data['allowMultiple'] as bool?) ?? correctIndexes.length > 1;
      final isCorrect = allowsMultiple
          ? responseSet.length == correctSet.length &&
              responseSet.containsAll(correctSet)
          : responseSet.contains(correctIndexes.first);
      return _QuestionScore(isScorable: true, isCorrect: isCorrect);
    }

    final correctOptions = _normalizeList(
      data['correctOptions'] ??
          data['correctOption'] ??
          data['correctAnswer'] ??
          data['answer'] ??
          data['answers'],
    );
    if (correctOptions.isEmpty) {
      return const _QuestionScore(isScorable: false);
    }
    final responseSet =
        response.map((entry) => entry.trim()).where((e) => e.isNotEmpty).toSet();
    final correctSet = correctOptions.toSet();
    final allowMultiple = _boolFromData(data, 'allowMultiple') ||
        correctOptions.length > 1;
    final isCorrect = allowMultiple
        ? responseSet.length == correctSet.length &&
            responseSet.containsAll(correctSet)
        : responseSet.contains(correctOptions.first);
    return _QuestionScore(isScorable: true, isCorrect: isCorrect);
  }

  _QuizResult _scoreQuiz({
    required QueryDocumentSnapshot<Map<String, dynamic>> quizDoc,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> questionDocs,
  }) {
    final quizData = quizDoc.data();
    final passingGrade = (quizData['passingGrade'] as num?)?.toDouble();
    var scoredCount = 0;
    var correctCount = 0;
    for (final doc in questionDocs) {
      final response = _responseFor(doc.reference);
      final score = _scoreQuestion(doc.data(), response);
      if (!score.isScorable) continue;
      scoredCount += 1;
      if (score.isCorrect == true) {
        correctCount += 1;
      }
    }
    final scorePercent =
        scoredCount == 0 ? 100.0 : (correctCount / scoredCount) * 100;
    final passed =
        passingGrade == null ? true : scorePercent >= passingGrade;
    return _QuizResult(
      scorePercent: scorePercent,
      passed: passed,
      scoredCount: scoredCount,
      correctCount: correctCount,
      passingGrade: passingGrade,
    );
  }

  Future<void> _persistQuizResponse({
    required TrainingViewerData detail,
    required QueryDocumentSnapshot<Map<String, dynamic>> quizDoc,
    required QueryDocumentSnapshot<Map<String, dynamic>> elementDoc,
    required List<String> response,
  }) async {
    if (widget.previewMode) return;
    final assignedRef = detail.assignedRef;
    if (assignedRef == null) return;
    final memberRef = await _resolveMemberRef();
    final elementRef = elementDoc.reference;
    final quizRef = quizDoc.reference;
    final assignedId = assignedRef.id;
    final docId = '${assignedId}_${quizRef.id}_${elementRef.id}';
    final score = _scoreQuestion(elementDoc.data(), response);
    final isNew = !_savedResultIds.contains(docId);
    if (isNew) {
      _savedResultIds.add(docId);
    }
    final data = <String, dynamic>{
      'assignedTrainingId': assignedRef,
      'trainingId': detail.trainingRef,
      'trainingQuizId': quizRef,
      'trainingQuizElementId': elementRef,
      'response': response,
      'responseType': (elementDoc.data()['type'] as String?)?.toLowerCase(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (isNew) 'createdAt': FieldValue.serverTimestamp(),
      if (memberRef != null) 'memberId': memberRef,
      if (score.isScorable) 'isCorrect': score.isCorrect,
    };
    final resultRef =
        FirebaseFirestore.instance.collection('trainingQuizElementResult').doc(docId);
    await resultRef.set(data, SetOptions(merge: true));
  }

  void _handleSignatureChanged(String value) {
    _signatureData = value;
    final hasSignature = value.isNotEmpty;
    if (hasSignature != _hasSignature) {
      setState(() => _hasSignature = hasSignature);
    }
  }

  Future<void> _onConfirm(TrainingViewerData detail) async {
    final assignedRef = detail.assignedRef;
    if (assignedRef == null || widget.previewMode) {
      if (!mounted) return;
      if (widget.onExit != null) {
        widget.onExit!();
      } else {
        Navigator.of(context).pop();
      }
      return;
    }

    final loader = widget.memberRefLoader;
    if (loader == null) {
      if (!mounted) return;
      SnackbarService.instance.showSnackBar(
        const SnackBar(duration: Duration(seconds: 5), content: Text('Member profile not found.')),
      );
      return;
    }

    final memberRef = await loader();
    if (memberRef == null) {
      if (!mounted) return;
      SnackbarService.instance.showSnackBar(
        const SnackBar(duration: Duration(seconds: 5), content: Text('Member profile not found.')),
      );
      return;
    }

    final batch = FirebaseFirestore.instance.batch();
    final signatureRef =
        FirebaseFirestore.instance.collection('assignedTrainingSignature').doc();
    batch.set(signatureRef, {
      'assignedTrainingId': assignedRef,
      'memberId': memberRef,
      'createdBy': memberRef,
      'signature': _signatureData,
      'createdAt': FieldValue.serverTimestamp(),
      'revision': detail.revision,
    });
    // Optimistically flip `complete` so the me_info_details list reflects
    // the signed state instantly via its snapshot listener; the
    // onSignatureCreated function still runs and fills in goodUntil /
    // warningDate for renewal trainings.
    batch.update(assignedRef, {'complete': true});
    await batch.commit();
    if (!mounted) return;
    if (widget.onExit != null) {
      widget.onExit!();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleNext(TrainingViewerData detail) async {
    final stepCount = detail.steps.length;
    if (_activeIndex < 0) {
      if (stepCount > 0) {
        _setActiveIndex(0, detail);
      } else if (mounted) {
        SnackbarService.instance.showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 5),
            content: Text(
              'This training has no lessons or quizzes yet.',
            ),
          ),
        );
      }
      return;
    }
    if (_activeIndex >= stepCount) return;

    final step = detail.steps[_activeIndex];
    if (step.kind == _TrainingViewerStepKind.quizQuestion) {
      final elementDoc = step.quizElementDoc!;
      var response = _responseFor(elementDoc.reference);
      final type = (elementDoc.data()['type'] as String?)?.toLowerCase();
      if (response.isEmpty && type == 'ranking') {
        final baseItems = _normalizeList(elementDoc.data()['items']);
        final items = _resolveLocalizedListForLocale(
          context,
          baseItems,
          elementDoc.data()['itemsLocalized'],
        );
        if (items.isNotEmpty) {
          response = items;
          _setResponse(elementDoc.reference, response);
        }
      }
      final isRequired =
          _boolFromData(elementDoc.data(), 'isRequired', fallback: true);
      if (isRequired && response.isEmpty) {
        if (mounted) {
          SnackbarService.instance.showSnackBar(
            const SnackBar(duration: Duration(seconds: 5), content: Text('Please answer the question.')),
          );
        }
        return;
      }
      await _persistQuizResponse(
        detail: detail,
        quizDoc: step.quizDoc!,
        elementDoc: elementDoc,
        response: response,
      );
      _setActiveIndex(_activeIndex + 1, detail);
      return;
    }

    if (step.kind == _TrainingViewerStepKind.quizResult) {
      final quizDoc = step.quizDoc!;
      final questionDocs = _quizQuestionDocs(detail, quizDoc);
      final result = _scoreQuiz(
        quizDoc: quizDoc,
        questionDocs: questionDocs,
      );
      _quizResultsById[quizDoc.id] = result;
      if (result.passed) {
        _setActiveIndex(_activeIndex + 1, detail);
      } else {
        _quizAttemptsById[quizDoc.id] =
            (_quizAttemptsById[quizDoc.id] ?? 0) + 1;
        _clearQuizResponses(questionDocs);
        if (mounted) {
          SnackbarService.instance.showSnackBar(
            const SnackBar(
              duration: Duration(seconds: 5),
              content: Text('Quiz not passed. Review the training and retry.'),
            ),
          );
        }
        _setActiveIndex(-1, detail);
      }
      return;
    }

    if (_activeIndex < stepCount) {
      _setActiveIndex(_activeIndex + 1, detail);
    }
  }

  void _goBack(TrainingViewerData detail) {
    if (_activeIndex <= -1) return;
    _setActiveIndex(_activeIndex - 1, detail);
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _quizQuestionDocs(
    TrainingViewerData detail,
    QueryDocumentSnapshot<Map<String, dynamic>> quizDoc,
  ) {
    final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final step in detail.steps) {
      if (step.kind != _TrainingViewerStepKind.quizQuestion) continue;
      if (step.quizDoc?.id != quizDoc.id) continue;
      final elementDoc = step.quizElementDoc;
      if (elementDoc != null) {
        docs.add(elementDoc);
      }
    }
    return docs;
  }

  void _clearQuizResponses(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> questionDocs,
  ) {
    for (final doc in questionDocs) {
      _responsesByElementPath.remove(_responseKey(doc.reference));
    }
  }

  Widget _wrapCanvas(Widget child) {
    return StandardCanvas(
      child: SafeArea(
        top: true,
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(child: child),
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: CanvasTopBookend(),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildIntroChildren(
    BuildContext context,
    TrainingViewerData detail,
  ) {
    final name = _resolveLocalizedText(context, detail.name);
    final description = _resolveLocalizedText(context, detail.description);
    final subjectStatement =
        _resolveLocalizedText(context, detail.subjectStatement);

    return [
      // Hero Image Section with Gradient Overlay
      if (detail.mediaItems.isNotEmpty)
        SizedBox(
          height: 300,
          child: Stack(
            fit: StackFit.expand,
            children: [
              FileCarouselViewer(
                mediaItems: detail.mediaItems,
                showImage: true,
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.3),
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 24,
                left: 24,
                right: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (name.isNotEmpty)
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              blurRadius: 8,
                              color: Colors.black54,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        )
      else
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppPaletteScope.of(context).primary2.withValues(alpha: 0.8),
                AppPaletteScope.of(context).primary2,
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (name.isNotEmpty)
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
      const SizedBox(height: 16),

      // Description Card
      if (description.trim().isNotEmpty)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                size: 28,
                color: AppPaletteScope.of(context).primary2,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overview',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppPaletteScope.of(context).primary2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

      if (description.trim().isNotEmpty) const SizedBox(height: 16),

      // Subject Statement Card
      if (subjectStatement.trim().isNotEmpty)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.amber[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.amber[200]!,
              width: 2,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 28,
                color: Colors.amber[700],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What You\'ll Learn',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber[900],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subjectStatement,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: Colors.amber[900],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

      if (subjectStatement.trim().isNotEmpty) const SizedBox(height: 16),

      if (detail.steps.isEmpty)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.red[200]!,
              width: 2,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.error_outline,
                size: 28,
                color: Colors.red[700],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No content yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[900],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This training has no lessons or quizzes yet. '
                      'Ask your administrator to add content before starting.',
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: Colors.red[900],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

      if (detail.steps.isEmpty) const SizedBox(height: 16),

      const SizedBox(height: 24),
    ];
  }

  Widget _buildElementBody(
    BuildContext context,
    _TrainingViewerStep step,
  ) {
    final elementSnap = step.elementDoc!;
    final data = elementSnap.data();
    final elementDescription =
        _resolveLocalizedText(context, data['description']);
    final elementLink = (data['url'] as String?)?.trim() ?? '';

    final semanticLabel = elementDescription.trim();

    // 3 lines at 16px font * 1.5 line height = 72px + padding
    const textAreaHeight = 72.0 + 32.0; // 3 lines + vertical padding
    // Extra height when a link row is shown below the description.
    const linkRowHeight = 40.0;
    final hasLink = elementLink.isNotEmpty;
    final totalTextAreaHeight =
        hasLink ? textAreaHeight + linkRowHeight : textAreaHeight;

    return FutureBuilder<List<FileCarouselItem>>(
      future: _loadElementMediaItems(elementSnap.reference, data),
      builder: (context, mediaSnap) {
        final items = mediaSnap.data ?? const <FileCarouselItem>[];
        final primaryItem = items.isNotEmpty ? items.first : null;
        return Semantics(
          label: semanticLabel.isEmpty ? null : semanticLabel,
          readOnly: true,
          child: Column(
            children: [
              // Image area - fills available space above text
              Expanded(
                child: TrainingFileViewer(
                  item: primaryItem,
                ),
              ),
              // Dedicated black text area - 3 lines high (+ link row if present)
              Container(
                height: totalTextAreaHeight,
                width: double.infinity,
                color: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: elementDescription.trim().isEmpty
                          ? const SizedBox.shrink()
                          : Listener(
                              onPointerDown: (_) => _onScrollTouchStart(),
                              onPointerUp: (_) => _onScrollTouchEnd(),
                              onPointerCancel: (_) => _onScrollTouchEnd(),
                              child: SingleChildScrollView(
                                controller: _elementTextScrollController,
                                child: Text(
                                  elementDescription,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ),
                    ),
                    if (hasLink) _buildElementLink(context, elementLink),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildElementLink(BuildContext context, String rawUrl) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        onTap: () => _launchTrainingUrl(context, rawUrl),
        child: Row(
          children: [
            const Icon(
              Icons.open_in_new,
              size: 18,
              color: Colors.lightBlueAccent,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                rawUrl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.lightBlueAccent,
                  fontSize: 14,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.lightBlueAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchTrainingUrl(BuildContext context, String rawUrl) async {
    var trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return;
    if (!trimmed.contains('://')) {
      trimmed = 'https://$trimmed';
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        SnackbarService.instance.showSnackBar(
          const SnackBar(duration: Duration(seconds: 5), content: Text('Unable to open the link.')),
        );
      }
    }
  }

  List<Widget> _buildQuizIntroChildren(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> quizDoc,
  ) {
    final data = quizDoc.data();
    final name = _resolveLocalizedText(context, data['name']);
    final description = _resolveLocalizedText(context, data['description']);
    final passingGrade = (data['passingGrade'] as num?)?.toDouble();
    final passingText = passingGrade == null
        ? null
        : '${passingGrade.toStringAsFixed(
            passingGrade.truncateToDouble() == passingGrade ? 0 : 2,
          )}%';
    final primaryColor = AppPaletteScope.of(context).primary2;
    return [
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primaryColor.withValues(alpha: 0.8),
              primaryColor,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.quiz, color: Colors.black54, size: 40),
            const SizedBox(height: 16),
            Text(
              name.isEmpty ? 'Quiz' : name,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      if (passingText != null) ...[
        const SizedBox(height: 16),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle_outline, size: 28, color: primaryColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Passing Grade',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      passingText,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
      if (description.trim().isNotEmpty) ...[
        const SizedBox(height: 16),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                description,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 24),
    ];
  }

  List<Widget> _buildQuizQuestionChildren(
    BuildContext context,
    _TrainingViewerStep step,
  ) {
    final elementDoc = step.quizElementDoc!;
    final data = elementDoc.data();
    final type = (data['type'] as String?)?.toLowerCase();
    final prompt = _resolveLocalizedText(context, data['question']);
    final helpText = _resolveLocalizedText(context, data['description']);
    final isRequired = _boolFromData(data, 'isRequired', fallback: true);

    Widget content;
    if (type == 'ranking') {
      final baseItems = _normalizeList(data['items']);
      final displayItems = _resolveLocalizedListForLocale(
        context,
        baseItems,
        data['itemsLocalized'],
      );
      final itemLabels =
          _buildLabelMapForLocale(context, baseItems, data['itemsLocalized']);
      final itemsForTile =
          baseItems.isNotEmpty ? baseItems : displayItems;
      final response = _responseFor(elementDoc.reference);
      content = RankingSurveyTile(
        prompt: prompt,
        helpText: helpText,
        items: itemsForTile,
        itemLabels: itemLabels.isEmpty ? null : itemLabels,
        isRequired: isRequired,
        rankedItems: response.isNotEmpty ? response : itemsForTile,
        onRankingChanged: (values) => _setResponse(
          elementDoc.reference,
          values,
        ),
      );
    } else {
      final baseOptions = _normalizeList(data['options']);
      final displayOptions = _resolveLocalizedListForLocale(
        context,
        baseOptions,
        data['optionsLocalized'],
      );
      final optionLabels =
          _buildLabelMapForLocale(context, baseOptions, data['optionsLocalized']);
      final optionsForTile =
          baseOptions.isNotEmpty ? baseOptions : displayOptions;
      final allowMultiple = _boolFromData(data, 'allowMultiple');
      final allowOther = _boolFromData(data, 'allowOther');
      final shuffleOptions = _boolFromData(data, 'shuffleOptions');
      final response = _responseFor(elementDoc.reference);
      content = ChoiceSurveyTile(
        prompt: prompt,
        helpText: helpText,
        options: optionsForTile,
        optionLabels: optionLabels.isEmpty ? null : optionLabels,
        allowMultiple: allowMultiple,
        allowOther: allowOther,
        shuffleOptions: shuffleOptions,
        isRequired: isRequired,
        selectedValues: response,
        onSelectionChanged: (values) => _setResponse(
          elementDoc.reference,
          values,
        ),
      );
    }

    return [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Question ${step.questionIndex ?? 1}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppPaletteScope.of(context).primary2,
              ),
            ),
            const SizedBox(height: 12),
            content,
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildQuizResultChildren(
    BuildContext context,
    TrainingViewerData detail,
    QueryDocumentSnapshot<Map<String, dynamic>> quizDoc,
  ) {
    final questionDocs = _quizQuestionDocs(detail, quizDoc);
    final result = _scoreQuiz(quizDoc: quizDoc, questionDocs: questionDocs);
    _quizResultsById[quizDoc.id] = result;
    final name = _resolveLocalizedText(context, quizDoc.data()['name']);
    final summary = result.scoredCount == 0
        ? 'Results recorded.'
        : '${result.correctCount} of ${result.scoredCount} correct';
    final scoreText = '${result.scorePercent.toStringAsFixed(0)}%';
    final passedText = result.passed ? 'Passed' : 'Try Again';
    final Color statusColor =
        result.passed ? Colors.green[700]! : Colors.red[700]!;
    final Color statusBg =
        result.passed ? Colors.green[50]! : Colors.red[50]!;
    final Color statusBorder =
        result.passed ? Colors.green[200]! : Colors.red[200]!;
    final IconData statusIcon =
        result.passed ? Icons.check_circle : Icons.cancel;
    final primaryColor = AppPaletteScope.of(context).primary2;

    return [
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primaryColor.withValues(alpha: 0.8),
              primaryColor,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.assessment, color: Colors.black54, size: 40),
            const SizedBox(height: 16),
            Text(
              name.isEmpty ? 'Quiz Results' : name,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              scoreText,
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              summary,
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: statusBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: statusBorder, width: 2),
        ),
        child: Row(
          children: [
            Icon(statusIcon, size: 28, color: statusColor),
            const SizedBox(width: 16),
            Text(
              passedText,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
    ];
  }

  Widget _buildSignatureSheet(TrainingViewerData detail) {
    final primaryColor2 = AppPaletteScope.of(context).primary2;
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(
          top: BorderSide(color: Colors.grey[300]!, width: 2),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SignatureField(
            onChanged: _handleSignatureChanged,
            iconColor: primaryColor2,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor2,
                foregroundColor: Colors.black,
              ),
              onPressed: _hasSignature ? () => _onConfirm(detail) : null,
              child: const Text('Confirm'),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAcknowledgementChildren(
    BuildContext context,
    TrainingViewerData detail,
  ) {
    final acknowledgement =
        _resolveLocalizedText(context, detail.acknowledgement);
    final passedAll = _allQuizzesPassed(detail);
    return [
      if (passedAll)
        ContainerActionWidget(
          title: 'Congratulations',
          actionText: '',
          content: const Text('You passed your training.'),
          enabled: false,
        ),
      ContainerHeader(
        titleHeader: 'Acknowledgement',
        title: acknowledgement,
        descriptionHeader: '',
        description: '',
        textIcon: null,
        descriptionIcon: null,
        trailingChildren: [
          SelectableRowTile<bool>(
            value: true,
            selected: _showSignature,
            label: 'Add signature',
            primaryColor: AppPaletteScope.of(context).primary2,
            onTap: () {
              setState(() {
                _showSignature = !_showSignature;
                if (!_showSignature) {
                  _signatureData = '';
                  _hasSignature = false;
                }
              });
            },
          ),
        ],
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: _showSignature
            ? _buildSignatureSheet(detail)
            : const SizedBox.shrink(),
      ),
      const SizedBox(height: 16),
    ];
  }

  bool _allQuizzesPassed(TrainingViewerData detail) {
    if (detail.quizDocs.isEmpty) return true;
    for (final quizDoc in detail.quizDocs) {
      final result = _quizResultsById[quizDoc.id];
      if (result == null || !result.passed) return false;
    }
    return true;
  }

  bool _canAdvanceFromStep(TrainingViewerData detail) {
    if (_activeIndex < 0) return detail.steps.isNotEmpty;
    if (_activeIndex >= detail.steps.length) return false;

    final step = detail.steps[_activeIndex];

    // Block advancement for element steps until audio completes (when narration is enabled)
    if (step.kind == _TrainingViewerStepKind.element) {
      if (detail.narration && !_audioCompleted) {
        return false;
      }
      return true;
    }

    if (step.kind == _TrainingViewerStepKind.quizQuestion) {
      final elementDoc = step.quizElementDoc!;
      final isRequired =
          _boolFromData(elementDoc.data(), 'isRequired', fallback: true);
        var response = _responseFor(elementDoc.reference);
        final type = (elementDoc.data()['type'] as String?)?.toLowerCase();
        if (response.isEmpty && type == 'ranking') {
          final baseItems = _normalizeList(elementDoc.data()['items']);
          final items = _resolveLocalizedListForLocale(
            context,
            baseItems,
            elementDoc.data()['itemsLocalized'],
          );
          if (items.isNotEmpty) {
            response = items;
          }
        }
      if (!isRequired) return true;
      return response.isNotEmpty;
    }
    return true;
  }

  Widget _buildBottomBar(
    BuildContext context,
    TrainingViewerData detail,
  ) {
    final stepCount = detail.steps.length;
    final isIntro = _activeIndex < 0;
    final isEnd = _activeIndex >= stepCount;
    final canGoBack = _activeIndex > -1;
    final canGoNext = !isEnd && _canAdvanceFromStep(detail);
    final centerLabel = isIntro ? 'Begin' : 'Exit';
    final VoidCallback onCenter = isIntro
        ? () => _handleNext(detail)
        : (widget.onExit ?? () => Navigator.of(context).pop());
    final VoidCallback? onPrevious = isIntro
        ? (widget.onExit ?? () => Navigator.of(context).pop())
        : (canGoBack ? () => _goBack(detail) : null);

    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom;
    final navPadding = bottomInset > 0 ? 0.0 : media.viewPadding.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        minimum: EdgeInsets.only(bottom: navPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TrainingNavigationBar(
              onPrevious: onPrevious,
              onNext: canGoNext ? () => _handleNext(detail) : null,
              onCenter: onCenter,
              centerLabel: centerLabel,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TrainingViewerData>(
      future: _viewerFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Colors.grey[100],
            body: _wrapCanvas(
              const Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (snap.hasError || !snap.hasData) {
          return Scaffold(
            backgroundColor: Colors.grey[100],
            body: _wrapCanvas(
              const Center(child: Text('Training not found.')),
            ),
          );
        }

        final detail = snap.data!;
        final stepCount = detail.steps.length;
        final isIntro = _activeIndex < 0;
        final isAcknowledgement = _activeIndex >= stepCount;

        Widget body;
        if (isIntro) {
          final bottomPadding =
              16.0 + MediaQuery.of(context).padding.bottom;
          body = _wrapCanvas(
            Stack(
              children: [
                ListView(
                  padding: EdgeInsets.only(bottom: bottomPadding),
                  children: _buildIntroChildren(context, detail),
                ),
                if (_isPreparingAudio)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.5),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 24,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 48,
                                height: 48,
                                child: CircularProgressIndicator(
                                  strokeWidth: 4,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppPaletteScope.of(context).primary2,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Preparing audio...',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[800],
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
        } else if (isAcknowledgement) {
          final bottomPadding =
              16.0 + MediaQuery.of(context).padding.bottom;
          body = _wrapCanvas(
            ListView(
              padding: EdgeInsets.only(bottom: bottomPadding),
              children: _buildAcknowledgementChildren(context, detail),
            ),
          );
        } else {
          final step = detail.steps[_activeIndex];
          if (step.kind == _TrainingViewerStepKind.element) {
            body = _wrapCanvas(_buildElementBody(context, step));
          } else {
            final bottomPadding =
                16.0 + MediaQuery.of(context).padding.bottom;
            final children = switch (step.kind) {
              _TrainingViewerStepKind.quizIntro =>
                _buildQuizIntroChildren(context, step.quizDoc!),
              _TrainingViewerStepKind.quizQuestion =>
                _buildQuizQuestionChildren(context, step),
              _TrainingViewerStepKind.quizResult =>
                _buildQuizResultChildren(context, detail, step.quizDoc!),
              _TrainingViewerStepKind.element =>
                const <Widget>[],
            };
            body = _wrapCanvas(
              ListView(
                padding: EdgeInsets.only(bottom: bottomPadding),
                children: children,
              ),
            );
          }
        }

        final decorator = widget.decorator;
        if (decorator != null) {
          body = decorator(context, detail, body);
        }

        return Scaffold(
          backgroundColor: Colors.grey[100],
          bottomNavigationBar: _buildBottomBar(context, detail),
          body: body,
        );
      },
    );
  }
}

class TrainingViewerData {
  final String companyId;
  final String? assignedTrainingId;
  final DocumentReference<Map<String, dynamic>>? assignedRef;
  final DocumentReference<Map<String, dynamic>> trainingRef;
  final dynamic name;
  final dynamic description;
  final dynamic acknowledgement;
  final dynamic subjectStatement;
  final bool narration;
  final int revision;
  final List<FileCarouselItem> mediaItems;
  final List<_TrainingViewerContentItem> contentItems;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> quizDocs;
  final List<_TrainingViewerStep> steps;

  TrainingViewerData({
    required this.companyId,
    required this.assignedTrainingId,
    required this.assignedRef,
    required this.trainingRef,
    required this.name,
    required this.description,
    required this.acknowledgement,
    required this.subjectStatement,
    required this.narration,
    required this.revision,
    required this.mediaItems,
    required this.contentItems,
    required this.quizDocs,
    required this.steps,
  });
}

enum _TrainingViewerContentKind {
  element,
  quiz,
}

class _TrainingViewerContentItem {
  const _TrainingViewerContentItem({
    required this.kind,
    required this.doc,
    this.order,
    this.createdAt,
  });

  final _TrainingViewerContentKind kind;
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final int? order;
  final Timestamp? createdAt;
}

enum _TrainingViewerStepKind {
  element,
  quizIntro,
  quizQuestion,
  quizResult,
}

class _TrainingViewerStep {
  const _TrainingViewerStep._({
    required this.kind,
    this.elementDoc,
    this.quizDoc,
    this.quizElementDoc,
    this.questionIndex,
  });

  factory _TrainingViewerStep.element(
    QueryDocumentSnapshot<Map<String, dynamic>> elementDoc,
  ) =>
      _TrainingViewerStep._(
        kind: _TrainingViewerStepKind.element,
        elementDoc: elementDoc,
      );

  factory _TrainingViewerStep.quizIntro(
    QueryDocumentSnapshot<Map<String, dynamic>> quizDoc,
  ) =>
      _TrainingViewerStep._(
        kind: _TrainingViewerStepKind.quizIntro,
        quizDoc: quizDoc,
      );

  factory _TrainingViewerStep.quizQuestion({
    required QueryDocumentSnapshot<Map<String, dynamic>> quizDoc,
    required QueryDocumentSnapshot<Map<String, dynamic>> elementDoc,
    int? questionIndex,
  }) =>
      _TrainingViewerStep._(
        kind: _TrainingViewerStepKind.quizQuestion,
        quizDoc: quizDoc,
        quizElementDoc: elementDoc,
        questionIndex: questionIndex,
      );

  factory _TrainingViewerStep.quizResult(
    QueryDocumentSnapshot<Map<String, dynamic>> quizDoc,
  ) =>
      _TrainingViewerStep._(
        kind: _TrainingViewerStepKind.quizResult,
        quizDoc: quizDoc,
      );

  final _TrainingViewerStepKind kind;
  final QueryDocumentSnapshot<Map<String, dynamic>>? elementDoc;
  final QueryDocumentSnapshot<Map<String, dynamic>>? quizDoc;
  final QueryDocumentSnapshot<Map<String, dynamic>>? quizElementDoc;
  final int? questionIndex;
}

class _QuizResult {
  const _QuizResult({
    required this.scorePercent,
    required this.passed,
    required this.scoredCount,
    required this.correctCount,
    required this.passingGrade,
  });

  final double scorePercent;
  final bool passed;
  final int scoredCount;
  final int correctCount;
  final double? passingGrade;
}

class _QuestionScore {
  const _QuestionScore({
    required this.isScorable,
    this.isCorrect,
  });

  final bool isScorable;
  final bool? isCorrect;
}

class _OrderedMediaItem {
  const _OrderedMediaItem({
    required this.order,
    required this.item,
  });

  final int order;
  final FileCarouselItem item;
}

String? _extractImageUrl(Object? item) {
  if (item is Map<String, dynamic>) {
    final candidate = item['url'] ??
        item['downloadUrl'] ??
        item['downloadURL'] ??
        item['imageUrl'] ??
        item['uri'] ??
        item['storagePath'] ??
        item['path'];
    if (candidate is String) {
      final trimmed = candidate.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
  } else if (item is String) {
    final trimmed = item.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return null;
}

List<String> _galleryImageUrls(
  dynamic rawImages, {
  Iterable<String?> fallbacks = const [],
}) {
  final entries = <_ImagePayloadEntry>[];
  var fallbackOrder = 0;

  void addEntry({
    required String url,
    int? order,
    bool isMaster = false,
  }) {
    entries.add(
      _ImagePayloadEntry(
        url: url,
        order: order ?? fallbackOrder,
        isMaster: isMaster,
      ),
    );
    final nextBase = order ?? fallbackOrder;
    fallbackOrder = nextBase + 1;
  }

  if (rawImages is Iterable) {
    for (final item in rawImages) {
      String? url;
      bool isMaster = false;
      int? order;

      if (item is Map<String, dynamic>) {
        url = _extractImageUrl(item);
        final masterFlag =
            item['isMaster'] ?? item['master'] ?? item['primary'] ?? item['isPrimary'];
        if (masterFlag is bool && masterFlag) {
          isMaster = true;
        }
        final ord = item['order'];
        if (ord is num) {
          order = ord.toInt();
        }
      } else if (item is String) {
        final trimmed = item.trim();
        if (trimmed.isNotEmpty) {
          url = trimmed;
          order = fallbackOrder;
          isMaster = fallbackOrder == 0;
        }
      }

      if (url != null) {
        addEntry(url: url, order: order, isMaster: isMaster);
      }
    }
  }

  entries.sort((a, b) => a.order.compareTo(b.order));

  if (entries.isNotEmpty) {
    final masterIndex = entries.indexWhere((e) => e.isMaster);
    if (masterIndex > 0) {
      final master = entries.removeAt(masterIndex);
      entries.insert(0, master.copyWith(order: 0, isMaster: true));
    } else if (masterIndex == -1) {
      entries[0] = entries[0].copyWith(order: 0, isMaster: true);
    } else {
      entries[0] = entries[0].copyWith(order: 0, isMaster: true);
    }
  }

  final urls = <String>[];
  for (final entry in entries) {
    if (!urls.contains(entry.url)) {
      urls.add(entry.url);
    }
  }

  for (final fallback in fallbacks) {
    final trimmed = fallback?.trim();
    if (trimmed == null || trimmed.isEmpty) continue;
    if (!urls.contains(trimmed)) {
      urls.add(trimmed);
    }
  }
  return urls;
}

class _ImagePayloadEntry {
  const _ImagePayloadEntry({
    required this.url,
    required this.order,
    required this.isMaster,
  });

  final String url;
  final int order;
  final bool isMaster;

  _ImagePayloadEntry copyWith({
    String? url,
    int? order,
    bool? isMaster,
  }) {
    return _ImagePayloadEntry(
      url: url ?? this.url,
      order: order ?? this.order,
      isMaster: isMaster ?? this.isMaster,
    );
  }
}
