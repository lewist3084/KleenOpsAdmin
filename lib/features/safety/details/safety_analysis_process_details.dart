import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/widgets/tiles/safety_analysis_tile.dart';
import 'package:shared_widgets/containers/container_header.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/lists/standardViewGroup.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:shared_widgets/search/search_field_action.dart';
import 'package:shared_widgets/services/firestore_service.dart';
import 'package:kleenops_admin/services/tenant_firebase_service.dart';
import '../tabs/potential_cause_tabs.dart';
import '../../objects/utils/company_object_file_images.dart';
import '../../objects/utils/object_process_file_images.dart';
import 'package:shared_widgets/utils/process_localization_utils.dart';
import 'package:kleenops_admin/services/ai/ai_context_service.dart';
import 'package:kleenops_admin/widgets/ai/ai_screen_context.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';

class SafetyAnalysisProcessDetailsScreen extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> objectProcessTaskRef;

  const SafetyAnalysisProcessDetailsScreen({
    super.key,
    required this.objectProcessTaskRef,
  });

  @override
  State<SafetyAnalysisProcessDetailsScreen> createState() =>
      _SafetyAnalysisProcessDetailsScreenState();
}

class _SafetyAnalysisProcessDetailsScreenState
    extends State<SafetyAnalysisProcessDetailsScreen> {
  DocumentReference<Map<String, dynamic>> get objectProcessTaskRef =>
      widget.objectProcessTaskRef;

  final Map<String, Future<DocumentSnapshot<Map<String, dynamic>>>>
      _taskFutureCache = {};
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _objectProcessTaskStream;

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
    final baseAiContext = AiContextPresets.safetyAnalysisProcessDetails(
      processId: objectProcessTaskRef.id,
      label: 'Process',
      entityPath: objectProcessTaskRef.path,
    );

    Widget buildBottomBar({VoidCallback? onAiPressed}) {
      if (hideChrome) return const SizedBox.shrink();
      final menuSections = MenuDrawerSections(
      );
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: 'Process Details',
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
            stream: _objectProcessTaskStream ??= objectProcessTaskRef.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Center(child: CircularProgressIndicator());
              }

              final data = snapshot.data!.data()!;
              final localeCode = Localizations.localeOf(context).languageCode;
              final resolvedObjectProcessName =
                  ProcessLocalizationUtils.resolveLocalizedText(
                data['objectProcessName'] ?? data['name'] ?? data['processName'],
                localeCode: localeCode,
                fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
              ).trim();
              final objectProcessName = resolvedObjectProcessName.isNotEmpty
                  ? resolvedObjectProcessName
                  : (data['objectProcessName'] ??
                          data['name'] ??
                          data['processName'] ??
                          '')
                      .toString();
              final imageFuture = _resolveProcessImageUrl(data);
              final taskRef =
                  data['taskId'] as DocumentReference<Map<String, dynamic>>?;

              const bottomPadding = 16.0;

              return SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: bottomPadding + MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      future: taskRef == null
                          ? null
                          : (_taskFutureCache[taskRef.path] ??=
                              taskRef.get()),
                      builder: (ctx, taskSnap) {
                        final taskData = taskSnap.data?.data();
                        final resolvedTaskName =
                            ProcessLocalizationUtils.resolveLocalizedText(
                          taskData?['name'],
                          localeCode: localeCode,
                          fallbackLocaleCode:
                              ProcessLocalizationUtils.defaultLocaleCode,
                        ).trim();
                        final taskName = resolvedTaskName.isNotEmpty
                            ? resolvedTaskName
                            : (taskData?['name'] ?? '').toString();
                        return ContainerHeader(
                          showImage: false,
                          image: null,
                          titleHeader: 'Task Name',
                          title: taskName,
                          descriptionHeader: 'Process',
                          description: objectProcessName,
                        );
                      },
                    ),
                    FutureBuilder<String>(
                      future: imageFuture,
                      builder: (ctx, imageSnap) {
                        final imageUrl = imageSnap.data ?? '';
                        return ContainerActionWidget(
                          title: 'Failure Modes',
                          content: _buildFailureModeList(context, imageUrl),
                          actionText: 'Add',
                          onAction: () => _showAddFailureModeDialog(context),
                        );
                      },
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

  DocumentReference<Map<String, dynamic>> get _companyRef =>
      objectProcessTaskRef.parent.parent!;

  Widget _buildFailureModeList(BuildContext context, String processImageUrl) {
    final stream = _companyRef
        .collection('failureMode')
        .where('objectProcessTaskId', isEqualTo: objectProcessTaskRef)
        .snapshots();

    return StandardViewGroup(
      queryStream: stream,
      groupBy: (_) => null,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      emptyMessage: 'No failure modes found.',
      onSwipeRight: (doc) => _deleteFailureMode(context, doc),
      onTap: (doc) {
        Navigator.of(context).push(
          MaterialPageRoute(
            settings: RouteSettings(
              name: '/safety/failure-mode/${doc.id}',
            ),
            builder: (_) => PotentialCauseTabsScreen(
              failureModeRef: doc.reference,
            ),
          ),
        );
      },
      itemBuilder: (doc) {
        return FutureBuilder<Map<String, dynamic>>(
          future: _loadFailureModeTileData(doc),
          builder: (ctx, snap) {
            if (!snap.hasData) {
              return const ListTile(title: Text('...'));
            }
            final pfmName = snap.data!['pfmName'] as String;
            final effName = snap.data!['effName'] as String;
            final sevName = snap.data!['sevName'] as String;
            final prn = snap.data!['maxPrn'] as num;

            return SafetyAnalysisTile(
              imageUrl: processImageUrl,
              showImage: processImageUrl.isNotEmpty,
              firstLine: pfmName,
              firstLineIcon: Icons.error_outline,
              secondLine: effName,
              secondLineIcon: Icons.report_problem_outlined,
              thirdLine: sevName,
              thirdLineIcon: Icons.flag,
              bottomRightText: 'PRN $prn',
            );
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>> _loadFailureModeTileData(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data();
    final pfmRef = data['potentialFailureModeId'] as DocumentReference?;
    final effectRef = data['potentialEffectId'] as DocumentReference?;
    final sevRef = data['severityId'] as DocumentReference?;

    final results = await Future.wait([
      pfmRef?.get() ?? Future.value(null),
      effectRef?.get() ?? Future.value(null),
      sevRef?.get() ?? Future.value(null),
    ]);

    final pfmSnapshot = results[0];
    final effSnapshot = results[1];
    final sevSnapshot = results[2];
    final pfmData = pfmSnapshot?.data() as Map<String, dynamic>?;
    final effData = effSnapshot?.data() as Map<String, dynamic>?;
    final sevData = sevSnapshot?.data() as Map<String, dynamic>?;
    final pfmName = pfmData?['name'] ?? 'Unnamed';
    final effName = effData?['name'] ?? 'Unnamed';
    final sevName = sevData?['nameConcatenated'] ?? 'Unknown';
    final severityPos = (sevData?['position'] as num?) ?? 0;

    final pcSnap = await _companyRef
        .collection('failureModePotentialCause')
        .where('failureModeId', isEqualTo: doc.reference)
        .get();

    num maxPrn = 0;
    for (final pcDoc in pcSnap.docs) {
      final pcData = pcDoc.data();
      final occRef = pcData['occurrenceId'] as DocumentReference?;
      final detRef = pcData['detectionId'] as DocumentReference?;
      final occSnapshot = await occRef?.get();
      final detSnapshot = await detRef?.get();
      final occData = occSnapshot?.data() as Map<String, dynamic>?;
      final detData = detSnapshot?.data() as Map<String, dynamic>?;
      final occPos = (occData?['position'] as num?) ?? 0;
      final detPos = (detData?['position'] as num?) ?? 0;
      final prn = severityPos * occPos * detPos;
      if (prn > maxPrn) maxPrn = prn;
    }

    return {
      'pfmName': pfmName,
      'effName': effName,
      'sevName': sevName,
      'maxPrn': maxPrn,
    };
  }

  Future<void> _showAddFailureModeDialog(BuildContext context) async {
    final companyRef = _companyRef;

    final pfmSnap = await FirebaseFirestore.instance.collection('potentialFailureMode').get();
    final pfmDocs = pfmSnap.docs
      ..sort((a, b) {
        final aName = (a.data()['name'] as String?) ?? '';
        final bName = (b.data()['name'] as String?) ?? '';
        return aName.compareTo(bName);
      });

    final effectSnap = await FirebaseFirestore.instance.collection('potentialEffect').get();
    final effectDocs = effectSnap.docs
      ..sort((a, b) {
        final aName = (a.data()['name'] as String?) ?? '';
        final bName = (b.data()['name'] as String?) ?? '';
        return aName.compareTo(bName);
      });

    final sevSnap = await TenantFirebaseService.instance
        .firestoreFor(companyRef.id)
        .collection('severity')
        .get();
    final sevDocs = sevSnap.docs
      ..sort((a, b) {
        final aPos = (a.data()['position'] as num?) ?? 0;
        final bPos = (b.data()['position'] as num?) ?? 0;
        return aPos.compareTo(bPos);
      });

    DocumentReference? selPfm;
    DocumentReference? selEffect;
    DocumentReference? selSev;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setState) => DialogAction(
          title: 'Add Failure Mode',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SearchAddSelectDropdown<DocumentReference>(
                label: 'Potential Failure Mode',
                items: pfmDocs.map((d) => d.reference).toList(),
                itemLabel: (ref) =>
                    (pfmDocs.firstWhere((d) => d.reference == ref).data()['name']
                        as String? ?? 'Unnamed'),
                onChanged: (val) => setState(() => selPfm = val),
              ),
              const SizedBox(height: 16),
              SearchAddSelectDropdown<DocumentReference>(
                label: 'Potential Effect',
                items: effectDocs.map((d) => d.reference).toList(),
                itemLabel: (ref) =>
                    (effectDocs.firstWhere((d) => d.reference == ref).data()['name']
                        as String? ?? 'Unnamed'),
                onChanged: (val) => setState(() => selEffect = val),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<DocumentReference>(
                decoration: const InputDecoration(labelText: 'Severity'),
                value: selSev,
                items: sevDocs.map((d) {
                  final name =
                      d.data()['nameConcatenated'] as String? ?? 'Unnamed';
                  return DropdownMenuItem(
                    value: d.reference,
                    child: Text(name),
                  );
                }).toList(),
                onChanged: (val) => setState(() => selSev = val),
              ),
            ],
          ),
          cancelText: 'Cancel',
          actionText: 'Add',
          onCancel: () => Navigator.of(ctx2).pop(),
          onAction: () async {
            if (selPfm == null || selEffect == null || selSev == null) {
              SnackbarService.instance.showSnackBar(
                const SnackBar(duration: Duration(seconds: 5), content: Text('Please fill all fields.')),
              );
              return;
            }
            await FirestoreService().saveDocument(
              collectionRef: FirebaseFirestore.instance.collection('failureMode'),
              data: {
                'objectProcessTaskId': objectProcessTaskRef,
                'potentialFailureModeId': selPfm,
                'potentialEffectId': selEffect,
                'severityId': selSev,
                'createdAt': FieldValue.serverTimestamp(),
              },
            );
            Navigator.of(ctx2).pop();
          },
        ),
      ),
    );
  }

  Future<void> _deleteFailureMode(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> docSnap,
  ) async {
    final docRef = docSnap.reference;
    final oldData = docSnap.data();
    await docRef.delete();
    SnackbarService.instance.showSnackBar(
      SnackBar(
        content: const Text('Failure mode deleted.'),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () => docRef.set(oldData),
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }
}

