//  floor_multi_select.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_widgets/buttons/button_select_text.dart';
import 'package:shared_widgets/theme/app_palette.dart';
import 'package:shared_widgets/utils/process_localization_utils.dart';
import 'package:kleenops_admin/l10n/app_localizations.dart';

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
  Future<List<Map<String, dynamic>>> _fetchFloors(BuildContext context) async {
    final localeCode =
        Localizations.localeOf(context).languageCode.trim().toLowerCase();
    final effectiveLocale = localeCode.isNotEmpty
        ? localeCode
        : ProcessLocalizationUtils.defaultLocaleCode;
    List<Map<String, dynamic>> floorOptions = [];
    for (final buildingRef in widget.selectedBuildings) {
      final buildingSnap = await buildingRef.get();
      final buildingData = buildingSnap.data() as Map<String, dynamic>?;
      final buildingAbbr = ProcessLocalizationUtils.resolveLocalizedText(
        (buildingData?['buildingAbbreviation'] ??
            buildingData?['nameAbbreviation']),
        localeCode: effectiveLocale,
        fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
      ).trim();
      final buildingName = ProcessLocalizationUtils.resolveLocalizedText(
        buildingData?['name'],
        localeCode: effectiveLocale,
        fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
      ).trim();
      final buildingLabel = buildingAbbr.isNotEmpty
          ? buildingAbbr
          : (buildingName.isNotEmpty ? buildingName : buildingRef.id);

      final companyRef = buildingRef.parent.parent;
      if (companyRef == null) continue;
      final floorQuery = await companyRef
          .collection('floor')
          .where('buildingId', isEqualTo: buildingRef)
          .get();
      for (final floorDoc in floorQuery.docs) {
        final floorData = floorDoc.data() as Map<String, dynamic>?;
        final floorName = ProcessLocalizationUtils.resolveLocalizedText(
          floorData?['name'],
          localeCode: effectiveLocale,
          fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
        ).trim();
        final floorLabel = floorName.isNotEmpty ? floorName : floorDoc.id;
        floorOptions.add({
          'floorRef': floorDoc.reference,
          'label': '$buildingLabel: $floorLabel',
        });
      }
    }
    floorOptions.sort(
      (a, b) => (a['label'] as String).compareTo(b['label'] as String),
    );
    return floorOptions;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final effectiveColor =
        widget.selectedColor ?? AppPaletteScope.of(context).primary2;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchFloors(context),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const LinearProgressIndicator();
        }
        final options = snapshot.data!;
        if (options.isEmpty) {
          return Text(loc.facilitiesBuildingDetailsNoFloors);
        }
        return InputDecorator(
          decoration: InputDecoration(
            labelText: loc.facilitiesBuildingDetailsFloorsTitle,
            border: const OutlineInputBorder(),
          ),
          child: Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: options.map((option) {
              final floorRef = option['floorRef'] as DocumentReference;
              final label = option['label'] as String;
              final isSelected = widget.selectedFloors.contains(floorRef);
              return ButtonSelectText(
                label: label,
                selected: isSelected,
                selectedColor: effectiveColor,
                onTap: () {
                  final newSelection =
                      List<DocumentReference>.from(widget.selectedFloors);
                  if (isSelected) {
                    newSelection.remove(floorRef);
                  } else {
                    newSelection.add(floorRef);
                  }
                  widget.onChanged(newSelection);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
