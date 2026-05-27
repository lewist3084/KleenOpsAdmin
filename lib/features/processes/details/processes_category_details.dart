import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/features/processes/forms/processes_category_form.dart';
import 'package:shared_widgets/utils/process_localization_utils.dart';
import 'package:kleenops_admin/services/ai/ai_context_service.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/labels/header_info_icon_value.dart';

class ProcessesCategoryDetailsScreen extends StatefulWidget {
  const ProcessesCategoryDetailsScreen({
    super.key,
    required this.companyRef,
    required this.docId,
  });

  final DocumentReference<Map<String, dynamic>> companyRef;
  final String docId;

  @override
  State<ProcessesCategoryDetailsScreen> createState() =>
      _ProcessesCategoryDetailsScreenState();
}

class _ProcessesCategoryDetailsScreenState
    extends State<ProcessesCategoryDetailsScreen> {
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _docStream;

  String _effectiveLocaleCode(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final language = locale.languageCode.trim().toLowerCase();
    final script = locale.scriptCode?.trim().toLowerCase();
    final country = locale.countryCode?.trim().toLowerCase();
    final segments = <String>[];
    if (language.isNotEmpty) {
      segments.add(language);
    }
    if (script != null && script.isNotEmpty) {
      segments.add(script);
    }
    if (country != null && country.isNotEmpty) {
      segments.add(country);
    }
    if (segments.isEmpty) {
      return ProcessLocalizationUtils.defaultLocaleCode;
    }
    return ProcessLocalizationUtils.normalizeLocaleCode(segments.join('-'));
  }

  Widget _wrapCanvas(Widget child) {
    return StandardCanvas(
      child: SafeArea(
        top: true,
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(child: child),
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: CanvasTopBookend(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final companyRef = widget.companyRef;
    final docId = widget.docId;
    const categoryLabel = 'Process Category';
    const nameLabel = 'Name';
    const descriptionLabel = 'Description';
    const unnamed = 'Unnamed';
    const noDescription = 'No description provided.';
    final docRef = companyRef.collection('processCategory').doc(docId);

    Widget buildBottomBar({VoidCallback? onAiPressed}) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: categoryLabel,
            onAiPressed: onAiPressed,
          ),
          const HomeNavBarAdapter(highlightSelected: false),
        ],
      );
    }

    return Scaffold(
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final controller = ref.read(aiCanvasControllerProvider);
          return buildBottomBar(onAiPressed: controller.toggle);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProcessesCategoryForm(
                companyRef: companyRef,
                docId: docId,
              ),
            ),
          );
        },
        child: const Icon(Icons.edit),
      ),
      body: _wrapCanvas(
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _docStream ??= docRef.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text('Error: ${snapshot.error}'),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docSnap = snapshot.data;
            if (docSnap == null || !docSnap.exists) {
              return const Center(child: Text('Category not found'));
            }

            final data = docSnap.data() ?? const <String, dynamic>{};
            final localeCode = _effectiveLocaleCode(context);
            final rawName = ProcessLocalizationUtils.resolveLocalizedText(
              data['name'],
              localeCode: localeCode,
              fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
            ).trim();
            final rawDescription =
                ProcessLocalizationUtils.resolveLocalizedText(
              data['description'],
              localeCode: localeCode,
              fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
            ).trim();
            final name = rawName.isNotEmpty ? rawName : unnamed;
            final description =
                rawDescription.isNotEmpty ? rawDescription : noDescription;

            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: ContainerActionWidget(
                title: categoryLabel,
                actionText: '',
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HeaderInfoIconValue(
                      header: nameLabel,
                      value: name,
                      icon: Icons.category_outlined,
                    ),
                    const SizedBox(height: 16),
                    HeaderInfoIconValue(
                      header: descriptionLabel,
                      value: description,
                      icon: Icons.description_outlined,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
