// lib/features/training/forms/training_quiz_form.dart

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
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';

class TrainingQuizForm extends ConsumerStatefulWidget {
  final String? quizId;
  final String companyId;
  final String trainingId;

  const TrainingQuizForm({
    super.key,
    this.quizId,
    required this.companyId,
    required this.trainingId,
  });

  @override
  ConsumerState<TrainingQuizForm> createState() => _TrainingQuizFormState();
}

class _TrainingQuizFormState extends ConsumerState<TrainingQuizForm> {
  bool _loading = false;
  bool _initialLoadStarted = false;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _passingGradeController = TextEditingController();
  late final Set<String> _supportedLocaleCodeSet;
  late String _localeCode;
  Map<String, dynamic>? _cachedData;
  final Map<String, String> _nameTranslations = {};
  final Map<String, String> _descriptionTranslations = {};

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

  Future<DocumentReference<Map<String, dynamic>>> _quizRef() async {
    final collection = _companyRef().collection('trainingQuiz');
    if (widget.quizId != null && widget.quizId!.trim().isNotEmpty) {
      return collection.doc(widget.quizId);
    }
    return collection.doc();
  }

  DocumentReference<Map<String, dynamic>> _companyRef() {
    return FirebaseFirestore.instance
        .collection('company')
        .doc(widget.companyId);
  }

  DocumentReference<Map<String, dynamic>> _trainingRef() {
    return _companyRef().collection('training').doc(widget.trainingId);
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
    _populateTranslations(_nameTranslations, data['name']);
    _populateTranslations(_descriptionTranslations, data['description']);
    final name = ProcessLocalizationUtils.resolveLocalizedText(
      data['name'],
      localeCode: _localeCode,
      fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
    );
    final description = ProcessLocalizationUtils.resolveLocalizedText(
      data['description'],
      localeCode: _localeCode,
      fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
    );
    _nameController.text = name;
    _descriptionController.text = description;
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
    if (!_initialLoadStarted && widget.quizId != null) {
      _initialLoadStarted = true;
      _loadExisting();
    }
  }

  Future<void> _loadExisting() async {
    setState(() => _loading = true);
    try {
      final quizRef = await _quizRef();
      final snap = await quizRef.get();
      final data = snap.data();
      if (data != null) {
        _cachedData = data;
        _applyData(data);
        final passing = data['passingGrade'];
        if (passing is num) {
          _passingGradeController.text = passing.toString();
        }
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
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final gradeText = _passingGradeController.text.trim();
    final double? passingGrade = gradeText.isEmpty
        ? null
        : double.tryParse(gradeText.replaceAll(',', '.'));
    try {
      final quizRef = await _quizRef();
      final trainingRef = _trainingRef();
      final companyRef = _companyRef();
      final namePayload = _buildLocalizedPayload(
        latestValue: name,
        existingTranslations: _nameTranslations,
      );
      final descriptionPayload = _buildLocalizedPayload(
        latestValue: description,
        existingTranslations: _descriptionTranslations,
      );
      final data = <String, dynamic>{
        'name': namePayload ?? name,
        if (descriptionPayload != null)
          'description': descriptionPayload
        else if (description.isEmpty)
          'description': FieldValue.delete()
        else
          'description': description,
        'passingGrade': passingGrade,
        'trainingId': trainingRef,
        'trainingRef': trainingRef,
        'companyRef': companyRef,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (widget.quizId == null || widget.quizId!.trim().isEmpty) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }
      await quizRef.set(data, SetOptions(merge: true));
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      SnackbarService.instance.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: Text('Failed to save quiz: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _passingGradeController.dispose();
    super.dispose();
  }

  InputDecoration _gradeDecoration() {
    return const InputDecoration(
      labelText: 'Passing grade (%)',
      suffixText: '%',
    );
  }

  void _showInfoDialog(String title, String message) {
    if (message.trim().isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => DialogAction(
        title: title,
        content: Text(message),
        cancelText: 'Close',
        onCancel: () => Navigator.of(dialogContext).pop(),
        showActionButton: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && widget.quizId != null) {
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      ContainerActionWidget(
                        title: 'Quiz Details',
                        onTitleInfoPressed: () => _showInfoDialog(
                          'Quiz Details',
                          _infoQuizDetails,
                        ),
                        actionText: '',
                        content: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AITextField(
                                controller: _nameController,
                                labelText: 'Name',
                                minLines: 1,
                                maxLines: 2,
                                validator: (value) =>
                                    (value == null || value.trim().isEmpty)
                                        ? 'Required'
                                        : null,
                              ),
                              const SizedBox(height: 16),
                              AITextField(
                                controller: _descriptionController,
                                labelText: 'Description',
                                minLines: 3,
                                maxLines: 5,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ContainerActionWidget(
                        title: 'Passing Requirement',
                        onTitleInfoPressed: () => _showInfoDialog(
                          'Passing Requirement',
                          _infoPassingRequirement,
                        ),
                        actionText: '',
                        content: TextFormField(
                          controller: _passingGradeController,
                          decoration: _gradeDecoration(),
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) {
                              return 'Required';
                            }
                            final numValue =
                                double.tryParse(text.replaceAll(',', '.'));
                            if (numValue == null) {
                              return 'Invalid number';
                            }
                            if (numValue < 0 || numValue > 100) {
                              return 'Must be 0‑100';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
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
            title: widget.quizId == null ? 'New Quiz' : 'Edit Quiz',
          ),
          const HomeNavBarAdapter(),
        ],
      ),
    );
  }
}

const String _infoQuizDetails =
    'Give this quiz a clear name and description so learners know what to expect.';
const String _infoPassingRequirement =
    'Enter the minimum percentage a learner must achieve to pass this quiz.';
