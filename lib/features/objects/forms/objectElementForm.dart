// lib/features/objects/screens/objectElementForm.dart
// rev-2025-07-14 – fixes incorrect unit conversion by using per-unit
// conversion factors stored in the scalar/{id}/scalarUnit/{unitId}
// subcollection.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:shared_widgets/markup/image_markup.dart';
import 'package:shared_widgets/fields/markup_image_field.dart';
import 'package:shared_widgets/dialogs/dialog_select.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/common/utils/image_payload.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:kleenops_admin/common/field_info/field_info_registry.dart';
import 'package:kleenops_admin/features/processes/utils/process_localization_utils.dart';
import 'package:kleenops_admin/features/objects/utils/object_element_file_images.dart';
import 'package:kleenops_admin/features/objects/utils/company_object_file_images.dart';
import 'package:kleenops_admin/l10n/app_localizations.dart';

class ObjectElementForm extends ConsumerStatefulWidget {
  const ObjectElementForm({super.key, this.extraData});
  final Map<String, dynamic>? extraData;

  @override
  ConsumerState<ObjectElementForm> createState() => ObjectElementFormState();
}

class ObjectElementFormState extends ConsumerState<ObjectElementForm> {
  /* ── form fields ────────────────────────────────────────── */
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _imageUrl;
  DocumentReference<Map<String, dynamic>>? _selectedElementMaterialId;
  DocumentReference<Map<String, dynamic>>? _selectedScalarId;
  double? _scalarUnitQuantity;
  double? _percentObject;
  double? _lengthFeet;
  double? _widthFeet;
  double? _heightFeet;
  bool _coveringMode = false;
  List<dynamic> _companyImages = <dynamic>[];
  List<Map<String, dynamic>> _elementImages = <Map<String, dynamic>>[];

  /* ── edit state ─────────────────────────────────────────── */
  Map<String, dynamic>? _existingItem;
  String? _existingDocId;

  /* ── choices & flags ────────────────────────────────────── */
  List<Map<String, dynamic>> _elementMaterialChoices = [];
  bool _loadingMaterials = false;

  List<Map<String, dynamic>> _scalarChoices = [];
  bool _loadingScalars = false;

  String _measurementSystem = 'Standard';
  bool _saving = false;
  late final Set<String> _supportedLocaleCodeSet;
  bool _initialLoadStarted = false;
  late String _localeCode;
  Map<String, dynamic>? _cachedData;
  final Map<String, String> _nameTranslations = {};

  /* ── INIT ───────────────────────────────────────────────── */
  @override
  void initState() {
    super.initState();

    _supportedLocaleCodeSet = AppLocalizations.supportedLocales
        .map(_localeCodeOf)
        .where((code) => code.isNotEmpty)
        .toSet()
      ..add(_normalizeLocaleCode(ProcessLocalizationUtils.defaultLocaleCode));
    _localeCode = ProcessLocalizationUtils.defaultLocaleCode;

    _existingItem = widget.extraData?['existingItem'] as Map<String, dynamic>?;
    if (_existingItem != null) {
      _existingDocId = _existingItem!['id'] as String?;
      _cachedData = _existingItem;
      _applyData(_cachedData);
      // When pulling refs from the object's elements array, the generic type
      // information may be lost (DocumentReference<Map<String, dynamic>>
      // becomes just DocumentReference). Re-apply the converter so the
      // references have the expected `Map<String, dynamic>` generic.
      _selectedElementMaterialId =
          (_existingItem!['elementMaterialId'] as DocumentReference?)
              ?.withConverter<Map<String, dynamic>>(
        fromFirestore: (s, _) => s.data()!,
        toFirestore: (m, _) => m,
      );
      _selectedScalarId = (_existingItem!['scalarId'] as DocumentReference?)
          ?.withConverter<Map<String, dynamic>>(
        fromFirestore: (s, _) => s.data()!,
        toFirestore: (m, _) => m,
      );
      _percentObject = (_existingItem!['percentObject'] != null)
          ? double.tryParse(_existingItem!['percentObject'].toString())
          : null;
    }

    _fetchCompanyObjectFields();
    _fetchElementMaterials();
    _fetchScalars();
    _fetchMeasurementSystem();
    Future.microtask(_loadElementFileImages);
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
      if (_elementMaterialChoices.isNotEmpty) {
        _fetchElementMaterials();
      }
    }
    if (!_initialLoadStarted) {
      _initialLoadStarted = true;
      if (_cachedData != null) {
        _applyData(_cachedData);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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
    return segments.isEmpty ? '' : _normalizeLocaleCode(segments.join('-'));
  }

  void _applyData(Map<String, dynamic>? data) {
    if (data == null) return;
    _populateTranslations(_nameTranslations, data['name']);
    final resolvedName = ProcessLocalizationUtils.resolveLocalizedText(
      data['name'],
      localeCode: _localeCode,
      fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
    );
    _nameController.text = resolvedName;
    _lengthFeet = _asDouble(data['lengthFeet']);
    _widthFeet = _asDouble(data['widthFeet']);
    _heightFeet = _asDouble(data['heightFeet']);
    if (mounted) {
      setState(() {});
    }
  }

  static double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
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

  /* ── helper fetches ─────────────────────────────────────── */
  Future<void> _fetchCompanyObjectFields() async {
    final docRef = widget.extraData?['companyObjectDocRef']
        as DocumentReference<Map<String, dynamic>>?;
    if (docRef == null) return;
    final snap = await docRef.get();
    if (!mounted || !snap.exists) return;
    final d = snap.data()!;
    final fileImages = await CompanyObjectFileImages.headerImageGalleryForRef(
      objectRef: docRef,
    );
    if (fileImages.isNotEmpty) {
      _companyImages = [
        for (final img in fileImages)
          {
            'url': img.url,
            'order': img.order,
            'isMaster': img.isMaster,
            if (img.caption != null) 'caption': img.caption,
            if (img.altText != null) 'altText': img.altText,
          },
      ];
    }
    _coveringMode = (d['ceilingCovering'] as bool? ?? false) ||
        (d['floorCovering'] as bool? ?? false) ||
        (d['wallCovering'] as bool? ?? false);
    setState(() {});
  }

  Future<void> _loadElementFileImages() async {
    final existingId = _existingDocId;
    if (existingId == null || existingId.isEmpty) return;
    final companyObjectRef = widget.extraData?['companyObjectDocRef']
        as DocumentReference<Map<String, dynamic>>?;
    final companyRef = companyObjectRef?.parent.parent
        as DocumentReference<Map<String, dynamic>>?;
    if (companyRef == null) return;
    final elementRef = companyRef.collection('objectElement').doc(existingId);
    final entries = await ObjectElementFileImages.headerImageEntries(
      companyRef: companyRef,
      elementRef: elementRef,
    );
    if (entries.isEmpty || !mounted) return;
    _elementImages = entries;
    final url = entries.first['url'];
    if (url is String && url.trim().isNotEmpty) {
      _imageUrl = url.trim();
    }
    setState(() {});
  }

  dynamic _cloneImageEntry(dynamic entry) {
    if (entry is Map) {
      final clone = <String, dynamic>{};
      entry.forEach((key, value) {
        clone[key.toString()] = _cloneImageEntry(value);
      });
      return clone;
    }
    if (entry is Iterable && entry is! String) {
      return entry.map(_cloneImageEntry).toList();
    }
    return entry;
  }

  List<dynamic> _cloneImages(dynamic rawImages) {
    if (rawImages is Iterable && rawImages is! String) {
      return rawImages.map(_cloneImageEntry).toList();
    }
    return <dynamic>[];
  }

  List<Map<String, dynamic>> _coerceImageEntries(dynamic rawImages) {
    final entries = <Map<String, dynamic>>[];
    if (rawImages is Iterable && rawImages is! String) {
      for (final item in rawImages) {
        if (item is Map<String, dynamic>) {
          entries.add(Map<String, dynamic>.from(item));
        } else if (item is Map) {
          final normalized = <String, dynamic>{};
          item.forEach((key, value) {
            normalized[key.toString()] = value;
          });
          entries.add(normalized);
        } else if (item is String) {
          final trimmed = item.trim();
          if (trimmed.isNotEmpty) {
            entries.add({'url': trimmed});
          }
        }
      }
    }
    return entries;
  }

  Future<List<dynamic>> _buildElementImages({
    required DocumentReference<Map<String, dynamic>> companyObjectRef,
  }) async {
    if (_elementImages.isNotEmpty) {
      return _cloneImages(_elementImages);
    }

    if (_companyImages.isNotEmpty) {
      return _cloneImages(_companyImages);
    }

    return buildSingleImageGallery(_imageUrl);
  }

  Future<void> _fetchElementMaterials() async {
    setState(() => _loadingMaterials = true);
    final companyRef = await ref.read(companyIdProvider.future);
    if (!mounted) return;
    if (companyRef == null) {
      setState(() => _loadingMaterials = false);
      return;
    }
    final snap = await companyRef.collection('elementMaterial').get();
    if (!mounted) return;
    final choices = <Map<String, dynamic>>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final ref = doc.reference.withConverter<Map<String, dynamic>>(
        fromFirestore: (s, _) => s.data()!,
        toFirestore: (m, _) => m,
      );
      final rawNameField = data['name'];
      final localizedName = ProcessLocalizationUtils.resolveLocalizedText(
        rawNameField,
        localeCode: _localeCode,
        fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
      );
      final rawName = localizedName.trim();
      final name = rawName.isEmpty ? 'Unnamed' : rawName;
      final rawDescriptionField = data['description'];
      final rawDescription = ProcessLocalizationUtils.resolveLocalizedText(
        rawDescriptionField,
        localeCode: _localeCode,
        fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
      ).trim();
      final rawSku = (data['sku'] as String?)?.trim();
      final imageUrl = '';
      final searchText = [
        name,
        if (rawDescription.isNotEmpty) rawDescription,
        if (rawSku != null && rawSku.isNotEmpty) rawSku,
      ].join(' ');

      choices.add({
        'ref': ref,
        'name': name,
        'nameField': rawNameField,
        'searchText': searchText,
        'imageUrl': imageUrl,
      });
    }

    choices.sort(
      (a, b) => (a['name'] as String).compareTo(b['name'] as String),
    );
    _elementMaterialChoices = choices;
    setState(() => _loadingMaterials = false);
  }

  Future<void> _fetchScalars() async {
    setState(() => _loadingScalars = true);
    final snap = await FirebaseFirestore.instance.collection('scalar').get();
    _scalarChoices = snap.docs.map((d) {
      final m = d.data();
      return {
        'ref': d.reference.withConverter<Map<String, dynamic>>(
            fromFirestore: (s, _) => s.data()!, toFirestore: (m, _) => m),
        'name': m['name'] ?? 'Unnamed',
        'standardUnit': m['standardUnit'] ?? 'sq ft',
        'metricUnit': m['metricUnit'] ?? 'm²',
        'standardConversion': m['standardConversion'] ?? 1.0,
        'metricConversion': m['metricConversion'] ?? 1.0,
      };
    }).toList()
      ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    setState(() => _loadingScalars = false);
  }

  Future<void> _fetchMeasurementSystem() async {
    final companyRef = await ref.read(companyIdProvider.future);
    if (companyRef == null) return;
    final snap = await companyRef.get();
    if (!snap.exists) return;
    setState(() {
      _measurementSystem =
          (snap.data()?['measurementSystem'] as String?) ?? 'Standard';
    });
  }

  Map<String, dynamic>? _materialChoiceForRef(
      DocumentReference<Map<String, dynamic>> ref) {
    for (final choice in _elementMaterialChoices) {
      final choiceRef =
          choice['ref'] as DocumentReference<Map<String, dynamic>>;
      if (choiceRef.path == ref.path) {
        return choice;
      }
    }
    return null;
  }

  String _materialLabel(DocumentReference<Map<String, dynamic>> ref) {
    final choice = _materialChoiceForRef(ref);
    final name = choice?['name'] as String?;
    if (name == null || name.trim().isEmpty) {
      return 'Unnamed';
    }
    return name;
  }

  String _materialSearchText(DocumentReference<Map<String, dynamic>> ref) {
    final choice = _materialChoiceForRef(ref);
    final search = choice?['searchText'] as String?;
    if (search != null && search.isNotEmpty) {
      return search;
    }
    return _materialLabel(ref);
  }

  String _materialImageUrl(DocumentReference<Map<String, dynamic>> ref) {
    final choice = _materialChoiceForRef(ref);
    final url = choice?['imageUrl'] as String?;
    return url ?? '';
  }

  DocumentReference<Map<String, dynamic>>? _resolveMaterialSelection(
    DocumentReference<Map<String, dynamic>>? ref,
  ) {
    if (ref == null) return null;
    final choice = _materialChoiceForRef(ref);
    if (choice == null) return ref;
    return choice['ref'] as DocumentReference<Map<String, dynamic>>?;
  }

  Future<void> _openElementMaterialDialog() async {
    FocusScope.of(context).unfocus();
    final loc = AppLocalizations.of(context)!;

    final items = _elementMaterialChoices
        .map((c) => c['ref'] as DocumentReference<Map<String, dynamic>>)
        .toList();
    final initialSelection = _resolveMaterialSelection(
      _selectedElementMaterialId,
    );

    final selected =
        await showDialog<DocumentReference<Map<String, dynamic>>?>(
      context: context,
      builder: (dialogCtx) =>
          DialogSelect<DocumentReference<Map<String, dynamic>>>(
        title: loc.objectElementFormElementMaterialLabel,
        items: items,
        itemLabel: _materialLabel,
        itemSearchString: _materialSearchText,
        itemImageUrl: _materialImageUrl,
        initialSelection: initialSelection,
        tileType: DialogSelectTileType.radio,
        onCancel: () => Navigator.of(dialogCtx).pop(),
        onSubmit: (result) =>
            Navigator.of(dialogCtx).pop(result.firstOrNull),
      ),
    );

    if (!mounted || selected == null) return;
    setState(() => _selectedElementMaterialId = selected);
  }

  Widget _elementMaterialDropdown() {
    final loc = AppLocalizations.of(context)!;
    final selectedRef = _selectedElementMaterialId;
    String displayText = loc.searchFieldActionTapToChoose;
    if (selectedRef != null) {
      final label = _materialLabel(selectedRef).trim();
      if (label.isNotEmpty) {
        displayText = label;
      }
    }

    return GestureDetector(
      onTap: _openElementMaterialDialog,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: loc.objectElementFormElementMaterialLabel,
          border: OutlineInputBorder(),
        ),
        child: Text(displayText),
      ),
    );
  }

  /* ── unit conversion helper ────────────────────────────── */
  Future<Map<String, double>> _convertQuantity({
    required DocumentReference<Map<String, dynamic>> scalarRef,
    required String measurementSystem, // 'Standard' | 'Metric'
    required double input,
  }) async {
    // Find the scalarUnit doc matching the current system
    final qs = await scalarRef
        .collection('scalarUnit')
        .where('measurementSystem', isEqualTo: measurementSystem)
        .limit(1)
        .get();

    if (qs.docs.isEmpty) return {'std': 0.0, 'met': 0.0};

    final u = qs.docs.first.data();
    final mc = (u['metricConversion'] as num).toDouble(); // sf ➜ m² or L ➜ m³
    final sc = (u['standardConversion'] as num).toDouble(); // m² ➜ sf or m³ ➜ L

    if (measurementSystem == 'Standard') {
      return {'std': input, 'met': input * mc};
    } else {
      return {'std': input * sc, 'met': input};
    }
  }

  /* ── image markup ───────────────────────────────────────── */
  Future<void> _launchImageMarkup() async {
    final loc = AppLocalizations.of(context)!;
    if (_imageUrl == null || _imageUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.objectElementFormNoImageToMarkup)),
      );
      return;
    }
    final res = await Navigator.of(context).push<String>(
      MaterialPageRoute(
          builder: (_) => BasicImageMarkupScreen(imageUrl: _imageUrl!)),
    );
    if (res != null && res.isNotEmpty) setState(() => _imageUrl = res);
  }

  /* ── SAVE ───────────────────────────────────────────────── */
  Future<void> saveForm() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final companyObjectRef = widget.extraData?['companyObjectDocRef']
        as DocumentReference<Map<String, dynamic>>?;
    if (companyObjectRef == null) return;

    final companyDocRef = companyObjectRef.parent.parent
        as DocumentReference<Map<String, dynamic>>?;
    if (companyDocRef == null) return;

    setState(() => _saving = true);

    final trimmedName = _nameController.text.trim();

    final materialChoice = _selectedElementMaterialId == null
        ? null
        : _materialChoiceForRef(_selectedElementMaterialId!);
    dynamic materialNameField =
        materialChoice?['nameField'] ?? materialChoice?['name'];
    if (materialNameField == null && _selectedElementMaterialId != null) {
      try {
        final matSnap = await _selectedElementMaterialId!.get();
        if (matSnap.exists) {
          materialNameField = matSnap.data()?['name'];
        }
      } catch (_) {}
    }
    if (_selectedElementMaterialId != null) {
      materialNameField ??= _existingItem?['elementMaterialName'];
    }

    final namePayload = _buildLocalizedPayload(
      latestValue: trimmedName,
      existingTranslations: _nameTranslations,
    );
    final nameField = namePayload ?? trimmedName;
    final materialNameValue = materialNameField;
    final bool hasMaterialNameValue = materialNameValue is Map
        ? materialNameValue.isNotEmpty
        : materialNameValue is String
            ? materialNameValue.trim().isNotEmpty
            : materialNameValue != null;

    final docId = _existingDocId ??
        FirebaseFirestore.instance.collection('dummy').doc().id;

    final imagesPayload = await _buildElementImages(
      companyObjectRef: companyObjectRef,
    );
    final resolvedImageUrl = primaryImageUrl(imagesPayload) ?? '';
    final baseEntries = _elementImages.isNotEmpty
        ? _elementImages
        : _coerceImageEntries(imagesPayload);
    var fileImageEntries = canonicalImageGallery(baseEntries);
    final selectedUrl = _imageUrl?.trim() ?? '';
    if (selectedUrl.isNotEmpty) {
      if (fileImageEntries.isEmpty) {
        fileImageEntries = buildSingleImageGallery(selectedUrl);
      } else {
        final hasSelected = fileImageEntries.any((entry) {
          final url = entry['url'];
          return url is String && url.trim() == selectedUrl;
        });
        if (!hasSelected) {
          fileImageEntries = buildSingleImageGallery(selectedUrl);
        } else if ((fileImageEntries.first['url'] as String?)?.trim() !=
            selectedUrl) {
          final reordered = <Map<String, dynamic>>[
            {'url': selectedUrl, 'order': 0, 'isMaster': true},
            ...fileImageEntries.where((entry) {
              final url = entry['url'];
              return url is String && url.trim() != selectedUrl;
            }),
          ];
          fileImageEntries = canonicalImageGallery(reordered);
        }
      }
    } else if (fileImageEntries.isEmpty &&
        resolvedImageUrl.trim().isNotEmpty) {
      fileImageEntries = buildSingleImageGallery(resolvedImageUrl);
    }

    Map<String, dynamic> newData;
    if (_coveringMode) {
      newData = {
        'name': nameField,
        'elementMaterialId': _selectedElementMaterialId,
        if (hasMaterialNameValue) 'elementMaterialName': materialNameValue,
        'percentObject': _percentObject ?? 0.0,
        'scalarId': FirebaseFirestore.instance
            .collection('scalar')
            .doc('UHkCZCZkQSMsnqhy0IQ5') // area scalar
            .withConverter<Map<String, dynamic>>(
              fromFirestore: (s, _) => s.data()!,
              toFirestore: (m, _) => m,
            ),
      };
    } else {
      final input = _scalarUnitQuantity ?? 0.0;
      if (_selectedScalarId == null) return;

      final q = await _convertQuantity(
        scalarRef: _selectedScalarId!,
        measurementSystem: _measurementSystem,
        input: input,
      );

      newData = {
        'name': nameField,
        'elementMaterialId': _selectedElementMaterialId,
        if (hasMaterialNameValue) 'elementMaterialName': materialNameValue,
        'scalarId': _selectedScalarId,
        'standardQuantity': q['std'],
        'metricQuantity': q['met'],
      };
    }

    // Append physical dimensions (shared by both covering and non-covering).
    if (_lengthFeet != null) {
      newData['lengthFeet'] = _lengthFeet;
      newData['lengthMeters'] = _lengthFeet! * 0.3048;
    }
    if (_widthFeet != null) {
      newData['widthFeet'] = _widthFeet;
      newData['widthMeters'] = _widthFeet! * 0.3048;
    }
    if (_heightFeet != null) {
      newData['heightFeet'] = _heightFeet;
      newData['heightMeters'] = _heightFeet! * 0.3048;
    }

    final now = Timestamp.now();
    final elementArrayPayload = <String, dynamic>{
      'id': docId,
      ...newData,
      'companyObjectId': companyObjectRef,
      'companyObjectDocId': companyObjectRef.id,
      'companyId': companyDocRef.id,
      'updatedAt': now,
    };

    final existingCreatedRaw = _existingItem?['createdAt'];
    Timestamp? existingCreatedAt;
    if (existingCreatedRaw is Timestamp) {
      existingCreatedAt = existingCreatedRaw;
    }
    elementArrayPayload['createdAt'] = existingCreatedAt ?? now;

    final elementDocPayload = <String, dynamic>{
      ...elementArrayPayload,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': existingCreatedAt == null
          ? FieldValue.serverTimestamp()
          : existingCreatedAt,
    };

    final elementDocRef = companyDocRef.collection('objectElement').doc(docId);

    final batch = FirebaseFirestore.instance.batch();
    batch.set(elementDocRef, elementDocPayload);

    if (_existingItem != null) {
      batch.update(companyObjectRef, {
        'elements': FieldValue.arrayRemove([_existingItem])
      });
    }

    batch.update(companyObjectRef, {
      'elements': FieldValue.arrayUnion([elementArrayPayload])
    });

    await batch.commit();

    await ObjectElementFileImages.syncHeaderImages(
      companyRef: companyDocRef,
      elementRef: elementDocRef,
      images: fileImageEntries,
      fallbackUrl: resolvedImageUrl,
      elementName: trimmedName.isNotEmpty ? trimmedName : 'Element',
      companyObjectRef: companyObjectRef,
    );

    if (mounted) context.pop(true);
  }

  /* ── UI ─────────────────────────────────────────────────── */
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final bool hideChrome = false;
    final isEdit = _existingDocId != null;
    String unitLabel;
    if (_selectedScalarId != null) {
      final sel = _scalarChoices.firstWhere(
        (c) =>
            (c['ref'] as DocumentReference<Map<String, dynamic>>).id ==
            _selectedScalarId?.id,
        orElse: () => {},
      );
      unitLabel = _measurementSystem == 'Metric'
          ? (sel['metricUnit'] as String? ?? 'm²')
          : (sel['standardUnit'] as String? ?? 'sq ft');
    } else {
      unitLabel = _measurementSystem == 'Metric' ? 'm²' : 'sq ft';
    }

    return Scaffold(
      appBar: hideChrome
          ? null
          : StandardAppBar(
              title: isEdit
                  ? loc.objectElementFormTitleEdit
                  : loc.objectElementFormTitleNew,
            ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: hideChrome ? 16 : 80),
        child: Form(
          key: _formKey,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (_imageUrl?.isNotEmpty ?? false)
              ContainerActionWidget(
                title: loc.objectElementFormImagesTitle,
                titleInfoKey: FieldInfoKeys.objectsImages,
                actionText: '',
                content: MarkupImageField(
                  imageUrl: _imageUrl!,
                  onImageChanged: (u) => setState(() => _imageUrl = u),
                  onMarkupTap: _launchImageMarkup,
                ),
              ),
            if (_imageUrl?.isNotEmpty ?? false) const SizedBox(height: 16),
            ContainerActionWidget(
              title: loc.objectElementFormElementHeader,
              titleInfoKey: FieldInfoKeys.objectsElementName,
              actionText: '',
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: loc.objectElementFormElementNameLabel,
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty)
                            ? loc.objectElementFormRequired
                            : null,
                  ),
                  const SizedBox(height: 16),
                  if (_loadingMaterials) ...[
                    const Align(
                      alignment: Alignment.center,
                      child: SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ] else ...[
                    _elementMaterialDropdown(),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_coveringMode) ...[
              ContainerActionWidget(
                title: AppLocalizations.of(context)!
                    .objectElementFormElementPercentageHeader,
                titleInfoKey: FieldInfoKeys.objectsElementPercentage,
                actionText: '',
                content: TextFormField(
                  initialValue: _percentObject != null
                      ? (_percentObject! * 100).toString()
                      : '',
                  decoration: InputDecoration(
                    labelText: loc.objectElementFormElementPercentageHeader,
                    suffixText: '%',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final p = double.tryParse(v ?? '');
                    if (p == null || p < 0 || p > 100) {
                      return loc.objectElementFormPercentRange;
                    }
                    return null;
                  },
                  onSaved: (v) =>
                      _percentObject = (double.tryParse(v ?? '') ?? 0) / 100,
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (!_coveringMode) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _loadingScalars
                        ? const CircularProgressIndicator()
                        : DropdownButtonFormField<
                            DocumentReference<Map<String, dynamic>>>(
                            decoration: InputDecoration(
                              labelText: loc.objectElementFormMeasuredByLabel,
                              border: OutlineInputBorder(),
                            ),
                            initialValue: _selectedScalarId,
                            items: _scalarChoices.map((c) {
                              return DropdownMenuItem(
                                value: c['ref']
                                    as DocumentReference<Map<String, dynamic>>,
                                child: Text(c['name'] as String),
                              );
                            }).toList(),
                            onChanged: (v) =>
                                setState(() => _selectedScalarId = v),
                            validator: (v) =>
                                v == null ? loc.objectElementFormRequired : null,
                          ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: _scalarUnitQuantity?.toString() ?? '',
                      decoration: InputDecoration(
                        labelText:
                            loc.objectElementFormMeasurementLabel(unitLabel),
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) =>
                          double.tryParse(v ?? '') == null
                              ? loc.objectElementFormInvalid
                              : null,
                      onSaved: (v) =>
                          _scalarUnitQuantity = double.tryParse(v ?? ''),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            ContainerActionWidget(
              title: loc.objectElementFormDimensionsTitle,
              actionText: '',
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    initialValue: _lengthFeet?.toString() ?? '',
                    decoration: InputDecoration(
                      labelText: _measurementSystem == 'Metric'
                          ? loc.objectElementFormLengthMetricLabel
                          : loc.objectElementFormLengthLabel,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onSaved: (v) =>
                        _lengthFeet = double.tryParse(v ?? ''),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: _widthFeet?.toString() ?? '',
                    decoration: InputDecoration(
                      labelText: _measurementSystem == 'Metric'
                          ? loc.objectElementFormWidthMetricLabel
                          : loc.objectElementFormWidthLabel,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onSaved: (v) =>
                        _widthFeet = double.tryParse(v ?? ''),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: _heightFeet?.toString() ?? '',
                    decoration: InputDecoration(
                      labelText: _measurementSystem == 'Metric'
                          ? loc.objectElementFormHeightMetricLabel
                          : loc.objectElementFormHeightLabel,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onSaved: (v) =>
                        _heightFeet = double.tryParse(v ?? ''),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
      bottomNavigationBar: hideChrome
          ? null
          : SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 8),
              child: CancelSaveBar(
                onCancel: () => context.pop(),
                onSave: saveForm,
              ),
            ),
    );
  }
}


