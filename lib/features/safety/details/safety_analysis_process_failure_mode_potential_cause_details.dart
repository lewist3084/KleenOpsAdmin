import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/labels/header_info_icon_value.dart';
import 'package:shared_widgets/lists/standardViewGroup.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';
import 'package:shared_widgets/search/search_field_action.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import '../forms/corrective_action_form.dart';
import 'package:kleenops_admin/services/ai/ai_context_service.dart';
import 'package:kleenops_admin/widgets/ai/ai_screen_context.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';

class SafetyAnalysisProcessFailureModePotentialCauseDetailsScreen
    extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> potentialCauseRef;

  const SafetyAnalysisProcessFailureModePotentialCauseDetailsScreen({
    super.key,
    required this.potentialCauseRef,
  });

  @override
  State<SafetyAnalysisProcessFailureModePotentialCauseDetailsScreen>
      createState() =>
          _SafetyAnalysisProcessFailureModePotentialCauseDetailsScreenState();
}

class _SafetyAnalysisProcessFailureModePotentialCauseDetailsScreenState
    extends State<SafetyAnalysisProcessFailureModePotentialCauseDetailsScreen> {
  DocumentReference<Map<String, dynamic>> get potentialCauseRef =>
      widget.potentialCauseRef;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _potentialCauseStream;

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
    final bool hideChrome = false;
    final baseAiContext = AiContextPresets.safetyPotentialCauseDetails(
      potentialCauseId: potentialCauseRef.id,
      label: 'Potential Cause',
      entityPath: potentialCauseRef.path,
    );

    Widget buildBottomBar({VoidCallback? onAiPressed}) {
      if (hideChrome) return const SizedBox.shrink();
      final menuSections = MenuDrawerSections(
      );
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: 'Potential Cause Details',
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(context),
        child: const Icon(Icons.edit),
      ),
      body: AiScreenContext(
        context: baseAiContext,
        child: _wrapCanvas(
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _potentialCauseStream ??= potentialCauseRef.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Center(child: CircularProgressIndicator());
              }

              final data = snapshot.data!.data()!;
              final pcRef = data['potentialCauseId'] as DocumentReference?;
              final occRef = data['occurrenceId'] as DocumentReference?;
              final procRef = data['processControlId'] as DocumentReference?;
              final detRef = data['detectionId'] as DocumentReference?;
              final legacyControl =
                  data['currentProcessControl'] as String? ?? '';

              const bottomPadding = 16.0;

              return FutureBuilder<List<DocumentSnapshot?>>(
                future: Future.wait([
                  pcRef?.get() ?? Future.value(null),
                  occRef?.get() ?? Future.value(null),
                  procRef?.get() ?? Future.value(null),
                  detRef?.get() ?? Future.value(null),
                ]),
                builder: (ctx, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final pcName = (snap.data![0]?.data()
                          as Map<String, dynamic>?)?['name'] ??
                      '';
                  final occName = (snap.data![1]?.data()
                          as Map<String, dynamic>?)?['nameConcatenated'] ??
                      '';
                  final controlName = (snap.data![2]?.data()
                          as Map<String, dynamic>?)?['name'] ??
                      legacyControl;
                  final detName = (snap.data![3]?.data()
                          as Map<String, dynamic>?)?['nameConcatenated'] ??
                      '';

                  return ListView(
                    padding: EdgeInsets.only(
                      bottom:
                          bottomPadding + MediaQuery.of(context).padding.bottom,
                    ),
                    children: [
                      ContainerActionWidget(
                        title: null,
                        actionText: '',
                        content: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            HeaderInfoIconValue(
                              header: 'Potential Cause',
                              value: pcName,
                              icon: Icons.warning_amber_outlined,
                            ),
                            const SizedBox(height: 16),
                            HeaderInfoIconValue(
                              header: 'Occurrence',
                              value: occName,
                              icon: Icons.change_circle_outlined,
                            ),
                            const SizedBox(height: 16),
                            HeaderInfoIconValue(
                              header: 'Current Process Control',
                              value: controlName,
                              icon: Icons.gpp_maybe_outlined,
                            ),
                            const SizedBox(height: 16),
                            HeaderInfoIconValue(
                              header: 'Detection',
                              value: detName,
                              icon: Icons.search,
                            ),
                          ],
                        ),
                      ),
                      ContainerActionWidget(
                        title: 'Corrective Actions',
                        actionText: 'Add',
                        onAction: () => _openCorrectiveActionForm(context),
                        content: _buildCorrectiveActionList(),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCorrectiveActionList() {
    final stream =
        potentialCauseRef.collection('controlCorrectiveAction').snapshots();

    return StandardViewGroup(
      queryStream: stream,
      groupBy: (_) => null,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      emptyMessage: 'No corrective actions found.',
      itemBuilder: (doc) {
        final data = doc.data();
        final name = data['name'] as String? ?? 'Unnamed';
        return StandardTileSmallDart.iconText(
          leadingicon: Icons.build,
          text: name,
        );
      },
    );
  }

  void _openCorrectiveActionForm(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CorrectiveActionForm(
          potentialCauseRef: potentialCauseRef,
        ),
      ),
    );
  }

  DocumentReference<Map<String, dynamic>> get _companyRef =>
      potentialCauseRef.parent.parent!;

  Future<void> _showEditDialog(BuildContext context) async {
    final pcSnap = await FirebaseFirestore.instance.collection('potentialCause').get();
    final pcDocs = pcSnap.docs
      ..sort((a, b) {
        final aName = (a.data()['name'] as String?) ?? '';
        final bName = (b.data()['name'] as String?) ?? '';
        return aName.compareTo(bName);
      });

    final occSnap =
        await FirebaseFirestore.instance.collection('occurrence').get();
    final occDocs = occSnap.docs
      ..sort((a, b) {
        final aPos = (a.data()['position'] as num?) ?? 0;
        final bPos = (b.data()['position'] as num?) ?? 0;
        return aPos.compareTo(bPos);
      });

    final procSnap = await FirebaseFirestore.instance.collection('processControl').get();
    final procDocs = procSnap.docs
      ..sort((a, b) {
        final aName = (a.data()['name'] as String?) ?? '';
        final bName = (b.data()['name'] as String?) ?? '';
        return aName.compareTo(bName);
      });

    final detSnap =
        await FirebaseFirestore.instance.collection('detection').get();
    final detDocs = detSnap.docs
      ..sort((a, b) {
        final aPos = (a.data()['position'] as num?) ?? 0;
        final bPos = (b.data()['position'] as num?) ?? 0;
        return aPos.compareTo(bPos);
      });

    final currentData = await potentialCauseRef.get();
    final pcRef = currentData['potentialCauseId'] as DocumentReference?;
    final occRef = currentData['occurrenceId'] as DocumentReference?;
    final procRef = currentData['processControlId'] as DocumentReference?;
    final detRef = currentData['detectionId'] as DocumentReference?;

    DocumentReference? selPc = pcRef;
    DocumentReference? selOcc = occRef;
    DocumentReference? selProc = procRef;
    DocumentReference? selDet = detRef;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setState) => DialogAction(
          title: 'Edit Potential Cause',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SearchAddSelectDropdown<DocumentReference>(
                label: 'Potential Cause',
                items: pcDocs.map((d) => d.reference).toList(),
                itemLabel: (ref) => (pcDocs
                        .firstWhere((d) => d.reference == ref)
                        .data()['name'] as String? ??
                    'Unnamed'),
                initialValue: selPc,
                onChanged: (val) => setState(() => selPc = val),
              ),
              const SizedBox(height: 16),
              SearchAddSelectDropdown<DocumentReference>(
                label: 'Occurrence',
                items: occDocs.map((d) => d.reference).toList(),
                itemLabel: (ref) => (occDocs
                        .firstWhere((d) => d.reference == ref)
                        .data()['nameConcatenated'] as String? ??
                    'Unnamed'),
                initialValue: selOcc,
                onChanged: (val) => setState(() => selOcc = val),
              ),
              const SizedBox(height: 16),
              SearchAddSelectDropdown<DocumentReference>(
                label: 'Current Process Control',
                items: procDocs.map((d) => d.reference).toList(),
                itemLabel: (ref) => (procDocs
                        .firstWhere((d) => d.reference == ref)
                        .data()['name'] as String? ??
                    'Unnamed'),
                initialValue: selProc,
                onChanged: (val) => setState(() => selProc = val),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<DocumentReference>(
                decoration: const InputDecoration(labelText: 'Detection'),
                initialValue: selDet,
                items: detDocs.map((d) {
                  final name =
                      d.data()['nameConcatenated'] as String? ?? 'Unnamed';
                  return DropdownMenuItem(
                    value: d.reference,
                    child: Text(name),
                  );
                }).toList(),
                onChanged: (val) => setState(() => selDet = val),
              ),
            ],
          ),
          cancelText: 'Cancel',
          actionText: 'Save',
          onCancel: () => Navigator.of(ctx2).pop(),
          onAction: () async {
            if (selPc == null ||
                selOcc == null ||
                selProc == null ||
                selDet == null) {
              SnackbarService.instance.showSnackBar(
                const SnackBar(duration: Duration(seconds: 5), content: Text('Please fill all fields.')),
              );
              return;
            }
            await potentialCauseRef.update({
              'potentialCauseId': selPc,
              'occurrenceId': selOcc,
              'processControlId': selProc,
              'detectionId': selDet,
            });
            Navigator.of(ctx2).pop();
          },
        ),
      ),
    );
  }
}
