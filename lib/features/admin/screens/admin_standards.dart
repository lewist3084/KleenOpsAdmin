import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/labels/header_info_icon_value.dart';
import 'package:shared_widgets/labels/text_value_inline.dart';
import 'package:shared_widgets/labels/text_info_checkbox.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';

const _mandatoryLunchKeys = <String>[
  'mandatoryLunch',
  'MandatoryLunch',
  'mandatoryLunchCamelTex',
  'MandatoryLunchCamelTex',
];

const _mandatoryLunchClockoutKeys = <String>[
  'mandatoryLunchClockout',
  'MandatoryLunchClockout',
  'mandatoryLunchClockOut',
  'MandatoryLunchClockOut',
  'mandatoryLunchClockoutCamelTex',
  'MandatoryLunchClockoutCamelTex',
];

bool _resolveBool(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    if (!data.containsKey(key)) continue;
    final value = data[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalised = value.trim().toLowerCase();
      if (normalised == 'true') return true;
      if (normalised == 'false') return false;
      final numeric = num.tryParse(normalised);
      if (numeric != null) return numeric != 0;
    }
  }
  return false;
}

/// Displays company standards such as measurement system and employee metrics.
class AdminStandardsContent extends ConsumerWidget {
  const AdminStandardsContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyAsync = ref.watch(companyIdProvider);

    return companyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (companyRef) {
        if (companyRef == null) {
          return const Center(child: Text('No company found.'));
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: companyRef.snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.data!.exists) {
              return const Center(child: Text('Company not found.'));
            }

            final data = snapshot.data!.data() ?? {};
            final measurementSystem = data['measurementSystem'] ?? 'Standard';
            final earlyArrivalGrace =
                data['earlyArrivalGracePeriod'] ?? data['earlyGracePeriod'];
            final lateArrivalGrace =
                data['lateArrivalGracePeriod'] ?? data['lateGracePeriod'];
            final earlyDepartureGrace = data['earlyDepartureGracePeriod'] ??
                data['departureGracePeriod'] ??
                data['earlyGracePeriod'];
            final lateDepartureGrace = data['lateDepartureGracePeriod'] ??
                data['departureGracePeriod'] ??
                data['lateGracePeriod'];
            final dependabilityMinimum = data['dependabilityMinimum'];
            final contributionMinimum = data['contributionMinimum'];
            final evaluationInterval = data['evaluationInterval'] ??
                data['EvaluationInterval'] ??
                data['evaluationIntervalCamelText'] ??
                data['EvaluationIntervalCamelText'] ??
                data['evaluationIntervalCamelTex'] ??
                data['EvaluationIntervalCamelTex'] ??
                data['evaluationIntervalText'] ??
                data['EvaluationIntervalText'];
            final mandatoryLunchAt = data['mandatoryLunchAt'] ??
                data['MandatoryLunchAt'] ??
                data['mandatoryLunchAtCamelTex'] ??
                data['MandatoryLunchAtCamelTex'];
            final lunchBreak = data['lunchBreak'] ??
                data['LunchBreak'] ??
                data['lunchBreakCamelTex'] ??
                data['LunchBreakCamelTex'];
            final mandatoryLunch = _resolveBool(data, _mandatoryLunchKeys);
            final mandatoryLunchClockout =
                _resolveBool(data, _mandatoryLunchClockoutKeys);

            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ContainerActionWidget(
                    title: 'Measurements',
                    content: HeaderInfoIconValue(
                      header: 'Measurement System',
                      value: measurementSystem,
                      icon: Icons.straighten,
                      boldHeader: false,
                    ),
                    actionText: '',
                  ),
                  ContainerActionWidget(
                    title: 'Employees',
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextValueInline(
                          header: 'Early Arrival Grace',
                          value: earlyArrivalGrace,
                          icon: Icons.login,
                          boldHeader: false,
                        ),
                        const SizedBox(height: 8),
                        TextValueInline(
                          header: 'Late Arrival Grace',
                          value: lateArrivalGrace,
                          icon: Icons.timer,
                          boldHeader: false,
                        ),
                        const SizedBox(height: 8),
                        TextValueInline(
                          header: 'Early Departure Grace',
                          value: earlyDepartureGrace,
                          icon: Icons.logout,
                          boldHeader: false,
                        ),
                        const SizedBox(height: 8),
                        TextValueInline(
                          header: 'Late Departure Grace',
                          value: lateDepartureGrace,
                          icon: Icons.timer_off,
                          boldHeader: false,
                        ),
                        const SizedBox(height: 8),
                        TextValueInline(
                          header: 'Dependability Minimum',
                          value: dependabilityMinimum,
                          icon: Icons.star_border,
                          boldHeader: false,
                        ),
                        const SizedBox(height: 8),
                        TextValueInline(
                          header: 'Contribution Minimum',
                          value: contributionMinimum,
                          icon: Icons.note_add_outlined,
                          boldHeader: false,
                        ),
                        const SizedBox(height: 8),
                        TextValueInline(
                          header: 'Lunch Required After',
                          value: mandatoryLunchAt,
                          icon: Icons.schedule,
                          boldHeader: false,
                        ),
                        const SizedBox(height: 8),
                        TextValueInline(
                          header: 'Lunch Break',
                          value: lunchBreak,
                          icon: Icons.fastfood,
                          boldHeader: false,
                        ),
                        const SizedBox(height: 8),
                        TextInfoCheckbox(
                          text: 'Mandatory Lunch',
                          leadingIcon: Icons.restaurant_menu,
                          trailingActions: [
                            TextInfoAction(
                              icon: mandatoryLunch
                                  ? Icons.check_box
                                  : Icons.check_box_outline_blank,
                              active: mandatoryLunch,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextInfoCheckbox(
                          text: 'Mandatory Lunch Clockout',
                          leadingIcon: Icons.punch_clock,
                          trailingActions: [
                            TextInfoAction(
                              icon: mandatoryLunchClockout
                                  ? Icons.check_box
                                  : Icons.check_box_outline_blank,
                              active: mandatoryLunchClockout,
                            ),
                          ],
                        ),
                      ],
                    ),
                    actionText: '',
                  ),
                  ContainerActionWidget(
                    title: 'Evaluation',
                    content: TextValueInline(
                      header: 'Evaluation Interval',
                      value: evaluationInterval,
                      icon: Icons.timeline,
                      boldHeader: false,
                    ),
                    actionText: '',
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}



