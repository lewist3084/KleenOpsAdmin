// lib/features/engagement/tabs/engagement_reports_tabs.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';
import 'package:kleenops_admin/features/engagement/screens/internal_reports.dart';
import 'package:kleenops_admin/features/engagement/screens/external_reports.dart';
import 'package:shared_widgets/tabs/lazy_tab_view.dart';
import 'package:shared_widgets/tabs/standard_tab.dart';

final engagementReportsTabsSearchVisibleProvider =
    StateProvider<bool>((_) => false);

class EngagementReportsTabs extends StatelessWidget {
  const EngagementReportsTabs({super.key});

  @override
  Widget build(BuildContext context) {
    const bottomInset = 16.0;

    return DefaultTabController(
      length: 2,
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
                Tab(text: 'Internal'),
                Tab(text: 'External'),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: const LazyTabView(
                physics: NeverScrollableScrollPhysics(),
                children: [
                  InternalReportsContent(),
                  ExternalReportsContent(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
