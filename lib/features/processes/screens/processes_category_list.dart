// lib/features/processes/screens/processes_category_list.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:shared_widgets/lists/standardViewGroup.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:shared_widgets/utils/process_localization_utils.dart';
import 'package:kleenops_admin/features/processes/details/processes_category_details.dart';
import 'package:kleenops_admin/features/processes/forms/processes_category_form.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';

class ProcessesCategoryListScreen extends ConsumerStatefulWidget {
  const ProcessesCategoryListScreen({super.key});

  @override
  ConsumerState<ProcessesCategoryListScreen> createState() =>
      _ProcessesCategoryListScreenState();
}

class _ProcessesCategoryListScreenState
    extends ConsumerState<ProcessesCategoryListScreen> {
  final ValueNotifier<bool> _fabVisibleNotifier = ValueNotifier<bool>(true);

  @override
  void dispose() {
    _fabVisibleNotifier.dispose();
    super.dispose();
  }

  void _deleteCategory(
    BuildContext context,
    CollectionReference<Map<String, dynamic>> collection,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final localeCode =
        Localizations.localeOf(context).languageCode.trim().toLowerCase();
    final effectiveLocale = localeCode.isNotEmpty
        ? localeCode
        : ProcessLocalizationUtils.defaultLocaleCode;
    final dataBackup = doc.data();
    final oldName = ProcessLocalizationUtils.resolveLocalizedText(
      dataBackup['name'],
      localeCode: effectiveLocale,
      fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
    );
    final docId = doc.id;
    doc.reference.delete();
    SnackbarService.instance.showSnackBar(
      SnackBar(
        content: Text(
          'Deleted "${oldName.isEmpty ? 'Unnamed' : oldName}"',
        ),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () {
            collection.doc(docId).set(dataBackup);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final companyRefAsync = ref.watch(companyIdProvider);

    return companyRefAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
      data: (companyRef) {
        if (companyRef == null) {
          return const Center(child: Text('No company linked'));
        }

        final collection = companyRef.collection('processCategory');
        final localeCode =
            Localizations.localeOf(context).languageCode.trim().toLowerCase();
        final effectiveLocale = localeCode.isNotEmpty
            ? localeCode
            : ProcessLocalizationUtils.defaultLocaleCode;

        const bottomPadding = 16.0;

        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
              child: NotificationListener<ScrollNotification>(
                onNotification: (scrollInfo) {
                  if (scrollInfo is ScrollUpdateNotification &&
                      scrollInfo.scrollDelta != null) {
                    if (scrollInfo.scrollDelta! > 0 &&
                        _fabVisibleNotifier.value) {
                      _fabVisibleNotifier.value = false;
                    } else if (scrollInfo.scrollDelta! < 0 &&
                        !_fabVisibleNotifier.value) {
                      _fabVisibleNotifier.value = true;
                    }
                  }
                  return false;
                },
                child: StandardViewGroup(
                  queryStream: collection.snapshots(),
                  groupBy: (_) => null,
                  headerIcon: null,
                  emptyMessage: 'No categories found',
                  itemSort: (a, b) {
                    final aName = ProcessLocalizationUtils.resolveLocalizedText(
                      a.data()['name'],
                      localeCode: effectiveLocale,
                      fallbackLocaleCode:
                          ProcessLocalizationUtils.defaultLocaleCode,
                    );
                    final bName = ProcessLocalizationUtils.resolveLocalizedText(
                      b.data()['name'],
                      localeCode: effectiveLocale,
                      fallbackLocaleCode:
                          ProcessLocalizationUtils.defaultLocaleCode,
                    );
                    return aName.toLowerCase().compareTo(bName.toLowerCase());
                  },
                  itemBuilder: (doc) {
                    final resolvedName =
                        ProcessLocalizationUtils.resolveLocalizedText(
                      doc.data()['name'],
                      localeCode: effectiveLocale,
                      fallbackLocaleCode:
                          ProcessLocalizationUtils.defaultLocaleCode,
                    );
                    final name =
                        resolvedName.isNotEmpty ? resolvedName : 'Unnamed';
                    return StandardTileSmallDart.iconText(
                      leadingicon: Icons.category_outlined,
                      text: name,
                    );
                  },
                  onTap: (doc) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProcessesCategoryDetailsScreen(
                          companyRef: companyRef,
                          docId: doc.id,
                        ),
                      ),
                    );
                  },
                  onSwipeRight: (doc) =>
                      _deleteCategory(context, collection, doc),
                  shrinkWrap: false,
                  physics: const AlwaysScrollableScrollPhysics(),
                ),
              ),
            ),
            Positioned(
              bottom: bottomPadding,
              right: 16,
              child: ValueListenableBuilder<bool>(
                valueListenable: _fabVisibleNotifier,
                builder: (context, isVisible, child) => AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: isVisible ? 1.0 : 0.0,
                  child: child,
                ),
                child: FloatingActionButton(
                  heroTag: null,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProcessesCategoryForm(
                          companyRef: companyRef,
                        ),
                      ),
                    );
                  },
                  child: const Icon(Icons.add),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
