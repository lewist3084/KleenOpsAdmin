// lib/features/objects/details/element_material_details.dart
// DEGRADED port — admin-absent AI canvas widgets stripped, hardcoded English.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:shared_widgets/utils/process_localization_utils.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/labels/header_info_icon_value.dart';
import 'package:kleenops_admin/features/objects/forms/element_material_form.dart';

class ElementMaterialDetailsScreen extends StatefulWidget {
  const ElementMaterialDetailsScreen({
    super.key,
    required this.companyRef,
    required this.docId,
  });

  final DocumentReference<Map<String, dynamic>> companyRef;
  final String docId;

  @override
  State<ElementMaterialDetailsScreen> createState() =>
      _ElementMaterialDetailsScreenState();
}

class _ElementMaterialDetailsScreenState
    extends State<ElementMaterialDetailsScreen> {
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
    const label = 'Element Material';
    const nameLabel = 'Name';
    const descriptionLabel = 'Description';
    const unnamed = 'Unnamed';
    const noDescription = 'No description provided.';
    final docRef = companyRef.collection('elementMaterial').doc(docId);

    return Scaffold(
      bottomNavigationBar: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(title: label),
          HomeNavBarAdapter(highlightSelected: false),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ElementMaterialForm(
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
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docSnap = snapshot.data;
            if (docSnap == null || !docSnap.exists) {
              return const Center(child: Text('Not found'));
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
                title: label,
                actionText: '',
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HeaderInfoIconValue(
                      header: nameLabel,
                      value: name,
                      icon: Icons.science_outlined,
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
