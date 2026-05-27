// lib/features/training/forms/training_quiz_element_form.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:shared_widgets/utils/process_localization_utils.dart';
import 'package:kleenops_admin/l10n/app_localizations.dart';
import 'package:kleenops_admin/services/ai_text_adapter.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';

class TrainingQuizElementForm extends ConsumerStatefulWidget {
  final String companyId;
  final String trainingId;
  final String quizId;
  final String? elementId;

  const TrainingQuizElementForm({
    super.key,
    required this.companyId,
    required this.trainingId,
    required this.quizId,
    this.elementId,
  });

  @override
  ConsumerState<TrainingQuizElementForm> createState() =>
      _TrainingQuizElementFormState();
}

class _TrainingQuizElementFormState
    extends ConsumerState<TrainingQuizElementForm> {
  bool _loading = false;
  bool _initialLoadStarted = false;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();
  late final Set<String> _supportedLocaleCodeSet;
  late String _localeCode;
  Map<String, dynamic>? _cachedData;
  final Map<String, String> _questionTranslations = {};
  final Map<String, String> _detailsTranslations = {};

  @override
  void initState() {
    super.initState();
    _supportedLocaleCodeSet = AppLocalizations.supportedLocales
        .map(_localeCodeOf)
        .where((code) => code.isNotEmpty)
        .toSet()
      ..add(_normalizeLocaleCode(ProcessLocalizationUtils.defaultLocaleCode));
    _localeCode = ProcessLocalizationUtils.defaultLocaleCode;
  }

  DocumentReference<Map<String, dynamic>> _companyRef() {
    return FirebaseFirestore.instance
        .collection('company')
        .doc(widget.companyId);
  }

  DocumentReference<Map<String, dynamic>> _quizRef() {
    return _companyRef().collection('trainingQuiz').doc(widget.quizId);
  }

  DocumentReference<Map<String, dynamic>> _elementRef() {
    final collection = _companyRef().collection('trainingQuizElement');
    if (widget.elementId != null && widget.elementId!.trim().isNotEmpty) {
      return collection.doc(widget.elementId);
    }
    return collection.doc();
  }

  String _normalizeLocaleCode(String code) {
    return ProcessLocalizationUtils.normalizeLocaleCode(code);
  }

  String _localeCodeOf(Locale locale) {
    final language = locale.languageCode.trim().toLowerCase();
    final script = locale.scriptCode?.trim().toLowerCase();
    final country = locale.countryCode?.trim().toLowerCase();
    final segments = <String>[];
    if (language.isNotEmpty) {
      segments.add(language);
    }
    if (script != null && script.isNotEmpty) {
      segments.add(script);
    }
    if (country != null && country.isNotEmpty) {
      segments.add(country);
    }
    if (segments.isEmpty) {
      return '';
    }
    return _normalizeLocaleCode(segments.join('-'));
  }

  void _populateTranslations(
    Map<String, String> target,
    dynamic fieldValue,
  ) {
    target.clear();
    final normalized = ProcessLocalizationUtils.normalizeLocalizedField(
      fieldValue,
      fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
    );
    if (normalized == null) return;
    for (final entry in normalized.entries) {
      final key = entry.key.toString();
      final normalizedKey = _normalizeLocaleCode(key);
      if (normalizedKey == 'source' || normalizedKey == 'lang') continue;
      final value = entry.value;
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) continue;
        target[normalizedKey] = trimmed;
      }
    }
    final sourceLang = normalized['lang'];
    final sourceValue = normalized['source'];
    if (sourceLang is String &&
        sourceValue is String &&
        sourceLang.trim().isNotEmpty &&
        sourceValue.trim().isNotEmpty) {
      final normalizedSource = _normalizeLocaleCode(sourceLang);
      target.putIfAbsent(normalizedSource, () => sourceValue.trim());
    }
  }

  Map<String, dynamic>? _buildLocalizedPayload({
    required String latestValue,
    required Map<String, String> existingTranslations,
  }) {
    final trimmed = latestValue.trim();
    final merged = <String, String>{};
    for (final entry in existingTranslations.entries) {
      final key = _normalizeLocaleCode(entry.key);
      final value = entry.value.trim();
      if (key.isEmpty || value.isEmpty) continue;
      merged[key] = value;
    }
    final normalizedLocale = _normalizeLocaleCode(_localeCode);
    if (trimmed.isNotEmpty) {
      if (normalizedLocale.isNotEmpty) {
        merged[normalizedLocale] = trimmed;
      }
    } else if (normalizedLocale.isNotEmpty) {
      merged.remove(normalizedLocale);
    }
    if (merged.isEmpty) return null;
    final fallback =
        _normalizeLocaleCode(ProcessLocalizationUtils.defaultLocaleCode);
    final sourceLanguage = merged.containsKey(normalizedLocale)
        ? normalizedLocale
        : (merged.containsKey(fallback) ? fallback : merged.keys.first);
    final sourceValue = merged[sourceLanguage]!.trim();
    return ProcessLocalizationUtils.buildLocalizedFieldPayload(
      source: sourceValue,
      sourceLanguage: sourceLanguage,
      translations: merged,
      fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
    );
  }

  void _applyData(Map<String, dynamic>? data) {
    if (data == null) return;
    _populateTranslations(_questionTranslations, data['question']);
    _populateTranslations(_detailsTranslations, data['details']);
    final question = ProcessLocalizationUtils.resolveLocalizedText(
      data['question'],
      localeCode: _localeCode,
      fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
    );
    final details = ProcessLocalizationUtils.resolveLocalizedText(
      data['details'],
      localeCode: _localeCode,
      fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
    );
    _questionController.text = question;
    _detailsController.text = details;
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.maybeLocaleOf(context);
    final inferredFull = locale != null ? _localeCodeOf(locale) : '';
    final inferredLanguage = locale?.languageCode.trim().toLowerCase() ?? '';
    final candidates = <String>[
      if (inferredFull.isNotEmpty) inferredFull,
      if (inferredLanguage.isNotEmpty) inferredLanguage,
      ProcessLocalizationUtils.defaultLocaleCode,
    ];
    final nextLocale = candidates.firstWhere(
      (code) => _supportedLocaleCodeSet.contains(code),
      orElse: () => ProcessLocalizationUtils.defaultLocaleCode,
    );
    if (_localeCode != nextLocale) {
      _localeCode = nextLocale;
      if (_cachedData != null) {
        _applyData(_cachedData);
      }
    }
    if (!_initialLoadStarted && widget.elementId != null) {
      _initialLoadStarted = true;
      _loadExisting();
    }
  }

  Future<void> _loadExisting() async {
    setState(() => _loading = true);
    try {
      final snap = await _elementRef().get();
      final data = snap.data();
      if (data != null) {
        _cachedData = data;
        _applyData(data);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> saveForm() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _loading = true);
    final question = _questionController.text.trim();
    final details = _detailsController.text.trim();
    try {
      final ref = _elementRef();
      final questionPayload = _buildLocalizedPayload(
        latestValue: question,
        existingTranslations: _questionTranslations,
      );
      final detailsPayload = _buildLocalizedPayload(
        latestValue: details,
        existingTranslations: _detailsTranslations,
      );
      final data = <String, dynamic>{
        'question': questionPayload ?? question,
        if (detailsPayload != null) 'details': detailsPayload else 'details': details,
        'trainingQuizId': _quizRef(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (widget.elementId == null || widget.elementId!.trim().isEmpty) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }
      await ref.set(data, SetOptions(merge: true));
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      SnackbarService.instance.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: Text('Failed to save quiz element: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && widget.elementId != null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      body: StandardCanvas(
        child: SafeArea(
          top: true,
          bottom: false,
          child: Stack(
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  padding: EdgeInsets.zero,
                  child: ContainerActionWidget(
                    title:
                        widget.elementId == null ? 'New Quiz Element' : 'Edit Quiz Element',
                    actionText: '',
                    content: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AITextField(
                            controller: _questionController,
                            labelText: 'Question',
                            minLines: 1,
                            maxLines: 3,
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                    ? 'Required'
                                    : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _detailsController,
                            decoration:
                                const InputDecoration(labelText: 'Details'),
                            minLines: 3,
                            maxLines: 5,
                            textInputAction: TextInputAction.newline,
                            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: CanvasTopBookend(),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CancelSaveBar(
            onCancel: () => Navigator.of(context).pop(),
            onSave: saveForm,
            showTopBorder: true,
            clipTopShadow: true,
            extraBottomPadding: 0,
            reserveNavBarSpace: false,
          ),
          DetailsAppBar(
            title: widget.elementId == null
                ? 'New Quiz Element'
                : 'Edit Quiz Element',
          ),
          const HomeNavBarAdapter(),
        ],
      ),
    );
  }
}
