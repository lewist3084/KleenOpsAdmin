//  object_multi_select.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kleenops_admin/features/objects/utils/company_object_file_images.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:shared_widgets/buttons/button_select_text.dart';
import 'package:shared_widgets/theme/app_palette.dart';
import 'package:shared_widgets/lists/standardViewGroup.dart';
import 'package:shared_widgets/search/search_control_strip.dart';
import 'package:shared_widgets/tiles/selectable_row_tile.dart';
import 'package:shared_widgets/utils/process_localization_utils.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';

class _ObjectOption {
  _ObjectOption({required this.ref, required this.name, required this.imageUrl});
  final DocumentReference ref;
  final String name;
  final String imageUrl;
}

class ObjectMultiSelectDropdown extends StatefulWidget {
  final DocumentReference companyId;
  final List<DocumentReference> selectedLocations;
  final List<DocumentReference> selectedObjects;
  final ValueChanged<List<DocumentReference>> onChanged;
  final Color? selectedColor;

  const ObjectMultiSelectDropdown({
    super.key,
    required this.companyId,
    required this.selectedLocations,
    required this.selectedObjects,
    required this.onChanged,
    this.selectedColor,
  });

  @override
  State<ObjectMultiSelectDropdown> createState() =>
      _ObjectMultiSelectDropdownState();
}

class _ObjectMultiSelectDropdownState
    extends State<ObjectMultiSelectDropdown> {
  Future<List<DocumentReference>> _queryObjects() async {
    if (widget.selectedLocations.isEmpty) return [];

    final invColl = widget.companyId.collection('objectInventory');
    final List<DocumentReference> refs = [];

    for (var i = 0; i < widget.selectedLocations.length; i += 10) {
      final chunk = widget.selectedLocations.skip(i).take(10).toList();
      final qSnap = await invColl.where('locationId', whereIn: chunk).get();
      for (final d in qSnap.docs) {
        final data = d.data();
        final r = data['companyObjectId'] as DocumentReference?;
        if (r != null) refs.add(r);
      }
    }

    final uniq = <String, DocumentReference>{};
    for (final r in refs) {
      uniq[r.id] = r;
    }
    return uniq.values.toList();
  }

  Future<Map<String, String>> _objectInfo(
    DocumentReference ref,
    String localeCode,
  ) async {
    final snap = await ref.get();
    final d = snap.data() as Map<String, dynamic>? ?? {};
    final resolvedLocal = ProcessLocalizationUtils.resolveLocalizedText(
      d['localName'],
      localeCode: localeCode,
      fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
    ).trim();
    final resolvedName = ProcessLocalizationUtils.resolveLocalizedText(
      d['name'],
      localeCode: localeCode,
      fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
    ).trim();
    final name = resolvedLocal.isNotEmpty
        ? resolvedLocal
        : (resolvedName.isNotEmpty ? resolvedName : ref.id);
    final companyRef =
        widget.companyId.withConverter<Map<String, dynamic>>(
      fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
      toFirestore: (data, _) => data,
    );
    final img = await CompanyObjectFileImages.primaryHeaderImageUrl(
      companyRef: companyRef,
      objectId: ref.id,
    );
    return {'name': name, 'img': img};
  }

  Future<List<_ObjectOption>> _loadOptions(String localeCode) async {
    final refs = await _queryObjects();
    final infos = await Future.wait(refs.map((r) => _objectInfo(r, localeCode)));
    final options = <_ObjectOption>[];
    for (var i = 0; i < refs.length; i++) {
      options.add(_ObjectOption(
        ref: refs[i],
        name: infos[i]['name'] ?? refs[i].id,
        imageUrl: infos[i]['img'] ?? '',
      ));
    }
    options.sort((a, b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return options;
  }

  Future<void> _openSelector() async {
    final localeCode = Localizations.localeOf(context).languageCode;
    final effectiveColor =
        widget.selectedColor ?? AppPaletteScope.of(context).primary2;
    final options = await _loadOptions(localeCode);
    if (!mounted) return;

    if (options.isEmpty) {
      SnackbarService.instance.showSnackBar(
        const SnackBar(duration: Duration(seconds: 5), content: Text('No objects found for those locations.')),
      );
      return;
    }

    var tmp = List<DocumentReference>.from(widget.selectedObjects);
    final searchController = TextEditingController();
    var query = '';

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            final q = query.trim().toLowerCase();
            final filtered = q.isEmpty
                ? options
                : options
                    .where((o) => o.name.toLowerCase().contains(q))
                    .toList();
            return DialogAction(
              title: 'Select Objects',
              wrapContentInScrollView: false,
              content: SizedBox(
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.6,
                child: StandardViewGroup.buildViewFromItems<_ObjectOption>(
                  items: filtered,
                  groupBy: (_) => '',
                  disableGrouping: true,
                  padding: EdgeInsets.zero,
                  emptyMessage: 'No results found.',
                  itemBuilder: (opt) {
                    final sel = tmp.contains(opt.ref);
                    final hasImg = opt.imageUrl.startsWith('http');
                    return SelectableRowTile<_ObjectOption>(
                      value: opt,
                      selected: sel,
                      onTap: () {
                        setState(() {
                          if (sel) {
                            tmp.remove(opt.ref);
                          } else {
                            tmp.add(opt.ref);
                          }
                        });
                      },
                      label: opt.name,
                      imageUrl: hasImg ? opt.imageUrl : null,
                      primaryColor: effectiveColor,
                    );
                  },
                ),
              ),
              searchBar: SearchControlStrip(
                controller: searchController,
                hintText: 'Search',
                onChanged: (value) => setState(() => query = value),
              ),
              cancelText: 'Cancel',
              actionText: 'OK',
              onCancel: () => Navigator.pop(ctx),
              onAction: () {
                Navigator.pop(ctx);
                widget.onChanged(tmp);
              },
            );
          },
        );
      },
    );

    searchController.dispose();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final localeCode = Localizations.localeOf(context).languageCode;
    final effectiveColor =
        widget.selectedColor ?? AppPaletteScope.of(context).primary2;
    return GestureDetector(
      onTap: _openSelector,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Objects',
          border: OutlineInputBorder(),
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.selectedObjects.isEmpty
              ? [const Text('Tap to select objects')]
              : widget.selectedObjects.map((ref) {
                  return FutureBuilder<Map<String, String>>(
                    future: _objectInfo(ref, localeCode),
                    builder: (_, snap) {
                      final info = snap.data;
                      final label = info?['name'] ?? ref.id;
                      final img = info?['img'] ?? '';
                      final hasImg = img.startsWith('http');
                      final isSelected = widget.selectedObjects.contains(ref);

                      return ButtonSelectText(
                        label: label,
                        selected: isSelected,
                        selectedColor: effectiveColor,
                        onTap: () {
                          final newSelection =
                              List<DocumentReference>.from(widget.selectedObjects);
                          if (isSelected) {
                            newSelection.remove(ref);
                          } else {
                            newSelection.add(ref);
                          }
                          widget.onChanged(newSelection);
                        },

                        // PASS current image URL as leadingImageUrl:
                        leadingImageUrl: hasImg ? img : null,

                        // if you want a trailing image, provide trailingImageUrl here
                        trailingImageUrl: null,
                      );
                    },
                  );
                }).toList(),
        ),
      ),
    );
  }
}
