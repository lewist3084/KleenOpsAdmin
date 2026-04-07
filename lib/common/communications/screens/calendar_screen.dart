import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart' as sf;

import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/common/communications/comm_menu.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';

class AdminCalendarScreen extends ConsumerWidget {
  const AdminCalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyAsync = ref.watch(companyIdProvider);
    final menuSections = MenuDrawerSections(
      communications: buildAdminCommunicationMenuItems(context),
    );

    return Scaffold(
      body: SafeArea(
        child: companyAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (companyRef) {
            if (companyRef == null) {
              return const Center(child: Text('No company.'));
            }
            return _CalendarBody(companyRef: companyRef);
          },
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(title: 'Calendar', menuSections: menuSections),
          const HomeNavBarAdapter(),
        ],
      ),
    );
  }
}

class _CalendarBody extends StatelessWidget {
  const _CalendarBody({required this.companyRef});
  final DocumentReference<Map<String, dynamic>> companyRef;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: companyRef
          .collection('timeline')
          .where('startTime', isGreaterThan: Timestamp.fromDate(
              DateTime.now().subtract(const Duration(days: 30))))
          .orderBy('startTime')
          .limit(200)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        final appointments = <sf.Appointment>[];

        for (final doc in docs) {
          final d = doc.data();
          final start = (d['startTime'] as Timestamp?)?.toDate();
          final end = (d['endTime'] as Timestamp?)?.toDate();
          final name = (d['name'] as String?) ??
              (d['title'] as String?) ??
              (d['snippet'] as String?) ??
              '';
          if (start == null) continue;

          appointments.add(sf.Appointment(
            startTime: start,
            endTime: end ?? start.add(const Duration(hours: 1)),
            subject: name,
            color: _colorForCategory(
                (d['timelineCategory'] as String?) ?? ''),
          ));
        }

        return sf.SfCalendar(
          view: sf.CalendarView.week,
          dataSource: _AppointmentDataSource(appointments),
          allowedViews: const [
            sf.CalendarView.day,
            sf.CalendarView.week,
            sf.CalendarView.month,
            sf.CalendarView.schedule,
          ],
          showNavigationArrow: true,
          showDatePickerButton: true,
          monthViewSettings: const sf.MonthViewSettings(
            appointmentDisplayMode:
                sf.MonthAppointmentDisplayMode.appointment,
          ),
        );
      },
    );
  }

  Color _colorForCategory(String category) {
    switch (category) {
      case 'callTranscription':
        return Colors.blue;
      case 'text_message_category':
        return Colors.green;
      case 'message_board_category':
        return Colors.orange;
      default:
        return Colors.teal;
    }
  }
}

class _AppointmentDataSource extends sf.CalendarDataSource {
  _AppointmentDataSource(List<sf.Appointment> source) {
    appointments = source;
  }
}
