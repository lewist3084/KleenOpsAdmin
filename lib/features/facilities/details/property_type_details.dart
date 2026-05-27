// Admin port: top-level `propertyType` collection, English strings hardcoded.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/common/field_info/field_info_registry.dart';
import 'package:kleenops_admin/features/facilities/forms/property_type_form.dart';
import 'package:kleenops_admin/widgets/layout/bookended_canvas.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/labels/header_info_icon_value.dart';
import 'package:shared_widgets/utils/process_localization_utils.dart';

class PropertyTypeDetailsScreen extends StatefulWidget {
  const PropertyTypeDetailsScreen({
    super.key,
    required this.docId,
  });

  final String docId;

  @override
  State<PropertyTypeDetailsScreen> createState() =>
      _PropertyTypeDetailsScreenState();
}

class _PropertyTypeDetailsScreenState extends State<PropertyTypeDetailsScreen> {
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _docStream;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final inferredCode = locale.languageCode.trim().toLowerCase();
    final effectiveLocale = inferredCode.isNotEmpty
        ? inferredCode
        : ProcessLocalizationUtils.defaultLocaleCode;

    String resolveField(dynamic field) {
      return ProcessLocalizationUtils.resolveLocalizedText(
        field,
        localeCode: effectiveLocale,
        fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
      ).trim();
    }

    final docRef = FirebaseFirestore.instance
        .collection('propertyType')
        .doc(widget.docId);
    const detailTitle = 'Property Type Details';

    return Scaffold(
      body: BookendedCanvas(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
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
              return const Center(child: Text('Property type not found.'));
            }

            final data = docSnap.data() ?? const <String, dynamic>{};
            final rawName = resolveField(data['name']);
            final rawDescription = resolveField(data['description']);
            final name = rawName.isNotEmpty ? rawName : 'Unnamed';
            final description = rawDescription.isNotEmpty
                ? rawDescription
                : 'No description provided.';

            return SingleChildScrollView(
              child: ContainerActionWidget(
                actionText: '',
                padding: EdgeInsets.zero,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HeaderInfoIconValue(
                      header: 'Name',
                      value: name,
                      icon: Icons.category_outlined,
                      infoKey: FieldInfoKeys.facilitiesPropertyTypeName,
                    ),
                    const SizedBox(height: 16),
                    HeaderInfoIconValue(
                      header: 'Description',
                      value: description,
                      icon: Icons.description_outlined,
                      infoKey: FieldInfoKeys.facilitiesPropertyTypeDescription,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PropertyTypeForm(docId: widget.docId),
            ),
          );
        },
        tooltip: 'Edit property type',
        child: const Icon(Icons.edit),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          DetailsAppBar(title: detailTitle),
          HomeNavBarAdapter(highlightSelected: false),
        ],
      ),
    );
  }
}
