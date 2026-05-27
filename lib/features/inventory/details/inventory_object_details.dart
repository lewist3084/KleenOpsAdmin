// lib/features/inventory/details/inventory_object_details.dart
//
// DEGRADED port: drops the `EquipmentConnectionStatus` widget (lives in
// kleenops/widgets/equipment/) and inlines a minimal text-only "last
// seen" indicator instead. Everything else (identification, monitoring,
// location, webhook setup, geofence) ports unchanged.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:kleenops_admin/app/shared_widgets/drawers/appbar_logout_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';
import 'package:kleenops_admin/widgets/layout/bookended_canvas.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/containers/container_header.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:shared_widgets/labels/header_info_icon_value.dart';
import 'package:shared_widgets/tabs/standard_tab.dart';
import 'package:shared_widgets/theme/app_palette.dart';

class InventoryObjectDetailsScreen extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> objectRef;
  final DocumentReference<Map<String, dynamic>>? inventoryRef;

  const InventoryObjectDetailsScreen({
    super.key,
    required this.objectRef,
    this.inventoryRef,
  });

  @override
  State<InventoryObjectDetailsScreen> createState() =>
      _InventoryObjectDetailsScreenState();
}

class _InventoryObjectDetailsScreenState
    extends State<InventoryObjectDetailsScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  bool _realtimeTracking = false;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _objectStream;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _inventoryStream;

  @override
  void initState() {
    super.initState();
    _initTabController(hasMonitoring: false);
  }

  void _initTabController({required bool hasMonitoring}) {
    _tabController?.removeListener(_handleTabSelection);
    _tabController?.dispose();
    final length = hasMonitoring ? 4 : 3;
    _tabController = TabController(length: length, vsync: this);
    _tabController!.addListener(_handleTabSelection);
  }

  @override
  void dispose() {
    _tabController?.removeListener(_handleTabSelection);
    _tabController?.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    if (!(_tabController?.indexIsChanging ?? true)) {
      setState(() {});
    }
  }

  List<ContentMenuItem> _buildActionItems() {
    return const [
      ContentMenuItem(
        icon: Icons.print,
        label: 'Print Asset Labels',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    Widget buildBottomBar() {
      final menuSections = MenuDrawerSections(
        actions: _buildActionItems(),
      );
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: 'Inventory Object Details',
            menuSections: menuSections,
          ),
          const HomeNavBarAdapter(highlightSelected: false),
        ],
      );
    }

    return Scaffold(
      drawer: const UserDrawer(),
      bottomNavigationBar: buildBottomBar(),
      body: BookendedCanvas(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _objectStream ??= widget.objectRef.snapshots(),
      builder: (context, objSnapshot) {
        if (objSnapshot.hasError) {
          return _buildCenteredMessage(
            'Failed to load object: ${objSnapshot.error}',
          );
        }
        if (!objSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!objSnapshot.data!.exists) {
          return _buildCenteredMessage('Object not found.');
        }

        final objData = objSnapshot.data!.data() ?? <String, dynamic>{};

        if (widget.inventoryRef != null) {
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _inventoryStream ??= widget.inventoryRef!.snapshots(),
            builder: (context, invSnapshot) {
              if (!invSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final invData = invSnapshot.data!.exists
                  ? (invSnapshot.data!.data() ?? <String, dynamic>{})
                  : <String, dynamic>{};

              final hasMonitoring = invData['realtimeTracking'] == true;
              if (hasMonitoring != _realtimeTracking) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  setState(() {
                    _realtimeTracking = hasMonitoring;
                    _initTabController(hasMonitoring: hasMonitoring);
                  });
                });
              }

              return _buildContent(
                objData: objData,
                invData: invData,
              );
            },
          );
        }

        return _buildContent(
          objData: objData,
          invData: const <String, dynamic>{},
        );
      },
    );
  }

  Widget _buildContent({
    required Map<String, dynamic> objData,
    required Map<String, dynamic> invData,
  }) {
    final String localName =
        (objData['localName'] ?? objData['name'] ?? '').toString().trim();
    final String description =
        (objData['description'] ?? objData['Description'] ?? '')
            .toString()
            .trim();
    final String serialNumber =
        (invData['serialNumber'] ?? objData['objectSerialNumber'] ?? '')
            .toString()
            .trim();
    final String assetTag =
        (invData['assetTag'] ?? objData['objectAssetTag'] ?? '')
            .toString()
            .trim();
    const bottomPadding = 16.0;

    return ListView(
      padding: EdgeInsets.only(
        bottom: bottomPadding + MediaQuery.of(context).padding.bottom,
      ),
      children: [
        ContainerHeader(
          showImage: false,
          titleHeader: 'Local Name',
          title: localName.isNotEmpty ? localName : 'Unnamed Object',
          descriptionHeader: 'Description',
          description: description.isNotEmpty
              ? description
              : 'No description provided.',
          textIcon: Icons.category_outlined,
          descriptionIcon: Icons.info_outlined,
        ),
        _buildTabsSection(
          serialNumber: serialNumber,
          assetTag: assetTag,
          invData: invData,
        ),
      ],
    );
  }

  Widget _buildTabsSection({
    required String serialNumber,
    required String assetTag,
    required Map<String, dynamic> invData,
  }) {
    final theme = Theme.of(context);
    final tabs = <Tab>[
      const Tab(text: 'Details'),
      if (_realtimeTracking) const Tab(text: 'Monitoring'),
      const Tab(text: 'Charts'),
      const Tab(text: 'Records'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StandardTabBar(
          controller: _tabController!,
          isScrollable: false,
          labelStyle: theme.textTheme.titleMedium,
          tabs: tabs,
        ),
        _buildCurrentTabBody(
          serialNumber: serialNumber,
          assetTag: assetTag,
          invData: invData,
        ),
      ],
    );
  }

  Widget _buildCurrentTabBody({
    required String serialNumber,
    required String assetTag,
    required Map<String, dynamic> invData,
  }) {
    final index = _tabController?.index ?? 0;

    if (_realtimeTracking) {
      switch (index) {
        case 0:
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _buildIdentificationSection(
              serialNumber: serialNumber,
              assetTag: assetTag,
            ),
          );
        case 1:
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _buildMonitoringSection(invData: invData),
          );
        case 2:
          return _buildPlaceholder('Charts');
        case 3:
        default:
          return _buildPlaceholder('Records');
      }
    }

    switch (index) {
      case 0:
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: _buildIdentificationSection(
            serialNumber: serialNumber,
            assetTag: assetTag,
          ),
        );
      case 1:
        return _buildPlaceholder('Charts');
      case 2:
      default:
        return _buildPlaceholder('Records');
    }
  }

  Widget _buildIdentificationSection({
    required String serialNumber,
    required String assetTag,
  }) {
    return ContainerActionWidget(
      title: 'Identification',
      actionText: '',
      onAction: null,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HeaderInfoIconValue(
            header: 'Serial Number',
            value: serialNumber.isNotEmpty ? serialNumber : 'N/A',
            icon: Icons.numbers,
          ),
          const SizedBox(height: 12),
          HeaderInfoIconValue(
            header: 'Asset Tag',
            value: assetTag.isNotEmpty ? assetTag : 'N/A',
            icon: Icons.sell,
          ),
        ],
      ),
    );
  }

  // ── Monitoring Tab ─────────────────────────────────────────────────

  Widget _buildMonitoringSection({required Map<String, dynamic> invData}) {
    final runtime = invData['runtime'] as Map<String, dynamic>? ?? const {};
    final sensorConfig =
        invData['sensorConfig'] as Map<String, dynamic>? ?? const {};
    final maintenance =
        invData['maintenance'] as Map<String, dynamic>? ?? const {};

    final bool isRunning = runtime['isRunning'] == true;
    final double totalHours = (runtime['totalHours'] as num?)?.toDouble() ?? 0;
    final double hoursThisCycle =
        (runtime['hoursThisCycle'] as num?)?.toDouble() ?? 0;

    final Timestamp? lastEventAt = invData['lastEventAt'] as Timestamp?;
    final String connectionMethod =
        (sensorConfig['connectionMethod'] ?? '').toString();

    final List<dynamic> sensorIds =
        sensorConfig['sensorIds'] is List ? sensorConfig['sensorIds'] : [];
    final List<dynamic> dataTypes =
        sensorConfig['dataTypes'] is List ? sensorConfig['dataTypes'] : [];

    final double? intervalHours =
        (maintenance['intervalHours'] as num?)?.toDouble();
    final double? nextServiceDue =
        (maintenance['nextServiceDueHours'] as num?)?.toDouble();

    final companyId = widget.objectRef.parent.parent?.id ?? '';
    final inventoryId = widget.inventoryRef?.id ?? '';

    return Column(
      children: [
        ContainerActionWidget(
          title: 'Connection Status',
          actionText: '',
          onAction: null,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildConnectionStatusLine(lastEventAt: lastEventAt),
              const SizedBox(height: 12),
              HeaderInfoIconValue(
                header: 'Running',
                value: isRunning ? 'Yes' : 'No',
                icon: isRunning ? Icons.play_circle_filled : Icons.stop_circle,
              ),
              const SizedBox(height: 12),
              HeaderInfoIconValue(
                header: 'Total Runtime',
                value: '${totalHours.toStringAsFixed(1)} hrs',
                icon: Icons.timer,
              ),
              const SizedBox(height: 12),
              HeaderInfoIconValue(
                header: 'Hours This Cycle',
                value: '${hoursThisCycle.toStringAsFixed(1)} hrs',
                icon: Icons.update,
              ),
            ],
          ),
        ),
        if (invData['lastKnownLocation'] is Map) ...[
          const SizedBox(height: 12),
          _buildLocationSection(
            lastKnownLocation:
                invData['lastKnownLocation'] as Map<String, dynamic>,
            geofenceStatus: invData['geofenceStatus'] as Map<String, dynamic>?,
            connectionMethod: connectionMethod,
          ),
        ],
        if (connectionMethod == 'wifi' &&
            companyId.isNotEmpty &&
            inventoryId.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildWebhookSection(
            companyId: companyId,
            inventoryId: inventoryId,
          ),
        ],
        if (dataTypes.isNotEmpty) ...[
          const SizedBox(height: 12),
          ContainerActionWidget(
            title: 'Monitoring',
            actionText: '',
            onAction: null,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HeaderInfoIconValue(
                  header: 'Data Types',
                  value: dataTypes
                      .map((t) => switch (t) {
                            'current' => 'On/Off (Runtime)',
                            'temperature' => 'Temperature',
                            'vibration' => 'Vibration',
                            'pressure' => 'Pressure',
                            _ => t.toString(),
                          })
                      .join(', '),
                  icon: Icons.data_usage,
                ),
                if (sensorIds.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  HeaderInfoIconValue(
                    header: 'Sensors',
                    value: sensorIds.join(', '),
                    icon: Icons.sensors,
                  ),
                ],
              ],
            ),
          ),
        ],
        if (intervalHours != null || nextServiceDue != null) ...[
          const SizedBox(height: 12),
          ContainerActionWidget(
            title: 'Maintenance Schedule',
            actionText: '',
            onAction: null,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (intervalHours != null)
                  HeaderInfoIconValue(
                    header: 'Service Interval',
                    value: '${intervalHours.toStringAsFixed(0)} hrs',
                    icon: Icons.build,
                  ),
                if (nextServiceDue != null) ...[
                  const SizedBox(height: 12),
                  HeaderInfoIconValue(
                    header: 'Next Service Due',
                    value: '${nextServiceDue.toStringAsFixed(0)} hrs',
                    icon: Icons.event,
                  ),
                  if (totalHours > 0) ...[
                    const SizedBox(height: 12),
                    HeaderInfoIconValue(
                      header: 'Remaining',
                      value:
                          '${(nextServiceDue - totalHours).toStringAsFixed(1)} hrs',
                      icon: Icons.hourglass_bottom,
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Inline substitute for `EquipmentConnectionStatus` from kleenops,
  /// which doesn't ship with admin.
  Widget _buildConnectionStatusLine({Timestamp? lastEventAt}) {
    String label;
    IconData icon;
    Color color;
    if (lastEventAt == null) {
      label = 'No events yet';
      icon = Icons.cloud_off_outlined;
      color = Colors.grey.shade600;
    } else {
      final diff = DateTime.now().difference(lastEventAt.toDate());
      if (diff.inMinutes < 10) {
        label = 'Connected';
        icon = Icons.cloud_done_outlined;
        color = Colors.green.shade700;
      } else if (diff.inHours < 2) {
        label = 'Last seen ${diff.inMinutes} min ago';
        icon = Icons.cloud_queue_outlined;
        color = Colors.orange.shade700;
      } else {
        label = 'Offline (${diff.inHours}h)';
        icon = Icons.cloud_off_outlined;
        color = Colors.red.shade700;
      }
    }
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  // ── Location Section (LoRa / Cellular) ─────────────────────────

  Widget _buildLocationSection({
    required Map<String, dynamic> lastKnownLocation,
    Map<String, dynamic>? geofenceStatus,
    required String connectionMethod,
  }) {
    final double? lat = (lastKnownLocation['lat'] as num?)?.toDouble();
    final double? lng = (lastKnownLocation['lng'] as num?)?.toDouble();
    final String source = (lastKnownLocation['source'] ?? '').toString();
    final Timestamp? updatedAt =
        lastKnownLocation['updatedAt'] as Timestamp?;

    final String? gatewayName =
        lastKnownLocation['gatewayName']?.toString();
    final num? rssi = lastKnownLocation['rssi'] as num?;

    final num? speed = lastKnownLocation['speed'] as num?;
    final num? heading = lastKnownLocation['heading'] as num?;
    final bool? ignition = lastKnownLocation['ignition'] as bool?;

    final List<dynamic> currentZones =
        geofenceStatus?['currentZones'] is List
            ? geofenceStatus!['currentZones']
            : [];
    final Map<String, dynamic>? lastTransition =
        geofenceStatus?['lastTransition'] as Map<String, dynamic>?;

    String updatedLabel = 'Never';
    if (updatedAt != null) {
      final diff = DateTime.now().difference(updatedAt.toDate());
      if (diff.inMinutes < 1) {
        updatedLabel = 'Just now';
      } else if (diff.inMinutes < 60) {
        updatedLabel = '${diff.inMinutes} min ago';
      } else if (diff.inHours < 24) {
        updatedLabel = '${diff.inHours}h ago';
      } else {
        updatedLabel = '${diff.inDays}d ago';
      }
    }

    return ContainerActionWidget(
      title: 'Location',
      actionText: '',
      onAction: null,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: source == 'cellular'
                      ? Colors.green.shade50
                      : Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: source == 'cellular'
                        ? Colors.green.shade300
                        : Colors.indigo.shade300,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      source == 'cellular'
                          ? Icons.gps_fixed
                          : Icons.cell_tower,
                      size: 14,
                      color: source == 'cellular'
                          ? Colors.green.shade700
                          : Colors.indigo.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      source == 'cellular' ? 'GPS' : 'LoRa',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: source == 'cellular'
                            ? Colors.green.shade700
                            : Colors.indigo.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Updated $updatedLabel',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (lat != null && lng != null)
            HeaderInfoIconValue(
              header: 'Coordinates',
              value: '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
              icon: Icons.location_on,
            ),
          if (source == 'lora') ...[
            if (gatewayName != null) ...[
              const SizedBox(height: 12),
              HeaderInfoIconValue(
                header: 'Gateway',
                value: gatewayName,
                icon: Icons.cell_tower,
              ),
            ],
            if (rssi != null) ...[
              const SizedBox(height: 12),
              HeaderInfoIconValue(
                header: 'Signal (RSSI)',
                value: '$rssi dBm',
                icon: rssi > -70
                    ? Icons.signal_cellular_alt
                    : rssi > -90
                        ? Icons.signal_cellular_alt_2_bar
                        : Icons.signal_cellular_alt_1_bar,
              ),
            ],
          ],
          if (source == 'cellular') ...[
            if (speed != null) ...[
              const SizedBox(height: 12),
              HeaderInfoIconValue(
                header: 'Speed',
                value: '${speed.toStringAsFixed(1)} km/h',
                icon: Icons.speed,
              ),
            ],
            if (heading != null) ...[
              const SizedBox(height: 12),
              HeaderInfoIconValue(
                header: 'Heading',
                value: '${heading.toStringAsFixed(0)}°',
                icon: Icons.explore,
              ),
            ],
            if (ignition != null) ...[
              const SizedBox(height: 12),
              HeaderInfoIconValue(
                header: 'Ignition',
                value: ignition ? 'On' : 'Off',
                icon: ignition ? Icons.key : Icons.key_off,
              ),
            ],
          ],
          if (currentZones.isNotEmpty) ...[
            const SizedBox(height: 12),
            HeaderInfoIconValue(
              header: 'Current Zones',
              value: '${currentZones.length} zone(s)',
              icon: Icons.fence,
            ),
          ],
          if (lastTransition != null) ...[
            const SizedBox(height: 12),
            HeaderInfoIconValue(
              header: 'Last Geofence Event',
              value:
                  '${lastTransition['event'] == 'enter' ? 'Entered' : 'Left'} '
                  '${lastTransition['zoneName'] ?? 'zone'}',
              icon: lastTransition['event'] == 'enter'
                  ? Icons.login
                  : Icons.logout,
            ),
          ],
        ],
      ),
    );
  }

  // ── Webhook URL Section ─────────────────────────────────────────

  Widget _buildWebhookSection({
    required String companyId,
    required String inventoryId,
  }) {
    final startUrl =
        'https://us-central1-kleenops.cloudfunctions.net/equipmentRuntimeEvent/$companyId/$inventoryId?event=start';
    final stopUrl =
        'https://us-central1-kleenops.cloudfunctions.net/equipmentRuntimeEvent/$companyId/$inventoryId?event=stop';

    return ContainerActionWidget(
      title: 'Device Setup',
      actionText: '',
      onAction: null,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppPaletteScope.of(context)
                  .primary2
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: AppPaletteScope.of(context).primary2,
                        size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Shelly Setup Instructions',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppPaletteScope.of(context).primary2,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '1. Open the Shelly app on your phone\n'
                  '2. Select your Shelly device\n'
                  '3. Go to Actions (or Webhooks)\n'
                  '4. For "Switch turned ON", paste the Start URL\n'
                  '5. For "Switch turned OFF", paste the Stop URL\n'
                  '6. Save and test by toggling the switch',
                  style: TextStyle(
                    color: AppPaletteScope.of(context).primary2,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildCopyableUrl(label: 'Start URL (Switch ON)', url: startUrl),
          const SizedBox(height: 12),
          _buildCopyableUrl(label: 'Stop URL (Switch OFF)', url: stopUrl),
        ],
      ),
    );
  }

  Widget _buildCopyableUrl({required String label, required String url}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 12)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  url,
                  style:
                      const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                tooltip: 'Copy to clipboard',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: url));
                  SnackbarService.instance.showSnackBar(
                    SnackBar(
                      content: Text('$label copied'),
                      duration: const Duration(seconds: 5),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder(String label) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text('$label placeholder'),
    );
  }

  Widget _buildCenteredMessage(String message) {
    return Center(child: Text(message));
  }
}
