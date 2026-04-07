import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/common/communications/comm_menu.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import '../models/message_board_post.dart';
import '../services/message_board_service.dart';

class AdminMessageBoardScreen extends ConsumerStatefulWidget {
  const AdminMessageBoardScreen({super.key});

  @override
  ConsumerState<AdminMessageBoardScreen> createState() =>
      _AdminMessageBoardScreenState();
}

class _AdminMessageBoardScreenState
    extends ConsumerState<AdminMessageBoardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final companyAsync = ref.watch(companyIdProvider);
    final userAsync = ref.watch(userDocumentProvider);
    final menuSections = MenuDrawerSections(
      communications: buildAdminCommunicationMenuItems(context),
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              tabs: const [Tab(text: 'Board'), Tab(text: 'History')],
            ),
            Expanded(
              child: companyAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (companyRef) {
                  if (companyRef == null) {
                    return const Center(child: Text('No company.'));
                  }
                  return userAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                    data: (userData) {
                      final memberRef = userData['memberRef']
                          as DocumentReference<Map<String, dynamic>>?;
                      final memberName =
                          (userData['name'] as String?) ?? '';
                      if (memberRef == null) {
                        return const Center(child: Text('No member.'));
                      }
                      final teamAccess =
                          (userData['teamAccess'] as List<dynamic>? ?? [])
                              .whereType<DocumentReference>()
                              .toList();
                      final service = MessageBoardService(
                        companyRef: companyRef,
                        memberRef: memberRef,
                        memberName: memberName,
                      );
                      return TabBarView(
                        controller: _tabController,
                        children: [
                          _PostGrid(
                            service: service,
                            teamAccess: teamAccess,
                            archived: false,
                          ),
                          _PostGrid(
                            service: service,
                            teamAccess: teamAccess,
                            archived: true,
                          ),
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
          DetailsAppBar(title: 'Message Board', menuSections: menuSections),
          const HomeNavBarAdapter(),
        ],
      ),
    );
  }
}

class _PostGrid extends StatelessWidget {
  const _PostGrid({
    required this.service,
    required this.teamAccess,
    required this.archived,
  });

  final MessageBoardService service;
  final List<DocumentReference> teamAccess;
  final bool archived;

  @override
  Widget build(BuildContext context) {
    final stream = archived
        ? service.watchArchivedPosts(teamRefs: teamAccess)
        : service.watchPosts(teamRefs: teamAccess);

    return StreamBuilder<List<MessageBoardPost>>(
      stream: stream,
      builder: (context, snap) {
        final posts = snap.data ?? [];
        if (posts.isEmpty) {
          return Center(
            child: Text(
              archived ? 'No archived posts' : 'No posts yet',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          );
        }

        if (archived) {
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: posts.length,
            itemBuilder: (_, i) {
              final post = posts[i];
              final dateStr = DateFormat.yMMMd().format(post.createdAt);
              return Card(
                child: ListTile(
                  title: Text(post.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('$dateStr by ${post.createdByName}',
                      style: const TextStyle(fontSize: 11)),
                  trailing: IconButton(
                    icon: const Icon(Icons.restore),
                    onPressed: () => service.restorePost(post.id),
                  ),
                ),
              );
            },
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 300,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.0,
          ),
          itemCount: posts.length,
          itemBuilder: (_, i) {
            final post = posts[i];
            final noteColor = post.noteColor != null
                ? Color(
                    int.parse(post.noteColor!.replaceFirst('#', '0xFF')))
                : const Color(0xFFFFEB3B);
            return Container(
              decoration: BoxDecoration(
                color: post.type == MessageBoardPostType.note
                    ? noteColor
                    : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post.isPinned)
                    const Icon(Icons.push_pin, size: 14, color: Colors.black54),
                  Text(post.title,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  if (post.content != null) ...[
                    const SizedBox(height: 4),
                    Expanded(
                      child: Text(post.content!,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade700),
                          overflow: TextOverflow.fade),
                    ),
                  ] else
                    const Spacer(),
                  Text(
                    '${post.createdByName} • ${DateFormat.MMMd().format(post.createdAt)}',
                    style:
                        TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
