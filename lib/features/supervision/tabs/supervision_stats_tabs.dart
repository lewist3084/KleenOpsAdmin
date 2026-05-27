//  supervision_stats_tabs.dart

import 'package:flutter/material.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_appbar_adapter.dart';
import 'package:kleenops_admin/features/supervision/screens/supervision_stats_hours_worked.dart';
import 'package:shared_widgets/tabs/lazy_tab_view.dart';
import 'package:shared_widgets/tabs/standard_tab.dart';

class SupervisionStatsTabs extends StatelessWidget {
  const SupervisionStatsTabs({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ContentAppBar(),
      body: DefaultTabController(
        length: 4,
        child: Column(
          children: [
            Container(
              color: Colors.white,
              child: StandardTabBar(
                isScrollable: true,
                dividerColor: Colors.grey[300],
                indicatorWeight: 3,
                labelColor: Colors.black,
                unselectedLabelColor: Colors.grey[600],
                tabs: const [
                  Tab(text: 'Hours Worked'),
                  Tab(text: 'Contribution'),
                  Tab(text: 'Dependability'),
                  Tab(text: 'Quality'),
                ],
              ),
            ),
            Expanded(
              child: Builder(
                builder: (context) => LazyTabView(
                  controller: DefaultTabController.of(context),
                  physics: const NeverScrollableScrollPhysics(),
                  children: const [
                    SupervisionStatsHoursWorkedContent(
                        key: PageStorageKey('sup-stats-hours')),
                    Center(
                        key: PageStorageKey('sup-stats-contribution'),
                        child: Text('Contribution Tab Placeholder')),
                    Center(
                        key: PageStorageKey('sup-stats-dependability'),
                        child: Text('Dependability Tab Placeholder')),
                    Center(
                        key: PageStorageKey('sup-stats-quality'),
                        child: Text('Quality Tab Placeholder')),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
