import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/common/communications/comm_menu.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import '../models/email_message.dart';

class AdminEmailScreen extends ConsumerStatefulWidget {
  const AdminEmailScreen({super.key});

  @override
  ConsumerState<AdminEmailScreen> createState() => _AdminEmailScreenState();
}

class _AdminEmailScreenState extends ConsumerState<AdminEmailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final companyAsync = ref.watch(companyIdProvider);
    final memberAsync = ref.watch(memberDocRefProvider);
    final menuSections = MenuDrawerSections(
      communications: buildAdminCommunicationMenuItems(context),
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Inbox'),
                Tab(text: 'Sent'),
                Tab(text: 'Junk'),
              ],
            ),
            Expanded(
              child: companyAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (companyRef) {
                  if (companyRef == null) {
                    return const Center(child: Text('No company.'));
                  }
                  return memberAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                    data: (memberRef) {
                      if (memberRef == null) {
                        return const Center(child: Text('No member.'));
                      }
                      final emailsRef = memberRef.collection('email');
                      return TabBarView(
                        controller: _tabController,
                        children: [
                          _EmailList(emailsRef: emailsRef, folder: 'INBOX'),
                          _EmailList(emailsRef: emailsRef, folder: 'Sent'),
                          _EmailList(emailsRef: emailsRef, folder: 'Junk'),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(title: 'Email', menuSections: menuSections),
          const HomeNavBarAdapter(),
        ],
      ),
    );
  }
}

class _EmailList extends StatelessWidget {
  const _EmailList({required this.emailsRef, required this.folder});
  final CollectionReference<Map<String, dynamic>> emailsRef;
  final String folder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: emailsRef
          .where('folder', isEqualTo: folder)
          .where('isDeleted', isEqualTo: false)
          .orderBy('receivedAt', descending: true)
          .snapshots(),
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
                Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text('No emails in $folder',
                    style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final email = EmailMessage.fromFirestore(docs[index]);
            return _EmailTile(email: email);
          },
        );
      },
    );
  }
}

class _EmailTile extends StatelessWidget {
  const _EmailTile({required this.email});
  final EmailMessage email;

  @override
  Widget build(BuildContext context) {
    final isUnread = !email.isRead;
    final dateStr = _formatDate(email.receivedAt);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _avatarColor(email.from),
        child: Text(
          email.senderDisplayName.isNotEmpty
              ? email.senderDisplayName[0].toUpperCase()
              : '?',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      title: Row(
        children: [
          if (isUnread)
            Container(
              width: 8, height: 8,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          Expanded(
            child: Text(
              email.senderDisplayName,
              style: TextStyle(
                fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(dateStr,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(email.subject,
              style: TextStyle(
                  fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          if (email.emailSummary != null && email.emailSummary!.isNotEmpty)
            Text(email.emailSummary!,
                style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis)
          else
            Text(email.preview,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
        ],
      ),
      isThreeLine: true,
    );
  }

  Color _avatarColor(String email) {
    const colors = [
      Colors.blue, Colors.green, Colors.orange, Colors.purple,
      Colors.teal, Colors.pink, Colors.indigo, Colors.cyan,
    ];
    return colors[email.hashCode.abs() % colors.length];
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final emailDate = DateTime(date.year, date.month, date.day);
    if (emailDate == today) return DateFormat.jm().format(date);
    if (emailDate == today.subtract(const Duration(days: 1))) return 'Yesterday';
    if (now.difference(date).inDays < 7) return DateFormat.E().format(date);
    return DateFormat.MMMd().format(date);
  }
}
