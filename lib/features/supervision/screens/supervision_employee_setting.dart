//  supervision_employee_setting.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/labels/text_info_checkbox.dart';
import 'package:kleenops_admin/features/supervision/logic/permission_updates.dart';

/// Settings tab for supervision: toggles user access permissions.
class SupervisionEmployeeSettingContent extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> employeeRef;

  const SupervisionEmployeeSettingContent({
    super.key,
    required this.employeeRef,
  });

  @override
  State<SupervisionEmployeeSettingContent> createState() =>
      _SupervisionEmployeeSettingContentState();
}

class _SupervisionEmployeeSettingContentState
    extends State<SupervisionEmployeeSettingContent> {
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _employeeDocStream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _employeeDocStream ??= widget.employeeRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return Center(child: Text('Error loading settings: \${snapshot.error}'));
        }

        final data = snapshot.data!.data()!;

        final isActive = data['active'] as bool? ?? false;
        final isDirectLabor = data['directLabor'] as bool? ?? false;

        final showContact = data['showContact'] as bool? ?? false;
        final alertAfterHours = data['alertAfterHours'] as bool? ?? false;
        final messageBoard = data['messageBoard'] as bool? ?? false;
        final bulletinBoard = data['bulletinBoard'] as bool? ?? false;

        final canSafetyReport = data['canSafetyReport'] as bool? ?? false;
        final canInventoryRequest =
            data['canInventoryRequest'] as bool? ?? false;
        final canPolicyReport = data['canPolicyReport'] as bool? ?? false;

        final canApproveAbsences = data['canApproveAbsences'] as bool? ?? false;
        final canPostCalendarToTeam =
            data['canPostCalendarToTeam'] as bool? ?? false;

        final canReceiveLateAlerts =
            data['canReceiveLateAlerts'] as bool? ?? false;
        final canReceiveAbsenceAlerts =
            data['canReceiveAbsenceAlerts'] as bool? ?? false;
        final canApprovePerformance =
            data['canApprovePerformance'] as bool? ?? false;
        final canReceiveAdHocTaskAlerts =
            data['canReceiveAdHocTaskAlerts'] as bool? ?? false;

        final trackDependability = data['trackDependability'] as bool? ?? false;
        final aiAccess = data['aiAccess'] as bool? ?? false;

        final canComplete = data['canComplete'] as bool? ?? false;
        final canSkip = data['canSkip'] as bool? ?? false;
        final canDisablePacing = data['canDisablePacing'] as bool? ?? false;
        final canOverride = data['canOverride'] as bool? ?? false;
        final canAlertTask = data['canAlertTask'] as bool? ?? false;
        final canFlag = data['canFlag'] as bool? ?? false;
        final canQuality = data['canQuality'] as bool? ?? false;
        final canRemoveContributor =
            data['canRemoveContributor'] as bool? ?? false;
        final overrideClockIn = data['overrideClockIn'] as bool? ?? false;
        final overrideTrainingLockout =
            data['overrideTrainingLockout'] as bool? ?? false;

        final appTasks = data['tasks'] as bool? ?? false;
        final appFacilities = data['facilities'] as bool? ?? false;
        final appMarketplace = data['marketplace'] as bool? ?? false;
        final appObjects = data['objects'] as bool? ?? false;
        final appProcesses = data['processes'] as bool? ?? false;
        final appScheduling = data['scheduling'] as bool? ?? false;
        final appHR = data['hr'] as bool? ?? false;
        final appSupervision = data['supervision'] as bool? ?? false;
        final appTraining = data['training'] as bool? ?? false;
        final appQuality = data['quality'] as bool? ?? false;
        final appSafety = data['safety'] as bool? ?? false;
        final appInventory = data['inventory'] as bool? ?? false;
        final appPurchasing = data['purchasing'] as bool? ?? false;
        final appOccupancy = data['occupancy'] as bool? ?? false;
        final appEngagement = data['engagement'] as bool? ?? false;
        final appSales = data['sales'] as bool? ?? false;
        final appLegal = data['legal'] as bool? ?? false;
        final appFinance = data['finance'] as bool? ?? false;
        final appAdministration = data['administration'] as bool? ?? false;

        void updateTaskPermission({
          required String permissionKey,
          required bool enabled,
        }) {
          final updates = buildPermissionUpdate(
            permissionKey: permissionKey,
            enabled: enabled,
          );
          widget.employeeRef.update(updates);
        }

        return ListView(
          children: [
            ContainerActionWidget(
              title: 'Status',
              content: Column(
                children: [
                  TextInfoCheckbox(
                    text: 'Active',
                    value: isActive,
                    onChanged: (v) {
                      if (v == null) return;
                      widget.employeeRef.update({'active': v});
                    },
                  ),
                ],
              ),
              actionText: '',
            ),
            ContainerActionWidget(
              title: 'Accounting',
              content: Column(
                children: [
                  TextInfoCheckbox(
                    text: 'Direct Labor',
                    value: isDirectLabor,
                    onChanged: (v) {
                      if (v == null) return;
                      widget.employeeRef.update({'directLabor': v});
                    },
                  ),
                ],
              ),
              actionText: '',
            ),
            ContainerActionWidget(
              title: 'Performance',
              content: Column(
                children: [
                  TextInfoCheckbox(
                    text: 'Track Dependability',
                    value: trackDependability,
                    onChanged: (v) {
                      if (v == null) return;
                      widget.employeeRef.update({'trackDependability': v});
                    },
                  ),
                ],
              ),
              actionText: '',
            ),
            ContainerActionWidget(
              title: 'AI Access',
              content: Column(
                children: [
                  TextInfoCheckbox(
                    text: 'General Access',
                    value: aiAccess,
                    onChanged: (v) {
                      if (v == null) return;
                      widget.employeeRef.update({'aiAccess': v});
                    },
                  ),
                ],
              ),
              actionText: '',
            ),
            ContainerActionWidget(
              title: 'Communication',
              content: Column(
                children: [
                  TextInfoCheckbox(
                    text: 'Show Contact Information',
                    value: showContact,
                    onChanged: (v) {
                      if (v == null) return;
                      widget.employeeRef.update({'showContact': v});
                    },
                  ),
                  TextInfoCheckbox(
                    text: 'Alert After Hours',
                    value: alertAfterHours,
                    onChanged: (v) {
                      if (v == null) return;
                      widget.employeeRef.update({'alertAfterHours': v});
                    },
                  ),
                  TextInfoCheckbox(
                    text: 'Message Board',
                    value: messageBoard,
                    onChanged: (v) {
                      if (v == null) return;
                      widget.employeeRef.update({'messageBoard': v});
                    },
                  ),
                  TextInfoCheckbox(
                    text: 'Bulletin Board',
                    value: bulletinBoard,
                    onChanged: (v) {
                      if (v == null) return;
                      widget.employeeRef.update({'bulletinBoard': v});
                    },
                  ),
                ],
              ),
              actionText: '',
            ),
            ContainerActionWidget(
              title: 'Calendar',
              content: Column(
                children: [
                  TextInfoCheckbox(
                    text: 'Approve Absences',
                    value: canApproveAbsences,
                    onChanged: (v) {
                      if (v == null) return;
                      widget.employeeRef.update({'canApproveAbsences': v});
                    },
                  ),
                  TextInfoCheckbox(
                    text: 'Post to Team',
                    value: canPostCalendarToTeam,
                    onChanged: (v) {
                      if (v == null) return;
                      widget.employeeRef
                          .update({'canPostCalendarToTeam': v});
                    },
                  ),
                ],
              ),
              actionText: '',
            ),
            ContainerActionWidget(
              title: 'Supervisor Alerts',
              content: Column(
                children: [
                  TextInfoCheckbox(
                    text: 'Receive Late Alerts',
                    value: canReceiveLateAlerts,
                    onChanged: (v) {
                      if (v == null) return;
                      widget.employeeRef.update({'canReceiveLateAlerts': v});
                    },
                  ),
                  TextInfoCheckbox(
                    text: 'Receive Absence Alerts',
                    value: canReceiveAbsenceAlerts,
                    onChanged: (v) {
                      if (v == null) return;
                      widget.employeeRef
                          .update({'canReceiveAbsenceAlerts': v});
                    },
                  ),
                  TextInfoCheckbox(
                    text: 'Approve Performance Disputes',
                    value: canApprovePerformance,
                    onChanged: (v) {
                      if (v == null) return;
                      widget.employeeRef.update({'canApprovePerformance': v});
                    },
                  ),
                  TextInfoCheckbox(
                    text: 'Receive Ad-Hoc Task Alerts',
                    value: canReceiveAdHocTaskAlerts,
                    onChanged: (v) {
                      if (v == null) return;
                      widget.employeeRef
                          .update({'canReceiveAdHocTaskAlerts': v});
                    },
                  ),
                ],
              ),
              actionText: '',
            ),
            ContainerActionWidget(
              title: 'Actions',
              content: Column(
                children: [
                  TextInfoCheckbox(
                    text: 'Safety Reports',
                    value: canSafetyReport,
                    onChanged: (v) {
                      if (v == null) return;
                      widget.employeeRef.update({'canSafetyReport': v});
                    },
                  ),
                  TextInfoCheckbox(
                    text: 'Inventory Requests',
                    value: canInventoryRequest,
                    onChanged: (v) {
                      if (v == null) return;
                      widget.employeeRef.update({'canInventoryRequest': v});
                    },
                  ),
                  TextInfoCheckbox(
                    text: 'Policy Reports',
                    value: canPolicyReport,
                    onChanged: (v) {
                      if (v == null) return;
                      widget.employeeRef.update({'canPolicyReport': v});
                    },
                  ),
                ],
              ),
              actionText: '',
            ),
            ContainerActionWidget(
              title: 'Tasks',
              content: Column(
                children: [
                  TextInfoCheckbox(
                    text: 'Force Complete',
                    value: canComplete,
                    onChanged: (v) {
                      if (v == null) return;
                      updateTaskPermission(
                          permissionKey: 'canComplete', enabled: v);
                    },
                  ),
                  TextInfoCheckbox(
                    text: 'Skip Tasks',
                    value: canSkip,
                    onChanged: (v) {
                      if (v == null) return;
                      updateTaskPermission(
                          permissionKey: 'canSkip', enabled: v);
                    },
                  ),
                  TextInfoCheckbox(
                    text: 'Disable Pacing',
                    value: canDisablePacing,
                    onChanged: (v) {
                      if (v == null) return;
                      updateTaskPermission(
                        permissionKey: 'canDisablePacing',
                        enabled: v,
                      );
                    },
                  ),
                  TextInfoCheckbox(
                    text: 'Override Restrictions',
                    value: canOverride,
                    onChanged: (v) {
                      if (v == null) return;
                      updateTaskPermission(
                        permissionKey: 'canOverride',
                        enabled: v,
                      );
                    },
                  ),
                  TextInfoCheckbox(
                    text: 'Create Task Alerts',
                    value: canAlertTask,
                    onChanged: (v) {
                      if (v == null) return;
                      updateTaskPermission(
                          permissionKey: 'canAlertTask', enabled: v);
                    },
                  ),
                  TextInfoCheckbox(
                    text: 'Flag Tasks',
                    value: canFlag,
                    onChanged: (v) {
                      if (v == null) return;
                      updateTaskPermission(
                          permissionKey: 'canFlag', enabled: v);
                    },
                  ),
                  TextInfoCheckbox(
                    text: 'Quality Reports',
                    value: canQuality,
                    onChanged: (v) {
                      if (v == null) return;
                      updateTaskPermission(
                          permissionKey: 'canQuality', enabled: v);
                    },
                  ),
                  TextInfoCheckbox(
                    text: 'Remove Contributors',
                    value: canRemoveContributor,
                    onChanged: (v) {
                      if (v == null) return;
                      updateTaskPermission(
                        permissionKey: 'canRemoveContributor',
                        enabled: v,
                      );
                    },
                  ),
                  TextInfoCheckbox(
                    text: 'Override Clock In',
                    value: overrideClockIn,
                    onChanged: (v) {
                      if (v == null) return;
                      widget.employeeRef.update({'overrideClockIn': v});
                    },
                  ),
                  TextInfoCheckbox(
                    text: 'Override Training Lockout',
                    value: overrideTrainingLockout,
                    onChanged: (v) {
                      if (v == null) return;
                      widget.employeeRef
                          .update({'overrideTrainingLockout': v});
                    },
                  ),
                ],
              ),
              actionText: '',
            ),
            ContainerActionWidget(
              title: 'Apps',
              content: Column(
                children: [
                  TextInfoCheckbox(
                    text: 'Tasks',
                    value: appTasks,
                    onChanged: (v) {
                      if (v == null) return;
                      widget.employeeRef.update({'tasks': v});
                    },
                  ),
                  TextInfoCheckbox(
                    text: 'Facilities',
                    value: appFacilities,
                    onChanged: (v) {
                      if (v == null) return;
                      widget.employeeRef.update({'facilities': v});
                    },
                  ),
                  TextInfoCheckbox(
                    text: 'Marketplace',
                    value: appMarketplace,
                    onChanged: (v) {
                      if (v == null) return;
                      widget.employeeRef.update({'marketplace': v});
                    },
                  ),
                  TextInfoCheckbox(
                    text: 'Objects',
                    value: appObjects,
                    onChanged: (v) {
                      if (v == null) return;
                      widget.employeeRef.update({'objects': v});
                    },
                  ),
                  TextInfoCheckbox(
                    text: 'Processes',
                    value: appProcesses,
                    onChanged: (v) {
                      if (v == null) return;
                      widget.employeeRef.update({'processes': v});
                    },
                  ),
                  TextInfoCheckbox(
                    text: 'Scheduling',
                    value: appScheduling,
                    onChanged: (v) {
                      if (v == null) return;
                      widget.employeeRef.update({'scheduling': v});
                    },
                  ),
                  TextInfoCheckbox(
                    text: 'HR',
                    value: appHR,
                    onChanged: (v) {
                      if (v == null) return;
                      widget.employeeRef.update({'hr': v});
                    },
                  ),
                  TextInfoCheckbox(
                    text: 'Supervision',
                    value: appSupervision,
                    onChanged: (v) {
                      if (v == null) return;
                      widget.employeeRef.update({'supervision': v});
                    },
                  ),
                  TextInfoCheckbox(
                    text: 'Training',
                    value: appTraining,
                    onChanged: (v) {
                      if (v == null) return;
                      widget.employeeRef.update({'training': v});
                    },
                  ),
                  TextInfoCheckbox(
                    text: 'Quality',
                    value: appQuality,
                    onChanged: (v) {
                      if (v == null) return;
                      widget.employeeRef.update({'quality': v});
                    },
                  ),
                  TextInfoCheckbox(
                    text: 'Safety',
                    value: appSafety,
                    onChanged: (v) {
                      if (v == null) return;
                      widget.employeeRef.update({'safety': v});
                    },
                  ),
                  TextInfoCheckbox(
                    text: 'Inventory',
                    value: appInventory,
                    onChanged: (v) {
                      if (v == null) return;
                      widget.employeeRef.update({'inventory': v});
                    },
                  ),
                  TextInfoCheckbox(
                    text: 'Purchasing',
                    value: appPurchasing,
                    onChanged: (v) {
                      if (v == null) return;
                      widget.employeeRef.update({'purchasing': v});
                    },
                  ),
                  TextInfoCheckbox(
                    text: 'Occupancy',
                    value: appOccupancy,
                    onChanged: (v) {
                      if (v == null) return;
                      widget.employeeRef.update({'occupancy': v});
                    },
                  ),
                  TextInfoCheckbox(
                    text: 'Engagement',
                    value: appEngagement,
                    onChanged: (v) {
                      if (v == null) return;
                      widget.employeeRef.update({'engagement': v});
                    },
                  ),
                  TextInfoCheckbox(
                    text: 'Sales',
                    value: appSales,
                    onChanged: (v) {
                      if (v == null) return;
                      widget.employeeRef.update({'sales': v});
                    },
                  ),
                  TextInfoCheckbox(
                    text: 'Legal',
                    value: appLegal,
                    onChanged: (v) {
                      if (v == null) return;
                      widget.employeeRef.update({'legal': v});
                    },
                  ),
                  TextInfoCheckbox(
                    text: 'Accounting',
                    value: appFinance,
                    onChanged: (v) {
                      if (v == null) return;
                      widget.employeeRef.update({'finance': v});
                    },
                  ),
                  TextInfoCheckbox(
                    text: 'Administration',
                    value: appAdministration,
                    onChanged: (v) {
                      if (v == null) return;
                      widget.employeeRef.update({'administration': v});
                    },
                  ),
                ],
              ),
              actionText: '',
            ),
          ],
        );
      },
    );
  }
}
