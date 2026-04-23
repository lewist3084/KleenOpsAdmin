// catalog_form.dart
//
// Admin-only edit form for a `object` doc in the global catalog. Reached
// from the FAB on CatalogDetailsScreen. Text fields cover scalar
// properties; reference fields (objectCategory, brand, scalar, scalar
// units, packaging-dimension units) open a DialogSelect so the admin can
// pick or correct an assignment — including setting an object category
// on items that were transferred without one.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/dialogs/dialog_select.dart';
import 'package:shared_widgets/services/catalog_firebase_service.dart';
import 'package:shared_widgets/utils/process_localization_utils.dart';

import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';

class CatalogForm extends StatefulWidget {
  final String docId;
  const CatalogForm({super.key, required this.docId});

  @override
  State<CatalogForm> createState() => _CatalogFormState();
}

/// Lightweight holder for a reference-typed dropdown option. Keeps the
/// DocumentReference alongside a display label, optional group label (for
/// grouping scalar units by their parent scalar), and a search string.
class _RefChoice {
  final DocumentReference<Map<String, dynamic>> ref;
  final String label;
  final String? groupLabel;
  final String searchText;
  const _RefChoice({
    required this.ref,
    required this.label,
    this.groupLabel,
    required this.searchText,
  });
}

class _CatalogFormState extends State<CatalogForm> {
  final _formKey = GlobalKey<FormState>();

  // Text controllers — one per free-text / numeric field on the object doc.
  final _nameCtl = TextEditingController();
  final _descriptionCtl = TextEditingController();
  final _productCodeCtl = TextEditingController();
  final _upcCtl = TextEditingController();
  final _brandTextCtl = TextEditingController();
  final _productLineCtl = TextEditingController();
  final _colorCtl = TextEditingController();
  final _fragranceCtl = TextEditingController();
  final _containerTypeCtl = TextEditingController();
  final _packagingTypeCtl = TextEditingController();
  final _canonicalUrlCtl = TextEditingController();
  final _scalarUnitQtyCtl = TextEditingController();
  final _productWeightCtl = TextEditingController();
  final _packagingWeightCtl = TextEditingController();
  final _packagingLengthCtl = TextEditingController();
  final _packagingWidthCtl = TextEditingController();
  final _packagingHeightCtl = TextEditingController();

  // Reference selections — nullable so the admin can clear an assignment.
  DocumentReference<Map<String, dynamic>>? _objectCategoryId;
  DocumentReference<Map<String, dynamic>>? _brandId;
  DocumentReference<Map<String, dynamic>>? _brandOwnerId;
  DocumentReference<Map<String, dynamic>>? _scalarId;
  DocumentReference<Map<String, dynamic>>? _scalarUnitId;
  DocumentReference<Map<String, dynamic>>? _productWeightUnitId;
  DocumentReference<Map<String, dynamic>>? _packagingWeightUnitId;
  DocumentReference<Map<String, dynamic>>? _packagingDimensionsUnitId;

  // Retain the raw `name` field so we preserve localized translations
  // rather than collapsing everything to the currently-viewed locale.
  dynamic _nameRaw;
  dynamic _descriptionRaw;

  bool _loading = true;
  bool _saving = false;

  // Reference choice lists — loaded once on init.
  List<_RefChoice> _categoryChoices = [];
  List<_RefChoice> _brandChoices = [];
  List<_RefChoice> _brandOwnerChoices = [];
  List<_RefChoice> _scalarChoices = [];
  List<_RefChoice> _allScalarUnitChoices = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _descriptionCtl.dispose();
    _productCodeCtl.dispose();
    _upcCtl.dispose();
    _brandTextCtl.dispose();
    _productLineCtl.dispose();
    _colorCtl.dispose();
    _fragranceCtl.dispose();
    _containerTypeCtl.dispose();
    _packagingTypeCtl.dispose();
    _canonicalUrlCtl.dispose();
    _scalarUnitQtyCtl.dispose();
    _productWeightCtl.dispose();
    _packagingWeightCtl.dispose();
    _packagingLengthCtl.dispose();
    _packagingWidthCtl.dispose();
    _packagingHeightCtl.dispose();
    super.dispose();
  }

  String _localeCode() {
    try {
      return Localizations.localeOf(context).toString();
    } catch (_) {
      return ProcessLocalizationUtils.defaultLocaleCode;
    }
  }

  Future<void> _load() async {
    final db = CatalogFirebaseService.instance.firestore;
    try {
      final snap = await db.collection('object').doc(widget.docId).get();
      final d = snap.data() ?? <String, dynamic>{};

      _nameRaw = d['name'];
      _descriptionRaw = d['description'];
      _nameCtl.text = ProcessLocalizationUtils.resolveLocalizedText(
        _nameRaw,
        localeCode: _localeCode(),
      );
      _descriptionCtl.text = ProcessLocalizationUtils.resolveLocalizedText(
        _descriptionRaw,
        localeCode: _localeCode(),
      );
      _productCodeCtl.text =
          (d['objectProductCode'] ?? d['productNumber'] ?? '').toString();
      _upcCtl.text = (d['objectBarcode'] ?? d['upc'] ?? '').toString();
      _brandTextCtl.text = (d['brand'] ?? '').toString();
      _productLineCtl.text = (d['productLine'] ?? '').toString();
      _colorCtl.text = (d['color'] ?? '').toString();
      _fragranceCtl.text = (d['fragrance'] ?? d['scent'] ?? '').toString();
      _containerTypeCtl.text = (d['containerType'] ?? '').toString();
      _packagingTypeCtl.text = (d['packagingType'] ?? '').toString();
      _canonicalUrlCtl.text = (d['canonicalUrl'] ?? '').toString();
      _scalarUnitQtyCtl.text = _numStr(d['scalarUnitQuantity']);
      _productWeightCtl.text = _numStr(d['productWeight']);
      _packagingWeightCtl.text = _numStr(d['packagingWeight']);
      _packagingLengthCtl.text = _numStr(d['packagingLength']);
      _packagingWidthCtl.text = _numStr(d['packagingWidth']);
      _packagingHeightCtl.text = _numStr(d['packagingHeight']);

      _objectCategoryId = _asRef(d['objectCategoryId']);
      _brandId = _asRef(d['brandId']);
      _brandOwnerId = _asRef(d['brandOwnerId']);
      _scalarId = _asRef(d['scalarId']);
      _scalarUnitId = _asRef(d['scalarUnitId']);
      _productWeightUnitId = _asRef(d['productWeightUnitId']);
      _packagingWeightUnitId = _asRef(d['packagingWeightUnitId']);
      _packagingDimensionsUnitId = _asRef(d['packagingDimensionsUnitId']);

      await Future.wait([
        _loadCategoryChoices(),
        _loadBrandChoices(),
        _loadBrandOwnerChoices(),
        _loadScalarChoices(),
        _loadAllScalarUnitChoices(),
      ]);
    } catch (e) {
      debugPrint('[CatalogForm] load failed: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  DocumentReference<Map<String, dynamic>>? _asRef(dynamic v) {
    if (v is DocumentReference) {
      return v.withConverter<Map<String, dynamic>>(
        fromFirestore: (s, _) => s.data()!,
        toFirestore: (m, _) => m,
      );
    }
    return null;
  }

  String _numStr(dynamic v) {
    if (v == null) return '';
    if (v is num) {
      if (v == v.toInt()) return v.toInt().toString();
      return v.toString();
    }
    return v.toString();
  }

  Future<void> _loadCategoryChoices() async {
    final db = CatalogFirebaseService.instance.firestore;
    final snap = await db.collection('objectCategory').get();
    final locale = _localeCode();
    _categoryChoices = snap.docs.map((doc) {
      final data = doc.data();
      final name = ProcessLocalizationUtils.resolveLocalizedText(
        data['name'],
        localeCode: locale,
      ).trim();
      return _RefChoice(
        ref: doc.reference.withConverter<Map<String, dynamic>>(
          fromFirestore: (s, _) => s.data()!,
          toFirestore: (m, _) => m,
        ),
        label: name.isEmpty ? 'Unnamed' : name,
        searchText: '$name ${doc.id}',
      );
    }).toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  }

  Future<void> _loadBrandChoices() async {
    final db = CatalogFirebaseService.instance.firestore;
    final snap = await db.collection('brand').get();
    _brandChoices = snap.docs.map((doc) {
      final name = (doc.data()['name'] ?? '').toString().trim();
      return _RefChoice(
        ref: doc.reference.withConverter<Map<String, dynamic>>(
          fromFirestore: (s, _) => s.data()!,
          toFirestore: (m, _) => m,
        ),
        label: name.isEmpty ? 'Unnamed' : name,
        searchText: '$name ${doc.id}',
      );
    }).toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  }

  Future<void> _loadBrandOwnerChoices() async {
    final db = CatalogFirebaseService.instance.firestore;
    final snap = await db.collection('brandOwner').get();
    _brandOwnerChoices = snap.docs.map((doc) {
      final name = (doc.data()['name'] ?? '').toString().trim();
      return _RefChoice(
        ref: doc.reference.withConverter<Map<String, dynamic>>(
          fromFirestore: (s, _) => s.data()!,
          toFirestore: (m, _) => m,
        ),
        label: name.isEmpty ? 'Unnamed' : name,
        searchText: '$name ${doc.id}',
      );
    }).toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  }

  Future<void> _loadScalarChoices() async {
    final db = CatalogFirebaseService.instance.firestore;
    final snap = await db.collection('scalar').get();
    final locale = _localeCode();
    _scalarChoices = snap.docs.map((doc) {
      final data = doc.data();
      final name = ProcessLocalizationUtils.resolveLocalizedText(
        data['name'],
        localeCode: locale,
      ).trim();
      final fallback = name.isEmpty ? doc.id : name;
      return _RefChoice(
        ref: doc.reference.withConverter<Map<String, dynamic>>(
          fromFirestore: (s, _) => s.data()!,
          toFirestore: (m, _) => m,
        ),
        label: fallback,
        searchText: '$fallback ${doc.id}',
      );
    }).toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  }

  /// Loads every scalar-unit doc across the catalog via collectionGroup.
  /// Each choice is labelled `{parent scalar} → {unit name}` and grouped
  /// by parent scalar so the DialogSelect can show a section header per
  /// scalar (Mass, Length, Volume, etc.).
  Future<void> _loadAllScalarUnitChoices() async {
    final db = CatalogFirebaseService.instance.firestore;
    final scalarNameById = <String, String>{};
    for (final choice in _scalarChoices) {
      scalarNameById[choice.ref.id] = choice.label;
    }
    // Fallback: if scalar choices loaded after this, hydrate on demand.
    if (scalarNameById.isEmpty) {
      final scalarSnap = await db.collection('scalar').get();
      final locale = _localeCode();
      for (final s in scalarSnap.docs) {
        final name = ProcessLocalizationUtils.resolveLocalizedText(
          s.data()['name'],
          localeCode: locale,
        ).trim();
        scalarNameById[s.id] = name.isEmpty ? s.id : name;
      }
    }

    final snap = await db.collectionGroup('scalarUnit').get();
    final locale = _localeCode();
    _allScalarUnitChoices = snap.docs.map((doc) {
      final data = doc.data();
      final abbrev = (data['abbreviatedName'] ??
              data['abbreviationName'] ??
              data['abbreviation'] ??
              '')
          .toString()
          .trim();
      final fullName = ProcessLocalizationUtils.resolveLocalizedText(
        data['name'],
        localeCode: locale,
      ).trim();
      final unitLabel = abbrev.isNotEmpty
          ? (fullName.isNotEmpty && fullName != abbrev
              ? '$fullName ($abbrev)'
              : abbrev)
          : (fullName.isNotEmpty ? fullName : doc.id);
      final parentScalarId = doc.reference.parent.parent?.id ?? '';
      final parentScalarName =
          scalarNameById[parentScalarId] ?? parentScalarId;
      return _RefChoice(
        ref: doc.reference.withConverter<Map<String, dynamic>>(
          fromFirestore: (s, _) => s.data()!,
          toFirestore: (m, _) => m,
        ),
        label: unitLabel,
        groupLabel: parentScalarName,
        searchText:
            '$unitLabel $parentScalarName $abbrev $fullName ${doc.id}',
      );
    }).toList()
      ..sort((a, b) {
        final g = (a.groupLabel ?? '').compareTo(b.groupLabel ?? '');
        if (g != 0) return g;
        return a.label.toLowerCase().compareTo(b.label.toLowerCase());
      });
  }

  Future<void> _openRefDialog({
    required String title,
    required List<_RefChoice> choices,
    required DocumentReference<Map<String, dynamic>>? currentRef,
    required ValueChanged<DocumentReference<Map<String, dynamic>>?> onChanged,
    bool useGrouping = false,
  }) async {
    FocusScope.of(context).unfocus();
    _RefChoice? current;
    if (currentRef != null) {
      for (final c in choices) {
        if (c.ref.path == currentRef.path) {
          current = c;
          break;
        }
      }
    }
    // Object sentinels distinguish three outcomes: pick (returns
    // _RefChoice), cancel (returns _kCancel), clear (returns _kClear).
    // null from barrier dismiss is treated as cancel.
    final selected = await showDialog<Object?>(
      context: context,
      builder: (dialogCtx) {
        return DialogSelect<_RefChoice>(
          title: title,
          items: choices,
          itemLabel: (c) => c.label,
          itemSearchString: (c) => c.searchText,
          itemGroupLabel: useGrouping ? (c) => c.groupLabel : null,
          initialSelection: current,
          tileType: DialogSelectTileType.radio,
          onCancel: () => Navigator.of(dialogCtx).pop(_kCancel),
          onSubmit: (res) => Navigator.of(dialogCtx).pop(res.firstOrNull),
          header: currentRef == null
              ? null
              : Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(dialogCtx).pop(_kClear),
                    icon: const Icon(Icons.clear, size: 18),
                    label: const Text('Clear'),
                  ),
                ),
        );
      },
    );

    if (!mounted) return;
    if (selected == null || identical(selected, _kCancel)) return;
    if (identical(selected, _kClear)) {
      setState(() => onChanged(null));
      return;
    }
    if (selected is _RefChoice) {
      setState(() => onChanged(selected.ref));
    }
  }

  String _labelFor(
    DocumentReference<Map<String, dynamic>>? ref,
    List<_RefChoice> choices,
  ) {
    if (ref == null) return 'Tap to choose';
    for (final c in choices) {
      if (c.ref.path == ref.path) return c.label;
    }
    return ref.id;
  }

  Widget _refRow({
    required String label,
    required IconData icon,
    required DocumentReference<Map<String, dynamic>>? ref,
    required List<_RefChoice> choices,
    required ValueChanged<DocumentReference<Map<String, dynamic>>?> onChanged,
    bool useGrouping = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openRefDialog(
          title: label,
          choices: choices,
          currentRef: ref,
          onChanged: onChanged,
          useGrouping: useGrouping,
        ),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.arrow_drop_down),
          ),
          child: Text(
            _labelFor(ref, choices),
            style: TextStyle(
              color: ref == null ? Colors.grey.shade500 : Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  Widget _textRow(
    TextEditingController ctl,
    String label, {
    IconData? icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctl,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon == null ? null : Icon(icon),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  /// Merges the freshly-typed text back into a localized field map while
  /// preserving translations for other locales. For simple string sources
  /// (the scraper default), we continue to write a plain string.
  dynamic _mergeLocalized(dynamic original, String latest) {
    final trimmed = latest.trim();
    if (original is! Map) {
      return trimmed;
    }
    final locale = ProcessLocalizationUtils.normalizeLocaleCode(_localeCode());
    final merged = <String, dynamic>{};
    original.forEach((key, value) {
      merged[key.toString()] = value;
    });
    if (trimmed.isEmpty) {
      merged.remove(locale);
    } else {
      merged[locale] = trimmed;
    }
    return merged.isEmpty ? trimmed : merged;
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? true)) return;
    setState(() => _saving = true);
    try {
      final db = CatalogFirebaseService.instance.firestore;
      final docRef = db.collection('object').doc(widget.docId);

      final updates = <String, dynamic>{
        'name': _mergeLocalized(_nameRaw, _nameCtl.text),
        'nameLower': _nameCtl.text.trim().toLowerCase(),
        'description': _mergeLocalized(_descriptionRaw, _descriptionCtl.text),
        'objectProductCode': _productCodeCtl.text.trim(),
        'objectBarcode': _upcCtl.text.trim(),
        'brand': _brandTextCtl.text.trim(),
        'productLine': _productLineCtl.text.trim(),
        'color': _colorCtl.text.trim(),
        'fragrance': _fragranceCtl.text.trim(),
        'containerType': _containerTypeCtl.text.trim(),
        'packagingType': _packagingTypeCtl.text.trim(),
        'canonicalUrl': _canonicalUrlCtl.text.trim(),
        'scalarUnitQuantity': _parseNum(_scalarUnitQtyCtl.text),
        'productWeight': _parseNum(_productWeightCtl.text),
        'packagingWeight': _parseNum(_packagingWeightCtl.text),
        'packagingLength': _parseNum(_packagingLengthCtl.text),
        'packagingWidth': _parseNum(_packagingWidthCtl.text),
        'packagingHeight': _parseNum(_packagingHeightCtl.text),
        'objectCategoryId': _objectCategoryId,
        'brandId': _brandId,
        'brandOwnerId': _brandOwnerId,
        'scalarId': _scalarId,
        'scalarUnitId': _scalarUnitId,
        'productWeightUnitId': _productWeightUnitId,
        'packagingWeightUnitId': _packagingWeightUnitId,
        'packagingDimensionsUnitId': _packagingDimensionsUnitId,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await docRef.update(updates);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  dynamic _parseNum(String s) {
    final trimmed = s.trim();
    if (trimmed.isEmpty) return null;
    final n = num.tryParse(trimmed);
    return n;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: const StandardAppBar(title: 'Edit Product'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 80),
          children: [
            ContainerActionWidget(
              title: 'Identity',
              actionText: '',
              content: Column(
                children: [
                  _textRow(_nameCtl, 'Name', icon: Icons.label_outline),
                  _textRow(
                    _descriptionCtl,
                    'Description',
                    icon: Icons.info_outlined,
                    maxLines: 4,
                  ),
                  _textRow(
                    _productCodeCtl,
                    'Product Code',
                    icon: Icons.confirmation_number_outlined,
                  ),
                  _textRow(_upcCtl, 'UPC', icon: Icons.qr_code),
                ],
              ),
            ),
            ContainerActionWidget(
              title: 'Brand',
              actionText: '',
              content: Column(
                children: [
                  _refRow(
                    label: 'Brand',
                    icon: Icons.branding_watermark_outlined,
                    ref: _brandId,
                    choices: _brandChoices,
                    onChanged: (v) => _brandId = v,
                  ),
                  _refRow(
                    label: 'Brand Owner',
                    icon: Icons.business_outlined,
                    ref: _brandOwnerId,
                    choices: _brandOwnerChoices,
                    onChanged: (v) => _brandOwnerId = v,
                  ),
                  _textRow(
                    _brandTextCtl,
                    'Brand (text)',
                    icon: Icons.edit_outlined,
                  ),
                ],
              ),
            ),
            ContainerActionWidget(
              title: 'Category',
              actionText: '',
              content: Column(
                children: [
                  _refRow(
                    label: 'Object Category',
                    icon: Icons.category,
                    ref: _objectCategoryId,
                    choices: _categoryChoices,
                    onChanged: (v) => _objectCategoryId = v,
                  ),
                  _textRow(
                    _productLineCtl,
                    'Object Subcategory / Product Line',
                    icon: Icons.subdirectory_arrow_right,
                  ),
                ],
              ),
            ),
            ContainerActionWidget(
              title: 'Content',
              actionText: '',
              content: Column(
                children: [
                  _refRow(
                    label: 'Usage (Scalar)',
                    icon: Icons.straighten,
                    ref: _scalarId,
                    choices: _scalarChoices,
                    onChanged: (v) => _scalarId = v,
                  ),
                  _refRow(
                    label: 'Content Unit',
                    icon: Icons.science_outlined,
                    ref: _scalarUnitId,
                    choices: _allScalarUnitChoices,
                    onChanged: (v) => _scalarUnitId = v,
                    useGrouping: true,
                  ),
                  _textRow(
                    _scalarUnitQtyCtl,
                    'Content Value',
                    icon: Icons.format_list_numbered,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ],
              ),
            ),
            ContainerActionWidget(
              title: 'Product Weight',
              actionText: '',
              content: Column(
                children: [
                  _refRow(
                    label: 'Product Weight Unit',
                    icon: Icons.balance_outlined,
                    ref: _productWeightUnitId,
                    choices: _allScalarUnitChoices,
                    onChanged: (v) => _productWeightUnitId = v,
                    useGrouping: true,
                  ),
                  _textRow(
                    _productWeightCtl,
                    'Product Weight Value',
                    icon: Icons.scale_outlined,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  _textRow(
                    _containerTypeCtl,
                    'Container Type',
                    icon: Icons.takeout_dining_outlined,
                  ),
                ],
              ),
            ),
            ContainerActionWidget(
              title: 'Packaging',
              actionText: '',
              content: Column(
                children: [
                  _textRow(
                    _packagingTypeCtl,
                    'Packaging Type',
                    icon: Icons.inventory_2_outlined,
                  ),
                  _refRow(
                    label: 'Packaging Weight Unit',
                    icon: Icons.balance_outlined,
                    ref: _packagingWeightUnitId,
                    choices: _allScalarUnitChoices,
                    onChanged: (v) => _packagingWeightUnitId = v,
                    useGrouping: true,
                  ),
                  _textRow(
                    _packagingWeightCtl,
                    'Packaging Weight Value',
                    icon: Icons.scale_outlined,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  _refRow(
                    label: 'Packaging Dimensions Unit',
                    icon: Icons.straighten,
                    ref: _packagingDimensionsUnitId,
                    choices: _allScalarUnitChoices,
                    onChanged: (v) => _packagingDimensionsUnitId = v,
                    useGrouping: true,
                  ),
                  _textRow(
                    _packagingLengthCtl,
                    'Length',
                    icon: Icons.height,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  _textRow(
                    _packagingWidthCtl,
                    'Width',
                    icon: Icons.swap_horiz,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  _textRow(
                    _packagingHeightCtl,
                    'Height',
                    icon: Icons.vertical_align_top,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ],
              ),
            ),
            ContainerActionWidget(
              title: 'Attributes',
              actionText: '',
              content: Column(
                children: [
                  _textRow(_colorCtl, 'Color', icon: Icons.palette_outlined),
                  _textRow(_fragranceCtl, 'Fragrance', icon: Icons.air),
                  _textRow(
                    _canonicalUrlCtl,
                    'Source URL',
                    icon: Icons.link,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CancelSaveBar(
        onCancel: () => Navigator.of(context).pop(false),
        onSave: _save,
        isSaving: _saving,
      ),
    );
  }
}

// Sentinels used to distinguish between three dialog outcomes: cancel,
// clear-the-selection, and pick-a-value. Identity-compared via `identical`
// so they can't collide with any real _RefChoice payload.
final Object _kCancel = Object();
final Object _kClear = Object();
