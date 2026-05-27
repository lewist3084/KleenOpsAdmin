// lib/features/training/details/training_assigned_training_details.dart

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_widgets/utils/process_localization_utils.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/containers/container_header.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';

class TrainingAssignedTrainingDetailsScreen extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final String assignedTrainingId;

  const TrainingAssignedTrainingDetailsScreen({
    super.key,
    required this.companyRef,
    required this.assignedTrainingId,
  });

  @override
  State<TrainingAssignedTrainingDetailsScreen> createState() =>
      _TrainingAssignedTrainingDetailsScreenState();
}

class _TrainingAssignedTrainingDetailsScreenState
    extends State<TrainingAssignedTrainingDetailsScreen> {
  late final DocumentReference<Map<String, dynamic>> _assignedRef;
  late final Future<_AssignedTrainingInfo> _infoFuture;
  final DateFormat _timestampFormat = DateFormat.yMd().add_jm();

  @override
  void initState() {
    super.initState();
    _assignedRef = FirebaseFirestore.instance
        .collection('assignedTraining')
        .doc(widget.assignedTrainingId);
    _infoFuture = _loadTrainingInfo();
  }

  Future<_AssignedTrainingInfo> _loadTrainingInfo() async {
    final assignedSnap = await _assignedRef.get();
    final trainingRef = assignedSnap.data()?['trainingId']
        as DocumentReference<Map<String, dynamic>>?;
    if (trainingRef == null) {
      return const _AssignedTrainingInfo(name: '', description: '');
    }

    final trainingSnap = await trainingRef.get();
    final data = trainingSnap.data() ?? <String, dynamic>{};
    return _AssignedTrainingInfo(
      name: data['name'],
      description: data['description'],
    );
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

  void _showSignatureDialog(int revision, String signature) {
    showDialog<void>(
      context: context,
      builder: (_) => DialogAction(
        title: 'Signature (rev $revision)',
        cancelText: 'Close',
        onCancel: () => Navigator.of(context).pop(),
        showActionButton: false,
        content: signature.isEmpty
            ? const Text('No signature data.')
            : Image.memory(
                base64Decode(signature),
                height: 200,
                fit: BoxFit.contain,
              ),
      ),
    );
  }

  Widget _buildSignatureTile(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final ts = (data['createdAt'] as Timestamp?)?.toDate();
    final when = ts == null ? '-' : _timestampFormat.format(ts);
    final rev = data['revision'] as int? ?? 0;
    final sig = data['signature'] as String? ?? '';

    return StandardTileSmallDart.iconText(
      leadingicon: Icons.edit,
      text: 'Revision $rev',
      secondText: when,
      secondTextIcon: Icons.access_time,
      trailingIcon1: sig.isEmpty ? null : Icons.visibility,
      trailingAction1:
          sig.isEmpty ? null : () => _showSignatureDialog(rev, sig),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom + 16;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: null,
      body: _wrapCanvas(
        FutureBuilder<_AssignedTrainingInfo>(
          future: _infoFuture,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('Error: ${snap.error}'));
            }

            final info = snap.data ??
                const _AssignedTrainingInfo(name: '', description: '');
            final localeCodeRaw = ProcessLocalizationUtils.normalizeLocaleCode(
              Localizations.localeOf(context).toString(),
            );
            final localeCode = localeCodeRaw.isNotEmpty
                ? localeCodeRaw
                : ProcessLocalizationUtils.defaultLocaleCode;
            final name = ProcessLocalizationUtils.resolveLocalizedText(
              info.name,
              localeCode: localeCode,
              fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
            );
            final description = ProcessLocalizationUtils.resolveLocalizedText(
              info.description,
              localeCode: localeCode,
              fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
            );
            final hasDescription = description.trim().isNotEmpty;

            return ListView(
              padding: EdgeInsets.only(bottom: bottomPadding),
              children: [
                ContainerHeader(
                  titleHeader: 'Training',
                  title: name.isNotEmpty ? name : 'Training',
                  descriptionHeader: hasDescription ? 'Description' : '',
                  description: description,
                  textIcon: Icons.school_outlined,
                  descriptionIcon: Icons.description_outlined,
                ),
                const SizedBox(height: 16),
                ContainerActionStandardViewGroup(
                  title: 'Signatures',
                  queryStream: FirebaseFirestore.instance
                      .collection('assignedTrainingSignature')
                      .where('assignedTrainingId', isEqualTo: _assignedRef)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  groupBy: (_) => null,
                  itemBuilder: _buildSignatureTile,
                  emptyMessage: 'No signatures found.',
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  actionText: '',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AssignedTrainingInfo {
  final dynamic name;
  final dynamic description;

  const _AssignedTrainingInfo({
    required this.name,
    required this.description,
  });
}
