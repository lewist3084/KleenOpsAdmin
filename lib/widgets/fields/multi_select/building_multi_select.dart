//  building_multi_select.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_widgets/buttons/button_select_text.dart';
import 'package:shared_widgets/theme/app_palette.dart';
import 'package:shared_widgets/utils/process_localization_utils.dart';
import 'package:kleenops_admin/l10n/app_localizations.dart';

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
  Future<List<Map<String, dynamic>>> _fetchBuildings(
      BuildContext context) async {
    final localeCode =
        Localizations.localeOf(context).languageCode.trim().toLowerCase();
    final effectiveLocale = localeCode.isNotEmpty
        ? localeCode
        : ProcessLocalizationUtils.defaultLocaleCode;
    List<Map<String, dynamic>> buildingOptions = [];
    for (final propertyRef in widget.selectedProperties) {
      final propertySnap = await propertyRef.get();
      final propertyData = propertySnap.data() as Map<String, dynamic>?;
      final propertyAbbr = ProcessLocalizationUtils.resolveLocalizedText(
        propertyData?['propertyAbbreviation'],
        localeCode: effectiveLocale,
        fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
      ).trim();
      final propertyName = ProcessLocalizationUtils.resolveLocalizedText(
        propertyData?['name'],
        localeCode: effectiveLocale,
        fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
      ).trim();
      final propertyLabel = propertyAbbr.isNotEmpty
          ? propertyAbbr
          : (propertyName.isNotEmpty ? propertyName : propertyRef.id);

      final companyRef = propertyRef.parent.parent;
      if (companyRef == null) continue;
      final buildingQuery = await companyRef
          .collection('building')
          .where('propertyId', isEqualTo: propertyRef)
          .get();
      for (final buildingDoc in buildingQuery.docs) {
        final buildingData = buildingDoc.data() as Map<String, dynamic>?;
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
            : (buildingName.isNotEmpty ? buildingName : buildingDoc.id);
        buildingOptions.add({
          'buildingRef': buildingDoc.reference,
          'label': '$propertyLabel: $buildingLabel',
        });
      }
    }
    buildingOptions
        .sort((a, b) => (a['label'] as String).compareTo(b['label'] as String));
    return buildingOptions;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final effectiveColor =
        widget.selectedColor ?? AppPaletteScope.of(context).primary2;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchBuildings(context),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const LinearProgressIndicator();
        }
        final options = snapshot.data!;
        if (options.isEmpty) {
          return Text(loc.facilitiesPropertyDetailsNoBuildings);
        }
        return InputDecorator(
          decoration: InputDecoration(
            labelText: loc.facilitiesPropertyDetailsBuildingsTitle,
            border: const OutlineInputBorder(),
          ),
          child: Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: options.map((option) {
              final buildingRef = option['buildingRef'] as DocumentReference;
              final label = option['label'] as String;
              final isSelected = widget.selectedBuildings.contains(buildingRef);
              return ButtonSelectText(
                label: label,
                selected: isSelected,
                selectedColor: effectiveColor,
                onTap: () {
                  final newSelection =
                      List<DocumentReference>.from(widget.selectedBuildings);
                  if (isSelected) {
                    newSelection.remove(buildingRef);
                  } else {
                    newSelection.add(buildingRef);
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
