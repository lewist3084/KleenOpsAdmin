// lib/features/objects/screens/objectsInventoryForm.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/cancel_save_adapter.dart';
import 'package:kleenops_admin/widgets/fields/multi_scan_field.dart';
import 'package:kleenops_admin/widgets/equipment/equipment_setup_wizard.dart';
import 'package:kleenops_admin/widgets/fields/multiSelect/property_multi_select.dart';
import 'package:kleenops_admin/widgets/fields/multiSelect/building_multi_select.dart';
import 'package:kleenops_admin/widgets/fields/multiSelect/floor_multi_select.dart';
import 'package:kleenops_admin/widgets/fields/multiSelect/location_multi_select.dart';
import 'package:kleenops_admin/common/utils/location_display_utils.dart';
import 'package:kleenops_admin/l10n/app_localizations.dart';

class ObjectsInventoryForm extends StatefulWidget {
  final DocumentReference companyId; // /company/{cid}
  final String objectId; // companyObject doc id

  const ObjectsInventoryForm({
    super.key,
    required this.companyId,
    required this.objectId,
  });

  @override
  State<ObjectsInventoryForm> createState() => ObjectsInventoryFormState();
}

class ObjectsInventoryFormState extends State<ObjectsInventoryForm> {
  final _formKey = GlobalKey<FormState>();

  // numeric inputs
  int? _quantity; // non-covering, non-tracked
  double? _percentLocation; // 0-1 for coverings

  // flags
  bool _hasCoverings = false;
  bool _trackObject = false;
  bool _saving = false;

  // tracked-object fields
  String? _serialNumber;
  String? _assetTag;
  String? _objectName;

  // realtime monitoring fields
  bool _realtimeTracking = false;
  EquipmentSetupResult? _setupResult;

  // cascade selections
  List<DocumentReference> _properties = [];
  List<DocumentReference> _buildings = [];
  List<DocumentReference> _floors = [];
  List<DocumentReference<Map<String, dynamic>>> _locations = [];

  @override
  void initState() {
    super.initState();
    _loadObjectFlags();
  }

  Future<void> _loadObjectFlags() async {
    final snap = await widget.companyId
        .collection('companyObject')
        .doc(widget.objectId)
        .get();

    if (snap.exists) {
      final d = snap.data() as Map<String, dynamic>;
      final resolvedName = _resolveObjectName(d);
      setState(() {
        _hasCoverings = (d['wallCovering'] ?? false) ||
            (d['floorCovering'] ?? false) ||
            (d['ceilingCovering'] ?? false);
        _trackObject = d['trackObject'] ?? false;
        _objectName = resolvedName.isNotEmpty ? resolvedName : null;
      });
    }
  }

  String _resolveObjectName(Map<String, dynamic> data) {
    final localName = (data['localName'] ?? '').toString().trim();
    if (localName.isNotEmpty) return localName;
    return (data['name'] ?? '').toString().trim();
  }

  /*──────────────────────────────  SAVE  ───────────────────────────*/
  Future<void> _saveForm() async {
    final loc = AppLocalizations.of(context)!;
    final form = _formKey.currentState;
    if (form == null) return;
    if (!form.validate()) return;
    form.save();

    // basic required-field checks
    if (_locations.isEmpty ||
        (_trackObject &&
            (_serialNumber == null || _assetTag == null)) ||
        (!_trackObject && _hasCoverings && _percentLocation == null) ||
        (!_trackObject && !_hasCoverings && _quantity == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.objectsInventoryFillAllRequiredFields),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final objRef = widget.companyId
          .collection('companyObject')
          .doc(widget.objectId);
      String? objectName = _objectName;
      if (objectName == null || objectName.trim().isEmpty) {
        final objSnap = await objRef.get();
        if (objSnap.exists) {
          final data = objSnap.data();
          if (data != null) {
            final resolvedName = _resolveObjectName(data);
            if (resolvedName.isNotEmpty) {
              objectName = resolvedName;
            }
          }
        }
      }

      final batch = FirebaseFirestore.instance.batch();
      final locationFieldsByPath = <String, Map<String, dynamic>>{};
      final functionCache = <String, Map<String, dynamic>>{};
      final locationSnaps = await Future.wait(
        _locations.map((locRef) => locRef.get()),
      );
      for (var i = 0; i < _locations.length; i++) {
        final locRef = _locations[i];
        final locSnap = locationSnaps[i];
        final locData =
            locSnap.exists ? (locSnap.data() ?? <String, dynamic>{}) : {};
        final rawName = (locData['name'] ?? locRef.id).toString().trim();
        final locationName = rawName.isNotEmpty ? rawName : locRef.id;
        dynamic functionNameField = locData['functionName'];
        final rawFunctionRef = locData['functionId'];
        DocumentReference<Map<String, dynamic>>? functionRef;
        if (rawFunctionRef is DocumentReference<Map<String, dynamic>>) {
          functionRef = rawFunctionRef;
        } else if (rawFunctionRef is DocumentReference) {
          functionRef = rawFunctionRef.withConverter<Map<String, dynamic>>(
            fromFirestore: (s, _) => s.data() ?? <String, dynamic>{},
            toFirestore: (m, _) => m,
          );
        }
        if (functionNameField == null && functionRef != null) {
          final cached = functionCache[functionRef.path];
          if (cached != null) {
            functionNameField = cached['name'];
          } else {
            final functionSnap = await functionRef.get();
            if (functionSnap.exists) {
              final functionData =
                  functionSnap.data() ?? <String, dynamic>{};
              functionCache[functionRef.path] = functionData;
              functionNameField = functionData['name'];
            }
          }
        }

        final locationFields = <String, dynamic>{
          'locationName': locationName,
        };
        if (functionNameField != null) {
          locationFields['locationFunctionName'] = functionNameField;
        }
        final concatenatedPayload =
            LocationDisplayUtils.buildConcatenatedNamePayload(
          locationName: locationName,
          functionNameField: functionNameField,
        );
        if (concatenatedPayload != null) {
          locationFields['locationConcatenatedName'] = concatenatedPayload;
        } else {
          final fallbackConcat =
              locData['concatenatedName'] ?? locData['ConcatenatedName'];
          if (fallbackConcat is Map) {
            locationFields['locationConcatenatedName'] =
                Map<String, dynamic>.from(fallbackConcat);
          } else if (fallbackConcat is String) {
            final trimmed = fallbackConcat.trim();
            if (trimmed.isNotEmpty) {
              locationFields['locationConcatenatedName'] = trimmed;
            }
          }
          if (!locationFields.containsKey('locationConcatenatedName') &&
              locationName.isNotEmpty) {
            locationFields['locationConcatenatedName'] = locationName;
          }
        }
        locationFieldsByPath[locRef.path] = locationFields;
      }

      for (final locRef in _locations) {
        final doc = widget.companyId
            .collection('objectInventory')
            .doc(); // auto-id
        final locationFields =
            locationFieldsByPath[locRef.path] ?? const <String, dynamic>{};

        final payload = <String, dynamic>{
          'companyObjectId': objRef,
          'locationId': locRef,
          'active': true,
          'lastUpdated': FieldValue.serverTimestamp(),
          if (objectName != null && objectName.trim().isNotEmpty)
            'name': objectName.trim(),
          if (locationFields.isNotEmpty) ...locationFields,
          if (_trackObject) ...{
            'quantity': 1,
            'serialNumber': _serialNumber,
            'assetTag': _assetTag,
            'realtimeTracking': _realtimeTracking,
            if (_realtimeTracking && _setupResult != null) ...{
              'sensorConfig': _setupResult!.toSensorConfig(),
              'runtime': <String, dynamic>{
                'totalHours': 0,
                'hoursThisCycle': 0,
                'isRunning': false,
              },
              if (_setupResult!.maintenanceIntervalHours != null)
                'maintenance': <String, dynamic>{
                  'intervalHours': _setupResult!.maintenanceIntervalHours,
                },
            },
          } else if (_hasCoverings) ...{
            'percentLocation': _percentLocation,
          } else ...{
            'quantity': _quantity,
          },
        };
        batch.set(doc, payload);
      }

      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.objectsInventoryAdded)),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.objectsInventoryFailedToSave(e.toString())),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  /*──────────────────────────  SETUP SUMMARY  ─────────────────────*/
  Widget _buildSetupSummary() {
    final r = _setupResult!;
    final method = switch (r.connectionMethod) {
      ConnectionMethod.wifi => 'WiFi Device',
      ConnectionMethod.ble => 'Bluetooth Sensor',
      ConnectionMethod.lora => 'LoRa Sensor',
      ConnectionMethod.cellular => 'Cellular Device',
      ConnectionMethod.manual => 'Manual / Advanced',
    };
    final types = r.dataTypes.map((t) => switch (t) {
          'current' => 'On/Off',
          'temperature' => 'Temperature',
          'vibration' => 'Vibration',
          'pressure' => 'Pressure',
          _ => t,
        }).join(', ');
    final maintenance = r.maintenanceIntervalHours != null
        ? 'Every ${r.maintenanceIntervalHours} hrs'
        : 'None';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _summaryRow('Connection', method),
          _summaryRow('Monitoring', types),
          _summaryRow('Maintenance', maintenance),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 12)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  /*──────────────────────────────  UI  ─────────────────────────────*/
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    // Show a simple loading screen while saving
    if (_saving) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: StandardAppBar(
              title: loc.objectsInventoryAddTitle,
            ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // --- quantity / percent / tracking fields ---
                if (_trackObject) ...[
                  MultiScanField(
                    labelText: loc.objectsFormSerialNumberLabel,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? loc.objectsInventoryRequiredField : null,
                    onSaved: (v) => _serialNumber = v,
                  ),
                  const SizedBox(height: 16),
                  MultiScanField(
                    labelText: loc.objectsFormAssetTagLabel,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? loc.objectsInventoryRequiredField : null,
                    onSaved: (v) => _assetTag = v,
                  ),
                ] else if (_hasCoverings) ...[
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: loc.objectsInventoryPercentCoverageLabel,
                      suffixText: '%',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final n = double.tryParse(v ?? '');
                      if (n == null) return loc.objectsInventoryEnterNumber;
                      if (n < 0 || n > 100) return loc.objectsInventoryRangeZeroToHundred;
                      return null;
                    },
                    onSaved: (v) =>
                        _percentLocation = double.parse(v!) / 100,
                  ),
                ] else ...[
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: loc.objectsInventoryQuantityPerLocationLabel,
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        int.tryParse(v ?? '') == null ? loc.objectsInventoryWholeNumber : null,
                    onSaved: (v) => _quantity = int.tryParse(v ?? ''),
                  ),
                ],
                // --- realtime monitoring (only for tracked objects) ---
                if (_trackObject) ...[
                  const SizedBox(height: 24),
                  SwitchListTile(
                    title: Text(loc.objectsInventoryRealtimeTrackingLabel),
                    subtitle: Text(
                        loc.objectsInventoryRealtimeTrackingDescription),
                    value: _realtimeTracking,
                    onChanged: (v) => setState(() => _realtimeTracking = v),
                  ),
                  if (_realtimeTracking) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      icon: Icon(_setupResult != null
                          ? Icons.check_circle
                          : Icons.sensors),
                      label: Text(_setupResult != null
                          ? 'Sensor Setup Complete — Tap to Edit'
                          : 'Set Up Sensor Connection'),
                      onPressed: () async {
                        final result = await showEquipmentSetupWizard(
                          context,
                          existingConfig: _setupResult?.toSensorConfig(),
                        );
                        if (result != null) {
                          setState(() => _setupResult = result);
                        }
                      },
                    ),
                    if (_setupResult != null) ...[
                      const SizedBox(height: 8),
                      _buildSetupSummary(),
                    ],
                  ],
                ],
                const SizedBox(height: 24),
                // --- property + building + floor + location cascade ---
                PropertyMultiSelectDropdown(
                  companyId: widget.companyId
                      as DocumentReference<Map<String, dynamic>>,
                  selectedProperties: _properties,
                  onChanged: (props) {
                    setState(() {
                      _properties = props;
                      _buildings.clear();
                      _floors.clear();
                      _locations.clear();
                    });
                  },
                ),
                if (_properties.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  BuildingMultiSelectDropdown(
                    selectedProperties: _properties,
                    selectedBuildings: _buildings,
                    onChanged: (blds) {
                      setState(() {
                        _buildings = blds;
                        _floors.clear();
                        _locations.clear();
                      });
                    },
                  ),
                ],
                if (_buildings.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  FloorMultiSelectDropdown(
                    selectedBuildings: _buildings,
                    selectedFloors: _floors,
                    onChanged: (flrs) {
                      setState(() {
                        _floors = flrs;
                        _locations.clear();
                      });
                    },
                  ),
                ],
                if (_floors.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  LocationMultiSelectDropdown(
                    companyRef: widget.companyId
                        as DocumentReference<Map<String, dynamic>>,
                    selectedFloors:
                        _floors.cast<DocumentReference<Map<String, dynamic>>>(),
                    selectedLocations: _locations,
                    onChanged: (locs) => setState(() => _locations = locs),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 8),
              child: CancelSaveBar(
                onCancel: () => context.pop(),
                onSave: _saveForm,
              ),
            ),
    );
  }
}
