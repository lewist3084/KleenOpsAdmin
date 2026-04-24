import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:shared_widgets/lists/standardViewGroup.dart';
import 'package:shared_widgets/tiles/standard_tile_large.dart';
import 'package:kleenops_admin/app/shared_widgets/search/search_control_strip_adapter.dart';
import 'package:kleenops_admin/widgets/fields/multi_select/day_multi_select.dart';
import 'package:kleenops_admin/widgets/fields/multi_select/week_multi_select.dart';
import 'package:kleenops_admin/widgets/fields/multi_select/month_multi_select.dart';
import 'package:kleenops_admin/features/scheduling/screens/widgets/time_picker_field.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:shared_widgets/services/firestore_service.dart';
import 'package:kleenops_admin/features/sales/details/marketing_delivery_details.dart';

/// Shows a dialog for creating or editing a marketing delivery schedule.
/// When [docRef] is provided the dialog will load the existing values and
/// update that document on save. Otherwise a new document is created under
/// `FirebaseFirestore.instance.collection('schedule')`.
Future<void> showDeliveryScheduleDialog({
  required BuildContext context,
  required DocumentReference<Map<String, dynamic>> companyRef,
  DocumentReference<Map<String, dynamic>>? docRef,
}) async {
  final fs = FirestoreService();

  // Default values
  String name = '';
  String desc = '';
  String frequency = 'Weekly';
  List<String> days = [];
  List<String> weeks = [];
  List<String> months = [];
  TimeOfDay? time;

  if (docRef != null) {
    final snap = await docRef.get();
    final data = snap.data();
    if (data != null) {
      name = data['name'] as String? ?? '';
      desc = data['description'] as String? ?? '';
      frequency = data['frequency'] as String? ?? 'Weekly';
      days = List<String>.from(data['day'] ?? []);
      weeks = List<String>.from(data['week'] ?? []);
      months = List<String>.from(data['month'] ?? []);
      final ts = data['time'];
      if (ts is Timestamp) {
        final dt = ts.toDate();
        time = TimeOfDay.fromDateTime(dt);
      }
    }
  }

  final nameCtl = TextEditingController(text: name);
  final descCtl = TextEditingController(text: desc);

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx2, setState) => DialogAction(
        title: docRef == null
            ? 'New Marketing Schedule'
            : 'Edit Marketing Schedule',
        cancelText: 'Cancel',
        actionText: 'Save',
        onCancel: () => Navigator.of(ctx2).pop(),
        onAction: () async {
          final nameVal = nameCtl.text.trim();
          final descVal = descCtl.text.trim();
          if (nameVal.isEmpty) return;
          Timestamp? ts;
          if (time != null) {
            final now = DateTime.now();
            ts = Timestamp.fromDate(DateTime(
                now.year, now.month, now.day, time!.hour, time!.minute));
          }

          final data = <String, dynamic>{
            'name': nameVal,
            'description': descVal,
            'frequency': frequency,
            'day': days,
            'week': weeks,
            'month': months,
            'time': ts,
          };

          if (docRef == null) {
            await fs.saveDocument(
              collectionRef: FirebaseFirestore.instance.collection('schedule'),
              data: {
                ...data,
                'createdAt': FieldValue.serverTimestamp(),
              },
            );
          } else {
            await docRef.update(data);
          }

          if (context.mounted) Navigator.of(ctx2).pop();
        },
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtl,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descCtl,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: frequency,
                decoration: const InputDecoration(labelText: 'Frequency'),
                items: const [
                  DropdownMenuItem(value: 'Weekly', child: Text('Weekly')),
                  DropdownMenuItem(value: 'Monthly', child: Text('Monthly')),
                  DropdownMenuItem(value: 'Annually', child: Text('Annually')),
                ],
                onChanged: (v) => setState(() => frequency = v ?? 'Weekly'),
              ),
              const SizedBox(height: 16),
              if (['Weekly', 'Monthly', 'Annually'].contains(frequency)) ...[
                DayMultiSelectDropdown(
                  selectedDays: days,
                  onChanged: (v) => setState(() => days = v),
                ),
                const SizedBox(height: 16),
              ],
              if (frequency == 'Monthly' || frequency == 'Annually') ...[
                WeekMultiSelectDropdown(
                  selectedWeeks: weeks,
                  onChanged: (v) => setState(() => weeks = v),
                ),
                const SizedBox(height: 16),
              ],
              if (frequency == 'Annually') ...[
                MonthMultiSelectDropdown(
                  selectedMonths: months,
                  onChanged: (v) => setState(() => months = v),
                ),
                const SizedBox(height: 16),
              ],
              TimePickerField(
                selectedTime: time,
                onTimePicked: (t) => setState(() => time = t),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  nameCtl.dispose();
  descCtl.dispose();
}

class MarketingScheduleContent extends ConsumerStatefulWidget {
  const MarketingScheduleContent({super.key, this.searchVisible = false});

  final bool searchVisible;

  @override
  ConsumerState<MarketingScheduleContent> createState() =>
      _MarketingScheduleContentState();
}

class _MarketingScheduleContentState
    extends ConsumerState<MarketingScheduleContent> {
  final TextEditingController _searchCtl = TextEditingController();
  String _search = '';

  Future<void> _showAddDialog(
      DocumentReference<Map<String, dynamic>> companyRef) async {
    await showDeliveryScheduleDialog(context: context, companyRef: companyRef);
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final companyAsync = ref.watch(companyIdProvider);
    final bool hideChrome = false;
    final bottomInset =
        (hideChrome ? 16.0 : kBottomNavigationBarHeight + 16.0) +
            MediaQuery.of(context).padding.bottom;

    return companyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (companyRef) {
        if (companyRef == null) {
          return const Center(child: Text('No company found.'));
        }

        final query = FirebaseFirestore.instance.collection('schedule').orderBy('frequency');

        final list = StandardViewGroup(
          queryStream: query.snapshots(),
          groupBy: (_) => '',
          itemBuilder: (doc) {
            final data = doc.data();
            final days = List<String>.from(data['day'] ?? []);
            final weeks = List<String>.from(data['week'] ?? []);
            final months = List<String>.from(data['month'] ?? []);
            String timeStr = '';
            final ts = data['time'];
            if (ts is Timestamp) {
              final dt = ts.toDate();
              timeStr = TimeOfDay.fromDateTime(dt).format(context);
            }
            return StandardTileLargeDart(
              imageUrl: '',
              showImage: false,
              firstLine: days.join(', '),
              secondLine: weeks.join(', '),
              thirdLine: months.join(', '),
              fourthLine: timeStr,
              firstLineIcon: Icons.schedule,
            );
          },
          onTap: (doc) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MarketingDeliveryDetailsScreen(
                  docRef: doc.reference,
                ),
              ),
            );
          },
        );

        return Stack(
          children: [
            Column(
              children: [
                if (widget.searchVisible)
                  SearchControlStrip(
                    controller: _searchCtl,
                    hintText: 'Search Schedule',
                    onChanged: (t) => setState(() => _search = t.trim()),
                  ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: bottomInset),
                    child: list,
                  ),
                ),
              ],
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                heroTag: null,
                child: const Icon(Icons.add),
                onPressed: () => _showAddDialog(companyRef),
              ),
            ),
          ],
        );
      },
    );
  }
}
