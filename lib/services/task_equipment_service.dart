// lib/services/task_equipment_service.dart
//
// Admin port: no-op. The kleenops version auto-connects/disconnects
// BLE-tracked equipment (via `ble_sensor_service.dart`) when an operator
// starts or finishes a task. The admin app does not ship the BLE sensor
// stack, so this preserves the public API as a silent no-op — task
// start/exit never blocks on equipment, which was already best-effort.

import 'package:cloud_firestore/cloud_firestore.dart';

/// Singleton service that, in kleenops, bridges task lifecycle with BLE
/// equipment connections. In admin it does nothing.
class TaskEquipmentService {
  TaskEquipmentService._();
  static final instance = TaskEquipmentService._();

  /// No-op in admin. See file header.
  Future<void> onTaskStart({
    required String companyId,
    required DocumentReference<Map<String, dynamic>> timelineRef,
  }) async {}

  /// No-op in admin. See file header.
  Future<void> onTaskExit({
    required String companyId,
    required DocumentReference<Map<String, dynamic>> timelineRef,
  }) async {}

  /// Always false in admin — no equipment is ever auto-connected.
  bool hasActiveEquipment(String timelinePath) => false;
}
