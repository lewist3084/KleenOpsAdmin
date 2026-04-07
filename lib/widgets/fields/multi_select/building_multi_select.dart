// lib/widgets/fields/multi_select/building_multi_select.dart
// Stub for admin app.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kleenops_admin/widgets/buttons/button_select_text.dart';

class BuildingMultiSelectDropdown extends StatefulWidget {
  final List<DocumentReference> selectedProperties;
  final List<DocumentReference> selectedBuildings;
  final ValueChanged<List<DocumentReference>> onChanged;
  final Color? selectedColor;

  const BuildingMultiSelectDropdown({
    super.key,
    required this.selectedProperties,
    required this.selectedBuildings,
    required this.onChanged,
    this.selectedColor,
  });

  @override
  State<BuildingMultiSelectDropdown> createState() =>
      _BuildingMultiSelectDropdownState();
}

class _BuildingMultiSelectDropdownState
    extends State<BuildingMultiSelectDropdown> {
  Future<List<Map<String, dynamic>>> _fetchBuildings() async {
    final options = <Map<String, dynamic>>[];
    for (final propertyRef in widget.selectedProperties) {
      final companyRef = propertyRef.parent.parent;
      if (companyRef == null) continue;
      final query = await companyRef
          .collection('building')
          .where('propertyId', isEqualTo: propertyRef)
          .get();
      for (final doc in query.docs) {
        final data = doc.data();
        final label = (data['buildingAbbreviation'] ?? data['name'] ?? doc.id)
            .toString();
        options.add({'buildingRef': doc.reference, 'label': label});
      }
    }
    options.sort(
        (a, b) => (a['label'] as String).compareTo(b['label'] as String));
    return options;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchBuildings(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final options = snapshot.data!;
        if (options.isEmpty) return const Text('No buildings found');
        return InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Buildings',
            border: OutlineInputBorder(),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((option) {
              final ref = option['buildingRef'] as DocumentReference;
              final label = option['label'] as String;
              final isSelected = widget.selectedBuildings.contains(ref);
              return ButtonSelectText(
                label: label,
                selected: isSelected,
                selectedColor: widget.selectedColor,
                onTap: () {
                  final newSel =
                      List<DocumentReference>.from(widget.selectedBuildings);
                  if (isSelected) {
                    newSel.remove(ref);
                  } else {
                    newSel.add(ref);
                  }
                  widget.onChanged(newSel);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
