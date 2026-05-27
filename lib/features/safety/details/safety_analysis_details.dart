//  safety_analysis_details.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:shared_widgets/containers/container_header.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/lists/standardViewGroup.dart';
import 'package:kleenops_admin/widgets/tiles/safety_analysis_tile.dart';
import '../../objects/utils/company_object_file_images.dart';
import '../../objects/utils/object_process_file_images.dart';
import 'safety_analysis_process_details.dart';
import 'package:shared_widgets/utils/process_localization_utils.dart';
import 'package:kleenops_admin/services/ai/ai_context_service.dart';
import 'package:kleenops_admin/widgets/ai/ai_screen_context.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';

class SafetyAnalysisDetailsScreen extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final String docId;

  const SafetyAnalysisDetailsScreen({
    super.key,
    required this.companyRef,
    required this.docId,
  });

  @override
  State<SafetyAnalysisDetailsScreen> createState() =>
      _SafetyAnalysisDetailsScreenState();
}

class _SafetyAnalysisDetailsScreenState
    extends State<SafetyAnalysisDetailsScreen> {
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _taskStream;

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

  Future<String> _resolveProcessImageUrl(Map<String, dynamic> data) async {
    final processRef = data['objectProcessId'] as DocumentReference?;
    if (processRef is DocumentReference<Map<String, dynamic>>) {
      final companyRef = processRef.parent.parent;
      if (companyRef is DocumentReference<Map<String, dynamic>>) {
        final fileUrl = await ObjectProcessFileImages.primaryHeaderImageUrl(
          companyRef: companyRef,
          processRef: processRef,
        );
        if (fileUrl.isNotEmpty) return fileUrl;
      }
    }
    final objectRef = data['companyObjectId'] as DocumentReference?;
    if (objectRef != null) {
      final fileUrl =
          await CompanyObjectFileImages.primaryHeaderImageUrlForRef(
        objectRef: objectRef,
      );
      if (fileUrl.isNotEmpty) return fileUrl;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final companyRef = FirebaseFirestore.instance;
    final docId = widget.docId;
    final docRef = FirebaseFirestore.instance.collection('task').doc(docId);
    final bool hideChrome = false;
    final baseAiContext = AiContextPresets.safetyAnalysisDetails(
      analysisId: docId,
      label: docId,
      entityPath: docRef.path,
    );

    Widget buildBottomBar({VoidCallback? onAiPressed}) {
      if (hideChrome) return const SizedBox.shrink();
      final menuSections = MenuDrawerSections(
      );
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: 'Safety Analysis Details',
            onAiPressed: onAiPressed,
            menuSections: menuSections,
          ),
          const HomeNavBarAdapter(highlightSelected: false),
        ],
      );
    }

    return Scaffold(
      appBar: null,
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final controller = ref.read(aiCanvasControllerProvider);
          return buildBottomBar(onAiPressed: controller.toggle);
        },
      ),
      body: AiScreenContext(
        context: baseAiContext,
        child: _wrapCanvas(
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _taskStream ??= docRef.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Center(child: CircularProgressIndicator());
              }

              final data = snapshot.data!.data()!;
              final localeCode =
                  Localizations.localeOf(context).languageCode;
              final name = ProcessLocalizationUtils.resolveLocalizedText(
                data['name'],
                localeCode: localeCode,
                fallbackLocaleCode:
                    ProcessLocalizationUtils.defaultLocaleCode,
              );
              const bottomPadding = 16.0;

              return SingleChildScrollView(
                padding: const EdgeInsets.only(
                  bottom: bottomPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ContainerHeader(
                      showImage: false,
                      image: null,
                      titleHeader: 'Task Name',
                      title: name,
                      descriptionHeader: '',
                      description: '',
                    ),
                    ContainerActionStandardViewGroup(
                      title: 'Task Processes',
                      queryStream: companyRef
                          .collection('objectProcessTask')
                          .where('taskId', isEqualTo: docRef)
                          .snapshots(),
                      groupBy: (_) => null,
                      itemSort: (a, b) {
                        final aData = a.data();
                        final bData = b.data();
                        final aPos =
                            (aData['position'] as num?) ??
                            (aData['stepValue'] as num?) ??
                            0;
                        final bPos =
                            (bData['position'] as num?) ??
                            (bData['stepValue'] as num?) ??
                            0;
                        return aPos.compareTo(bPos);
                      },
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      emptyMessage: 'No processes found.',
                      itemBuilder: (doc) {
                        final Map<String, dynamic> d = doc.data();
                        final localeCode =
                            Localizations.localeOf(context).languageCode;
                        final resolvedObjectProcessName =
                            ProcessLocalizationUtils.resolveLocalizedText(
                          d?['objectProcessName'] ??
                              d?['name'] ??
                              d?['processName'],
                          localeCode: localeCode,
                          fallbackLocaleCode:
                              ProcessLocalizationUtils.defaultLocaleCode,
                        ).trim();
                        final objectProcessName =
                            resolvedObjectProcessName.isNotEmpty
                                ? resolvedObjectProcessName
                                : (d?['objectProcessName'] ??
                                        d?['name'] ??
                                        d?['processName'] ??
                                        'Unknown')
                                    .toString();
                        final resolvedProcessName =
                            ProcessLocalizationUtils.resolveLocalizedText(
                          d?['processName'],
                          localeCode: localeCode,
                          fallbackLocaleCode:
                              ProcessLocalizationUtils.defaultLocaleCode,
                        ).trim();
                        final processName = resolvedProcessName.isNotEmpty
                            ? resolvedProcessName
                            : (d?['processName'] ?? '').toString();
                        final imageFuture = _resolveProcessImageUrl(d);

                        return FutureBuilder<String>(
                          future: imageFuture,
                          builder: (ctx, imageSnap) {
                            final imageUrl = imageSnap.data ?? '';
                            return FutureBuilder<num>(
                              future: _loadProcessMaxPrn(doc.reference),
                              builder: (ctx, snap) {
                                final prn = snap.data ?? 0;
                                return SafetyAnalysisTile(
                                  imageUrl: imageUrl,
                                  firstLine: objectProcessName,
                                  secondLine:
                                      processName.isNotEmpty ? processName : '',
                                  secondLineIcon: processName.isNotEmpty
                                      ? Icons.route_outlined
                                      : null,
                                  firstLineIcon: Icons.content_paste,
                                  bottomRightText: 'PRN $prn',
                                );
                              },
                            );
                          },
                        );
                      },
                      onTap: (doc) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SafetyAnalysisProcessDetailsScreen(
                              objectProcessTaskRef: doc.reference,
                            ),
                          ),
                        );
                      },
                      onSwipeLeft: null,
                      onSwipeRight: null,
                      headerIcon: null,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<num> _loadProcessMaxPrn(
      DocumentReference<Map<String, dynamic>> processRef) async {
    // All failure modes for this process
    final failureModeSnap = await FirebaseFirestore.instance
        .collection('failureMode')
        .where('objectProcessTaskId', isEqualTo: processRef)
        .get();

    num overallMax = 0;

    for (final fmDoc in failureModeSnap.docs) {
      final fmData = fmDoc.data();

      // --- Severity ---
      final sevRef =
          fmData['severityId'] as DocumentReference<Map<String, dynamic>>?;
      final sevSnap = await sevRef?.get();
      final sevData = sevSnap?.data();
      final sevPos = (sevData?['position'] as num?) ?? 0;

      // Potential causes for this failure mode
      final pcSnap = await FirebaseFirestore.instance
          .collection('failureModePotentialCause')
          .where('failureModeId', isEqualTo: fmDoc.reference)
          .get();

      for (final pcDoc in pcSnap.docs) {
        final pcData = pcDoc.data();

        final occRef =
            pcData['occurrenceId'] as DocumentReference<Map<String, dynamic>>?;
        final detRef =
            pcData['detectionId'] as DocumentReference<Map<String, dynamic>>?;

        final occSnap = await occRef?.get();
        final detSnap = await detRef?.get();

        final occData = occSnap?.data();
        final detData = detSnap?.data();

        final occPos = (occData?['position'] as num?) ?? 0;
        final detPos = (detData?['position'] as num?) ?? 0;

        final prn = sevPos * occPos * detPos;
        if (prn > overallMax) overallMax = prn;
      }
    }

    return overallMax;
  }
}

