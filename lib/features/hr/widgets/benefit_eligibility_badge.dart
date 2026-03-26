// lib/features/hr/widgets/benefit_eligibility_badge.dart

import 'package:flutter/material.dart';

/// A small badge that indicates whether an employee is eligible for benefits
/// based on their employment type and hours worked.
class BenefitEligibilityBadge extends StatelessWidget {
  final String employmentType;
  final double? weeklyHours;
  final double benefitsThreshold;

  const BenefitEligibilityBadge({
    super.key,
    required this.employmentType,
    this.weeklyHours,
    this.benefitsThreshold = 30,
  });

  @override
  Widget build(BuildContext context) {
    final eligible = _isEligible();
    final label = eligible ? 'Benefits Eligible' : 'Not Eligible';
    final color = eligible ? Colors.green : Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            eligible
                ? Icons.health_and_safety_outlined
                : Icons.block_outlined,
            size: 12,
            color: color[700],
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color[800],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  bool _isEligible() {
    // Full-time employees are always eligible
    if (employmentType == 'full-time') return true;

    // Contractors are typically not eligible
    if (employmentType == 'contractor') return false;

    // Part-time: check hours threshold
    if (weeklyHours != null) {
      return weeklyHours! >= benefitsThreshold;
    }

    // Default: part-time without hours info = not eligible
    return false;
  }
}
