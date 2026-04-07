// lib/widgets/fields/multi_select/location_multi_select.dart
// Stub for admin app.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kleenops_admin/widgets/buttons/button_select_text.dart';

class LocationMultiSelectDropdown extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final List<DocumentReference<Map<String, dynamic>>> selectedFloors;
  final List<DocumentReference<Map<String, dynamic>>> selectedLocations;
  final ValueChanged<List<DocumentReference<Map<String, dynamic>>>> onChanged;
  final Color? selectedColor;

  const LocationMultiSelectDropdown({
    super.key,
    required this.companyRef,
    required this.selectedFloors,
    required this.selectedLocations,
    required this.onChanged,
    this.selectedColor,
  });

  @override
  State<LocationMultiSelectDropdown> createState() =>
      _LocationMultiSelectDropdownState();
}

class _LocationMultiSelectDropdownState
    extends State<LocationMultiSelectDropdown> {
  Future<List<Map<String, dynamic>>> _fetchLocations() async {
    final options = <Map<String, dynamic>>[];
    for (final floorRef in widget.selectedFloors) {
      final query = await widget.companyRef
          .collection('location')
          .where('floorId', isEqualTo: floorRef)
          .get();
      for (final doc in query.docs) {
        final data = doc.data();
        final label = (data['name'] ?? doc.id).toString();
        options.add({'locRef': doc.reference, 'label': label});
      }
    }
    options.sort(
        (a, b) => (a['label'] as String).compareTo(b['label'] as String));
    return options;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchLocations(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final options = snapshot.data!;
        if (options.isEmpty) return const Text('No locations found');
        return InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Locations',
            border: OutlineInputBorder(),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((option) {
              final ref = option['locRef']
                  as DocumentReference<Map<String, dynamic>>;
              final label = option['label'] as String;
              final isSelected = widget.selectedLocations.contains(ref);
              return ButtonSelectText(
                label: label,
                selected: isSelected,
                selectedColor: widget.selectedColor,
                onTap: () {
                  final newSel =
                      List<DocumentReference<Map<String, dynamic>>>.from(
                          widget.selectedLocations);
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
