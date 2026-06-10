//  property_multi_select.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_widgets/buttons/button_select_text.dart';
import 'package:shared_widgets/theme/app_palette.dart';
import 'package:shared_widgets/utils/process_localization_utils.dart';

class PropertyMultiSelectDropdown extends StatefulWidget {
  final DocumentReference companyId;
  final List<DocumentReference> selectedProperties;
  final ValueChanged<List<DocumentReference>> onChanged;
  final Color? selectedColor;

  const PropertyMultiSelectDropdown({
    super.key,
    required this.companyId,
    required this.selectedProperties,
    required this.onChanged,
    this.selectedColor,
  });

  @override
  State<PropertyMultiSelectDropdown> createState() =>
      _PropertyMultiSelectDropdownState();
}

class _PropertyMultiSelectDropdownState
    extends State<PropertyMultiSelectDropdown> {
  bool _loading = true;
  List<DocumentSnapshot> _propertyDocs = [];

  String _resolveAbbreviation(dynamic value, String fallback) {
    if (value == null) return fallback;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isNotEmpty ? trimmed : fallback;
    }
    final normalized = ProcessLocalizationUtils.normalizeLocalizedField(value);
    if (normalized == null || normalized.isEmpty) return fallback;
    final source = normalized['source'];
    if (source is String) {
      final trimmed = source.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    final lang = normalized['lang'];
    if (lang is String) {
      final langKey = ProcessLocalizationUtils.normalizeLocaleCode(lang);
      if (langKey.isNotEmpty) {
        final langValue = normalized[langKey];
        if (langValue is String) {
          final trimmed = langValue.trim();
          if (trimmed.isNotEmpty) return trimmed;
        }
      }
    }
    for (final entry in normalized.entries) {
      if (entry.key == 'source' || entry.key == 'lang') continue;
      final val = entry.value;
      if (val is String) {
        final trimmed = val.trim();
        if (trimmed.isNotEmpty) return trimmed;
      }
    }
    return fallback;
  }

  @override
  void initState() {
    super.initState();
    _loadProperties();
  }

  Future<void> _loadProperties() async {
    try {
      final query = await widget.companyId.collection('property').get();
      _propertyDocs = query.docs;
      // Optional: sort by propertyAbbreviation
      _propertyDocs.sort((a, b) {
        final dataA = a.data() as Map<String, dynamic>?;
        final dataB = b.data() as Map<String, dynamic>?;
        final abbrA =
            _resolveAbbreviation(dataA?['propertyAbbreviation'], a.id);
        final abbrB =
            _resolveAbbreviation(dataB?['propertyAbbreviation'], b.id);
        return abbrA.compareTo(abbrB);
      });
    } catch (e) {
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const LinearProgressIndicator();
    }
    if (_propertyDocs.isEmpty) {
      return const Text('No properties found');
    }

    final effectiveColor =
        widget.selectedColor ?? AppPaletteScope.of(context).primary2;
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Properties',
        border: OutlineInputBorder(),
      ),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        children: _propertyDocs.map((doc) {
          final data = doc.data() as Map<String, dynamic>?;
          final abbreviation =
              _resolveAbbreviation(data?['propertyAbbreviation'], doc.id);
          final isSelected =
              widget.selectedProperties.contains(doc.reference);
          return ButtonSelectText(
            label: abbreviation,
            selected: isSelected,
            selectedColor: effectiveColor,
            onTap: () {
              final newSelection =
                  List<DocumentReference>.from(
                      widget.selectedProperties);
              if (isSelected) {
                newSelection.remove(doc.reference);
              } else {
                newSelection.add(doc.reference);
              }
              widget.onChanged(newSelection);
            },
          );
        }).toList(),
      ),
    );
  }
}
