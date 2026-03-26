// lib/features/objects/screens/objectProcessForm.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';
import 'package:kleenops_admin/common/field_info/field_info_registry.dart';
import 'package:kleenops_admin/services/ai_text_adapter.dart';
import 'package:kleenops_admin/widgets/tiles/image_text_tile_percent.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/dialogs/dialog_select.dart';
import 'package:shared_widgets/tiles/image_text_radio_button.dart';
import 'package:shared_widgets/search/search_field_action.dart';
import 'package:shared_widgets/fields/ai_text.dart' as shared;
import 'package:shared_widgets/lists/standardViewGroup.dart';
import 'package:kleenops_admin/features/processes/utils/process_localization_utils.dart';
import 'package:kleenops_admin/l10n/app_localizations.dart';
import 'package:kleenops_admin/common/utils/image_payload.dart';
import '../utils/company_object_file_images.dart';
import '../utils/object_element_file_images.dart';
import '../utils/object_process_file_images.dart';
import 'package:kleenops_admin/features/processes/utils/process_file_images.dart';

class ObjectProcessForm extends StatefulWidget {
  final DocumentReference companyId;
  final String objectId;
  final String? docId; // null → create
  final String initialImageUrl;

  const ObjectProcessForm({
    super.key,
    required this.companyId,
    required this.objectId,
    this.docId,
    this.initialImageUrl = '',
  });

  @override
  State<ObjectProcessForm> createState() => ObjectProcessFormState();
}

class ObjectProcessFormState extends State<ObjectProcessForm> {
  /* ─────────── form state ─────────── */
  final _formKey = GlobalKey<FormState>();
  final _nameC = TextEditingController();
  final _descC = TextEditingController();

  DocumentReference? _selectedProcess;
  DocumentReference? _selectedMeasureBy;
  List<Map<String, dynamic>> _processChoices = [];

  List<DocumentReference> _selectedResources = [];
  List<DocumentSnapshot<Map<String, dynamic>>> _resourceOptions = [];

  // Store selected element ids rather than DocumentReferences since the
  // object elements now live directly on the company object document.
  List<String> _selectedElements = [];
  final Map<String, int> _elementPercentages = {};

  late final DocumentReference<Map<String, dynamic>> _companyObjectRef;
  String? _imageUrl;

  String _measurementSystem = 'Standard';
  String _measureUnitLabel = '';

  bool _saving = false;
  Map<String, dynamic>? _existingItem;
  late final Set<String> _supportedLocaleCodeSet;
  bool _initialLoadStarted = false;
  late String _localeCode;
  Map<String, dynamic>? _cachedData;
  final Map<String, String> _nameTranslations = {};
  final Map<String, String> _descriptionTranslations = {};

  /* ─────────── lifecycle ─────────── */
  @override
  void initState() {
    super.initState();
    _supportedLocaleCodeSet = AppLocalizations.supportedLocales
        .map(_localeCodeOf)
        .where((code) => code.isNotEmpty)
        .toSet()
      ..add(_normalizeLocaleCode(ProcessLocalizationUtils.defaultLocaleCode));
    _localeCode = ProcessLocalizationUtils.defaultLocaleCode;
    _companyObjectRef =
        widget.companyId.collection('companyObject').doc(widget.objectId);
    _imageUrl = widget.initialImageUrl;
    _loadMeasurementSystem();
    _loadProcessOptions();
    _loadResourceOptions();
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
    if (!_initialLoadStarted) {
      _initialLoadStarted = true;
      _loadExisting();
    }
  }

  @override
  void dispose() {
    _nameC.dispose();
    _descC.dispose();
    super.dispose();
  }

  /* ─────────── Firestore helpers ─────────── */
  Future<void> _loadProcessOptions() async {
    final snap = await widget.companyId.collection('process').get();
    final choices = await Future.wait(snap.docs.map((d) async {
      final data = d.data();
      final rawName = data['name'];
      final englishName = ProcessLocalizationUtils.resolveLocalizedText(
        rawName,
        localeCode: ProcessLocalizationUtils.defaultLocaleCode,
      );
      final fileUrl = await ProcessFileImages.primaryHeaderImageUrl(
        companyRef: widget.companyId
            .withConverter<Map<String, dynamic>>(
          fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
          toFirestore: (data, _) => data,
        ),
        processRef: d.reference,
      );
      return {
        'ref': d.reference,
        'rawName': rawName,
        'sortName': englishName.isNotEmpty ? englishName : 'Unnamed',
        'imageUrl': fileUrl,
      };
    }).toList());
    _processChoices = choices
      ..sort(
        (a, b) => (a['sortName'] as String? ?? '')
            .toLowerCase()
            .compareTo((b['sortName'] as String? ?? '').toLowerCase()),
      );
    setState(() {});
  }

  Future<void> _loadResourceOptions() async {
    final collection = widget.companyId.collection('resource');
    QuerySnapshot<Map<String, dynamic>>? byObjectSnap;
    if (_companyObjectRef != null) {
      byObjectSnap = await collection
          .where('objectsArray', arrayContains: _companyObjectRef)
          .get();
    }

    List<QueryDocumentSnapshot<Map<String, dynamic>>> byProcess = [];
    if (_selectedProcess != null) {
      final snap = await collection
          .where('processes', arrayContains: _selectedProcess)
          .get();
      byProcess = snap.docs.where((doc) {
        final objs = (doc.data()['objectsArray'] as List<dynamic>? ?? [])
            .whereType<DocumentReference>();
        return objs.isEmpty;
      }).toList();
    }

    final map = <String, DocumentSnapshot<Map<String, dynamic>>>{};
    final combined = [
      ...?byObjectSnap?.docs,
      ...byProcess,
    ];
    for (final d in combined) {
      map[d.id] = d;
    }
    setState(() => _resourceOptions = map.values.toList());
  }

  Future<void> _loadMeasurementSystem() async {
    final snap = await widget.companyId.get();
    if (snap.exists) {
      final data = snap.data() as Map<String, dynamic>?;
      final sys = data?['measurementSystem'] ?? 'Standard';
      setState(() => _measurementSystem = sys);
    }
  }

  Future<void> _loadMeasureUnit() async {
    if (_selectedMeasureBy == null) return;
    final s = await _selectedMeasureBy!.get();
    if (s.exists) {
      final data = s.data() as Map<String, dynamic>;
      final unit = _measurementSystem == 'Standard'
          ? (data['standardUnit'] ?? '')
          : (data['metricUnit'] ?? '');
      setState(() => _measureUnitLabel = unit);
    }
  }

  Future<void> _loadExisting() async {
    if (widget.docId == null || widget.docId!.trim().isEmpty) return;

    final snap = await widget.companyId
        .collection('objectProcess')
        .doc(widget.docId)
        .get();
    if (!snap.exists) return;
    final d = snap.data() ?? <String, dynamic>{};
    if (d.isEmpty) return;

    _existingItem = Map<String, dynamic>.from(d);
    _cachedData = _existingItem;
    _applyData(_cachedData);
    _selectedProcess = d['processId'] as DocumentReference?;
    final fileImages = await ObjectProcessFileImages.headerImageEntries(
      companyRef: widget.companyId.withConverter<Map<String, dynamic>>(
        fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
        toFirestore: (data, _) => data,
      ),
      processRef:
          widget.companyId.collection('objectProcess').doc(widget.docId),
    );
    if (fileImages.isNotEmpty) {
      final url = fileImages.first['url'];
      if (url is String && url.trim().isNotEmpty) {
        _imageUrl = url.trim();
      }
    }
    _selectedMeasureBy = d['measureById'] as DocumentReference?;

    _selectedResources = [];
    final rawResources = d['processResources'] as List<dynamic>? ?? [];
    for (final r in rawResources) {
      if (r is DocumentReference) {
        _selectedResources.add(r);
      } else if (r is String && r.isNotEmpty) {
        _selectedResources.add(FirebaseFirestore.instance.doc(r));
      }
    }

    _selectedElements = [];
    _elementPercentages.clear();
    final rawElements = d['processElements'] as List<dynamic>? ?? [];
    for (final item in rawElements) {
      if (item is Map<String, dynamic>) {
        final id = item['elementId'] as String?;
        if (id != null) {
          _selectedElements.add(id);
          final pct = ((item['percent'] as num?) ?? 1) * 100;
          _elementPercentages[id] = pct.round();
        }
      } else if (item is String) {
        _selectedElements.add(item);
      }
    }

    _selectedMeasureBy = d['measureById'] as DocumentReference?;
    await _loadMeasureUnit();

    await _loadResourceOptions();
    setState(() {});
  }

  /* ─────────── SAVE ─────────── */
  void _applyData(Map<String, dynamic>? data) {
    if (data == null) return;
    _populateTranslations(_nameTranslations, data['objectProcessName']);
    _populateTranslations(
      _descriptionTranslations,
      data['objectProcessDescription'],
    );
    final name = ProcessLocalizationUtils.resolveLocalizedText(
      data['objectProcessName'] ?? data['name'] ?? data['processName'],
      localeCode: _localeCode,
      fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
    );
    final description = ProcessLocalizationUtils.resolveLocalizedText(
      data['objectProcessDescription'] ?? data['description'],
      localeCode: _localeCode,
      fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
    );
    _nameC.text = name;
    _descC.text = description;
    if (mounted) {
      setState(() {});
    }
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return; // CHANGED
    _formKey.currentState!.save();

    setState(() => _saving = true);

    try {
      final docId = (widget.docId?.trim().isNotEmpty ?? false)
          ? widget.docId!.trim()
          : widget.companyId.collection('objectProcess').doc().id;

      // Build the processElements list containing the selected element id,
      // the chosen percentage and the computed quantities based on that
      // percentage. Elements are stored directly on the company object
      // document, so pull the latest data to perform the calculations.
      final objSnap = await _companyObjectRef.get();
      final objData = objSnap.data() ?? <String, dynamic>{};
      final elementsRaw = (objData['elements'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>();
      final elementMap = {
        for (final m in elementsRaw)
          if (m['id'] is String) m['id'] as String: m
      };
      final bool floorCovering = objData['floorCovering'] == true;
      final bool wallCovering = objData['wallCovering'] == true;
      final bool ceilingCovering = objData['ceilingCovering'] == true;
      final bool hasCoverings =
          floorCovering || wallCovering || ceilingCovering;

      final objectElementEntries = <Map<String, dynamic>>[];
      for (final id in _selectedElements) {
        final base = elementMap[id];
        if (base == null) continue;
        final pct = (_elementPercentages[id] ?? 100) / 100.0;
        final baseStdQty = (base['standardQuantity'] as num?)?.toDouble();
        final baseMetQty = (base['metricQuantity'] as num?)?.toDouble();
        double stdQty = (baseStdQty ?? 0) * pct;
        double metQty = (baseMetQty ?? 0) * pct;
        if (hasCoverings && baseStdQty == null && baseMetQty == null) {
          stdQty = pct;
          metQty = pct;
        }
        objectElementEntries.add({
          'elementId': id,
          'percent': pct,
          'standardQuantity': stdQty,
          'metricQuantity': metQty,
          // Copy over additional metadata from the element so the process
          // stores all necessary details without needing further lookups.
          'elementMaterialId': base['elementMaterialId'],
          'name': base['name'],
          'scalarId': base['scalarId'],
        });
      }

      // Pull all fields from the selected process document so the
      // object process entry contains a full snapshot of that data.
      final baseProcessData = <String, dynamic>{};
      if (_selectedProcess != null) {
        final snap = await _selectedProcess!.get();
        if (snap.exists) {
          final procData = snap.data() as Map<String, dynamic>;
          baseProcessData.addAll(procData);
          if (procData['name'] != null) {
            baseProcessData['processName'] = procData['name'];
          }
          if (procData['description'] != null) {
            baseProcessData['processDescription'] = procData['description'];
          }
          baseProcessData.remove('name');
          baseProcessData.remove('description');
          baseProcessData.remove('images');
          baseProcessData.remove('imageUrl');
          baseProcessData.remove('mainProcessImageUrl');
        }
      }

      // ── 3.  ⚙️  compute objectProcessTime  ⚙️  ──────────────────
      // (a) total standard qty of the elements just created
      final totalStdQty = objectElementEntries.fold<double>(
        0,
        (sum, e) => sum + ((e['standardQuantity'] as num?) ?? 0).toDouble(),
      );
      final totalMetQty = objectElementEntries.fold<double>(
        0,
        (sum, e) => sum + ((e['metricQuantity'] as num?) ?? 0).toDouble(),
      );

      // (b) scalarQuantity of the “measured by” scalar (defaults to 1)
      DocumentReference? measureByRef = _selectedMeasureBy ??
          (baseProcessData['measureById'] as DocumentReference?);

      double scalarQty = 1.0;
      if (measureByRef != null) {
        final sSnap = await measureByRef.get();
        if (sSnap.exists) {
          final sData = sSnap.data() as Map<String, dynamic>?; // ðŸ‘ˆ cast once
          scalarQty = ((sData?['scalarQuantity'] as num?) ?? 1).toDouble();
        }
      }

      // (c) base processTime (minutes per scalarQuantity)
      final baseProcTime =
          ((baseProcessData['processTime'] as num?) ?? 0).toDouble();

      // (d) final time for THIS object
      double objectProcessTime =
          scalarQty > 0 ? baseProcTime * (totalStdQty / scalarQty) : 0;

      // ── NEW: scale labor cost based on objectProcessTime ────────────────
      final baseStandardLabor =
          (baseProcessData['standardLaborCost'] as num?)?.toDouble() ??
              (baseProcessData['laborCost'] as num?)?.toDouble() ??
              0.0;
      final baseMetricLabor =
          (baseProcessData['metricLaborCost'] as num?)?.toDouble() ??
              baseStandardLabor;
      final laborScale = baseProcTime > 0
          ? (objectProcessTime / baseProcTime)
          : 0.0;
      final double objectStandardLaborCost = baseStandardLabor * laborScale;
      final double objectMetricLaborCost = baseMetricLabor * laborScale;
      final double objectLaborCost = _measurementSystem == 'Metric'
          ? (objectMetricLaborCost != 0
              ? objectMetricLaborCost
              : objectStandardLaborCost)
          : (objectStandardLaborCost != 0
              ? objectStandardLaborCost
              : objectMetricLaborCost);

      // ── NEW: derive object-level material quantities and costs ────────────
      final double qtyFactor = scalarQty > 0 ? totalStdQty / scalarQty : 0;
      final List<Map<String, dynamic>> newMaterialStats = [];
      final processRef = _selectedProcess;
      if (processRef != null) {
        final materialSnap = await widget.companyId
            .collection('processMaterial')
            .where('processId', isEqualTo: processRef)
            .get();
        final materialRows = materialSnap.docs
            .map((doc) => Map<String, dynamic>.from(doc.data()))
            .toList();
        for (final row in materialRows) {
          final stdQty = (row['standardQuantity'] as num?)?.toDouble() ?? 0;
          final metQty = (row['metricQuantity'] as num?)?.toDouble() ?? 0;
          final stdCost =
              (row['standardMaterialCost'] as num?)?.toDouble() ?? 0;
          final metCost =
              (row['metricMaterialCost'] as num?)?.toDouble() ?? 0;

          newMaterialStats.add({
            ...row,
            'objectStandardQuantity': stdQty * qtyFactor,
            'objectMetricQuantity': metQty * qtyFactor,
            'objectStandardMaterialCost': stdCost * qtyFactor,
            'objectMetricMaterialCost': metCost * qtyFactor,
          });
        }
      }

      // Recalculate tool usage for this object
      final List<Map<String, dynamic>> newToolStats = [];
      if (processRef != null) {
        final toolSnap = await widget.companyId
            .collection('processTool')
            .where('processId', isEqualTo: processRef)
            .get();
        final toolRows = toolSnap.docs
            .map((doc) => Map<String, dynamic>.from(doc.data()))
            .toList();
        for (final row in toolRows) {
          row.remove('toolUsageTime');
          row.remove('toolUsageCost');
          row.remove('toolProcessUsagePercent');

          final pct =
              (row['toolUsagePercent'] as num?)?.toDouble() ?? 0; // 0-1
          double baseStdTime =
              (row['standardToolTime'] as num?)?.toDouble() ?? 0.0;
          double baseMetTime =
              (row['metricToolTime'] as num?)?.toDouble() ?? 0.0;
          final baseStdCost =
              (row['standardToolCost'] as num?)?.toDouble() ?? 0.0;
          final baseMetCost =
              (row['metricToolCost'] as num?)?.toDouble() ?? 0.0;

          if (baseStdTime == 0 && baseProcTime > 0 && pct > 0) {
            baseStdTime = baseProcTime * pct;
          }
          if (baseMetTime == 0) {
            baseMetTime = baseStdTime;
          }

          final objectStandardToolTime = baseStdTime * qtyFactor;
          double objectMetricToolTime;
          if (baseStdTime > 0 && baseMetTime > 0) {
            final ratio = baseMetTime / baseStdTime;
            objectMetricToolTime = objectStandardToolTime * ratio;
          } else if (baseMetTime > 0) {
            objectMetricToolTime = baseMetTime * qtyFactor;
          } else {
            objectMetricToolTime = objectStandardToolTime;
          }

          final costPerStandardMinute =
              baseStdTime > 0 ? baseStdCost / baseStdTime : 0.0;
          double costPerMetricMinute = 0.0;
          if (baseMetTime > 0 && baseMetCost > 0) {
            costPerMetricMinute = baseMetCost / baseMetTime;
          } else {
            costPerMetricMinute = costPerStandardMinute;
          }

          final objectStandardToolCost =
              costPerStandardMinute * objectStandardToolTime;
          final objectMetricToolCost =
              costPerMetricMinute * objectMetricToolTime;

          newToolStats.add({
            ...row,
            'objectToolUsagePercent': pct,
            'objectStandardToolTime': objectStandardToolTime,
            'objectMetricToolTime': objectMetricToolTime,
            'objectStandardToolCost': objectStandardToolCost,
            'objectMetricToolCost': objectMetricToolCost,
            // legacy fields retained for compatibility
            'objectToolUsageTime': objectStandardToolTime,
            'objectToolUsageCost': objectStandardToolCost,
          });
        }
      }
      // ── Aggregate costs for display text ──────────────────────────────
      final double objectStandardMaterialCost = newMaterialStats.fold<double>(
        0,
        (sum, m) =>
            sum + ((m['objectStandardMaterialCost'] as num?)?.toDouble() ?? 0),
      );
      final double objectMetricMaterialCost = newMaterialStats.fold<double>(
        0,
        (sum, m) =>
            sum + ((m['objectMetricMaterialCost'] as num?)?.toDouble() ?? 0),
      );
      final double objectMaterialCost = _measurementSystem == 'Metric'
          ? (objectMetricMaterialCost != 0
              ? objectMetricMaterialCost
              : objectStandardMaterialCost)
          : (objectStandardMaterialCost != 0
              ? objectStandardMaterialCost
              : objectMetricMaterialCost);

      final double objectStandardToolCost = newToolStats.fold<double>(
        0,
        (sum, m) =>
            sum + ((m['objectStandardToolCost'] as num?)?.toDouble() ?? 0),
      );
      final double objectMetricToolCost = newToolStats.fold<double>(
        0,
        (sum, m) =>
            sum + ((m['objectMetricToolCost'] as num?)?.toDouble() ?? 0),
      );
      final double objectStandardToolMinutes = newToolStats.fold<double>(
        0,
        (sum, m) =>
            sum + ((m['objectStandardToolTime'] as num?)?.toDouble() ?? 0),
      );
      final double objectMetricToolMinutes = newToolStats.fold<double>(
        0,
        (sum, m) =>
            sum + ((m['objectMetricToolTime'] as num?)?.toDouble() ?? 0),
      );

      final double objectToolCost = _measurementSystem == 'Metric'
          ? (objectMetricToolCost != 0
              ? objectMetricToolCost
              : objectStandardToolCost)
          : (objectStandardToolCost != 0
              ? objectStandardToolCost
              : objectMetricToolCost);
      final double objectStandardProcessCost =
          objectStandardLaborCost + objectStandardMaterialCost + objectStandardToolCost;
      final double objectMetricProcessCost =
          objectMetricLaborCost + objectMetricMaterialCost + objectMetricToolCost;
      final double objectProcessCost =
          objectLaborCost + objectMaterialCost + objectToolCost;

      final String objectProcessCostText =
          '${objectProcessCost.toStringAsFixed(3)} '
          '(${objectProcessTime.toStringAsFixed(0)} min)/$_measureUnitLabel';

      final companyRef =
          widget.companyId.withConverter<Map<String, dynamic>>(
        fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
        toFirestore: (data, _) => data,
      );
      final mainObjectImageUrl =
          await CompanyObjectFileImages.primaryHeaderImageUrl(
        companyRef: companyRef,
        objectId: _companyObjectRef.id,
      );

      final nameValue = _nameC.text.trim();
      final descriptionValue = _descC.text.trim();
      final namePayload = _buildLocalizedPayload(
        latestValue: nameValue,
        existingTranslations: _nameTranslations,
      );
      final descriptionPayload = _buildLocalizedPayload(
        latestValue: descriptionValue,
        existingTranslations: _descriptionTranslations,
      );

      final data = <String, Object?>{
        ...baseProcessData,
        'materialUsage': newMaterialStats,
        'toolUsage': newToolStats, // updated list
        'name': nameValue,
        'objectProcessName': namePayload ?? nameValue,
        'processElements': objectElementEntries,
        'processResources': _selectedResources,
        'objectStandardProcessQuantity': totalStdQty,
        'objectMetricProcessQuantity': totalMetQty,
        'objectProcessTime': objectProcessTime,
        'objectStandardLaborCost': objectStandardLaborCost,
        'objectMetricLaborCost': objectMetricLaborCost,
        'objectLaborCost': objectLaborCost,
        'objectStandardMaterialCost': objectStandardMaterialCost,
        'objectMetricMaterialCost': objectMetricMaterialCost,
        'objectMaterialCost': objectMaterialCost,
        'objectStandardToolCost': objectStandardToolCost,
        'objectMetricToolCost': objectMetricToolCost,
        'objectStandardToolMinutes': objectStandardToolMinutes,
        'objectMetricToolMinutes': objectMetricToolMinutes,
        'objectToolCost': objectToolCost,
        'objectStandardProcessCost': objectStandardProcessCost,
        'objectMetricProcessCost': objectMetricProcessCost,
        'objectProcessCost': objectProcessCost,
        'objectProcessCostText': objectProcessCostText,
        'mainObjectImageUrl': mainObjectImageUrl,
        'processId': _selectedProcess,
        'active': true,
        'updatedAt': Timestamp.now(),
      };
      if (descriptionPayload != null) {
        data['objectProcessDescription'] = descriptionPayload;
      } else if (descriptionValue.isNotEmpty) {
        data['objectProcessDescription'] = descriptionValue;
      }
      final existingLocalizationMeta =
          _existingItem?['objectProcessLocalizationMeta'];
      if (existingLocalizationMeta != null) {
        data['objectProcessLocalizationMeta'] = existingLocalizationMeta;
      }

      final now = Timestamp.now();
      final processPayload = <String, dynamic>{
        'id': docId,
        ...data,
        'companyObjectId': _companyObjectRef,
        'companyObjectDocId': _companyObjectRef.id,
        'companyId': widget.companyId.id,
        'updatedAt': now,
      };
      final existingCreatedRaw = _existingItem?['createdAt'];
      Timestamp? existingCreatedAt;
      if (existingCreatedRaw is Timestamp) {
        existingCreatedAt = existingCreatedRaw;
      }
      processPayload['createdAt'] = existingCreatedAt ?? now;

      final processDocPayload = <String, dynamic>{
        ...processPayload,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': existingCreatedAt == null
            ? FieldValue.serverTimestamp()
            : existingCreatedAt,
      };

      final processDocRef =
          widget.companyId.collection('objectProcess').doc(docId);

      final batch = FirebaseFirestore.instance.batch();
      batch.set(processDocRef, processDocPayload);
      await batch.commit();

      await ObjectProcessFileImages.syncHeaderImages(
        companyRef: widget.companyId.withConverter<Map<String, dynamic>>(
          fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
          toFirestore: (data, _) => data,
        ),
        processRef: processDocRef,
        images: buildSingleImageGallery(_imageUrl),
        processName: nameValue,
        companyObjectRef: _companyObjectRef,
      );

      // … your resource logic here …

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      final loc = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.objectsProcessFailedToSave(e.toString())),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _saving = false);
    }
  }

  /* ───────────────────────────── UI helpers ────────────────────────── */
  Future<void> _handleProcessSelection(DocumentReference? value) async {
    setState(() => _selectedProcess = value);

    if (value == null) return;

    final snapshot = await value.get();
    if (!mounted) return;

    final processData = snapshot.data() as Map<String, dynamic>? ?? {};
    final localeCode = Localizations.localeOf(context).languageCode;
    _nameC.text = ProcessLocalizationUtils.resolveLocalizedText(
      processData['name'],
      localeCode: localeCode,
    );
    _descC.text = ProcessLocalizationUtils.resolveLocalizedText(
      processData['description'],
      localeCode: localeCode,
    );

    final selectedMeasure = processData['measureById'] as DocumentReference?;
    final fileUrl = await ProcessFileImages.primaryHeaderImageUrl(
      companyRef: widget.companyId.withConverter<Map<String, dynamic>>(
        fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
        toFirestore: (data, _) => data,
      ),
      processRef: value,
    );
    final primaryImage = fileUrl;

    setState(() {
      _selectedMeasureBy = selectedMeasure;
      if (primaryImage.isNotEmpty) {
        _imageUrl = primaryImage;
      }
    });

    await _loadResourceOptions();
    await _loadMeasureUnit();
  }

  Future<void> _openProcessDialog() async {
    final loc = AppLocalizations.of(context)!;
    FocusScope.of(context).unfocus();

    final searchCtrl = TextEditingController();
    String query = '';
    DocumentReference? tempSelection = _selectedProcess;

    DocumentReference? resolveSelection(DocumentReference? ref) {
      if (ref == null) return null;
      for (final choice in _processChoices) {
        final choiceRef = choice['ref'] as DocumentReference?;
        if (choiceRef != null && choiceRef.path == ref.path) {
          return choiceRef;
        }
      }
      return ref;
    }

    final selected = await showDialog<DocumentReference?>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final normalizedSelection = resolveSelection(tempSelection);
          final localeCode = Localizations.localeOf(context).languageCode;
          final loweredQuery = query.toLowerCase();
          final filtered = _processChoices.where((choice) {
            final localizedName =
                ProcessLocalizationUtils.resolveLocalizedText(
              choice['rawName'],
              localeCode: localeCode,
            ).toLowerCase();
            return localizedName.contains(loweredQuery);
          }).toList();

          return DialogAction(
            title: loc.objectsProcessSelectProcessTitle,
            wrapContentInScrollView: false,
            content: SizedBox(
              width: double.infinity,
              height: 420,
              child: Column(
                children: [
                  SearchFieldAction(
                    controller: searchCtrl,
                    labelText: loc.commonSearch,
                    onChanged: (value) => setDialogState(() => query = value),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(child: Text(loc.objectsProcessNoProcessesFound))
                        : StandardViewGroup.buildViewFromItems<
                            Map<String, dynamic>>(
                            items: filtered,
                            groupBy: (_) => '',
                            disableGrouping: true,
                            shrinkWrap: true,
                            physics: const ClampingScrollPhysics(),
                            padding: EdgeInsets.zero,
                            itemBuilder: (choice) {
                              final ref =
                                  choice['ref'] as DocumentReference?;
                              if (ref == null) {
                                return const SizedBox.shrink();
                              }

                              final localizedName =
                                  ProcessLocalizationUtils.resolveLocalizedText(
                                        choice['rawName'],
                                        localeCode: localeCode,
                                      )
                                      .trim();
                              final name = localizedName.isNotEmpty
                                  ? localizedName
                                  : ((choice['sortName'] as String?) ??
                                      loc.commonUnnamed);
                              final imageUrl =
                                  (choice['imageUrl'] as String? ?? '').trim();

                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: ImageTextRadioButton<DocumentReference>(
                                  value: ref,
                                  groupValue: normalizedSelection,
                                  onChanged: (value) => setDialogState(
                                      () => tempSelection = value),
                                  label:
                                      name.isEmpty ? loc.commonUnnamed : name,
                                  imageUrl:
                                      imageUrl.isEmpty ? null : imageUrl,
                                    contentPadding: EdgeInsets.zero,
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            cancelText: loc.commonCancel,
            onCancel: () => Navigator.of(dialogCtx).pop(),
            actionText: loc.commonSelect,
            onAction: () =>
                Navigator.of(dialogCtx).pop(resolveSelection(tempSelection)),
          );
        },
      ),
    );

    searchCtrl.dispose();

    if (selected != null && mounted) {
      await _handleProcessSelection(selected);
    }
  }

  Widget _processDropdown() {
    final selectedRef = _selectedProcess;
    final loc = AppLocalizations.of(context)!;
    String displayText = loc.searchFieldActionTapToChoose;
    final localeCode = Localizations.localeOf(context).languageCode;

    if (selectedRef != null) {
      final match = _processChoices.firstWhere(
        (choice) {
          final choiceRef = choice['ref'] as DocumentReference?;
          return choiceRef != null && choiceRef.path == selectedRef.path;
        },
        orElse: () => const <String, dynamic>{},
      );
      final rawName = match['rawName'];
      final localizedName = ProcessLocalizationUtils.resolveLocalizedText(
        rawName,
        localeCode: localeCode,
      ).trim();
      if (localizedName.isNotEmpty) {
        displayText = localizedName;
      } else {
        final fallback = match['sortName'] as String?;
        if (fallback != null && fallback.trim().isNotEmpty) {
          displayText = fallback.trim();
        }
      }
    }

    return GestureDetector(
      onTap: _openProcessDialog,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: loc.objectsProcessLabel,
          border: OutlineInputBorder(),
        ),
        child: Text(displayText),
      ),
    );
  }

  Widget _multiSelectResources() {
    final loc = AppLocalizations.of(context)!;
    if (_resourceOptions.isEmpty) {
      return Text(loc.objectsProcessNoMatchingResources);
    }
    final localeCode = Localizations.localeOf(context).languageCode;
    return Column(
      children: _resourceOptions.map((doc) {
        final d = doc.data() ?? {};
        final ref = doc.reference;
        final resolvedName = ProcessLocalizationUtils.resolveLocalizedText(
          d['name'],
          localeCode: localeCode,
          fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
        ).trim();
        final name = resolvedName.isNotEmpty ? resolvedName : loc.commonUnnamed;
        final sel = _selectedResources.contains(ref);
        return CheckboxListTile(
          value: sel,
          title: Text(name),
          onChanged: (c) => setState(() {
            if (c == true) {
              _selectedResources.add(ref);
            } else {
              _selectedResources.removeWhere((r) => r.path == ref.path);
            }
          }),
        );
      }).toList(),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchElements() async {
    if (_selectedMeasureBy == null) return [];

    final snap = await _companyObjectRef.get();
    if (!snap.exists) return [];

    final data = snap.data() ?? {};
    final rawList = data['elements'] as List<dynamic>? ?? [];

    final out = <Map<String, dynamic>>[];

    for (final item in rawList) {
      if (item is! Map<String, dynamic>) continue;

      final mId = item['scalarId'];
      final match =
          (mId is DocumentReference && _selectedMeasureBy is DocumentReference)
              ? mId.path == _selectedMeasureBy!.path
              : mId == _selectedMeasureBy!.path;

      if (!match) continue;

      final id = item['id'];
      if (id is! String || id.isEmpty) continue;

      out.add({'id': id, 'data': item});
    }

    final localeCode = Localizations.localeOf(context).languageCode;
    out.sort((a, b) {
      final an = ProcessLocalizationUtils.resolveLocalizedText(
        a['data']['name'],
        localeCode: localeCode,
        fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
      ).toLowerCase();
      final bn = ProcessLocalizationUtils.resolveLocalizedText(
        b['data']['name'],
        localeCode: localeCode,
        fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
      ).toLowerCase();
      return an.compareTo(bn);
    });

    return out;
  }

  Widget _multiSelectElements() {
    final loc = AppLocalizations.of(context)!;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchElements(),
      builder: (_, s) {
        if (s.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = s.data ?? [];
        if (docs.isEmpty) return Text(loc.objectsProcessNoMatchingElements);
        final localeCode = Localizations.localeOf(context).languageCode;
        return Column(
          children: docs.map((e) {
            final d = e['data'] as Map<String, dynamic>? ?? {};
            final id = e['id'] as String;
            final resolvedName =
                ProcessLocalizationUtils.resolveLocalizedText(
              d['name'],
              localeCode: localeCode,
              fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
            );
            final name =
                resolvedName.isNotEmpty ? resolvedName : loc.commonUnnamed;
            final sel = _selectedElements.contains(id);
            final percentVal = ((d['percentObject'] as num?) ?? 1) * 100;
            _elementPercentages.putIfAbsent(id, () => percentVal.round());

            final baseQty = _measurementSystem == 'Standard'
                ? (d['standardQuantity'] as num? ?? 0).toDouble()
                : (d['metricQuantity'] as num? ?? 0).toDouble();
            final pct = (_elementPercentages[id] ?? 0) / 100.0;
            final finalQty = baseQty * pct;
            final qtyStr = finalQty.toStringAsFixed(2);
            final subTitle = '$qtyStr $_measureUnitLabel';

            return FutureBuilder<String>(
              future: ObjectElementFileImages.primaryHeaderImageUrl(
                companyRef: widget.companyId.withConverter<Map<String, dynamic>>(
                  fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
                  toFirestore: (data, _) => data,
                ),
                elementRef: widget.companyId
                    .collection('objectElement')
                    .doc(id),
              ),
              builder: (context, imageSnap) {
                final fileUrl = imageSnap.data?.trim() ?? '';
                return ImageTextTilePercent(
                  imageUrl: fileUrl,
                  title: name,
                  subTitle: subTitle,
                  initialPercentage: _elementPercentages[id]!,
                  checkboxValue: sel,
                  onCheckboxChanged: (c) => setState(() {
                    if (c == true) {
                      _selectedElements.add(id);
                    } else {
                      _selectedElements.removeWhere((r) => r == id);
                    }
                  }),
                  onPercentageChanged: (v) =>
                      setState(() => _elementPercentages[id] = v),
                );
              },
            );
          }).toList(),
        );
      },
    );
  }

  /* ─────────── build ─────────── */
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    if (_saving) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final saveStyle = ElevatedButton.styleFrom(
      backgroundColor: Theme.of(context).primaryColor,
      foregroundColor: Colors.white,
    );

    return Scaffold(
      appBar: null,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ContainerActionWidget(
                  title: loc.commonDetails,
                  titleInfoKey: FieldInfoKeys.objectsProcesses,
                  actionText: '',
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _processDropdown(),
                      const SizedBox(height: 16),
                      AITextField(
                        controller: _nameC,
                        labelText: loc.objectsProcessStatementLabel,
                        minLines: 1,
                        maxLines: 1,
                        height: shared.StreamingSpeechFieldHeight.singleLine,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? loc.objectsProcessEnterStatement
                            : null,
                      ),
                      const SizedBox(height: 16),
                      AITextField(
                        controller: _descC,
                        labelText: loc.objectsProcessInstructionsLabel,
                        minLines: 3,
                        maxLines: 3,
                        height: shared.StreamingSpeechFieldHeight.expanded,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? loc.objectsProcessEnterInstructions
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ContainerActionWidget(
                  title: loc.objectsProcessAddFileTitle,
                  titleInfoKey: FieldInfoKeys.objectsResources,
                  actionText: '',
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _multiSelectResources(),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: saveStyle,
                          child: Text(loc.commonSave),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ContainerActionWidget(
                  title: loc.objectsProcessSelectObjectElementsTitle,
                  actionText: '',
                  content: _multiSelectElements(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: CancelSaveBar(
        onCancel: () => Navigator.of(context).pop(),
        onSave: _save,
      ),
    );
  }
}



