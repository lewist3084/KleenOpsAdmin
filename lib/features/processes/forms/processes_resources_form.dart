// lib/features/processes/forms/processes_resources_form.dart
// DEGRADED: Document field stripped (no admin widgets/fields/document_field.dart).
// Document media type now just stores the URL; users must enter manually
// or wait for a document upload widget port.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';
import 'package:kleenops_admin/widgets/layout/bookended_canvas.dart';
import 'package:shared_widgets/fields/video_field.dart';
import 'package:shared_widgets/fields/markup_image_field.dart';
import 'package:shared_widgets/markup/image_markup.dart';
import 'package:shared_widgets/search/search_field_action.dart';
import 'package:kleenops_admin/services/ai_text_adapter.dart';
import 'package:shared_widgets/utils/process_localization_utils.dart';
import 'package:kleenops_admin/features/processes/utils/process_resource_file_media.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';

class ProcessesResourcesFormContent extends StatefulWidget {
  final DocumentReference companyId;
  final String? docId;
  final String? companyObjectIdPath;

  const ProcessesResourcesFormContent({
    super.key,
    required this.companyId,
    this.docId,
    this.companyObjectIdPath,
  });

  @override
  State<ProcessesResourcesFormContent> createState() =>
      ProcessesResourcesFormContentState();
}

class ProcessesResourcesFormContentState
    extends State<ProcessesResourcesFormContent> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _documentUrlController = TextEditingController();
  String? _videoUrl;
  String? _imageUrl;
  String? _documentUrl;
  String _mediaType = 'Video';
  DocumentReference? _selectedProcess;
  int? _videoDuration;
  DocumentReference? _companyObjectIdRef;

  bool _isLoading = false;
  bool _saving = false;
  bool _initialLoadStarted = false;
  late String _localeCode;
  Map<String, dynamic>? _cachedData;
  final Map<String, String> _nameTranslations = {};
  final Map<String, String> _descriptionTranslations = {};

  @override
  void initState() {
    super.initState();
    _localeCode = ProcessLocalizationUtils.defaultLocaleCode;

    if (widget.companyObjectIdPath != null &&
        widget.companyObjectIdPath!.isNotEmpty) {
      _companyObjectIdRef =
          FirebaseFirestore.instance.doc(widget.companyObjectIdPath!);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialLoadStarted) {
      _initialLoadStarted = true;
      _loadExistingData();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _documentUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingData() async {
    final docId = widget.docId?.trim();
    if (docId == null || docId.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final resourceRef = widget.companyId.collection('resource').doc(docId);
      final snapshot = await resourceRef.get();
      if (!snapshot.exists) {
        return;
      }
      final data = snapshot.data() ?? {};
      _cachedData = data;
      _applyData(_cachedData);

      final processes = (data['processes'] as List<dynamic>? ?? [])
          .whereType<DocumentReference>()
          .toList();
      _selectedProcess = processes.isNotEmpty ? processes.first : null;

      final objects = (data['objectsArray'] as List<dynamic>? ?? [])
          .whereType<DocumentReference>()
          .toList();
      _companyObjectIdRef = objects.isNotEmpty ? objects.first : null;

      final fileMedia = await ProcessResourceFileMedia.load(
        companyRef: widget.companyId as DocumentReference<Map<String, dynamic>>,
        resourceRef: resourceRef,
      );
      if (fileMedia.videos.isNotEmpty ||
          fileMedia.images.isNotEmpty ||
          fileMedia.documents.isNotEmpty) {
        _videoUrl = fileMedia.primaryVideoUrl ?? '';
        _imageUrl =
            fileMedia.primaryVideoThumbnail ?? fileMedia.primaryImageUrl ?? '';
        _videoDuration = fileMedia.primaryVideoDuration;
        _documentUrl = fileMedia.primaryDocumentUrl ?? '';
        _documentUrlController.text = _documentUrl ?? '';
        if ((_videoUrl ?? '').isNotEmpty) {
          _mediaType = 'Video';
        } else if ((_imageUrl ?? '').isNotEmpty) {
          _mediaType = 'Image';
        } else if ((_documentUrl ?? '').isNotEmpty) {
          _mediaType = 'Document';
        } else {
          _mediaType = data['mediaType'] as String? ?? 'Video';
        }
      } else {
        _documentUrl = '';
        _imageUrl = '';
        _videoUrl = '';
        _videoDuration = null;
        _mediaType = data['mediaType'] as String? ?? 'Video';
      }

      if (mounted) {
        setState(() {});
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    if (_selectedProcess == null) {
      SnackbarService.instance.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: const Text('Please select a process.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    final collectionRef = widget.companyId.collection('resource');
    final isCreate = widget.docId == null || widget.docId!.trim().isEmpty;
    final nameValue = _nameController.text.trim();
    final descriptionValue = _descriptionController.text.trim();
    final documentValue = _documentUrlController.text.trim();
    if (documentValue.isNotEmpty) {
      _documentUrl = documentValue;
    }
    final namePayload = _buildLocalizedPayload(
      latestValue: nameValue,
      existingTranslations: _nameTranslations,
    );
    final descriptionPayload = _buildLocalizedPayload(
      latestValue: descriptionValue,
      existingTranslations: _descriptionTranslations,
    );
    final processes = _selectedProcess != null
        ? <DocumentReference>[_selectedProcess!]
        : <DocumentReference>[];
    final objectsArray = _companyObjectIdRef != null
        ? <DocumentReference>[_companyObjectIdRef!]
        : <DocumentReference>[];
    final dataToSave = <String, dynamic>{
      'name': namePayload ?? nameValue,
      'mediaType': _mediaType,
      'processes': processes,
      'objectsArray': objectsArray,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (descriptionPayload == null) {
      if (!isCreate) {
        dataToSave['description'] = FieldValue.delete();
      }
    } else {
      dataToSave['description'] = descriptionPayload;
    }

    try {
      DocumentReference<Map<String, dynamic>> resourceRef;
      if (widget.docId == null) {
        resourceRef = await collectionRef.add(dataToSave);
      } else {
        resourceRef = collectionRef.doc(widget.docId!);
        await resourceRef.set({
          ...dataToSave,
          'videoUrl': FieldValue.delete(),
          'imageUrl': FieldValue.delete(),
          'imagesArray': FieldValue.delete(),
          'videos': FieldValue.delete(),
          'documentUrl': FieldValue.delete(),
          'processId': FieldValue.delete(),
          'companyObjectId': FieldValue.delete(),
          'videoDuration': FieldValue.delete(),
        }, SetOptions(merge: true));
      }
      await ProcessResourceFileMedia.syncResourceMedia(
        companyRef: widget.companyId as DocumentReference<Map<String, dynamic>>,
        resourceRef: resourceRef,
        resourceName: nameValue.isNotEmpty ? nameValue : 'Resource',
        imageUrl: _imageUrl,
        videoUrl: _videoUrl,
        videoThumbnail: _imageUrl,
        videoDuration: _videoDuration,
        documentUrl: _documentUrl,
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _saving) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: BookendedCanvas(
        child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _mediaType,
              decoration: const InputDecoration(labelText: 'Media Type'),
              items: const [
                DropdownMenuItem(value: 'Document', child: Text('Document')),
                DropdownMenuItem(value: 'Image', child: Text('Image')),
                DropdownMenuItem(value: 'Video', child: Text('Video')),
              ],
              onChanged: (value) =>
                  setState(() => _mediaType = value ?? 'Video'),
              onSaved: (value) => _mediaType = value ?? 'Video',
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: widget.companyId
                  .collection('process')
                  .orderBy('name')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(
                    height: 60,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final docs = snapshot.data!.docs;
                final effectiveLocale = _localeCode;
                final items = docs.map((d) => d.reference).toList();
                return SearchAddSelectDropdown<DocumentReference>(
                  label: 'Processes',
                  items: items,
                  initialValue: _selectedProcess,
                  itemLabel: (ref) {
                    final d = docs.firstWhere((doc) => doc.reference == ref);
                    final data = d.data();
                    final resolvedName =
                        ProcessLocalizationUtils.resolveLocalizedText(
                      data['name'],
                      localeCode: effectiveLocale,
                      fallbackLocaleCode:
                          ProcessLocalizationUtils.defaultLocaleCode,
                    );
                    return resolvedName.isNotEmpty
                        ? resolvedName
                        : 'Unnamed Process';
                  },
                  itemImageUrl: (_) => '',
                  onChanged: (val) => setState(() => _selectedProcess = val),
                );
              },
            ),
            const SizedBox(height: 16),
            AITextField(
              controller: _nameController,
              labelText: 'Name',
              validator: (val) => (val == null || val.trim().isEmpty)
                  ? 'Name is required'
                  : null,
            ),
            const SizedBox(height: 16),
            AITextField(
              controller: _descriptionController,
              labelText: 'Description',
              minLines: 3,
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            if (_mediaType == 'Video') ...[
              VideoField(
                videoUrl: _videoUrl,
                thumbnailUrl: _imageUrl,
                storageFolder: 'company/processResources/videos',
                hintText: 'No video selected',
                onVideoChanged: (newUrl) => setState(() => _videoUrl = newUrl),
                onThumbnailChanged: (thumbUrl) =>
                    setState(() => _imageUrl = thumbUrl),
                onVideoDurationChanged: (dur) =>
                    setState(() => _videoDuration = dur),
              ),
              const SizedBox(height: 16),
              if (_imageUrl != null && _imageUrl!.isNotEmpty) ...[
                const Text(
                  'Custom Thumbnail',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                MarkupImageField(
                  imageUrl: _imageUrl,
                  storageFolder: 'company/processResources/thumbnails',
                  onImageChanged: (newUrl) =>
                      setState(() => _imageUrl = newUrl),
                  onMarkupTap: () async {
                    final result = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            BasicImageMarkupScreen(imageUrl: _imageUrl!),
                      ),
                    );
                    if (result is String && result.isNotEmpty) {
                      setState(() => _imageUrl = result);
                    }
                  },
                ),
              ],
            ],
            if (_mediaType == 'Image') ...[
              MarkupImageField(
                imageUrl: _imageUrl,
                storageFolder: 'company/processResources/images',
                onImageChanged: (newUrl) => setState(() => _imageUrl = newUrl),
                onMarkupTap: () async {
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          BasicImageMarkupScreen(imageUrl: _imageUrl!),
                    ),
                  );
                  if (result is String && result.isNotEmpty) {
                    setState(() => _imageUrl = result);
                  }
                },
              ),
            ],
            if (_mediaType == 'Document') ...[
              // DEGRADED: Document upload widget not yet ported to admin.
              TextFormField(
                controller: _documentUrlController,
                decoration: const InputDecoration(
                  labelText: 'Document URL',
                  hintText: 'Paste a URL (document upload TBD)',
                ),
              ),
            ],
          ],
        ),
      ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CancelSaveBar(
            onCancel: () => context.pop(),
            onSave: _saveForm,
            reserveNavBarSpace: false,
          ),
          DetailsAppBar(
            title: widget.docId == null ? 'Add Resource' : 'Edit Resource',
          ),
          const HomeNavBarAdapter(),
        ],
      ),
    );
  }
}
