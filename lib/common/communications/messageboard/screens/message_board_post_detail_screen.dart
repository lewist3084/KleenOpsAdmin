// lib/common/communications/messageboard/screens/message_board_post_detail_screen.dart

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
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:shared_widgets/theme/app_palette.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:shared_widgets/viewers/file_carousel_viewer.dart';
import 'package:shared_widgets/viewers/pdf_viewer.dart' as pdf_viewer;
import '../models/message_board_post.dart';
import '../services/message_board_service.dart';
import '../widgets/pdf_preview.dart';
import 'message_board_form_screen.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';

class MessageBoardPostDetailScreen extends ConsumerStatefulWidget {
  final DocumentReference<Map<String, dynamic>> postRef;

  const MessageBoardPostDetailScreen({
    super.key,
    required this.postRef,
  });

  @override
  ConsumerState<MessageBoardPostDetailScreen> createState() =>
      _MessageBoardPostDetailScreenState();
}

class _MessageBoardPostDetailScreenState
    extends ConsumerState<MessageBoardPostDetailScreen> {
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _postStream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _postStream ??= widget.postRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            body: const Center(child: Text('Post not found.')),
            bottomNavigationBar: _buildBottomBar(context, null),
          );
        }

        final post = MessageBoardPost.fromFirestore(snapshot.data!);

        return Scaffold(
          body: SafeArea(
            child: _buildContent(context, post),
          ),
          floatingActionButton: _buildEditFab(context, post),
          bottomNavigationBar: _buildBottomBar(context, post),
        );
      },
    );
  }

  /// FAB visible only to the post's creator â€” a quick shortcut to the same
  /// edit flow that's also in the overflow menu.
  Widget? _buildEditFab(BuildContext context, MessageBoardPost post) {
    final createdByPath = post.createdByRef?.path;
    if (createdByPath == null) return null;

    final userData = ref.watch(userDocumentProvider).maybeWhen(
          data: (d) => d,
          orElse: () => const <String, dynamic>{},
        );
    final memberRef =
        userData['memberRef'] as DocumentReference<Map<String, dynamic>>?;
    if (memberRef == null || memberRef.path != createdByPath) return null;

    return FloatingActionButton(
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MessageBoardFormScreen(
            postRef: post.ref,
            initialData: post,
          ),
        ),
      ),
      backgroundColor: AppPaletteScope.of(context).primary2,
      foregroundColor: Colors.white,
      tooltip: 'Edit post',
      child: const Icon(Icons.edit),
    );
  }

  /// Bottom-stacked navigation: the details app bar sits on top of the
  /// home nav bar, replacing the top-of-screen [AppBar].
  Widget _buildBottomBar(BuildContext context, MessageBoardPost? post) {
    final controller = ref.read(aiCanvasControllerProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DetailsAppBar(
          title: post == null ? 'Post' : _getAppBarTitle(post.type),
          onAiPressed: controller.toggle,
          rightIcon1: post == null ? null : Icons.more_vert,
          rightAction1:
              post == null ? null : () => _showPostMenu(context, post),
          menuSections: MenuDrawerSections(
            actions: const <ContentMenuItem>[],
            resources: const <ContentMenuItem>[],
          ),
        ),
        const HomeNavBarAdapter(),
      ],
    );
  }

  /// Pin / edit / delete actions, surfaced from the details app bar's
  /// overflow icon now that the top [AppBar] (and its popup menu) is gone.
  void _showPostMenu(BuildContext context, MessageBoardPost post) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                post.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
              ),
              title: Text(post.isPinned ? 'Unpin' : 'Pin to top'),
              onTap: () {
                Navigator.pop(ctx);
                _handleMenuAction(context, ref, 'pin', post);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(ctx);
                _handleMenuAction(context, ref, 'edit', post);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title:
                  const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _handleMenuAction(context, ref, 'delete', post);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getAppBarTitle(MessageBoardPostType type) {
    switch (type) {
      case MessageBoardPostType.note:
        return 'Note';
      case MessageBoardPostType.image:
        return 'Image';
      case MessageBoardPostType.document:
        return 'Document';
      case MessageBoardPostType.video:
        return 'Video';
      case MessageBoardPostType.link:
        return 'Link';
    }
  }

  Widget _buildContent(BuildContext context, MessageBoardPost post) {
    switch (post.type) {
      case MessageBoardPostType.note:
        return _NoteDetailContent(post: post);
      case MessageBoardPostType.image:
        return _ImageDetailContent(post: post);
      case MessageBoardPostType.document:
        return _DocumentDetailContent(post: post);
      case MessageBoardPostType.video:
        return _VideoDetailContent(post: post);
      case MessageBoardPostType.link:
        return _LinkDetailContent(post: post);
    }
  }

  void _handleMenuAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    MessageBoardPost post,
  ) async {
    final companyRef = await ref.read(companyIdProvider.future);
    final userData = await ref.read(userDocumentProvider.future);
    final memberRef =
        userData['memberRef'] as DocumentReference<Map<String, dynamic>>?;
    final memberName =
        (userData['name'] as String?) ?? (userData['displayName'] as String?) ?? '';

    if (companyRef == null || memberRef == null) return;

    final service = MessageBoardService(
      companyRef: companyRef,
      memberRef: memberRef,
      memberName: memberName,
    );

    switch (action) {
      case 'pin':
        await service.togglePin(post.id, !post.isPinned);
        if (context.mounted) {
          SnackbarService.instance.showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 5),
              content: Text(post.isPinned ? 'Post unpinned' : 'Post pinned'),
            ),
          );
        }
        break;
      case 'edit':
        if (context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MessageBoardFormScreen(
                postRef: post.ref,
                initialData: post,
              ),
            ),
          );
        }
        break;
      case 'delete':
        if (context.mounted) {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => DialogAction(
              title: 'Delete Post',
              content: const Text('Are you sure you want to delete this post?'),
              cancelText: 'Cancel',
              onCancel: () => Navigator.pop(context, false),
              actionText: 'Delete',
              onAction: () => Navigator.pop(context, true),
              actionButtonColor: Colors.red[600],
              buttonTextColor: Colors.white,
            ),
          );

          if (confirmed == true && context.mounted) {
            await service.deletePost(post.id);
            Navigator.of(context).pop();
            SnackbarService.instance.showSnackBar(
              const SnackBar(duration: Duration(seconds: 5), content: Text('Post deleted')),
            );
          }
        }
        break;
    }
  }
}

class _NoteDetailContent extends StatelessWidget {
  final MessageBoardPost post;

  const _NoteDetailContent({required this.post});

  @override
  Widget build(BuildContext context) {
    final noteColor = post.noteColor != null
        ? Color(int.parse(post.noteColor!.replaceFirst('#', '0xFF')))
        : const Color(0xFFFFEB3B);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Note card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: noteColor,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(4, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post.isPinned)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(Icons.push_pin, size: 16, color: Colors.black54),
                          const SizedBox(width: 4),
                          Text(
                            'Pinned',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Text(
                    post.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  if (post.content != null && post.content!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      post.content!,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Metadata
            _MetadataSection(post: post),
          ],
        ),
      ),
    );
  }
}

class _ImageDetailContent extends StatelessWidget {
  final MessageBoardPost post;

  const _ImageDetailContent({required this.post});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.fileUrl != null)
            FileCarouselViewer(
              mediaItems: [
                FileCarouselItem.image(imageUrl: post.fileUrl!),
              ],
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (post.content != null && post.content!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    post.content!,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                      height: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                _MetadataSection(post: post),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentDetailContent extends StatelessWidget {
  final MessageBoardPost post;

  const _DocumentDetailContent({required this.post});

  @override
  Widget build(BuildContext context) {
    final isPdf = post.fileTypeLabel == 'PDF';
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.fileUrl != null)
            isPdf
                ? _buildPdfPreview(context, post.fileUrl!)
                : FileCarouselViewer(
                    showMediaTypeIcon: true,
                    mediaItems: [
                      FileCarouselItem.document(
                        fileUrl: post.fileUrl!,
                        title: post.fileName ?? 'Document',
                      ),
                    ],
                    onDocumentTap: (ctx, fileUrl, fileName) async {
                      final uri = Uri.tryParse(fileUrl);
                      if (uri != null) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                  ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (post.content != null && post.content!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    post.content!,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                      height: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                _MetadataSection(post: post),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfPreview(BuildContext context, String url) {
    // Mobile uses SfPdfViewer (wrapped in IgnorePointer); web uses a native
    // <iframe> with pointer-events: none. Either way the child swallows no
    // taps, so the GestureDetector below must use HitTestBehavior.opaque â€”
    // otherwise its default `deferToChild` behavior never receives the tap.
    final viewerHeight = MediaQuery.of(context).size.height * 0.55;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => pdf_viewer.PdfViewer(pdfUrl: url),
        ),
      ),
      child: SizedBox(
        height: viewerHeight,
        child: PdfPreviewBox(
          url: url,
          fallback: _PdfFallbackCard(post: post),
        ),
      ),
    );
  }
}

/// Shown when an inline PDF preview can't be rendered â€” offers a button to
/// open the document in the platform's native viewer instead.
class _PdfFallbackCard extends StatelessWidget {
  final MessageBoardPost post;

  const _PdfFallbackCard({required this.post});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade100),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.picture_as_pdf, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 12),
            Text(
              post.fileName ?? 'Document.pdf',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade800,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: post.fileUrl == null
                  ? null
                  : () {
                      final uri = Uri.tryParse(post.fileUrl!);
                      if (uri != null) {
                        launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPaletteScope.of(context).primary2,
                foregroundColor: Colors.black,
              ),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open PDF'),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoDetailContent extends StatelessWidget {
  final MessageBoardPost post;

  const _VideoDetailContent({required this.post});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.fileUrl != null)
            FileCarouselViewer(
              mediaItems: [
                FileCarouselItem.video(
                  videoUrl: post.fileUrl!,
                  thumbnailUrl: post.thumbnailUrl,
                ),
              ],
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (post.content != null && post.content!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    post.content!,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                      height: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                _MetadataSection(post: post),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkDetailContent extends StatelessWidget {
  final MessageBoardPost post;

  const _LinkDetailContent({required this.post});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Link card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppPaletteScope.of(context).primary2.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppPaletteScope.of(context)
                      .primary2
                      .withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.link,
                  size: 48,
                  color: AppPaletteScope.of(context).primary2,
                ),
                const SizedBox(height: 16),
                Text(
                  post.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (post.linkUrl != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    post.linkUrl!,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppPaletteScope.of(context).primary2,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _openLink(post.linkUrl),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open Link'),
                ),
              ],
            ),
          ),

          if (post.content != null && post.content!.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Description',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              post.content!,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
          ],

          const SizedBox(height: 24),
          _MetadataSection(post: post),
        ],
      ),
    );
  }

  void _openLink(String? url) async {
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _MetadataSection extends StatelessWidget {
  final MessageBoardPost post;

  const _MetadataSection({required this.post});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat.yMMMd().add_jm().format(post.createdAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppPaletteScope.of(context).primary2.withValues(alpha: 0.1),
              backgroundImage: post.createdByAvatarUrl != null
                  ? NetworkImage(post.createdByAvatarUrl!)
                  : null,
              child: post.createdByAvatarUrl == null
                  ? Text(
                      post.createdByName.isNotEmpty
                          ? post.createdByName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppPaletteScope.of(context).primary2,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.createdByName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (post.isPinned)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppPaletteScope.of(context).primary2.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.push_pin,
                      size: 14,
                      color: AppPaletteScope.of(context).primary2,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Pinned',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppPaletteScope.of(context).primary2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (post.teamNames.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: post.teamNames.map((name) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

