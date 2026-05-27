//  object_process_multi_select.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:shared_widgets/buttons/button_select_text.dart';
import 'package:shared_widgets/theme/app_palette.dart';
import 'package:shared_widgets/lists/standardViewGroup.dart';
import 'package:shared_widgets/search/search_control_strip.dart';
import 'package:shared_widgets/tiles/selectable_row_tile.dart';
import 'package:shared_widgets/utils/process_localization_utils.dart';
import 'package:kleenops_admin/features/objects/utils/company_object_file_images.dart';
import 'package:kleenops_admin/features/objects/utils/object_process_file_images.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';

class _ProcessRow {
  _ProcessRow({
    required this.ref,
    required this.objectName,
    required this.processName,
    required this.imageUrl,
  });

  final DocumentReference ref;
  final String objectName;
  final String processName;
  final String imageUrl;
}

class ObjectProcessMultiSelectDropdown extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final List<DocumentReference> selectedObjects;
  final List<DocumentReference> selectedObjectProcesses;
  final ValueChanged<List<DocumentReference>> onChanged;
  final Color? selectedColor;

  const ObjectProcessMultiSelectDropdown({
    super.key,
    required this.companyRef,
    required this.selectedObjects,
    required this.selectedObjectProcesses,
    required this.onChanged,
    this.selectedColor,
  });

  @override
  State<ObjectProcessMultiSelectDropdown> createState() =>
      _ObjectProcessMultiSelectDropdownState();
}

class _ObjectProcessMultiSelectDropdownState
    extends State<ObjectProcessMultiSelectDropdown> {
  Future<List<_ProcessRow>> _loadRows(String localeCode) async {
    final rowsPerObject = await Future.wait(
      widget.selectedObjects.map((objRef) => _loadObjectRows(objRef, localeCode)),
    );
    final all = rowsPerObject.expand((rs) => rs).toList()
      ..sort((a, b) {
        final byObj = a.objectName.toLowerCase().compareTo(b.objectName.toLowerCase());
        if (byObj != 0) return byObj;
        return a.processName.toLowerCase().compareTo(b.processName.toLowerCase());
      });
    return all;
  }

  Future<List<_ProcessRow>> _loadObjectRows(
    DocumentReference objRef,
    String localeCode,
  ) async {
    final objSnap = await objRef.get();
    final objData = (objSnap.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
    final resolvedObj = ProcessLocalizationUtils.resolveLocalizedText(
      objData['localName'] ?? objData['name'],
      localeCode: localeCode,
      fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
    ).trim();
    final objectName = resolvedObj.isNotEmpty ? resolvedObj : objRef.id;

    // Admin top-level objectProcess collection.
    final procSnap = await FirebaseFirestore.instance
        .collection('objectProcess')
        .where('companyObjectId', isEqualTo: objRef)
        .get();

    return Future.wait(procSnap.docs.map((doc) async {
      final m = doc.data();
      final resolvedName = ProcessLocalizationUtils.resolveLocalizedText(
        m['objectProcessName'] ?? m['name'] ?? m['processName'],
        localeCode: localeCode,
        fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
      ).trim();
      final processName = resolvedName.isNotEmpty ? resolvedName : doc.id;
      final img = await ObjectProcessFileImages.primaryHeaderImageUrl(
        companyRef: widget.companyRef,
        processRef: doc.reference,
      );
      return _ProcessRow(
        ref: doc.reference,
        objectName: objectName,
        processName: processName,
        imageUrl: img,
      );
    }));
  }

  Future<void> _openSelector() async {
    if (widget.selectedObjects.isEmpty) return;

    final localeCode = Localizations.localeOf(context).languageCode;
    final effectiveColor =
        widget.selectedColor ?? AppPaletteScope.of(context).primary2;
    final rows = await _loadRows(localeCode);
    if (!mounted) return;

    if (rows.isEmpty) {
      SnackbarService.instance.showSnackBar(
        const SnackBar(
            duration: Duration(seconds: 5),
            content: Text('No processes found for those objects.')),
      );
      return;
    }

    var tmp = List<DocumentReference>.from(widget.selectedObjectProcesses);
    final searchController = TextEditingController();
    var query = '';

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            final q = query.trim().toLowerCase();
            final filtered = q.isEmpty
                ? rows
                : rows
                    .where((r) =>
                        r.processName.toLowerCase().contains(q) ||
                        r.objectName.toLowerCase().contains(q))
                    .toList();
            return DialogAction(
              title: 'Select Processes',
              wrapContentInScrollView: false,
              content: SizedBox(
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.6,
                child: StandardViewGroup.buildViewFromItems<_ProcessRow>(
                  items: filtered,
                  groupBy: (r) => r.objectName,
                  padding: EdgeInsets.zero,
                  emptyMessage: 'No results found.',
                  itemBuilder: (r) {
                    final sel = tmp.contains(r.ref);
                    final hasImg = r.imageUrl.startsWith('http');
                    return SelectableRowTile<_ProcessRow>(
                      value: r,
                      selected: sel,
                      onTap: () {
                        setState(() {
                          if (sel) {
                            tmp.remove(r.ref);
                          } else {
                            tmp.add(r.ref);
                          }
                        });
                      },
                      label: r.processName,
                      imageUrl: hasImg ? r.imageUrl : null,
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

  Future<Map<String, String>> _info(DocumentReference processRef) async {
    final localeCode = Localizations.localeOf(context).languageCode;
    final procSnap = await processRef.get();
    if (!procSnap.exists) {
      return {'name': processRef.id, 'leadingImg': '', 'trailingImg': ''};
    }
    final item = procSnap.data() as Map<String, dynamic>? ?? {};
    final objRef = item['companyObjectId'] as DocumentReference?;
    final resolvedName = ProcessLocalizationUtils.resolveLocalizedText(
      item['objectProcessName'] ?? item['name'] ?? item['processName'],
      localeCode: localeCode,
      fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
    ).trim();
    final name = resolvedName.isNotEmpty ? resolvedName : processRef.id;
    final processImg = await ObjectProcessFileImages.primaryHeaderImageUrl(
      companyRef: widget.companyRef,
      processRef: processRef,
    );
    String leadingImg = '';
    if (objRef != null) {
      leadingImg = await CompanyObjectFileImages.primaryHeaderImageUrl(
        companyRef: widget.companyRef,
        objectId: objRef.id,
      );
    }

    return {
      'name': name,
      'leadingImg': leadingImg,
      'trailingImg': processImg,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectedObjects.isEmpty) return const SizedBox();

    final effectiveColor =
        widget.selectedColor ?? AppPaletteScope.of(context).primary2;
    return GestureDetector(
      onTap: _openSelector,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Processes',
          border: OutlineInputBorder(),
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.selectedObjectProcesses.isEmpty
              ? [const Text('Tap to select processes')]
              : widget.selectedObjectProcesses.map((ref) {
                  return FutureBuilder<Map<String, String>>(
                    future: _info(ref),
                    builder: (_, snap) {
                      final info = snap.data;
                      final label = info?['name'] ?? ref.id;
                      final leadingImg = info?['leadingImg'] ?? '';
                      final trailingImg = info?['trailingImg'] ?? '';
                      final hasLeading = leadingImg.startsWith('http');
                      final hasTrailing = trailingImg.startsWith('http');
                      final isSelected =
                          widget.selectedObjectProcesses.contains(ref);

                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
                        child: ButtonSelectText(
                          label: label,
                          selected: isSelected,
                          selectedColor: effectiveColor,
                          onTap: () {
                            final newSel = List<DocumentReference>.from(
                                widget.selectedObjectProcesses);
                            if (isSelected) {
                              newSel.remove(ref);
                            } else {
                              newSel.add(ref);
                            }
                            widget.onChanged(newSel);
                          },
                          leadingImageUrl: hasLeading ? leadingImg : null,
                          trailingImageUrl: hasTrailing ? trailingImg : null,
                        ),
                      );
                    },
                  );
                }).toList(),
        ),
      ),
    );
  }
}
