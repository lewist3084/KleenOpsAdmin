// lib/features/device_registry/screens/device_registry_home.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../theme/palette.dart';

/// Admin screen for managing the platform-level device registry.
///
/// Lists all provisioned / claimed / active hardware across companies.
/// Platform admins can provision new devices and view lifecycle state.
class DeviceRegistryHome extends StatefulWidget {
  const DeviceRegistryHome({super.key});

  @override
  State<DeviceRegistryHome> createState() => _DeviceRegistryHomeState();
}

class _DeviceRegistryHomeState extends State<DeviceRegistryHome> {
  String _typeFilter = 'all';
  String _statusFilter = 'all';

  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> q =
        FirebaseFirestore.instance.collection('deviceRegistry');
    if (_typeFilter != 'all') {
      q = q.where('deviceType', isEqualTo: _typeFilter);
    }
    if (_statusFilter != 'all') {
      q = q.where('status', isEqualTo: _statusFilter);
    }
    return q.orderBy('createdAt', descending: true).limit(100);
  }

  @override
  Widget build(BuildContext context) {
    const palette = adminPalette;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Registry'),
        backgroundColor: palette.primary1,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutePaths.dashboard),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Provision New Device',
            onPressed: () => _showProvisionDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Type filter
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _typeFilter,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Types')),
                      DropdownMenuItem(
                          value: 'loraGateway', child: Text('LoRa Gateway')),
                      DropdownMenuItem(
                          value: 'loraTag', child: Text('LoRa Tag')),
                      DropdownMenuItem(
                          value: 'cellularTracker',
                          child: Text('Cellular Tracker')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _typeFilter = v);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Status filter
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _statusFilter,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'all', child: Text('All Statuses')),
                      DropdownMenuItem(
                          value: 'provisioned', child: Text('Provisioned')),
                      DropdownMenuItem(
                          value: 'claimed', child: Text('Claimed')),
                      DropdownMenuItem(
                          value: 'active', child: Text('Active')),
                      DropdownMenuItem(
                          value: 'decommissioned',
                          child: Text('Decommissioned')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _statusFilter = v);
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Device list
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _buildQuery().snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.devices,
                            size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text('No devices found'),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (ctx, i) =>
                      _buildDeviceCard(docs[i].id, docs[i].data()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(String id, Map<String, dynamic> data) {
    final type = (data['deviceType'] ?? '').toString();
    final serial = (data['serialNumber'] ?? '').toString();
    final model = data['hardwareModel']?.toString();
    final status = (data['status'] ?? '').toString();
    final companyId = data['companyId']?.toString();
    final lastSeen = data['lastSeenAt'] as Timestamp?;

    IconData typeIcon;
    switch (type) {
      case 'loraGateway':
        typeIcon = Icons.cell_tower;
        break;
      case 'loraTag':
        typeIcon = Icons.sell;
        break;
      case 'cellularTracker':
        typeIcon = Icons.gps_fixed;
        break;
      default:
        typeIcon = Icons.device_unknown;
    }

    Color statusColor;
    switch (status) {
      case 'provisioned':
        statusColor = Colors.blue;
        break;
      case 'claimed':
        statusColor = Colors.orange;
        break;
      case 'active':
        statusColor = Colors.green;
        break;
      case 'decommissioned':
        statusColor = Colors.grey;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      child: ListTile(
        leading: Icon(typeIcon, color: statusColor),
        title: Text(serial),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: statusColor),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _typeLabel(type),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            if (model != null)
              Text('Model: $model', style: const TextStyle(fontSize: 11)),
            if (companyId != null)
              Text('Company: $companyId', style: const TextStyle(fontSize: 11)),
            if (lastSeen != null)
              Text('Last seen: ${_timeAgo(lastSeen)}',
                  style: const TextStyle(fontSize: 11)),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'loraGateway':
        return 'LoRa Gateway';
      case 'loraTag':
        return 'LoRa Tag';
      case 'cellularTracker':
        return 'Cellular Tracker';
      default:
        return type;
    }
  }

  String _timeAgo(Timestamp ts) {
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Future<void> _showProvisionDialog(BuildContext context) async {
    String deviceType = 'loraTag';
    final serialController = TextEditingController();
    final modelController = TextEditingController();
    final simController = TextEditingController();
    bool provisioning = false;
    String? error;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Provision New Device'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: deviceType,
                    decoration: const InputDecoration(
                      labelText: 'Device Type',
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'loraGateway', child: Text('LoRa Gateway')),
                      DropdownMenuItem(
                          value: 'loraTag', child: Text('LoRa Tag')),
                      DropdownMenuItem(
                          value: 'cellularTracker',
                          child: Text('Cellular Tracker')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => deviceType = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: serialController,
                    decoration: const InputDecoration(
                      labelText: 'Serial Number',
                      hintText: 'e.g. LORA-TAG-A3F2',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: modelController,
                    decoration: const InputDecoration(
                      labelText: 'Hardware Model (optional)',
                      hintText: 'e.g. KO-LORA-GW-01',
                    ),
                  ),
                  if (deviceType == 'cellularTracker') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: simController,
                      decoration: const InputDecoration(
                        labelText: 'SIM ICCID (optional)',
                      ),
                    ),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(error!,
                        style: TextStyle(
                            color: Colors.red.shade700, fontSize: 13)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: provisioning
                    ? null
                    : () {
                        serialController.dispose();
                        modelController.dispose();
                        simController.dispose();
                        Navigator.pop(ctx);
                      },
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: provisioning
                    ? null
                    : () async {
                        final serial = serialController.text.trim();
                        if (serial.isEmpty) {
                          setDialogState(
                              () => error = 'Serial number is required');
                          return;
                        }

                        setDialogState(() {
                          provisioning = true;
                          error = null;
                        });

                        try {
                          final callable =
                              FirebaseFunctions.instanceFor(
                                      region: 'us-central1')
                                  .httpsCallable('deviceProvision');
                          final result =
                              await callable.call<Map<String, dynamic>>({
                            'deviceType': deviceType,
                            'serialNumber': serial,
                            'hardwareModel':
                                modelController.text.trim().isNotEmpty
                                    ? modelController.text.trim()
                                    : null,
                            'simIccid': simController.text.trim().isNotEmpty
                                ? simController.text.trim()
                                : null,
                          });

                          final deviceToken =
                              result.data['deviceToken'] as String?;
                          final qrCodeDataUrl =
                              result.data['qrCodeDataUrl'] as String?;

                          serialController.dispose();
                          modelController.dispose();
                          simController.dispose();

                          if (ctx.mounted) Navigator.pop(ctx);

                          // Show the token + QR code
                          if (mounted && deviceToken != null) {
                            _showTokenDialog(deviceToken, qrCodeDataUrl);
                          }
                        } on FirebaseFunctionsException catch (e) {
                          setDialogState(() {
                            error = e.message ?? 'Provisioning failed';
                            provisioning = false;
                          });
                        } catch (e) {
                          setDialogState(() {
                            error = e.toString();
                            provisioning = false;
                          });
                        }
                      },
                child: provisioning
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Provision'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showTokenDialog(String token, String? qrDataUrl) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Device Provisioned'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Save this token securely. It will be baked into the device '
                'firmware and cannot be retrieved later.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        token,
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: token));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Token copied to clipboard'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              if (qrDataUrl != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'QR Code (print and affix to device):',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Image.network(qrDataUrl, width: 200, height: 200),
              ],
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
