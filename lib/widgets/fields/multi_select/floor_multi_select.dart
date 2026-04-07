// lib/widgets/fields/multi_select/floor_multi_select.dart
// Stub for admin app.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kleenops_admin/widgets/buttons/button_select_text.dart';

class FloorMultiSelectDropdown extends StatefulWidget {
  final List<DocumentReference> selectedBuildings;
  final List<DocumentReference> selectedFloors;
  final ValueChanged<List<DocumentReference>> onChanged;
  final Color? selectedColor;

  const FloorMultiSelectDropdown({
    super.key,
    required this.selectedBuildings,
    required this.selectedFloors,
    required this.onChanged,
    this.selectedColor,
  });

  @override
  State<FloorMultiSelectDropdown> createState() =>
      _FloorMultiSelectDropdownState();
}

class _FloorMultiSelectDropdownState extends State<FloorMultiSelectDropdown> {
  Future<List<Map<String, dynamic>>> _fetchFloors() async {
    final options = <Map<String, dynamic>>[];
    for (final buildingRef in widget.selectedBuildings) {
      final companyRef = buildingRef.parent.parent;
      if (companyRef == null) continue;
      final query = await companyRef
          .collection('floor')
          .where('buildingId', isEqualTo: buildingRef)
          .get();
      for (final doc in query.docs) {
        final data = doc.data();
        final label = (data['name'] ?? doc.id).toString();
        options.add({'floorRef': doc.reference, 'label': label});
      }
    }
    options.sort(
        (a, b) => (a['label'] as String).compareTo(b['label'] as String));
    return options;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchFloors(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final options = snapshot.data!;
        if (options.isEmpty) return const Text('No floors found');
        return InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Floors',
            border: OutlineInputBorder(),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((option) {
              final ref = option['floorRef'] as DocumentReference;
              final label = option['label'] as String;
              final isSelected = widget.selectedFloors.contains(ref);
              return ButtonSelectText(
                label: label,
                selected: isSelected,
                selectedColor: widget.selectedColor,
                onTap: () {
                  final newSel =
                      List<DocumentReference>.from(widget.selectedFloors);
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
