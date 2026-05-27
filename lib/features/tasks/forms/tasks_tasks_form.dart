// lib/features/tasks/forms/tasks_tasks_form.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kleenops_admin/l10n/app_localizations.dart';
import 'package:shared_widgets/utils/process_localization_utils.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';

class TasksTasksForm {
  static String _normalizeLocaleCode(String code) {
    return ProcessLocalizationUtils.normalizeLocaleCode(code);
  }

  static String _localeCodeOf(Locale locale) {
    final language = locale.languageCode.trim().toLowerCase();
    final script = locale.scriptCode?.trim().toLowerCase();
    final country = locale.countryCode?.trim().toLowerCase();
    final segments = <String>[
      if (language.isNotEmpty) language,
      if (script != null && script.isNotEmpty) script,
      if (country != null && country.isNotEmpty) country,
    ];
    if (segments.isEmpty) return '';
    return _normalizeLocaleCode(segments.join('-'));
  }

  static String _resolveLocaleCode(BuildContext context) {
    final supportedLocaleCodeSet = AppLocalizations.supportedLocales
        .map(_localeCodeOf)
        .where((code) => code.isNotEmpty)
        .toSet()
      ..add(_normalizeLocaleCode(ProcessLocalizationUtils.defaultLocaleCode));
    final locale = Localizations.maybeLocaleOf(context);
    final inferredFull = locale != null ? _localeCodeOf(locale) : '';
    final inferredLanguage = locale?.languageCode.trim().toLowerCase() ?? '';
    final candidates = <String>[
      if (inferredFull.isNotEmpty) inferredFull,
      if (inferredLanguage.isNotEmpty) inferredLanguage,
      ProcessLocalizationUtils.defaultLocaleCode,
    ];
    return candidates.firstWhere(
      (code) => supportedLocaleCodeSet.contains(_normalizeLocaleCode(code)),
      orElse: () => ProcessLocalizationUtils.defaultLocaleCode,
    );
  }

  static Map<String, dynamic> _buildLocalizedPayload({
    required String value,
    required String localeCode,
  }) {
    final trimmed = value.trim();
    return ProcessLocalizationUtils.buildLocalizedFieldPayload(
      source: trimmed,
      sourceLanguage: localeCode,
      translations: <String, String>{localeCode: trimmed},
      fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
    );
  }

  static Future<void> showAddTaskDialog(BuildContext context) async {
    final loc = AppLocalizations.of(context)!;
    final titleController = TextEditingController();
    final noteController = TextEditingController();
    final durationController = TextEditingController();

    bool submitted = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return DialogAction(
              title: 'Tasks',
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(labelText: loc.commonName),
                    textInputAction: TextInputAction.next,
                    onTapOutside: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                  ),
                  TextField(
                    controller: noteController,
                    decoration:
                        InputDecoration(labelText: loc.commonDescription),
                    textInputAction: TextInputAction.next,
                    onTapOutside: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                  ),
                  TextField(
                    controller: durationController,
                    decoration:
                        const InputDecoration(labelText: 'Duration (minutes)'),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    onTapOutside: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                  ),
                ],
              ),
              cancelText: loc.commonCancel,
              actionText: loc.commonSave,
              onCancel: () => Navigator.of(context).pop(),
              onAction: () {
                submitted = true;
                Navigator.of(context).pop();
              },
            );
          },
        );
      },
    );

    if (!submitted) return;

    final taskTitle = titleController.text.trim();
    final taskNote = noteController.text.trim();
    final durationMinutes = int.tryParse(durationController.text.trim()) ?? 0;

    if (taskTitle.isEmpty || durationMinutes <= 0) {
      SnackbarService.instance.showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 5),
          content: Text('Name is required'),
        ),
      );
      return;
    }

    final now = DateTime.now();
    final startTime = now.subtract(Duration(minutes: durationMinutes));

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final uid = currentUser.uid;
    // Admin: collection-group on TOP-LEVEL `memberByUid` (admin has no
    // per-company subcollections; the index is just a top-level collection).
    final memberIndexSnap = await FirebaseFirestore.instance
        .collection('memberByUid')
        .where('uid', isEqualTo: uid)
        .where('active', isEqualTo: true)
        .limit(1)
        .get();
    if (memberIndexSnap.docs.isEmpty) {
      SnackbarService.instance.showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 5),
          content: Text('Active membership not found.'),
        ),
      );
      return;
    }
    final memberIndexDoc = memberIndexSnap.docs.first;
    final memberIndexData = memberIndexDoc.data();
    final memberId = memberIndexData['memberId'] as String?;
    if (memberId == null || memberId.trim().isEmpty) {
      SnackbarService.instance.showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 5),
          content: Text('Member profile not found.'),
        ),
      );
      return;
    }
    final memberRef =
        FirebaseFirestore.instance.collection('member').doc(memberId.trim());
    final memberSnap = await memberRef.get();
    final memberData = memberSnap.data() ?? <String, dynamic>{};
    final primaryTeamRef = memberData['primaryTeamId'];
    final userName = memberData['name'] ?? '';
    if (!context.mounted) return;
    final localeCode = _resolveLocaleCode(context);

    final timelineCollection =
        FirebaseFirestore.instance.collection('timeline');

    final timelineData = {
      'title': taskTitle,
      'note': taskNote,
      'titleLocalized': _buildLocalizedPayload(
        value: taskTitle,
        localeCode: localeCode,
      ),
      if (taskNote.trim().isNotEmpty)
        'noteLocalized': _buildLocalizedPayload(
          value: taskNote,
          localeCode: localeCode,
        ),
      'timelineCategory': 'Rpl9Mn34gJBdZ007jXpo',
      'memberId': memberRef,
      'teamId': primaryTeamRef,
      'createdAt': FieldValue.serverTimestamp(),
      'endTime': Timestamp.fromDate(now),
      'startTime': Timestamp.fromDate(startTime),
      'completeTimestamp': FieldValue.serverTimestamp(),
      'contributors': {
        memberRef.id: {
          'memberId': memberRef,
          'name': userName,
          'duration': durationMinutes,
          'endTime': Timestamp.fromDate(now),
          'startTime': Timestamp.fromDate(startTime),
        },
      },
    };

    try {
      await timelineCollection.add(timelineData);
      SnackbarService.instance.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: Text('Tasks ${loc.commonSave}'),
        ),
      );
    } catch (e) {
      SnackbarService.instance.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: Text('Error saving task: $e'),
        ),
      );
    }
  }
}
