// lib/widgets/fields/multiSelect/property_multi_select.dart
// Stub for admin app — the full widget lives in the kleenops app.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kleenops_admin/widgets/buttons/button_select_text.dart';

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

  @override
  void initState() {
    super.initState();
    _loadProperties();
  }

  Future<void> _loadProperties() async {
    try {
      final query = await widget.companyId.collection('property').get();
      _propertyDocs = query.docs;
      _propertyDocs.sort((a, b) {
        final dataA = a.data() as Map<String, dynamic>?;
        final dataB = b.data() as Map<String, dynamic>?;
        final abbrA = (dataA?['propertyAbbreviation'] ?? a.id).toString();
        final abbrB = (dataB?['propertyAbbreviation'] ?? b.id).toString();
        return abbrA.compareTo(abbrB);
      });
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LinearProgressIndicator();
    if (_propertyDocs.isEmpty) return const Text('No properties found');

    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Properties',
        border: OutlineInputBorder(),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _propertyDocs.map((doc) {
          final data = doc.data() as Map<String, dynamic>?;
          final label = (data?['propertyAbbreviation'] ?? doc.id).toString();
          final isSelected = widget.selectedProperties.contains(doc.reference);
          return ButtonSelectText(
            label: label,
            selected: isSelected,
            selectedColor: widget.selectedColor,
            onTap: () {
              final newSel = List<DocumentReference>.from(widget.selectedProperties);
              if (isSelected) {
                newSel.remove(doc.reference);
              } else {
                newSel.add(doc.reference);
              }
              widget.onChanged(newSel);
            },
          );
        }).toList(),
      ),
    );
  }
}
