// lib/widgets/fields/location_multi_select.dart
// rev 2025-06-14g – precomputes and sorts by “building: floor: location” label in the dialog

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_widgets/dialogs/dialog_select.dart';
import 'package:shared_widgets/search/search_field_action.dart';
import 'package:shared_widgets/buttons/button_select_text.dart';
import 'package:shared_widgets/theme/app_palette.dart';
import 'package:shared_widgets/tiles/selectable_row_tile.dart';
import 'package:shared_widgets/lists/standardViewGroup.dart';
import 'package:shared_widgets/utils/process_localization_utils.dart';
import 'package:kleenops_admin/l10n/app_localizations.dart';
import 'package:shared_widgets/utils/location_display_utils.dart';
import 'package:kleenops_admin/features/facilities/utils/facilities_file_images.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';

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
  final Map<String, Future<DocumentSnapshot<Map<String, dynamic>>>>
      _locFutureCache = {};
  final Map<String, Future<DocumentSnapshot<Map<String, dynamic>>>>
      _floorFutureCache = {};

  // Fetch all location refs under the chosen floors
  Future<List<DocumentReference<Map<String, dynamic>>>>
      _fetchLocationRefs() async {
    final refs = <DocumentReference<Map<String, dynamic>>>[];
    for (final floorRef in widget.selectedFloors) {
      final q = await widget.companyRef
          .collection('location')
          .where('floorId', isEqualTo: floorRef)
          .get();
      refs.addAll(q.docs.map((d) => d.reference));
    }
    return refs;
  }

  // Build the label from the ConcatenatedName field.
  Future<String> _labelOf(
    DocumentReference<Map<String, dynamic>> locRef,
    String effectiveLocale,
  ) async {
    final locSnap = await locRef.get();
    final loc = locSnap.data() ?? <String, dynamic>{};
    final displayName =
        LocationDisplayUtils.resolveConcatenatedNameFromData(
      loc,
      effectiveLocale,
    );
    if (displayName.isNotEmpty) {
      return displayName;
    }
    return locRef.id;
  }

  String _groupFromLabel(String label) {
    final parts = label
        .split(':')
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    if (parts.length >= 2) {
      return '${parts[0]} - ${parts[1]}';
    }
    return parts.isNotEmpty ? parts.first : 'Locations';
  }

  Future<void> _openDialog() async {
    FocusScope.of(context).unfocus();
    final effectiveColor =
        widget.selectedColor ?? AppPaletteScope.of(context).primary2;
    final loc = AppLocalizations.of(context)!;
    final localeCode =
        Localizations.localeOf(context).languageCode.trim().toLowerCase();
    final effectiveLocale = localeCode.isNotEmpty
        ? localeCode
        : ProcessLocalizationUtils.defaultLocaleCode;
    var temp = List<DocumentReference<Map<String, dynamic>>>.from(
        widget.selectedLocations);

    // show progress while fetching locations/labels
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    // 1) fetch refs, 2) precompute labels, 3) sort
    final refs = await _fetchLocationRefs();
    if (!mounted) return;
    if (refs.isEmpty) {
      if (!mounted) return;
      Navigator.of(context).pop();
      if (!mounted) return;
      SnackbarService.instance.showSnackBar(
        SnackBar(duration: const Duration(seconds: 5), content: Text(loc.processesFormNoItemsFound)),
      );
      return;
    }

    final options = await Future.wait(refs.map((r) async {
      final lbl = await _labelOf(r, effectiveLocale);
      return _LocationOption(
        ref: r,
        label: lbl,
        group: _groupFromLabel(lbl),
      );
    }));
    if (!mounted) return;
    options.sort((a, b) => a.label.compareTo(b.label));

    if (!mounted) return;
    Navigator.of(context).pop(); // close progress

    final searchC = TextEditingController();
    String search = '';

    await showDialog(
      context: context,
      builder: (ctx) => DialogAction(
        title: 'Select Locations',
        cancelText: loc.commonCancel,
        actionText: loc.commonOk,
        onCancel: () => Navigator.pop(ctx),
        onAction: () {
          Navigator.pop(ctx);
          widget.onChanged(temp);
        },
        wrapContentInScrollView: false,
        content: StatefulBuilder(
          builder: (context, setDialog) {
            final filtered = options
                .where(
                  (opt) => opt.label.toLowerCase().contains(search),
                )
                .toList();
            final filteredRefs = filtered.map((opt) => opt.ref).toList();
            final allFilteredSelected = filteredRefs.isNotEmpty &&
                filteredRefs.every((ref) => temp.contains(ref));

            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SearchFieldAction(
                    controller: searchC,
                    labelText: loc.commonSearch,
                    onChanged: (v) => setDialog(() => search = v.toLowerCase()),
                    actionIcon: Icon(
                      allFilteredSelected
                          ? Icons.check_box_outline_blank
                          : Icons.check_box,
                    ),
                    actionTooltip: allFilteredSelected
                        ? 'Unselect all shown'
                        : 'Select all shown',
                    onAction: () {
                      if (filteredRefs.isEmpty) return;
                      setDialog(() {
                        if (allFilteredSelected) {
                          temp.removeWhere(
                            (loc) => filteredRefs.contains(loc),
                          );
                        } else {
                          for (final ref in filteredRefs) {
                            if (!temp.contains(ref)) {
                              temp.add(ref);
                            }
                          }
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(loc.processesFormNoItemsFound),
                          )
                        : Scrollbar(
                            thumbVisibility: filtered.length > 10,
                            child: StandardViewGroup.buildViewFromItems<
                                _LocationOption>(
                              items: filtered,
                              groupBy: (opt) => opt.group,
                              disableGrouping: true,
                              itemBuilder: (opt) {
                                final locRef = opt.ref;
                                final selected = temp.contains(locRef);

                                return FutureBuilder<
                                    DocumentSnapshot<Map<String, dynamic>>>(
                                  future: _locFutureCache[locRef.path] ??=
                                      locRef.get(),
                                  builder: (_, locSnap) {
                                    if (!locSnap.hasData ||
                                        !(locSnap.data?.exists ?? false)) {
                                      return SelectableRowTile<DocumentReference<Map<String, dynamic>>>(
                                        value: locRef,
                                        selected: selected,
                                        onTap: () {
                                          setDialog(() {
                                            if (selected) {
                                              temp.remove(locRef);
                                            } else {
                                              temp.add(locRef);
                                            }
                                          });
                                        },
                                        label: opt.label,
                                        imageFit: BoxFit.contain,
                                        primaryColor: effectiveColor,
                                      );
                                    }
                                    final locData = locSnap.data!.data()!;
                                    final floorRef = locData['floorId']
                                        as DocumentReference<
                                            Map<String, dynamic>>?;
                                    if (floorRef == null) {
                                      return SelectableRowTile<DocumentReference<Map<String, dynamic>>>(
                                        value: locRef,
                                        selected: selected,
                                        onTap: () {
                                          setDialog(() {
                                            if (selected) {
                                              temp.remove(locRef);
                                            } else {
                                              temp.add(locRef);
                                            }
                                          });
                                        },
                                        label: opt.label,
                                        imageFit: BoxFit.contain,
                                        primaryColor: effectiveColor,
                                      );
                                    }

                                    return FutureBuilder<
                                        DocumentSnapshot<Map<String, dynamic>>>(
                                      future: _floorFutureCache[floorRef.path] ??=
                                          floorRef.get(),
                                      builder: (_, floorSnap) {
                                        if (!floorSnap.hasData ||
                                            !(floorSnap.data?.exists ??
                                                false)) {
                                          return SelectableRowTile<DocumentReference<Map<String, dynamic>>>(
                                            value: locRef,
                                            selected: selected,
                                            onTap: () {
                                              setDialog(() {
                                                if (selected) {
                                                  temp.remove(locRef);
                                                } else {
                                                  temp.add(locRef);
                                                }
                                              });
                                            },
                                            label: opt.label,
                                            imageFit: BoxFit.contain,
                                            primaryColor: effectiveColor,
                                          );
                                        }
                                        final floor = floorSnap.data!.data()!;
                                        final locImagesFuture =
                                            FacilityFileImages
                                                .headerImageEntries(
                                          facilityRef:locRef,
                                        );
                                        final floorImagesFuture =
                                            FacilityFileImages
                                                .headerImageEntries(
                                          facilityRef:floorRef,
                                        );
                                        return FutureBuilder<
                                            List<List<Map<String, dynamic>>>>(
                                          future: Future.wait([
                                            locImagesFuture,
                                            floorImagesFuture,
                                          ]),
                                          builder: (context, imageSnap) {
                                            final imageLists = imageSnap.data ??
                                                const <List<Map<String, dynamic>>>[
                                                  <Map<String, dynamic>>[],
                                                  <Map<String, dynamic>>[],
                                                ];
                                            final locImages = imageLists[0];
                                            final floorImages = imageLists[1];
                                            final locImageUrl =
                                                locImages.isNotEmpty
                                                    ? (locImages.first['url']
                                                            as String?)
                                                        ?.trim()
                                                    : null;
                                            final floorImageUrl =
                                                floorImages.isNotEmpty
                                                    ? (floorImages.first['url']
                                                            as String?)
                                                        ?.trim()
                                                    : null;
                                            final imageUrl =
                                                (locImageUrl != null &&
                                                        locImageUrl.isNotEmpty)
                                                    ? locImageUrl
                                                    : (floorImageUrl ?? '');
                                            final w =
                                                (floor['imageWidth'] as num?)
                                                        ?.toDouble() ??
                                                    600;
                                            final h =
                                                (floor['imageHeight'] as num?)
                                                        ?.toDouble() ??
                                                    800;
                                            final xy = locData['xy']
                                                as Map<String, dynamic>?;

                                            return SelectableRowTile<DocumentReference<Map<String, dynamic>>>(
                                              value: locRef,
                                              selected: selected,
                                              onTap: () {
                                                setDialog(() {
                                                  if (selected) {
                                                    temp.remove(locRef);
                                                  } else {
                                                    temp.add(locRef);
                                                  }
                                                });
                                              },
                                              label: opt.label,
                                              imageFit: BoxFit.contain,
                                              imageUrl: imageUrl.isNotEmpty
                                                  ? imageUrl
                                                  : null,
                                              floorImgWidth: w,
                                              floorImgHeight: h,
                                              pinXAbsolute:
                                                  (xy?['x'] as num?)
                                                          ?.toDouble() ??
                                                      0,
                                              pinYAbsolute:
                                                  (xy?['y'] as num?)
                                                          ?.toDouble() ??
                                                      0,
                                              primaryColor: effectiveColor,
                                            );
                                          },
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                              itemSort: (a, b) => a.label.compareTo(b.label),
                              shrinkWrap: false,
                              physics: const ClampingScrollPhysics(),
                              padding: const EdgeInsets.only(bottom: 12),
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => searchC.dispose());
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final localeCode =
        Localizations.localeOf(context).languageCode.trim().toLowerCase();
    final effectiveLocale = localeCode.isNotEmpty
        ? localeCode
        : ProcessLocalizationUtils.defaultLocaleCode;
    final effectiveColor =
        widget.selectedColor ?? AppPaletteScope.of(context).primary2;
    return GestureDetector(
      onTap: _openDialog,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: loc.fieldInfoFacilitiesPropertyLocationTitle,
          border: const OutlineInputBorder(),
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.selectedLocations.isEmpty
              ? [Text(loc.processesFormTapToSelectItems)]
              : widget.selectedLocations.map((locRef) {
                  return FutureBuilder<String>(
                    future: _labelOf(locRef, effectiveLocale),
                    builder: (_, snap) {
                      final label = snap.data ?? 'Loading…';
                      final sel = widget.selectedLocations.contains(locRef);
                      return ButtonSelectText(
                        label: label,
                        selected: sel,
                        selectedColor: effectiveColor,
                        onTap: () {
                          final newSel = List<
                                  DocumentReference<Map<String, dynamic>>>.from(
                              widget.selectedLocations);
                          if (sel) {
                            newSel.remove(locRef);
                          } else {
                            newSel.add(locRef);
                          }
                          widget.onChanged(newSel);
                        },
                      );
                    },
                  );
                }).toList(),
        ),
      ),
    );
  }
}

class _LocationOption {
  const _LocationOption({
    required this.ref,
    required this.label,
    required this.group,
  });

  final DocumentReference<Map<String, dynamic>> ref;
  final String label;
  final String group;
}



