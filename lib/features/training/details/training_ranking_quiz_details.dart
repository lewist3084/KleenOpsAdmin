// lib/features/training/details/training_ranking_quiz_details.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/utils/process_localization_utils.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/containers/container_header.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/labels/header_info_icon_value.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';

import '../forms/training_ranking_quiz_form.dart';

class TrainingRankingQuizDetails extends StatelessWidget {
  final String companyId;
  final String trainingId;
  final String quizId;
  final String elementId;

  const TrainingRankingQuizDetails({
    super.key,
    required this.companyId,
    required this.trainingId,
    required this.quizId,
    required this.elementId,
  });

  DocumentReference<Map<String, dynamic>> _elementRef() {
    return FirebaseFirestore.instance
        .collection('company')
        .doc(companyId)
        .collection('trainingQuizElement')
        .doc(elementId);
  }

  void _launchEdit(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrainingRankingQuizForm(
          companyId: companyId,
          trainingId: trainingId,
          quizId: quizId,
          elementId: elementId,
        ),
      ),
    );
  }

  List<String> _normalizeList(dynamic raw) {
    if (raw is Iterable) {
      return raw
          .map((entry) => entry?.toString().trim() ?? '')
          .where((entry) => entry.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }

  Map<String, List<String>> _normalizeLocalizedListMap(dynamic raw) {
    if (raw is! Map) return const <String, List<String>>{};
    final normalized = <String, List<String>>{};
    for (final entry in raw.entries) {
      final key = ProcessLocalizationUtils.normalizeLocaleCode(
        entry.key.toString(),
      );
      if (key.isEmpty) continue;
      final list = _normalizeList(entry.value);
      if (list.isNotEmpty) {
        normalized[key] = list;
      }
    }
    return normalized;
  }

  String _effectiveLocaleCode(BuildContext context) {
    final localeRaw = ProcessLocalizationUtils.normalizeLocaleCode(
      Localizations.localeOf(context).toString(),
    );
    return localeRaw.isNotEmpty
        ? localeRaw
        : ProcessLocalizationUtils.defaultLocaleCode;
  }

  List<String> _resolveLocalizedList({
    required List<String> base,
    required Map<String, List<String>> localizedMap,
    required String localeCode,
  }) {
    if (localizedMap.isEmpty) return base;
    final fallback =
        localizedMap[ProcessLocalizationUtils.defaultLocaleCode] ??
            const <String>[];
    final candidate = localizedMap[localeCode] ??
        localizedMap[localeCode.split('-').first];
    if (candidate != null && candidate.isNotEmpty) {
      if (base.isEmpty || candidate.length == base.length) {
        return candidate;
      }
    }
    if (fallback.isNotEmpty && (base.isEmpty || fallback.length == base.length)) {
      return fallback;
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      floatingActionButton: FloatingActionButton(
        onPressed: () => _launchEdit(context),
        child: const Icon(Icons.edit),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            DetailsAppBar(title: 'Ranking Question'),
            HomeNavBarAdapter(highlightSelected: false),
          ],
        ),
      ),
      body: StandardCanvas(
        child: SafeArea(
          top: true,
          bottom: false,
          child: Stack(
            children: [
              Positioned.fill(
                child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: _elementRef().snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return const Center(child: Text('Question not found.'));
                    }
                    final data = snapshot.data!.data() ?? {};
                    final localeCode = _effectiveLocaleCode(context);
                    final question = ProcessLocalizationUtils.resolveLocalizedText(
                      data['question'],
                      localeCode: localeCode,
                      fallbackLocaleCode:
                          ProcessLocalizationUtils.defaultLocaleCode,
                    ).trim();
                    final description =
                        ProcessLocalizationUtils.resolveLocalizedText(
                      data['description'],
                      localeCode: localeCode,
                      fallbackLocaleCode:
                          ProcessLocalizationUtils.defaultLocaleCode,
                    ).trim();
                    final baseItems = _normalizeList(data['items']);
                    final localizedMap =
                        _normalizeLocalizedListMap(data['itemsLocalized']);
                    final items = _resolveLocalizedList(
                      base: baseItems,
                      localizedMap: localizedMap,
                      localeCode: localeCode,
                    );
                    final isRequired = data['isRequired'] as bool? ?? true;

                    const bottomPadding = 16.0;

                    return SingleChildScrollView(
                      padding: EdgeInsets.only(bottom: bottomPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ContainerHeader(
                            titleHeader: 'Question',
                            title:
                                question.isEmpty ? 'Ranking question' : question,
                            descriptionHeader: 'Description',
                            description: description.isEmpty
                                ? 'No description'
                                : description,
                            textIcon: Icons.format_list_numbered,
                            descriptionIcon: Icons.description,
                          ),
                          const SizedBox(height: 16),
                          ContainerActionWidget(
                            title: 'Items',
                            actionText: '',
                            content: Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: items.isEmpty
                                  ? const [Text('No items defined.')]
                                  : items
                                      .map((item) => Chip(label: Text(item)))
                                      .toList(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ContainerActionWidget(
                            title: 'Settings',
                            actionText: '',
                            content: HeaderInfoIconValue(
                              header: 'Required',
                              value: isRequired ? 'Yes' : 'No',
                              icon: Icons.check_circle_outline,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: CanvasTopBookend(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
