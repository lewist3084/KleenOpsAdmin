// Admin port: top-level `propertyType` collection, English strings hardcoded.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/common/field_info/field_info_registry.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';
import 'package:kleenops_admin/services/ai_text_adapter.dart';
import 'package:kleenops_admin/widgets/layout/bookended_canvas.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/services/firestore_service.dart';
import 'package:shared_widgets/utils/process_localization_utils.dart';

class PropertyTypeForm extends StatefulWidget {
  const PropertyTypeForm({super.key, this.docId});

  final String? docId;

  @override
  State<PropertyTypeForm> createState() => _PropertyTypeFormState();
}

class _PropertyTypeFormState extends State<PropertyTypeForm> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final FirestoreService _firestore = FirestoreService();

  bool _loading = false;
  bool _saving = false;
  bool _initialLoadStarted = false;
  late String _localeCode;
  Map<String, dynamic>? _cachedData;
  final Map<String, String> _nameTranslations = {};
  final Map<String, String> _descriptionTranslations = {};

  CollectionReference<Map<String, dynamic>> _collection() =>
      FirebaseFirestore.instance.collection('propertyType');

  @override
  void initState() {
    super.initState();
    _localeCode = ProcessLocalizationUtils.defaultLocaleCode;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.maybeLocaleOf(context);
    final inferredLanguage = locale?.languageCode.trim().toLowerCase() ?? '';
    final nextLocale = inferredLanguage.isNotEmpty
        ? inferredLanguage
        : ProcessLocalizationUtils.defaultLocaleCode;
    if (_localeCode != nextLocale) {
      _localeCode = nextLocale;
      if (_cachedData != null) {
        _applyData(_cachedData);
      }
    }
    if (!_initialLoadStarted) {
      _initialLoadStarted = true;
      if (widget.docId != null && widget.docId!.isNotEmpty) {
        _loadExisting();
      }
    }
  }

  Future<void> _loadExisting() async {
    setState(() => _loading = true);
    try {
      final snapshot = await _collection().doc(widget.docId!).get();
      if (!mounted) return;
      if (snapshot.exists) {
        _cachedData = snapshot.data();
        _applyData(_cachedData);
      }
    } catch (e) {
      if (!mounted) return;
      SnackbarService.instance.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: Text('Failed to load property type: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
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
    if (mounted) setState(() {});
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

  String _normalizeLocaleCode(String code) =>
      ProcessLocalizationUtils.normalizeLocaleCode(code);

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      SnackbarService.instance.showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 5),
          content: Text('Please enter name before saving.'),
        ),
      );
      return;
    }

    final description = _descriptionController.text.trim();
    setState(() => _saving = true);
    final payload = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final isCreate = widget.docId == null || widget.docId!.trim().isEmpty;
    final namePayload = _buildLocalizedPayload(
      latestValue: name,
      existingTranslations: _nameTranslations,
    );
    payload['name'] = namePayload ?? name;
    final descriptionPayload = _buildLocalizedPayload(
      latestValue: description,
      existingTranslations: _descriptionTranslations,
    );
    if (descriptionPayload == null) {
      if (!isCreate) payload['description'] = FieldValue.delete();
    } else {
      payload['description'] = descriptionPayload;
    }
    if (isCreate) {
      payload['createdAt'] = FieldValue.serverTimestamp();
    }

    try {
      await _firestore.saveDocument(
        collectionRef: _collection(),
        docId: widget.docId,
        data: payload,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      SnackbarService.instance.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: Text('Failed to save property type: $e'),
        ),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const propertyTypeLabel = 'Property Type';

    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : AbsorbPointer(
            absorbing: _saving,
            child: Stack(
              children: [
                SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ContainerActionWidget(
                        title: propertyTypeLabel,
                        titleInfoKey: FieldInfoKeys.facilitiesPropertyType,
                        actionText: '',
                        content: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AITextField(
                              controller: _nameController,
                              labelText: 'Name',
                              minLines: 1,
                              maxLines: 1,
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
                    ],
                  ),
                ),
                if (_saving)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0x66000000),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
          );

    return Scaffold(
      body: BookendedCanvas(child: body),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CancelSaveBar(
            onCancel: () => Navigator.of(context).pop(),
            onSave: _saving ? null : _handleSave,
            reserveNavBarSpace: false,
          ),
          const DetailsAppBar(title: propertyTypeLabel),
          const HomeNavBarAdapter(),
        ],
      ),
    );
  }
}
