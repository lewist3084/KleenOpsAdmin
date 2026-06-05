// lib/common/communications/messageboard/screens/message_board_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/services/ai/ai_context_service.dart';
import 'package:kleenops_admin/services/notification_badge_service.dart';
import 'package:shared_widgets/theme/app_palette.dart';
import 'package:kleenops_admin/widgets/layout/bookended_canvas.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:shared_widgets/tabs/lazy_tab_view.dart';
import 'package:shared_widgets/tabs/standard_tab.dart';
import '../models/message_board_post.dart';
import '../services/message_board_service.dart';
import '../widgets/pdf_preview.dart';
import 'message_board_form_screen.dart';
import 'message_board_post_detail_screen.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';

class MessageBoardScreen extends ConsumerStatefulWidget {
  const MessageBoardScreen({super.key});

  @override
  ConsumerState<MessageBoardScreen> createState() =>
      _MessageBoardScreenState();
}

class _MessageBoardScreenState extends ConsumerState<MessageBoardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Opening the board clears the unread-bulletin badge.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final memberRef = ref.read(memberDocRefProvider).value;
      NotificationBadgeService.instance.clearBulletinBadge(memberRef);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userDocAsync = ref.watch(userDocumentProvider);
    final canCreate = userDocAsync.maybeWhen(
      data: (data) => data['messageBoard'] == true,
      orElse: () => false,
    );
    final controller = ref.read(aiCanvasControllerProvider);
    final menuSections = MenuDrawerSections(
      actions: const <ContentMenuItem>[],
      resources: const <ContentMenuItem>[],
    );

    return Scaffold(
      body: BookendedCanvas(
        child: Column(
          children: [
            Container(
              color: Colors.white,
              child: StandardTabBar(
                controller: _tabController,
                isScrollable: true,
                dividerColor: Colors.grey[300],
                indicatorWeight: 3,
                labelColor: Colors.black,
                unselectedLabelColor: Colors.grey[600],
                tabs: const [
                  Tab(text: 'Board'),
                  Tab(text: 'History'),
                ],
              ),
            ),
            Expanded(
              child: LazyTabView(
                controller: _tabController,
                children: const [
                  _ActiveBoardTab(),
                  _HistoryTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: 'Message Board',
            onAiPressed: controller.toggle,
            menuSections: menuSections,
          ),
          const HomeNavBarAdapter(),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton(
              heroTag: 'messageBoardAddFab',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MessageBoardFormScreen(),
                ),
              ),
              tooltip: 'Add Post',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Active Board Tab
// ──────────────────────────────────────────────────────────────────────────────

class _ActiveBoardTab extends ConsumerWidget {
  const _ActiveBoardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyAsync = ref.watch(companyIdProvider);
    final userDocAsync = ref.watch(userDocumentProvider);

    return companyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (companyRef) {
        if (companyRef == null) {
          return const Center(child: Text('No company selected.'));
        }
        return userDocAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (userData) =>
              _buildBoardStream(context, companyRef, userData, archived: false),
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// History Tab
// ──────────────────────────────────────────────────────────────────────────────

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyAsync = ref.watch(companyIdProvider);
    final userDocAsync = ref.watch(userDocumentProvider);

    return companyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (companyRef) {
        if (companyRef == null) {
          return const Center(child: Text('No company selected.'));
        }
        return userDocAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (userData) =>
              _buildBoardStream(context, companyRef, userData, archived: true),
        );
      },
    );
  }
}

Widget _buildBoardStream(
  BuildContext context,
  DocumentReference<Map<String, dynamic>> companyRef,
  Map<String, dynamic> userData, {
  required bool archived,
}) {
  final memberRef =
      userData['memberRef'] as DocumentReference<Map<String, dynamic>>?;
  final memberName = (userData['name'] as String?) ??
      (userData['displayName'] as String?) ??
      '';
  final teamAccess = (userData['teamAccess'] as List<dynamic>? ?? [])
      .whereType<DocumentReference>()
      .toList();

  if (memberRef == null) {
    return const Center(child: Text('No member record.'));
  }

  final service = MessageBoardService(
    companyRef: companyRef,
    memberRef: memberRef,
    memberName: memberName,
  );

  final stream = archived
      ? service.watchArchivedPosts(teamRefs: teamAccess)
      : service.watchPosts(teamRefs: teamAccess);

  return StreamBuilder<List<MessageBoardPost>>(
    stream: stream,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(child: Text('Error: ${snapshot.error}'));
      }

      final posts = snapshot.data ?? [];
      if (posts.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                archived ? Icons.history : Icons.dashboard_outlined,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                archived ? 'No archived posts' : 'No posts yet',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
              if (!archived) ...[
                const SizedBox(height: 8),
                Text(
                  'Add notes, documents, and images to the board',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ],
          ),
        );
      }

      if (archived) {
        // History: simple list view
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: posts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final post = posts[index];
            return _ArchivedPostTile(post: post, service: service);
          },
        );
      }

      // Active board: pinned + recent grid
      final pinnedPosts = posts.where((p) => p.isPinned).toList();
      final regularPosts = posts.where((p) => !p.isPinned).toList();

      return CustomScrollView(
        slivers: [
          if (pinnedPosts.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: _SectionHeader(title: 'Pinned', icon: Icons.push_pin),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              sliver: SliverGrid(
                gridDelegate:
                    const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 300,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.0,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _MessageBoardPostCard(
                    post: pinnedPosts[i],
                    service: service,
                  ),
                  childCount: pinnedPosts.length,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
          if (regularPosts.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: _SectionHeader(title: 'Recent', icon: Icons.access_time),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
              sliver: SliverGrid(
                gridDelegate:
                    const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 300,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.0,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _MessageBoardPostCard(
                    post: regularPosts[i],
                    service: service,
                  ),
                  childCount: regularPosts.length,
                ),
              ),
            ),
          ],
        ],
      );
    },
  );
}

// ──────────────────────────────────────────────────────────────────────────────
// Archived post tile (list view for history)
// ──────────────────────────────────────────────────────────────────────────────

class _ArchivedPostTile extends StatelessWidget {
  const _ArchivedPostTile({required this.post, required this.service});
  final MessageBoardPost post;
  final MessageBoardService service;

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat.yMMMd().format(post.createdAt);
    final expiredStr = post.expiresAt != null
        ? 'Expired ${DateFormat.yMMMd().format(post.expiresAt!)}'
        : 'Manually archived';

    return Card(
      child: ListTile(
        leading: Icon(_iconForType(post.type), color: Colors.grey),
        title: Text(post.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '$expiredStr  •  Posted $dateStr by ${post.createdByName}',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'restore') {
              service.restorePost(post.id);
              SnackbarService.instance.showSnackBar(
                const SnackBar(duration: Duration(seconds: 5), content: Text('Post restored to board')),
              );
            } else if (value == 'delete') {
              service.deletePost(post.id);
              SnackbarService.instance.showSnackBar(
                const SnackBar(duration: Duration(seconds: 5), content: Text('Post permanently deleted')),
              );
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'restore', child: Text('Restore')),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MessageBoardPostDetailScreen(postRef: post.ref),
          ),
        ),
      ),
    );
  }

  IconData _iconForType(MessageBoardPostType type) {
    switch (type) {
      case MessageBoardPostType.note:
        return Icons.sticky_note_2;
      case MessageBoardPostType.image:
        return Icons.image;
      case MessageBoardPostType.document:
        return Icons.description;
      case MessageBoardPostType.video:
        return Icons.videocam;
      case MessageBoardPostType.link:
        return Icons.link;
    }
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Shared widgets
// ──────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Post card (visual board items)
// ──────────────────────────────────────────────────────────────────────────────

class _MessageBoardPostCard extends StatelessWidget {
  final MessageBoardPost post;
  final MessageBoardService service;

  const _MessageBoardPostCard({required this.post, required this.service});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openPost(context),
      onLongPress: () => _showPostOptions(context),
      child: Stack(
        children: [
          _buildCardContent(context, Theme.of(context)),
          // Expiration badge
          if (post.expiresAt != null)
            Positioned(
              bottom: 4,
              right: 4,
              child: _ExpirationBadge(post: post),
            ),
        ],
      ),
    );
  }

  Widget _buildCardContent(BuildContext context, ThemeData theme) {
    switch (post.type) {
      case MessageBoardPostType.note:
        return _buildNoteCard(theme);
      case MessageBoardPostType.image:
        return _buildImageCard(context, theme);
      case MessageBoardPostType.document:
        return _buildDocumentCard(context, theme);
      case MessageBoardPostType.video:
        return _buildVideoCard(context, theme);
      case MessageBoardPostType.link:
        return _buildLinkCard(context, theme);
    }
  }

  Widget _buildNoteCard(ThemeData theme) {
    final noteColor = post.noteColor != null
        ? Color(int.parse(post.noteColor!.replaceFirst('#', '0xFF')))
        : const Color(0xFFFFEB3B);

    return Container(
      decoration: BoxDecoration(
        color: noteColor,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post.isPinned)
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.push_pin, size: 16, color: Colors.black54),
              ),
            Text(
              post.title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (post.content != null && post.content!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  post.content!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                  overflow: TextOverflow.fade,
                ),
              ),
            ],
            const Spacer(),
            _buildFooter(Colors.black45),
          ],
        ),
      ),
    );
  }

  Widget _buildImageCard(BuildContext context, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (post.fileUrl != null)
                  CachedNetworkImage(
                    imageUrl: post.thumbnailUrl ?? post.fileUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      color: Colors.grey.shade200,
                      child: Icon(Icons.image, size: 40, color: Colors.grey.shade400),
                    ),
                  )
                else
                  Container(
                    color: Colors.grey.shade200,
                    child: Icon(Icons.image, size: 40, color: Colors.grey.shade400),
                  ),
                if (post.isPinned)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.push_pin, size: 14, color: AppPaletteScope.of(context).primary2),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(post.title,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(post.createdByName,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(BuildContext context, ThemeData theme) {
    final fileTypeLabel = post.fileTypeLabel ?? 'File';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildDocumentVisualPreview(fileTypeLabel),
                if (post.isPinned)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.push_pin,
                        size: 14,
                        color: AppPaletteScope.of(context).primary2,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  post.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                _buildFooter(Colors.grey.shade600),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentVisualPreview(String fileTypeLabel) {
    final isPdf = fileTypeLabel == 'PDF';
    // PDFs (web and mobile): render the actual first page inline, falling
    // back to the styled placeholder if the document can't be loaded.
    if (isPdf && post.fileUrl != null) {
      return PdfPreviewBox(
        url: post.fileUrl!,
        fallback: _buildFileTypePlaceholder(fileTypeLabel),
      );
    }
    // Non-PDF docs: styled file-type placeholder with filename.
    return _buildFileTypePlaceholder(fileTypeLabel);
  }

  Widget _buildFileTypePlaceholder(String fileTypeLabel) {
    final color = _getFileTypeColor(fileTypeLabel);
    final icon = _getFileTypeIcon(fileTypeLabel);
    return Container(
      color: color.withValues(alpha: 0.08),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: color),
          const SizedBox(height: 8),
          Text(
            fileTypeLabel,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 1.5,
            ),
          ),
          if (post.fileName != null) ...[
            const SizedBox(height: 4),
            Text(
              post.fileName!,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVideoCard(BuildContext context, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (post.thumbnailUrl != null)
            CachedNetworkImage(imageUrl: post.thumbnailUrl!, fit: BoxFit.cover, errorWidget: (_, __, ___) => Container(color: Colors.grey.shade900)),
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), shape: BoxShape.circle),
              child: Icon(Icons.play_arrow, size: 32, color: Colors.grey.shade800),
            ),
          ),
          if (post.isPinned)
            Positioned(
              top: 8, right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), shape: BoxShape.circle),
                child: Icon(Icons.push_pin, size: 14, color: AppPaletteScope.of(context).primary2),
              ),
            ),
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent]),
              ),
              child: Text(post.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white), maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkCard(BuildContext context, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPaletteScope.of(context).primary2.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppPaletteScope.of(context).primary2.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.link, color: AppPaletteScope.of(context).primary2, size: 20),
                ),
                const Spacer(),
                if (post.isPinned) Icon(Icons.push_pin, size: 16, color: AppPaletteScope.of(context).primary2),
              ],
            ),
            const SizedBox(height: 12),
            Text(post.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
            if (post.linkUrl != null) ...[
              const SizedBox(height: 4),
              Text(post.linkUrl!, style: TextStyle(fontSize: 10, color: AppPaletteScope.of(context).primary2), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
            const Spacer(),
            _buildFooter(Colors.grey.shade500),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(Color textColor) {
    final dateStr = DateFormat.MMMd().format(post.createdAt);
    return Row(
      children: [
        Expanded(
          child: Text(post.createdByName, style: TextStyle(fontSize: 10, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        Text(dateStr, style: TextStyle(fontSize: 10, color: textColor)),
      ],
    );
  }

  void _openPost(BuildContext context) {
    if (post.type == MessageBoardPostType.link && post.linkUrl != null) {
      final uri = Uri.tryParse(post.linkUrl!);
      if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MessageBoardPostDetailScreen(postRef: post.ref)),
    );
  }

  void _showPostOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(post.isPinned ? Icons.push_pin_outlined : Icons.push_pin),
              title: Text(post.isPinned ? 'Unpin' : 'Pin to top'),
              onTap: () {
                Navigator.pop(ctx);
                service.togglePin(post.id, !post.isPinned);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MessageBoardFormScreen(postRef: post.ref, initialData: post),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Archive'),
              onTap: () {
                Navigator.pop(ctx);
                service.archivePost(post.id);
                SnackbarService.instance.showSnackBar(
                  SnackBar(
                    duration: const Duration(seconds: 5),
                    content: const Text('Post archived'),
                    action: SnackBarAction(
                      label: 'Undo',
                      onPressed: () => service.restorePost(post.id),
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  builder: (dlgCtx) => DialogAction(
                    title: 'Delete Post',
                    content: const Text('Are you sure you want to delete this post?'),
                    cancelText: 'Cancel',
                    onCancel: () => Navigator.pop(dlgCtx),
                    actionText: 'Delete',
                    onAction: () {
                      Navigator.pop(dlgCtx);
                      service.deletePost(post.id);
                      SnackbarService.instance.showSnackBar(const SnackBar(duration: Duration(seconds: 5), content: Text('Post deleted')));
                    },
                    actionButtonColor: Colors.red[600],
                    buttonTextColor: Colors.white,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFileTypeIcon(String type) {
    switch (type) {
      case 'PDF': return Icons.picture_as_pdf;
      case 'Excel': return Icons.table_chart;
      case 'Word': return Icons.description;
      case 'PowerPoint': return Icons.slideshow;
      default: return Icons.insert_drive_file;
    }
  }

  Color _getFileTypeColor(String type) {
    switch (type) {
      case 'PDF': return Colors.red;
      case 'Excel': return Colors.green;
      case 'Word': return Colors.blue;
      case 'PowerPoint': return Colors.orange;
      default: return Colors.grey;
    }
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Expiration badge overlay
// ──────────────────────────────────────────────────────────────────────────────

class _ExpirationBadge extends StatelessWidget {
  const _ExpirationBadge({required this.post});
  final MessageBoardPost post;

  @override
  Widget build(BuildContext context) {
    final days = post.daysRemaining;
    if (days == null) return const SizedBox.shrink();

    final color = days <= 1
        ? Colors.red
        : days <= 3
            ? Colors.orange
            : Colors.grey;
    final label = days == 0
        ? 'Expires today'
        : days == 1
            ? '1 day left'
            : '$days days left';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }
}

