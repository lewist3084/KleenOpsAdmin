import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/labels/header_info_icon_value.dart';
import 'package:shared_widgets/lists/standardViewGroup.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:shared_widgets/services/firestore_service.dart';
import 'package:kleenops_admin/widgets/tiles/safety_analysis_tile.dart';
import 'package:shared_widgets/search/search_field_action.dart';
import '../../objects/utils/company_object_file_images.dart';
import '../../objects/utils/object_process_file_images.dart';
import 'safety_analysis_process_failure_mode_potential_cause_details.dart';
import 'package:kleenops_admin/services/ai/ai_context_service.dart';
import 'package:kleenops_admin/widgets/ai/ai_screen_context.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';

class SafetyAnalysisProcessFailureModeDetailsScreen extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> failureModeRef;

  const SafetyAnalysisProcessFailureModeDetailsScreen({
    super.key,
    required this.failureModeRef,
  });

  @override
  State<SafetyAnalysisProcessFailureModeDetailsScreen> createState() =>
      _SafetyAnalysisProcessFailureModeDetailsScreenState();
}

class _SafetyAnalysisProcessFailureModeDetailsScreenState
    extends State<SafetyAnalysisProcessFailureModeDetailsScreen> {
  DocumentReference<Map<String, dynamic>> get failureModeRef =>
      widget.failureModeRef;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _failureModeStream;

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
    final bool hideChrome = false;
    final baseAiContext = AiContextPresets.safetyFailureModeDetails(
      failureModeId: failureModeRef.id,
      label: 'Failure Mode',
      entityPath: failureModeRef.path,
    );

    Widget buildBottomBar({VoidCallback? onAiPressed}) {
      if (hideChrome) return const SizedBox.shrink();
      final menuSections = MenuDrawerSections(
      );
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: 'Failure Mode Details',
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
            stream: _failureModeStream ??= failureModeRef.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Center(child: CircularProgressIndicator());
              }

              final data = snapshot.data!.data()!;
              final pfmRef = data['potentialFailureModeId'] as DocumentReference?;
              final effectRef = data['potentialEffectId'] as DocumentReference?;
              final sevRef = data['severityId'] as DocumentReference?;
              final processRef = data['objectProcessTaskId'] as DocumentReference?;

              const bottomPadding = 16.0;

              return FutureBuilder<List<DocumentSnapshot?>>(
                future: Future.wait([
                  pfmRef?.get() ?? Future.value(null),
                  effectRef?.get() ?? Future.value(null),
                  sevRef?.get() ?? Future.value(null),
                  processRef?.get() ?? Future.value(null),
                ]),
                builder: (ctx, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final pfmName =
                      (snap.data![0]?.data() as Map<String, dynamic>?)?['name'] ??
                          'Unknown';
                  final effectName =
                      (snap.data![1]?.data() as Map<String, dynamic>?)?['name'] ??
                          'Unknown';
                  final severityData =
                      snap.data![2]?.data() as Map<String, dynamic>?;
                  final severityName =
                      severityData?['nameConcatenated'] ?? 'Unknown';
                  final severityPos = (severityData?['position'] as num?) ?? 0;
                  final processData =
                      snap.data![3]?.data() as Map<String, dynamic>? ?? {};
                  final imageFuture = _resolveProcessImageUrl(processData);

                  return FutureBuilder<String>(
                    future: imageFuture,
                    builder: (ctx, imageSnap) {
                      final processImageUrl = imageSnap.data ?? '';
                      return ListView(
                        padding: EdgeInsets.only(
                          bottom:
                              bottomPadding +
                                  MediaQuery.of(context).padding.bottom,
                        ),
                        children: [
                          ContainerActionWidget(
                            title: 'Details',
                            actionText: '',
                            content: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                HeaderInfoIconValue(
                                  header: 'Potential Failure Mode',
                                  value: pfmName,
                                  icon: Icons.error_outline,
                                ),
                                const SizedBox(height: 16),
                                HeaderInfoIconValue(
                                  header: 'Potential Effect',
                                  value: effectName,
                                  icon: Icons.report_problem_outlined,
                                ),
                                const SizedBox(height: 16),
                                HeaderInfoIconValue(
                                  header: 'Severity',
                                  value: severityName,
                                  icon: Icons.flag,
                                ),
                              ],
                            ),
                          ),
                          ContainerActionWidget(
                            title: 'Potential Causes',
                            actionText: 'Add',
                            onAction: () => _showAddPotentialCauseDialog(context),
                            content: _buildPotentialCauseList(
                              context,
                              processImageUrl,
                              severityPos,
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  DocumentReference<Map<String, dynamic>> get _companyRef =>
      failureModeRef.parent.parent!;

  Future<void> _deletePotentialCause(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> docSnap,
  ) async {
    final docRef = docSnap.reference;
    final oldData = docSnap.data();
    await docRef.delete();
    SnackbarService.instance.showSnackBar(
      SnackBar(
        content: const Text('Potential cause deleted.'),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () => docRef.set(oldData),
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Widget _buildPotentialCauseList(
      BuildContext context, String processImageUrl, num severityPos) {
    final stream = _companyRef
        .collection('failureModePotentialCause')
        .where('failureModeId', isEqualTo: failureModeRef)
        .snapshots();

    return StandardViewGroup(
      queryStream: stream,
      groupBy: (_) => null,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      emptyMessage: 'No potential causes found.',
      onSwipeRight: (doc) => _deletePotentialCause(context, doc),
      onTap: (doc) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                SafetyAnalysisProcessFailureModePotentialCauseDetailsScreen(
              potentialCauseRef: doc.reference,
            ),
          ),
        );
      },
      itemBuilder: (doc) {
        final data = doc.data();
        final pcRef = data['potentialCauseId'] as DocumentReference?;
        final occRef = data['occurrenceId'] as DocumentReference?;
        final detRef = data['detectionId'] as DocumentReference?;
        final control = data['currentProcessControl'] as String? ?? '';

        return FutureBuilder<List<DocumentSnapshot?>>(
          future: Future.wait([
            pcRef?.get() ?? Future.value(null),
            occRef?.get() ?? Future.value(null),
            detRef?.get() ?? Future.value(null),
          ]),
          builder: (ctx, snap) {
            if (!snap.hasData) {
              return const SizedBox.shrink();
            }
            final pcData = snap.data![0]?.data() as Map<String, dynamic>?;
            final occData = snap.data![1]?.data() as Map<String, dynamic>?;
            final detData = snap.data![2]?.data() as Map<String, dynamic>?;
            final pcName = pcData?['name'] ?? '';
            final occName = occData?['nameConcatenated'] ?? '';
            final detName = detData?['nameConcatenated'] ?? '';
            final occPos = (occData?['position'] as num?) ?? 0;
            final detPos = (detData?['position'] as num?) ?? 0;
            final prn = severityPos * occPos * detPos;
            return SafetyAnalysisTile(
              imageUrl: processImageUrl,
              showImage: processImageUrl.isNotEmpty,
              firstLine: pcName,
              firstLineIcon: Icons.warning_amber_outlined,
              secondLine: occName,
              secondLineIcon: Icons.change_circle_outlined,
              thirdLine: control,
              thirdLineIcon: Icons.gpp_maybe_outlined,
              fourthLine: detName,
              fourthLineIcon: Icons.search,
              bottomRightText: 'PRN $prn',
            );
          },
        );
      },
    );
  }

  Future<void> _showAddPotentialCauseDialog(BuildContext context) async {
    final companyRef = _companyRef;

    final pcSnap = await FirebaseFirestore.instance.collection('potentialCause').get();
    final pcDocs = pcSnap.docs
      ..sort((a, b) {
        final aName = (a.data()['name'] as String?) ?? '';
        final bName = (b.data()['name'] as String?) ?? '';
        return aName.compareTo(bName);
      });

    final occSnap = await FirebaseFirestore.instance.collection('occurrence').get();
    final occDocs = occSnap.docs
      ..sort((a, b) {
        final aPos = (a.data()['position'] as num?) ?? 0;
        final bPos = (b.data()['position'] as num?) ?? 0;
        return aPos.compareTo(bPos);
      });

    final detSnap = await FirebaseFirestore.instance.collection('detection').get();
    final detDocs = detSnap.docs
      ..sort((a, b) {
        final aPos = (a.data()['position'] as num?) ?? 0;
        final bPos = (b.data()['position'] as num?) ?? 0;
        return aPos.compareTo(bPos);
      });

    DocumentReference? selPc;
    DocumentReference? selOcc;
    DocumentReference? selDet;
    final controlController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setState) => DialogAction(
          title: 'Add Potential Cause',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SearchAddSelectDropdown<DocumentReference>(
                label: 'Potential Cause',
                items: pcDocs.map((d) => d.reference).toList(),
                itemLabel: (ref) =>
                    (pcDocs.firstWhere((d) => d.reference == ref).data()['name']
                        as String? ?? 'Unnamed'),
                onChanged: (val) => setState(() => selPc = val),
              ),
              const SizedBox(height: 16),
              SearchAddSelectDropdown<DocumentReference>(
                label: 'Occurrence',
                items: occDocs.map((d) => d.reference).toList(),
                itemLabel: (ref) =>
                    (occDocs.firstWhere((d) => d.reference == ref).data()['nameConcatenated'] as String? ?? 'Unnamed'),
                onChanged: (val) => setState(() => selOcc = val),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controlController,
                textInputAction: TextInputAction.done,
                onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                decoration:
                    const InputDecoration(labelText: 'Current Process Control'),
              ),
              const SizedBox(height: 16),
              SearchAddSelectDropdown<DocumentReference>(
                label: 'Detection',
                items: detDocs.map((d) => d.reference).toList(),
                itemLabel: (ref) =>
                    (detDocs.firstWhere((d) => d.reference == ref).data()['nameConcatenated'] as String? ?? 'Unnamed'),
                onChanged: (val) => setState(() => selDet = val),
              ),
            ],
          ),
          cancelText: 'Cancel',
          actionText: 'Add',
          onCancel: () => Navigator.of(ctx2).pop(),
          onAction: () async {
            if (selPc == null || selOcc == null || selDet == null) {
              SnackbarService.instance.showSnackBar(
                const SnackBar(duration: Duration(seconds: 5), content: Text('Please fill all fields.')),
              );
              return;
            }
            await FirestoreService().saveDocument(
              collectionRef:
                  FirebaseFirestore.instance.collection('failureModePotentialCause'),
              data: {
                'failureModeId': failureModeRef,
                'potentialCauseId': selPc,
                'occurrenceId': selOcc,
                'detectionId': selDet,
                'currentProcessControl': controlController.text.trim(),
              },
            );
            Navigator.of(ctx2).pop();
          },
        ),
      ),
    );
  }
}

