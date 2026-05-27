// lib/features/processes/screens/processes_processes_category.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:shared_widgets/utils/process_localization_utils.dart';
import 'package:kleenops_admin/features/processes/details/processes_category_details.dart';
import 'package:kleenops_admin/features/processes/forms/processes_category_form.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';

class ProcessesProcessesCategoryScreen extends ConsumerStatefulWidget {
  const ProcessesProcessesCategoryScreen({super.key});

  @override
  ConsumerState<ProcessesProcessesCategoryScreen> createState() =>
      _ProcessesProcessesCategoryScreenState();
}

class _ProcessesProcessesCategoryScreenState
    extends ConsumerState<ProcessesProcessesCategoryScreen> {
  CollectionReference<Map<String, dynamic>>? _categoryCollection;

  Future<void> _deleteCategory(
      DocumentSnapshot<Map<String, dynamic>> categoryDoc) async {
    final dataBackup = categoryDoc.data();
    final String docId = categoryDoc.id;
    await categoryDoc.reference.delete();
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    SnackbarService.instance.showSnackBar(
      SnackBar(
        content: const Text('Category deleted'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () async {
            if (dataBackup != null) {
              await _categoryCollection!.doc(docId).set(dataBackup);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final companyRefAsync = ref.watch(companyIdProvider);

    return companyRefAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        body: Center(child: Text('Error: $err')),
      ),
      data: (companyRef) {
        if (companyRef == null) {
          return const Scaffold(
            body: Center(child: Text('No company reference')),
          );
        }
        _categoryCollection = companyRef.collection('processCategory');
        final localeCode =
            Localizations.localeOf(context).languageCode.trim().toLowerCase();
        final effectiveLocale = localeCode.isNotEmpty
            ? localeCode
            : ProcessLocalizationUtils.defaultLocaleCode;

        return Scaffold(
          appBar: const StandardAppBar(title: 'Categories'),
          body: ContainerActionStandardViewGroup(
            title: 'Categories',
            actionText: 'Add',
            onAction: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProcessesCategoryForm(
                    companyRef: companyRef,
                  ),
                ),
              );
            },
            queryStream: _categoryCollection!.snapshots(),
            groupBy: (_) => '',
            itemSort: (a, b) {
              final aName = ProcessLocalizationUtils.resolveLocalizedText(
                a.data()['name'],
                localeCode: effectiveLocale,
                fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
              );
              final bName = ProcessLocalizationUtils.resolveLocalizedText(
                b.data()['name'],
                localeCode: effectiveLocale,
                fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
              );
              return aName.toLowerCase().compareTo(bName.toLowerCase());
            },
            itemBuilder:
                (QueryDocumentSnapshot<Map<String, dynamic>> categoryDoc) {
              final data = categoryDoc.data();
              final resolvedName =
                  ProcessLocalizationUtils.resolveLocalizedText(
                data['name'],
                localeCode: effectiveLocale,
                fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
              );
              final String categoryName =
                  resolvedName.isNotEmpty ? resolvedName : 'Unnamed';
              return Dismissible(
                key: Key(categoryDoc.id),
                direction: DismissDirection.startToEnd,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 16.0),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  await _deleteCategory(categoryDoc);
                  return false;
                },
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProcessesCategoryDetailsScreen(
                          companyRef: companyRef,
                          docId: categoryDoc.id,
                        ),
                      ),
                    );
                  },
                  child: StandardTileSmallDart.iconText(
                    leadingicon: Icons.view_list_outlined,
                    text: categoryName,
                  ),
                ),
              );
            },
            emptyMessage: 'No categories found',
            shrinkWrap: true,
            physics: const AlwaysScrollableScrollPhysics(),
          ),
        );
      },
    );
  }
}
