// lib/widgets/equipment/equipment_setup_wizard.dart
// Stub — admin app does not run the on-device equipment setup wizard.

import 'package:flutter/material.dart';

/// The connection method the user selects.
enum ConnectionMethod { wifi, ble, manual, lora, cellular }

/// Result returned when the wizard completes.
class EquipmentSetupResult {
  const EquipmentSetupResult({
    required this.connectionMethod,
    required this.dataTypes,
    this.mqttTopic,
    this.sensorIds,
    this.gatewayId,
    this.bleDeviceId,
    this.loraTagId,
    this.cellularTrackerId,
    this.reportingIntervalSec,
    this.maintenanceIntervalHours,
  });

  final ConnectionMethod connectionMethod;
  final List<String> dataTypes;
  final String? mqttTopic;
  final List<String>? sensorIds;
  final String? gatewayId;
  final String? bleDeviceId;
  final String? loraTagId;
  final String? cellularTrackerId;
  final int? reportingIntervalSec;
  final int? maintenanceIntervalHours;

  Map<String, dynamic> toSensorConfig() {
    return <String, dynamic>{
      'connectionMethod': connectionMethod.name,
      if (mqttTopic != null && mqttTopic!.isNotEmpty) 'mqttTopic': mqttTopic,
      if (sensorIds != null && sensorIds!.isNotEmpty) 'sensorIds': sensorIds,
      if (gatewayId != null && gatewayId!.isNotEmpty) 'gatewayId': gatewayId,
      if (bleDeviceId != null && bleDeviceId!.isNotEmpty)
        'bleDeviceId': bleDeviceId,
      if (loraTagId != null && loraTagId!.isNotEmpty) 'loraTagId': loraTagId,
      if (cellularTrackerId != null && cellularTrackerId!.isNotEmpty)
        'cellularTrackerId': cellularTrackerId,
      if (reportingIntervalSec != null)
        'reportingIntervalSec': reportingIntervalSec,
      if (maintenanceIntervalHours != null)
        'maintenanceIntervalHours': maintenanceIntervalHours,
    };
  }
}

/// No-op stub — returns null (wizard cancelled).
Future<EquipmentSetupResult?> showEquipmentSetupWizard(
  BuildContext context, {
  Map<String, dynamic>? existingConfig,
}) async {
  return null;
}
