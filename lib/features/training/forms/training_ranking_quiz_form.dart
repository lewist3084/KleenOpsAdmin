// lib/features/training/forms/training_ranking_quiz_form.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kleenops_admin/features/engagement/forms/survey_form_scaffold.dart';
import 'package:shared_widgets/utils/process_localization_utils.dart';
import 'package:kleenops_admin/l10n/app_localizations.dart';
import 'package:kleenops_admin/services/ai_text_adapter.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';

class TrainingRankingQuizForm extends StatefulWidget {
  final String companyId;
  final String trainingId;
  final String quizId;
  final String? elementId;

  const TrainingRankingQuizForm({
    super.key,
    required this.companyId,
    required this.trainingId,
    required this.quizId,
    this.elementId,
  });

  @override
  State<TrainingRankingQuizForm> createState() => _TrainingRankingQuizFormState();
}

class _TrainingRankingQuizFormState extends State<TrainingRankingQuizForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _itemController = TextEditingController();
  final List<String> _items = [];
  final List<String> _correctOrder = [];
  late final Set<String> _supportedLocaleCodeSet;
  late String _localeCode;
  Map<String, dynamic>? _cachedData;
  final Map<String, String> _questionTranslations = {};
  final Map<String, String> _descriptionTranslations = {};
  final Map<String, List<String>> _itemTranslations = {};
  bool _isRequired = true;
  bool _loading = false;
  bool _initialLoaded = false;

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

  CollectionReference<Map<String, dynamic>> get _elementsRef {
    return _companyRef().collection('trainingQuizElement');
  }

  DocumentReference<Map<String, dynamic>> get _elementRef {
    final base = _elementsRef;
    if (widget.elementId != null && widget.elementId!.trim().isNotEmpty) {
      return base.doc(widget.elementId);
    }
    return base.doc();
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

  void _populateListTranslations(
    Map<String, List<String>> target,
    dynamic raw,
  ) {
    target.clear();
    if (raw is! Map) return;
    for (final entry in raw.entries) {
      final key = _normalizeLocaleCode(entry.key.toString());
      if (key.isEmpty) continue;
      final list = _normalizeList(entry.value);
      if (list.isNotEmpty) {
        target[key] = list;
      }
    }
  }

  void _syncListTranslations({
    required Map<String, List<String>> translations,
    required List<String> baseValues,
  }) {
    final normalizedLocale = _normalizeLocaleCode(_localeCode);
    if (normalizedLocale.isNotEmpty) {
      translations[normalizedLocale] = List<String>.from(baseValues);
    }
    for (final entry in translations.entries.toList()) {
      final values = entry.value;
      if (values.length == baseValues.length) continue;
      if (values.length > baseValues.length) {
        translations[entry.key] = values.sublist(0, baseValues.length);
      } else {
        final next = List<String>.from(values);
        while (next.length < baseValues.length) {
          next.add('');
        }
        translations[entry.key] = next;
      }
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
    if (!_initialLoaded && widget.elementId != null) {
      _initialLoaded = true;
      _loadExisting();
    }
  }

  Future<void> _loadExisting() async {
    setState(() => _loading = true);
    try {
      final snap = await _elementRef.get();
      final data = snap.data();
      if (data == null) return;
      _cachedData = data;
      _applyData(data);
      final correctIndexes = _normalizeIndexList(
        data['correctOrderIndexes'] ??
            data['correctOrderIndex'] ??
            data['correctItemsIndexes'],
      );
      if (correctIndexes.isNotEmpty) {
        _correctOrder
          ..clear()
          ..addAll(correctIndexes
              .where((index) => index >= 0 && index < _items.length)
              .map((index) => _items[index]));
      } else {
        final correct = _normalizeList(
          data['correctOrder'] ??
              data['correctItems'] ??
              data['answers'] ??
              data['answer'],
        );
        _correctOrder
          ..clear()
          ..addAll(correct.where(_items.contains));
      }
      _syncCorrectOrder();
      _isRequired = data['isRequired'] as bool? ?? true;
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _applyData(Map<String, dynamic>? data) {
    if (data == null) return;
    _populateTranslations(_questionTranslations, data['question']);
    _populateTranslations(_descriptionTranslations, data['description']);
    _populateListTranslations(_itemTranslations, data['itemsLocalized']);

    final question = ProcessLocalizationUtils.resolveLocalizedText(
      data['question'],
      localeCode: _localeCode,
      fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
    );
    final description = ProcessLocalizationUtils.resolveLocalizedText(
      data['description'],
      localeCode: _localeCode,
      fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
    );
    _questionController.text = question;
    _descriptionController.text = description;

    _items
      ..clear()
      ..addAll(() {
        final base = _normalizeList(data['items']);
        final localized = _itemTranslations[_normalizeLocaleCode(_localeCode)];
        if (localized != null && localized.length == base.length) {
          return localized;
        }
        return base;
      }());
    _syncListTranslations(
      translations: _itemTranslations,
      baseValues: _items,
    );
    final correctIndexes = _normalizeIndexList(
      data['correctOrderIndexes'] ??
          data['correctOrderIndex'] ??
          data['correctItemsIndexes'],
    );
    if (correctIndexes.isNotEmpty) {
      _correctOrder
        ..clear()
        ..addAll(correctIndexes
            .where((index) => index >= 0 && index < _items.length)
            .map((index) => _items[index]));
    } else {
      final correct = _normalizeList(
        data['correctOrder'] ??
            data['correctItems'] ??
            data['answers'] ??
            data['answer'],
      );
      _correctOrder
        ..clear()
        ..addAll(correct.where(_items.contains));
    }
    _syncCorrectOrder();
    if (mounted) {
      setState(() {});
    }
  }

  void _addItem() {
    final text = _itemController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _items.add(text);
      _syncListTranslations(
        translations: _itemTranslations,
        baseValues: _items,
      );
      if (!_correctOrder.contains(text)) {
        _correctOrder.add(text);
      }
      _itemController.clear();
    });
  }

  void _removeItem(String item) {
    setState(() {
      _items.remove(item);
      _correctOrder.remove(item);
      _syncListTranslations(
        translations: _itemTranslations,
        baseValues: _items,
      );
      _syncCorrectOrder();
    });
  }

  void _reorderCorrectOrder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _correctOrder.removeAt(oldIndex);
      _correctOrder.insert(newIndex, item);
    });
  }

  void _syncCorrectOrder() {
    _correctOrder.removeWhere((item) => !_items.contains(item));
    for (final item in _items) {
      if (!_correctOrder.contains(item)) {
        _correctOrder.add(item);
      }
    }
  }

  List<String> _normalizeList(dynamic raw) {
    if (raw is Iterable) {
      return raw
          .map((value) => value?.toString().trim() ?? '')
          .where((value) => value.isNotEmpty)
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

  Future<void> saveForm() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_items.isEmpty) {
      SnackbarService.instance.showSnackBar(
        const SnackBar(duration: Duration(seconds: 5), content: Text('Add at least one item.')),
      );
      return;
    }
    _syncCorrectOrder();
    if (_correctOrder.length != _items.length) {
      SnackbarService.instance.showSnackBar(
        const SnackBar(duration: Duration(seconds: 5), content: Text('Set the correct order.')),
      );
      return;
    }
    setState(() => _loading = true);
    final question = _questionController.text.trim();
    final description = _descriptionController.text.trim();
    final questionPayload = _buildLocalizedPayload(
      latestValue: question,
      existingTranslations: _questionTranslations,
    );
    final descriptionPayload = _buildLocalizedPayload(
      latestValue: description,
      existingTranslations: _descriptionTranslations,
    );
    final correctIndexes = _correctOrder
        .map((item) => _items.indexOf(item))
        .where((index) => index >= 0)
        .toList(growable: false);
    try {
      final data = <String, dynamic>{
        'question': questionPayload ?? question,
        if (descriptionPayload != null)
          'description': descriptionPayload
        else
          'description': description,
        'type': 'ranking',
        'items': _items,
        'isRequired': _isRequired,
        'trainingQuizId': _quizRef(),
        'correctOrder': _correctOrder,
        if (correctIndexes.isNotEmpty)
          'correctOrderIndexes': correctIndexes,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (widget.elementId == null || widget.elementId!.trim().isEmpty) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }
      await _elementRef.set(data, SetOptions(merge: true));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      SnackbarService.instance.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: Text('Failed to save ranking question: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    _descriptionController.dispose();
    _itemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.elementId == null ? 'New Ranking Question' : 'Edit Ranking Question';
    if (_loading && widget.elementId != null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return SurveyFormScaffold(
      title: title,
      formKey: _formKey,
      onSave: saveForm,
      onCancel: () => Navigator.of(context).pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AITextField(
            controller: _questionController,
            labelText: 'Question',
            minLines: 1,
            maxLines: 3,
            validator: (value) =>
                (value == null || value.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(labelText: 'Description'),
            minLines: 2,
            maxLines: 4,
            textInputAction: TextInputAction.newline,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Items', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _items
                .map(
                  (item) => InputChip(
                    label: Text(item),
                    onDeleted: () => _removeItem(item),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _itemController,
                  decoration: const InputDecoration(labelText: 'Add item'),
                  textInputAction: TextInputAction.done,
                  onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                  onFieldSubmitted: (_) => _addItem(),
                ),
              ),
              IconButton(
                onPressed: _addItem,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Correct Order', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_items.isEmpty)
            const Text('Add items to set the correct order.'),
          if (_items.isNotEmpty)
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _correctOrder.length,
              onReorder: _reorderCorrectOrder,
              itemBuilder: (context, index) {
                final item = _correctOrder[index];
                return ListTile(
                  key: ValueKey(item),
                  leading: Text('${index + 1}'),
                  title: Text(item),
                  trailing: ReorderableDragStartListener(
                    index: index,
                    child: const Icon(Icons.drag_handle),
                  ),
                );
              },
            ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Required'),
            value: _isRequired,
            onChanged: (value) => setState(() => _isRequired = value),
          ),
        ],
      ),
    );
  }
}
