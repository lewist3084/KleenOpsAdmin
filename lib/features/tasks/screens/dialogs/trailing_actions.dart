// lib/features/tasks/screens/trailing_actions.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kleenops_admin/common/utils/geo_stamp.dart';
import 'package:kleenops_admin/features/tasks/logic/task_data_logic.dart';
import 'package:kleenops_admin/repositories/task_repository.dart';
import 'package:shared_widgets/utils/process_localization_utils.dart';
import 'package:kleenops_admin/features/tasks/screens/dialogs/trailing_dialog.dart';
import 'package:kleenops_admin/features/tasks/utils/task_alert_file_media.dart';
import 'package:kleenops_admin/services/task_equipment_service.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';

class TrailingActions {
  static String _normalizeLocaleCode(Locale? locale) {
    if (locale == null) {
      return ProcessLocalizationUtils.defaultLocaleCode;
    }
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

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static String _resolveLocalizedText(BuildContext context, dynamic value) {
    if (value == null) return '';
    if (value is String) return value.trim();
    final localeCode =
        _normalizeLocaleCode(Localizations.maybeLocaleOf(context));
    final resolved = ProcessLocalizationUtils.resolveLocalizedText(
      value,
      localeCode: localeCode,
      fallbackLocaleCode: ProcessLocalizationUtils.defaultLocaleCode,
    ).trim();
    if (resolved.isNotEmpty) {
      return resolved;
    }
    return value.toString();
  }

  /// Determines whether to display trailingAction1 based on "skip", "completeTimestamp", and blackout.
  static bool shouldDisplayTrailingAction1(Map<String, dynamic> data) {
    final now = DateTime.now();

    // If completeTimestamp is not null => do not display
    if (data['completeTimestamp'] != null) {
      return false; // << ADDED
    }
    if (isSkipActive(data, now)) return false;

    // Example blackout check
    if (data.containsKey('blackouts') && data['blackouts'] != null) {
      final blackouts = data['blackouts'] as List<dynamic>?;
      if (blackouts != null) {
        for (final b in blackouts) {
          final bMap = b as Map<String, dynamic>?;
          if (bMap == null) continue;
          final Timestamp? startTs = bMap['startTime'];
          final Timestamp? endTs = bMap['endTime'];
          if (startTs != null && endTs != null) {
            final blackoutStart = startTs.toDate();
            final blackoutEnd = endTs.toDate();
            if (now.isAfter(blackoutStart) && now.isBefore(blackoutEnd)) {
              return false;
            }
          }
        }
      }
    }

    return true;
  }

  /// Returns the callback for trailingAction1 for join/exit logic
  static VoidCallback? getTrailingAction1({
    required DocumentSnapshot<Map<String, dynamic>> doc,
    required String currentMemberId,
    required String currentUserName,
    required String companyDocId,
    required BuildContext context,
    bool allowOverrideJoin = false,
  }) {
    return () async {
      final taskRepo = TaskRepository();
      final firestore = FirebaseFirestore.instance;
      final timelineRef = doc.reference;
      final now = DateTime.now();
      final geoPoint = await captureGeoStamp();

      try {
        final snapshotData = doc.data();
        if (snapshotData == null) {
          throw Exception("Timeline task does not exist or has no data!");
        }

        final activeContributors =
            Map<String, dynamic>.from(snapshotData['activeContributors'] ?? {});
        final bool groupTask = snapshotData['groupTask'] == true;
        final int? maxParticipants = _asInt(snapshotData['maxParticipants']);
        final bool hasParticipantLimit =
            maxParticipants != null && maxParticipants > 0;

        final memberRef = firestore
            .collection('company')
            .doc(companyDocId)
            .collection('member')
            .doc(currentMemberId);

        // If user is in activeContributors => exit
        if (activeContributors.containsKey(currentMemberId)) {
          final exitConfirmed = await TrailingDialog.showExitTaskDialog(
            context: context,
          );
          if (!exitConfirmed) return; // user canceled

          final freshSnapshot = await timelineRef.get();
          if (!freshSnapshot.exists) {
            throw Exception("Timeline task no longer exists!");
          }
          final freshData = freshSnapshot.data()!;
          final currentActiveContributors =
              Map<String, dynamic>.from(freshData['activeContributors'] ?? {});
          final bool requireObjectChecks =
              freshData['completeObjectTask'] == true;

          if (!currentActiveContributors.containsKey(currentMemberId)) {
            // race condition
            SnackbarService.instance.showSnackBar(
              const SnackBar(
                  duration: Duration(seconds: 5),
                  content: Text('You are not an active contributor anymore.')),
            );
            return;
          }

          // Check how many are left if you exit
          final numberOfContributors = currentActiveContributors.length;
          final bool isLastPerson = (numberOfContributors == 1);

          bool? isComplete;
          String? note;

          if (isLastPerson) {
            isComplete = await TrailingDialog.showTaskCompletionDialog(
              context: context,
            );
            if (isComplete == null) {
              // user canceled
              return;
            }
            if (isComplete == true) {
              final taskRef = freshData['taskId'];
              if (requireObjectChecks && taskRef is DocumentReference) {
                final Map<String, dynamic> objectTaskChecks =
                    (freshData['objectTaskChecks'] as Map?)
                            ?.cast<String, dynamic>() ??
                        <String, dynamic>{};
                final objectTasksSnap = await taskRepo
                    .objectProcessTaskCollection(companyDocId)
                    .where('taskId', isEqualTo: taskRef)
                    .get();
                final requiredIds = objectTasksSnap.docs
                    .map((doc) => doc.id)
                    .toList(growable: false);
                final allChecked = requiredIds.isEmpty ||
                    requiredIds.every(
                      (id) => objectTaskChecks[id] == true,
                    );
                if (!allChecked) {
                  SnackbarService.instance.showSnackBar(
                    const SnackBar(
                      content: Text(
                        'For this task, you have to check off each individual task before it can be marked as complete.',
                      ),
                      duration: Duration(seconds: 5),
                    ),
                  );
                  return;
                }
              }
            }
            if (isComplete == false && !requireObjectChecks) {
              note = await TrailingDialog.showTaskNoteDialog(
                context: context,
              );
              if (note == null || note.trim().isEmpty) {
                // must have a note
                return;
              }
            }
          }

          // *** Transaction to remove user ***
          await firestore.runTransaction((transaction) async {
            final snap = await transaction.get(timelineRef);
            if (!snap.exists) {
              throw Exception("Timeline task does not exist!");
            }
            final data = snap.data()!;
            final currentActiveContributorsTx =
                Map<String, dynamic>.from(data['activeContributors'] ?? {});

            if (!currentActiveContributorsTx.containsKey(currentMemberId)) {
              throw Exception(
                  "User is not an active contributor (race condition).");
            }

            final userActiveData = currentActiveContributorsTx[currentMemberId]
                as Map<String, dynamic>;
            final Timestamp startTs = userActiveData['startTime'];
            final DateTime startTime = startTs.toDate();
            final int elapsedMs = now.difference(startTime).inMilliseconds;
            final int durationMinutes =
                elapsedMs <= 0 ? 1 : (elapsedMs / 60000).ceil();

            // Prepare contributor data and calculate total duration
            Map<String, dynamic> contributorData = Map<String, dynamic>.from(
                (data['contributors']?[currentMemberId]
                        as Map<String, dynamic>?) ??
                    {});
            contributorData['endTime'] = Timestamp.fromDate(now);
            contributorData['startTime'] ??= startTs;
            contributorData['duration'] = durationMinutes; // << ADDED
            contributorData['memberId'] = memberRef;
            if (geoPoint != null) contributorData['geoOut'] = geoPoint;

            final mergedContribs =
                Map<String, dynamic>.from(data['contributors'] ?? {});
            mergedContribs[currentMemberId] = contributorData;
            int totalDuration = 0;
            for (final entry in mergedContribs.values) {
              final m = entry as Map<String, dynamic>;
              totalDuration += (m['duration'] as int?) ?? 0;
            }

            // References needed for writes
            final taskTitle = _resolveLocalizedText(context, data['title']);
            final taskIdField = data['taskId'];
            DocumentReference existingTaskRef;
            if (taskIdField is DocumentReference) {
              existingTaskRef = taskIdField;
            } else if (taskIdField is String) {
              existingTaskRef = firestore
                  .collection('company')
                  .doc(companyDocId)
                  .collection('tasks')
                  .doc(taskIdField);
            } else {
              existingTaskRef = timelineRef;
            }

            // ── new: fetch the task doc’s name ─────────────
            final taskSnapTx = await transaction.get(existingTaskRef);
            final String taskName = _resolveLocalizedText(
              context,
              (taskSnapTx.data() as Map<String, dynamic>?)?['name'],
            );

            // Firestore requires all reads before any writes in a transaction.
            final memberSnap = await transaction.get(memberRef);

            final newTimelineRef = taskRepo.newTimelineDoc(companyDocId);

            // All reads are done above; begin writes
            transaction.update(timelineRef, {
              'activeContributors.$currentMemberId': FieldValue.delete(),
            });

            transaction.update(timelineRef, {
              'contributors.$currentMemberId': contributorData,
            });

            if (memberSnap.exists) {
              transaction.update(memberRef, {
                'activeTaskId': FieldValue.delete(),
              });
            }

            transaction.set(newTimelineRef, {
              'memberId': memberRef,
              'memberName': currentUserName,
              'name': taskName,
              'title': taskTitle,
              'startTime': Timestamp.fromDate(startTime),
              'endTime': Timestamp.fromDate(now),
              'taskId': existingTaskRef,
              'timelineId': timelineRef,
              'duration':
                  durationMinutes, // timelineCategory= E2HMUuMUUl4Alttuweba
              'timelineCategory': 'E2HMUuMUUl4Alttuweba',
              'timelineCategoryId':
                  taskRepo.timelineCategoryDoc('E2HMUuMUUl4Alttuweba'),
              if (geoPoint != null) 'geoOut': geoPoint,
            });

            // 5) If last person & user says "yes complete"
            if (isLastPerson && isComplete == true) {
              transaction.update(timelineRef, {
                'completeTimestamp': FieldValue.serverTimestamp(),
                'actualDuration': totalDuration,
                'endTimeExtended': FieldValue.serverTimestamp(),
              });
            }

            // 6) If last person & user says "no" => store note as a map entry
            if (isLastPerson &&
                isComplete == false &&
                note != null &&
                note.trim().isNotEmpty) {
              // Generate a unique key for the new note entry.
              final newNoteId = taskRepo.newId();

              transaction.update(timelineRef, {
                'taskNote.$newNoteId': {
                  'note': note.trim(),
                  'memberId': currentMemberId,
                  'name': currentUserName,
                  'timestamp': FieldValue.serverTimestamp(),
                }
              });
            }
          });

          SnackbarService.instance.showSnackBar(
            const SnackBar(duration: Duration(seconds: 5), content: Text('You have exited the task.')),
          );

          // Disconnect BLE-tracked equipment and record runtime
          unawaited(TaskEquipmentService.instance.onTaskExit(
            companyId: companyDocId,
            timelineRef: timelineRef,
          ));
        } else {
          // JOIN branch:
          // First, if this is not a group task and someone is already active, immediately show a snackbar.
          if (!groupTask &&
              activeContributors.isNotEmpty &&
              !allowOverrideJoin) {
            SnackbarService.instance.showSnackBar(
              const SnackBar(duration: Duration(seconds: 5), content: Text('Cannot join: not a group task.')),
            );
            return;
          }

          if (groupTask &&
              hasParticipantLimit &&
              activeContributors.length >= maxParticipants! &&
              !allowOverrideJoin) {
            SnackbarService.instance.showSnackBar(
              const SnackBar(
                  duration: Duration(seconds: 5),
                  content: Text('Cannot join: maximum participants reached.')),
            );
            return;
          }

          // Otherwise, proceed with showing the join dialog.
          final isOnlyUser = activeContributors.isEmpty; // might rename
          final alertNote =
              (snapshotData['taskAlertNote'] as String?)?.trim();
          final companyRef = taskRepo.companyDoc(companyDocId);
          final fileMedia = await TaskAlertFileMedia.load(
            companyRef: companyRef,
            alertRef: doc.reference,
          );
          final alertImages = fileMedia.images;
          final alertVideos = fileMedia.videos;
          final joinConfirmed = await TrailingDialog.showJoinTaskDialog(
            context: context,
            isOnlyUser: isOnlyUser,
            alertNote: alertNote,
            alertImages: alertImages,
            alertVideos: alertVideos,
          );
          if (!joinConfirmed) return;

          final memberSnap = await memberRef.get();
          if (!memberSnap.exists) {
            SnackbarService.instance.showSnackBar(
              const SnackBar(duration: Duration(seconds: 5), content: Text('Active membership not found.')),
            );
            return;
          }

          await firestore.runTransaction((transaction) async {
            final snapshot = await transaction.get(timelineRef);
            if (!snapshot.exists) {
              throw Exception("Timeline task does not exist!");
            }
            final data = snapshot.data()!;
            final currentActiveContributors =
                Map<String, dynamic>.from(data['activeContributors'] ?? {});
            final groupTaskFlag = data['groupTask'] == true;
            final maxParticipants = _asInt(data['maxParticipants']);
            final hasParticipantLimit =
                maxParticipants != null && maxParticipants > 0;

            if (!groupTaskFlag &&
                currentActiveContributors.isNotEmpty &&
                !allowOverrideJoin) {
              throw Exception(
                  "Cannot join: groupTask is false & the task is active.");
            }

            if (groupTaskFlag &&
                hasParticipantLimit &&
                currentActiveContributors.length >= maxParticipants! &&
                !allowOverrideJoin) {
              throw Exception("Cannot join: maximum participants reached.");
            }

            // Check if user is already active via membership
            final memberSnapshot = await transaction.get(memberRef);
            if (!memberSnapshot.exists) {
              throw Exception("Active membership not found.");
            }
            final memberData = memberSnapshot.data() ?? {};
            if (memberData['activeTaskId'] != null) {
              throw Exception("You are already active on another task.");
            }

            final nowTs = Timestamp.now();

            // Add user
            transaction.update(timelineRef, {
              'activeContributors.$currentMemberId': {
                'memberId': memberRef,
                'name': currentUserName,
                'startTime': nowTs,
                if (geoPoint != null) 'geoIn': geoPoint,
              },
              'contributors.$currentMemberId': {
                'memberId': memberRef,
                'name': currentUserName,
                'startTime': nowTs,
                'endTime': null,
                'duration': null, // << optional
                if (geoPoint != null) 'geoIn': geoPoint,
              },
            });

            transaction.update(memberRef, {
              'activeTaskId': timelineRef,
            });
          });

          SnackbarService.instance.showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 5),
              content: Text(isOnlyUser
                  ? 'You have started the task.'
                  : 'You have joined the task.'),
            ),
          );

          // Auto-connect BLE-tracked equipment (runs silently in background)
          unawaited(TaskEquipmentService.instance.onTaskStart(
            companyId: companyDocId,
            timelineRef: timelineRef,
          ));
        }
      } catch (e) {
        SnackbarService.instance.showSnackBar(
          SnackBar(duration: const Duration(seconds: 5), content: Text('Error: ${e.toString()}')),
        );
      }
    };
  }
}
