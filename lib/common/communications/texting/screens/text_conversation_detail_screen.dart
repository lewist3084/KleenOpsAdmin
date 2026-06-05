// lib/common/communications/texting/screens/text_conversation_detail_screen.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:kleenops_admin/app/shared_widgets/messaging/sms_control_strip_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/services/ai/ai_context_service.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:shared_widgets/theme/app_palette.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:shared_widgets/labels/text_info_checkbox.dart';
import 'package:shared_widgets/tiles/ai_canvas_tile.dart';
import 'package:shared_widgets/viewers/image_viewer.dart';
import 'package:shared_widgets/viewers/pdf_viewer.dart';
import '../models/text_conversation.dart';
import '../models/text_message.dart';
import '../services/texting_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../utils/text_attachment_actions.dart';
import '../services/external_sms_service.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';

class TextConversationDetailScreen extends ConsumerStatefulWidget {
  final DocumentReference<Map<String, dynamic>> conversationRef;

  const TextConversationDetailScreen({
    super.key,
    required this.conversationRef,
  });

  @override
  ConsumerState<TextConversationDetailScreen> createState() =>
      _TextConversationDetailScreenState();
}

class _TextConversationDetailScreenState
    extends ConsumerState<TextConversationDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _sending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final companyAsync = ref.watch(companyIdProvider);
    final userDocAsync = ref.watch(userDocumentProvider);

    return companyAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Error: $e')),
      ),
      data: (companyRef) {
        if (companyRef == null) {
          return const Scaffold(
            body: Center(child: Text('No company selected.')),
          );
        }

        return userDocAsync.when(
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Scaffold(
            body: Center(child: Text('Error: $e')),
          ),
          data: (userData) {
            final memberRef = userData['memberRef']
                as DocumentReference<Map<String, dynamic>>?;
            final memberName = (userData['name'] as String?) ??
                (userData['displayName'] as String?) ??
                '';

            if (memberRef == null) {
              return const Scaffold(
                body: Center(child: Text('No member record.')),
              );
            }

            final service = TextingService(
              companyRef: companyRef,
              memberRef: memberRef,
              memberName: memberName,
            );

            return _buildContent(
              service,
              memberRef.id,
              memberName,
              companyRef.id,
            );
          },
        );
      },
    );
  }

  Widget _buildContent(
    TextingService service,
    String currentMemberId,
    String memberName,
    String companyId,
  ) {
    final controller = ref.read(aiCanvasControllerProvider);
    final menuSections = MenuDrawerSections(
      actions: const <ContentMenuItem>[],
      resources: const <ContentMenuItem>[],
    );

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: widget.conversationRef.snapshots(),
      builder: (context, convSnapshot) {
        if (!convSnapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final conversation = TextConversation.fromFirestore(convSnapshot.data!);
        final title = conversation.getDisplayTitle(currentMemberId);
        final rawData = convSnapshot.data!.data() ?? const {};
        final typingMap = rawData['typing'] as Map<String, dynamic>?;
        final namesByUid = <String, String>{
          for (var i = 0;
              i < conversation.participantRefs.length &&
                  i < conversation.participantNames.length;
              i++)
            conversation.participantRefs[i].id: conversation.participantNames[i],
        };

        final isCreator = conversation.createdBy?.id == currentMemberId;
        final showDirectResponseBanner = conversation.directResponseMode == true &&
            conversation.createdBy != null &&
            !isCreator;
        final creatorName = conversation.createdBy == null
            ? null
            : namesByUid[conversation.createdBy!.id];

        return Scaffold(
          appBar: null,
          body: SafeArea(
            child: Column(
              children: [
                _OffDutyBanner(
                  participantRefs: conversation.participantRefs,
                  participantNames: conversation.participantNames,
                  currentMemberId: currentMemberId,
                ),
                if (showDirectResponseBanner)
                  _DirectResponseBanner(creatorName: creatorName),
                Expanded(
                  child: _MessagesList(
                    service: service,
                    conversation: conversation,
                    currentMemberId: currentMemberId,
                    scrollController: _scrollController,
                    onMessagesLoaded: _scrollToBottom,
                  ),
                ),
                _TypingIndicator(
                  typingMap: typingMap,
                  namesByUid: namesByUid,
                  currentMemberId: currentMemberId,
                ),
                SmsControlStrip(
                  controller: _messageController,
                  sending: _sending,
                  onSend: () => _sendMessage(service, conversation),
                  onAttachmentTap: () => _showAttachmentOptions(
                    context,
                    service: service,
                    conversation: conversation,
                    companyId: companyId,
                    memberName: memberName,
                  ),
                  onTypingChanged: (isTyping) =>
                      service.setTyping(conversation.id, isTyping),
                ),
              ],
            ),
          ),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DetailsAppBar(
                title: title,
                onAiPressed: controller.toggle,
                menuSections: menuSections,
                rightIcon1:
                    conversation.isExternal ? Icons.edit_outlined : null,
                rightAction1: conversation.isExternal
                    ? () => _renameConversation(conversation, title)
                    : null,
              ),
              const HomeNavBarAdapter(),
            ],
          ),
        );
      },
    );
  }

  void _showAttachmentOptions(
    BuildContext context, {
    required TextingService service,
    required TextConversation conversation,
    required String companyId,
    required String memberName,
  }) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Photo'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final attachment = await TextAttachmentActions.pickPhoto(
                  context,
                  ref,
                  companyId: companyId,
                  memberRef: service.memberRef,
                  memberName: memberName,
                );
                if (attachment != null) {
                  await _sendAttachment(service, conversation, attachment);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Video'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final attachment = await TextAttachmentActions.pickVideo(
                  context,
                  ref,
                  companyId: companyId,
                  memberRef: service.memberRef,
                  memberName: memberName,
                );
                if (attachment != null) {
                  await _sendAttachment(service, conversation, attachment);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: const Text('From device'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final attachment = await TextAttachmentActions.pickDocument(
                  context,
                  ref,
                  companyId: companyId,
                  memberRef: service.memberRef,
                  memberName: memberName,
                );
                if (attachment != null) {
                  await _sendAttachment(service, conversation, attachment);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: const Text('From my files'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final attachment =
                    await TextAttachmentActions.pickFromDrive(context);
                if (attachment != null) {
                  await _sendAttachment(service, conversation, attachment);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Send a message carrying [attachment]. Consumes the current text field as
  /// the caption when present; otherwise sends the attachment alone. Audience
  /// resolution matches [_sendMessage] — direct-response mode applies to
  /// captioned attachments exactly like a plain reply.
  Future<void> _sendAttachment(
    TextingService service,
    TextConversation conversation,
    TextMessageAttachment attachment,
  ) async {
    // External SMS: dispatch through the backend (Twilio) instead of a direct
    // Firestore write. The attachment is already uploaded to Storage.
    if (conversation.isExternal) {
      await _sendExternal(conversation, attachments: [attachment]);
      return;
    }

    final currentMemberId = service.memberRef.id;
    final text = _messageController.text.trim();

    bool? directResponseMode = conversation.directResponseMode;
    final isFirstSend = conversation.isGroup &&
        directResponseMode == null &&
        conversation.lastMessageAt == null;
    if (isFirstSend) {
      final picked = await _promptDirectResponseMode();
      if (picked == null) return;
      directResponseMode = picked;
      await service.setDirectResponseMode(conversation.id, picked);
    }

    final audience = conversation.participantRefs.map((r) => r.id).toList();
    List<String> audienceMemberIds = audience;
    bool isDirectResponse = false;
    final creatorId = conversation.createdBy?.id;
    if (directResponseMode == true &&
        creatorId != null &&
        creatorId != currentMemberId) {
      audienceMemberIds = [currentMemberId, creatorId];
      isDirectResponse = true;
    }

    setState(() => _sending = true);
    _messageController.clear();

    try {
      await service.sendMessage(
        conversationId: conversation.id,
        text: text,
        audienceMemberIds: audienceMemberIds,
        attachments: [attachment],
        isDirectResponse: isDirectResponse,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        SnackbarService.instance.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 5),
            content: Text('Failed to send attachment: $e'),
          ),
        );
        _messageController.text = text;
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _sendMessage(
      TextingService service, TextConversation conversation) async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // External SMS: dispatch through the backend (Twilio).
    if (conversation.isExternal) {
      await _sendExternal(conversation);
      return;
    }

    final currentMemberId = service.memberRef.id;

    // First-send dialog for group convos: ask whether replies should be
    // direct-response (private to the creator). Only ask once — once
    // directResponseMode is set on the doc, never re-prompt.
    bool? directResponseMode = conversation.directResponseMode;
    final isFirstSend = conversation.isGroup &&
        directResponseMode == null &&
        conversation.lastMessageAt == null;
    if (isFirstSend) {
      final picked = await _promptDirectResponseMode();
      if (picked == null) return;
      directResponseMode = picked;
      await service.setDirectResponseMode(conversation.id, picked);
    }

    // Every message carries its audience in `visibleToMemberIds`: a normal
    // send lists all participants; a non-creator reply in direct-response
    // mode is pinned to just the replier + the thread creator so the rest
    // of the group never sees it (preview, timeline, push and reads all
    // honour this list).
    final audience = conversation.participantRefs.map((r) => r.id).toList();
    List<String> audienceMemberIds = audience;
    bool isDirectResponse = false;
    final creatorId = conversation.createdBy?.id;
    if (directResponseMode == true &&
        creatorId != null &&
        creatorId != currentMemberId) {
      audienceMemberIds = [currentMemberId, creatorId];
      isDirectResponse = true;
    }

    setState(() => _sending = true);
    _messageController.clear();

    try {
      await service.sendMessage(
        conversationId: conversation.id,
        text: text,
        audienceMemberIds: audienceMemberIds,
        isDirectResponse: isDirectResponse,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        SnackbarService.instance.showSnackBar(
          SnackBar(duration: const Duration(seconds: 5), content: Text('Failed to send message: $e')),
        );
        _messageController.text = text;
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  /// Send an external SMS/MMS via the backend (Twilio). Consumes the text
  /// field as the message body / caption. Attachments are already uploaded to
  /// Storage, so we pass their URLs.
  Future<void> _sendExternal(
    TextConversation conversation, {
    List<TextMessageAttachment> attachments = const [],
  }) async {
    final text = _messageController.text.trim();
    if (text.isEmpty && attachments.isEmpty) return;
    final companyId = conversation.ref.parent.parent?.id;
    if (companyId == null) return;

    setState(() => _sending = true);
    _messageController.clear();
    try {
      await ExternalSmsService.instance.sendSms(
        companyId: companyId,
        conversationId: conversation.id,
        text: text,
        attachments: attachments,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        SnackbarService.instance.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 5),
            content: Text('Failed to send SMS: ${_friendlyError(e)}'),
          ),
        );
        _messageController.text = text;
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Rename an external conversation (the contact's display name). Persisted
  /// on the conversation doc's `title`.
  Future<void> _renameConversation(
    TextConversation conversation,
    String currentTitle,
  ) async {
    final controller = TextEditingController(text: currentTitle);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => DialogAction(
        title: 'Name this contact',
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Contact name'),
        ),
        cancelText: 'Cancel',
        onCancel: () => Navigator.of(ctx).pop(),
        actionText: 'Save',
        onAction: () => Navigator.of(ctx).pop(controller.text.trim()),
      ),
    );
    controller.dispose();
    if (newName == null || newName.isEmpty || newName == currentTitle) return;
    try {
      await conversation.ref.update({'title': newName});
    } catch (e) {
      if (mounted) {
        SnackbarService.instance.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 4),
            content: Text('Could not rename: $e'),
          ),
        );
      }
    }
  }

  String _friendlyError(Object e) {
    if (e is FirebaseFunctionsException && (e.message ?? '').isNotEmpty) {
      return e.message!;
    }
    return e.toString();
  }

  Future<bool?> _promptDirectResponseMode() async {
    bool checked = false;
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (innerContext, setLocal) {
            return DialogAction(
              title: 'Mass message',
              cancelText: 'Cancel',
              onCancel: () => Navigator.of(dialogContext).pop(null),
              actionText: 'Send',
              onAction: () => Navigator.of(dialogContext).pop(checked),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This is your first message to the group. '
                    'Choose how recipients should reply.',
                  ),
                  const SizedBox(height: 12),
                  TextInfoCheckbox(
                    leadingIcon: Icons.reply,
                    text: 'Direct response',
                    value: checked,
                    onChanged: (v) => setLocal(() => checked = v ?? false),
                    onInfoPressed: () {
                      SnackbarService.instance.showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Recipients see your message but their replies '
                            'only come to you — the rest of the group will '
                            'not see them.',
                          ),
                          duration: Duration(seconds: 5),
                        ),
                      );
                    },
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

class _MessagesList extends StatefulWidget {
  final TextingService service;
  final TextConversation conversation;
  final String currentMemberId;
  final ScrollController scrollController;
  final VoidCallback onMessagesLoaded;

  const _MessagesList({
    required this.service,
    required this.conversation,
    required this.currentMemberId,
    required this.scrollController,
    required this.onMessagesLoaded,
  });

  @override
  State<_MessagesList> createState() => _MessagesListState();
}

class _MessagesListState extends State<_MessagesList> {
  // Cached so the inner StreamBuilder doesn't re-subscribe (and flash a
  // loader) every time the parent rebuilds — e.g. typing-state pings on the
  // conversation doc fire roughly every 2s while the user dictates.
  late Stream<List<TextMessage>> _messagesStream;
  String? _lastMessageId;
  int _lastVisibleCount = 0;

  @override
  void initState() {
    super.initState();
    _messagesStream = widget.service.watchMessages(widget.conversation.id);
  }

  @override
  void didUpdateWidget(covariant _MessagesList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversation.id != widget.conversation.id ||
        oldWidget.service != widget.service) {
      _messagesStream = widget.service.watchMessages(widget.conversation.id);
      _lastMessageId = null;
      _lastVisibleCount = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TextMessage>>(
      stream: _messagesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allMessages = snapshot.data ?? const <TextMessage>[];
        final messages = allMessages.where((m) {
          final visible = m.visibleToMemberIds;
          if (visible == null || visible.isEmpty) return true;
          return visible.contains(widget.currentMemberId);
        }).toList();

        if (messages.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 12),
                Text(
                  'No messages yet',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Send a message to start the conversation',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          );
        }

        // Only scroll + mark-as-read when the visible message set actually
        // changes. Without this guard, every parent rebuild (e.g. a typing
        // ping written to the conversation doc) would re-fire animateTo
        // mid-flight and trigger another markMessagesAsRead batch write —
        // which is what was making the screen jump around during dictation.
        final latestId = messages.last.id;
        if (latestId != _lastMessageId ||
            messages.length != _lastVisibleCount) {
          _lastMessageId = latestId;
          _lastVisibleCount = messages.length;
          WidgetsBinding.instance
              .addPostFrameCallback((_) => widget.onMessagesLoaded());
          widget.service.markMessagesAsRead(widget.conversation.id);
        }

        return ListView.builder(
          controller: widget.scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final isCurrentUser =
                message.senderRef?.id == widget.currentMemberId;

            // Group by date
            Widget? dateHeader;
            if (index == 0 ||
                !_isSameDay(
                    messages[index - 1].createdAt, message.createdAt)) {
              dateHeader = _DateHeader(date: message.createdAt);
            }

            return Column(
              children: [
                if (dateHeader != null) dateHeader,
                _MessageBubble(
                  message: message,
                  isCurrentUser: isCurrentUser,
                  isLatest: index == messages.length - 1,
                  service: widget.service,
                  conversation: widget.conversation,
                ),
              ],
            );
          },
        );
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _DateHeader extends StatelessWidget {
  final DateTime date;

  const _DateHeader({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final diff = now.difference(date);

    String label;
    if (diff.inDays == 0) {
      label = 'Today';
    } else if (diff.inDays == 1) {
      label = 'Yesterday';
    } else if (diff.inDays < 7) {
      label = DateFormat.EEEE().format(date);
    } else {
      label = DateFormat.yMMMd().format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final TextMessage message;
  final bool isCurrentUser;
  final bool isLatest;
  final TextingService service;
  final TextConversation conversation;

  const _MessageBubble({
    required this.message,
    required this.isCurrentUser,
    required this.isLatest,
    required this.service,
    required this.conversation,
  });

  @override
  Widget build(BuildContext context) {
    final timeLabel = DateFormat.jm().format(message.createdAt);
    final timestampLabel =
        message.editedAt != null ? '$timeLabel · edited' : timeLabel;
    // Tapping your own message opens the editor.
    final canEdit = isCurrentUser && !message.isDeleted;

    // Image attachments render inline in the bubble; everything else stays a
    // tappable chip inside the tile.
    final images = message.attachments
        .where((a) =>
            a.type == TextMessageAttachmentType.image && a.url.isNotEmpty)
        .toList();
    final others = message.attachments
        .where((a) =>
            a.type != TextMessageAttachmentType.image || a.url.isEmpty)
        .toList();
    // Skip the bubble tile only for an image-only message (no caption / other
    // attachment) — then the image carries a trailing timestamp instead.
    final showTile =
        message.text.isNotEmpty || others.isNotEmpty || images.isEmpty;
    final bubbleWidth = MediaQuery.of(context).size.width * 0.75;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment:
            isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          for (final a in images)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _InlineImageAttachment(
                url: a.url,
                maxWidth: bubbleWidth,
                onTap: () => _openAttachment(context, a),
              ),
            ),
          if (showTile)
            AICanvasTile(
              message: message.text,
              role: isCurrentUser
                  ? AICanvasTileRole.user
                  : AICanvasTileRole.assistant,
              title: isCurrentUser ? null : message.senderName,
              timestamp: timestampLabel,
              showRoleBadge: false,
              onTap: canEdit ? () => _editMessage(context) : null,
              maxWidth: bubbleWidth,
              messageBuilder: (ctx, style) => _LinkifiedMessageText(
                text: message.text,
                style: style,
              ),
              attachments: others.map((a) {
                return AICanvasTileAttachment(
                  label: a.fileName ?? _getAttachmentTypeLabel(a.type),
                  onTap: () => _openAttachment(context, a),
                );
              }).toList(),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 4),
              child: Text(
                timestampLabel,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ),
        ],
      ),
    );
  }

  String _getAttachmentTypeLabel(TextMessageAttachmentType type) {
    switch (type) {
      case TextMessageAttachmentType.image:
        return 'Image';
      case TextMessageAttachmentType.video:
        return 'Video';
      case TextMessageAttachmentType.document:
        return 'Document';
      case TextMessageAttachmentType.audio:
        return 'Audio';
    }
  }

  Future<void> _openAttachment(
    BuildContext context,
    TextMessageAttachment attachment,
  ) async {
    final url = attachment.url;
    if (url.isEmpty) {
      SnackbarService.instance.showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 4),
          content: Text('This attachment has no content.'),
        ),
      );
      return;
    }
    final title = attachment.fileName ?? 'Attachment';
    final isPdf = _looksLikePdf(attachment);

    if (attachment.type == TextMessageAttachmentType.image) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              title: Text(title),
            ),
            body: ImageViewer(imageUrl: url),
          ),
        ),
      );
      return;
    }
    if (isPdf) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => PdfViewer(pdfUrl: url)),
      );
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !await canLaunchUrl(uri)) {
      SnackbarService.instance.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          content: Text('Could not open "$title".'),
        ),
      );
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  bool _looksLikePdf(TextMessageAttachment a) {
    final mime = a.mimeType?.toLowerCase();
    if (mime != null && mime.contains('pdf')) return true;
    final name = a.fileName?.toLowerCase() ?? '';
    return name.endsWith('.pdf');
  }

  /// Show an editor for the current member's own message and persist the
  /// change. Only the sender can edit (also enforced by the security rule).
  Future<void> _editMessage(BuildContext context) async {
    final controller = TextEditingController(text: message.text);
    final newText = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return DialogAction(
          title: 'Edit message',
          cancelText: 'Cancel',
          onCancel: () => Navigator.of(dialogContext).pop(),
          actionText: 'Save',
          onAction: () =>
              Navigator.of(dialogContext).pop(controller.text.trim()),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 1,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Edit your message',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.newline,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          ),
        );
      },
    );
    controller.dispose();

    // Cancelled, cleared, or unchanged — nothing to do.
    if (newText == null || newText.isEmpty || newText == message.text) return;

    // When editing the latest message, refresh the conversation-list preview
    // too. A direct-response reply keeps its generic placeholder so the
    // edited text never reaches the shared conversation doc.
    final visible = message.visibleToMemberIds;
    final isDirectResponse = visible != null &&
        visible.length < conversation.participantRefs.length;
    final previewText = isLatest
        ? (isDirectResponse ? 'Direct reply' : newText)
        : null;

    try {
      await service.editMessage(
        conversationId: conversation.id,
        messageId: message.id,
        newText: newText,
        previewText: previewText,
      );
    } catch (e) {
      if (context.mounted) {
        SnackbarService.instance.showSnackBar(
          SnackBar(duration: const Duration(seconds: 5), content: Text('Failed to edit message: $e')),
        );
      }
    }
  }
}

/// Inline image preview for an image attachment inside a message bubble.
/// Decodes from the download URL (works on web — Flutter decodes the bytes
/// regardless of Storage content-type) and opens the full-screen viewer on tap.
class _InlineImageAttachment extends StatelessWidget {
  const _InlineImageAttachment({
    required this.url,
    required this.maxWidth,
    required this.onTap,
  });

  final String url;
  final double maxWidth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: maxWidth, // keep previews roughly square-bounded
          ),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            loadingBuilder: (ctx, child, progress) {
              if (progress == null) return child;
              return Container(
                width: maxWidth,
                height: maxWidth * 0.6,
                color: Colors.grey.shade200,
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            },
            errorBuilder: (ctx, _, __) => Container(
              width: maxWidth,
              height: maxWidth * 0.4,
              color: Colors.grey.shade200,
              alignment: Alignment.center,
              child: Icon(Icons.broken_image_outlined,
                  color: Colors.grey.shade500),
            ),
          ),
        ),
      ),
    );
  }
}

class _DirectResponseBanner extends StatelessWidget {
  final String? creatorName;

  const _DirectResponseBanner({required this.creatorName});

  @override
  Widget build(BuildContext context) {
    final who = (creatorName == null || creatorName!.isEmpty)
        ? 'the sender'
        : creatorName!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppPaletteScope.of(context).primary2.withValues(alpha: 0.12),
      child: Row(
        children: [
          Icon(Icons.reply,
              size: 16, color: AppPaletteScope.of(context).primary2),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Your reply only goes to $who. Other recipients will not see it.',
              style: TextStyle(
                fontSize: 12,
                color: AppPaletteScope.of(context).primary2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  final Map<String, dynamic>? typingMap;
  final Map<String, String> namesByUid;
  final String currentMemberId;

  const _TypingIndicator({
    required this.typingMap,
    required this.namesByUid,
    required this.currentMemberId,
  });

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  static const Duration _freshness = Duration(seconds: 5);

  Timer? _expiryTimer;
  late final AnimationController _dotsController;

  @override
  void initState() {
    super.initState();
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _scheduleExpiry();
  }

  @override
  void didUpdateWidget(_TypingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleExpiry();
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    _dotsController.dispose();
    super.dispose();
  }

  // Re-evaluate when the freshest entry would expire so the indicator
  // disappears even if no further snapshots arrive (publisher crashed,
  // network dropped, etc.).
  void _scheduleExpiry() {
    _expiryTimer?.cancel();
    final entries = _freshEntries();
    if (entries.isEmpty) return;
    final now = DateTime.now();
    Duration soonest = _freshness;
    for (final ts in entries.values) {
      final remaining = _freshness - now.difference(ts);
      if (remaining < soonest) soonest = remaining;
    }
    if (soonest < const Duration(milliseconds: 250)) {
      soonest = const Duration(milliseconds: 250);
    }
    _expiryTimer = Timer(soonest, () {
      if (mounted) setState(() {});
    });
  }

  Map<String, DateTime> _freshEntries() {
    final map = widget.typingMap;
    if (map == null || map.isEmpty) return const {};
    final now = DateTime.now();
    final result = <String, DateTime>{};
    map.forEach((uid, value) {
      if (uid == widget.currentMemberId) return;
      if (value is! Timestamp) return;
      final ts = value.toDate();
      if (now.difference(ts) <= _freshness) {
        result[uid] = ts;
      }
    });
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final fresh = _freshEntries();
    if (fresh.isEmpty) return const SizedBox.shrink();

    final names = fresh.keys
        .map((uid) => widget.namesByUid[uid] ?? 'Someone')
        .toList();
    final String label;
    if (names.length == 1) {
      label = '${names.first} is typing';
    } else if (names.length == 2) {
      label = '${names[0]} and ${names[1]} are typing';
    } else {
      label = '${names.length} people are typing';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(width: 6),
          _AnimatedTypingDots(controller: _dotsController),
        ],
      ),
    );
  }
}

class _AnimatedTypingDots extends StatelessWidget {
  final AnimationController controller;
  const _AnimatedTypingDots({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (controller.value + i * 0.2) % 1.0;
            final raw = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
            final opacity = raw.clamp(0.25, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade600.withValues(alpha: opacity),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _OffDutyBanner extends StatefulWidget {
  final List<DocumentReference<Map<String, dynamic>>> participantRefs;
  final List<String> participantNames;
  final String currentMemberId;

  const _OffDutyBanner({
    required this.participantRefs,
    required this.participantNames,
    required this.currentMemberId,
  });

  @override
  State<_OffDutyBanner> createState() => _OffDutyBannerState();
}

class _OffDutyBannerState extends State<_OffDutyBanner> {
  final List<StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>> _subs = [];
  final Map<String, Map<String, dynamic>> _memberData = {};

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    super.dispose();
  }

  void _subscribe() {
    for (final ref in widget.participantRefs) {
      if (ref.id == widget.currentMemberId) continue;
      final sub = ref.snapshots().listen((snap) {
        if (!mounted) return;
        setState(() {
          _memberData[ref.id] = snap.data() ?? {};
        });
      });
      _subs.add(sub);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_memberData.isEmpty) return const SizedBox.shrink();

    final unreachableNames = <String>[];
    final reachableOffDutyNames = <String>[];
    int otherIndex = 0;
    for (int i = 0; i < widget.participantRefs.length; i++) {
      final ref = widget.participantRefs[i];
      if (ref.id == widget.currentMemberId) continue;
      final data = _memberData[ref.id];
      if (data == null) {
        otherIndex++;
        continue;
      }
      final clockedIn = data['clockedIn'] as bool? ?? false;
      final alertAfterHours = data['alertAfterHours'] as bool? ?? false;
      if (!clockedIn) {
        final first = (data['firstName'] as String?) ?? '';
        final last = (data['lastName'] as String?) ?? '';
        var name = '$first $last'.trim();
        if (name.isEmpty) {
          name = otherIndex < widget.participantNames.length
              ? widget.participantNames[otherIndex]
              : 'Recipient';
        }
        if (alertAfterHours) {
          reachableOffDutyNames.add(name);
        } else {
          unreachableNames.add(name);
        }
      }
      otherIndex++;
    }

    if (unreachableNames.isEmpty && reachableOffDutyNames.isEmpty) {
      return const SizedBox.shrink();
    }

    final messages = <String>[];
    if (unreachableNames.isNotEmpty) {
      messages.add(
        '${unreachableNames.join(", ")} '
        '${unreachableNames.length == 1 ? "is" : "are"} '
        'off duty. They will be notified when they clock in.',
      );
    }
    if (reachableOffDutyNames.isNotEmpty) {
      messages.add(
        '${reachableOffDutyNames.join(", ")} '
        '${reachableOffDutyNames.length == 1 ? "is" : "are"} '
        'off duty but still receiving notifications.',
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.orange.shade50,
      child: Row(
        children: [
          Icon(Icons.schedule, size: 16, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              messages.join(' '),
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders message text with auto-detected URLs as tappable hyperlinks and
/// a long-press gesture that copies the full message body to the clipboard.
class _LinkifiedMessageText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  const _LinkifiedMessageText({required this.text, this.style});

  @override
  State<_LinkifiedMessageText> createState() => _LinkifiedMessageTextState();
}

class _LinkifiedMessageTextState extends State<_LinkifiedMessageText> {
  // Match http(s) URLs and bare www.* URLs. We strip trailing punctuation
  // after matching so things like "see https://x.com." don't include the dot.
  static final RegExp _urlRegex = RegExp(
    r'(?:https?:\/\/|www\.)[^\s<>"\\]+',
    caseSensitive: false,
  );
  static const _trailingPunct = <String>{
    '.', ',', ')', ']', '!', '?', ';', ':', '\'', '"',
  };

  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  String _trimTrailing(String url) {
    var end = url.length;
    while (end > 0 && _trailingPunct.contains(url[end - 1])) {
      end--;
    }
    return url.substring(0, end);
  }

  Future<void> _openUrl(String url) async {
    final normalized = url.startsWith('http') ? url : 'https://$url';
    final uri = Uri.tryParse(normalized);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      SnackbarService.instance.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          content: Text('Could not open link: $e'),
        ),
      );
    }
  }

  Future<void> _copyAll() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (!mounted) return;
    SnackbarService.instance.showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 2),
        content: Text('Message copied'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();

    final baseStyle = widget.style;
    final linkStyle = (baseStyle ?? const TextStyle()).copyWith(
      color: Colors.blue.shade700,
      decoration: TextDecoration.underline,
      decorationColor: Colors.blue.shade700,
    );

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in _urlRegex.allMatches(widget.text)) {
      final rawUrl = match.group(0)!;
      final trimmed = _trimTrailing(rawUrl);
      if (trimmed.isEmpty) continue;

      final trailingLen = rawUrl.length - trimmed.length;
      final urlEnd = match.end - trailingLen;

      if (match.start > cursor) {
        spans.add(TextSpan(text: widget.text.substring(cursor, match.start)));
      }

      final recognizer = TapGestureRecognizer()..onTap = () => _openUrl(trimmed);
      _recognizers.add(recognizer);
      spans.add(TextSpan(
        text: trimmed,
        style: linkStyle,
        recognizer: recognizer,
      ));

      cursor = urlEnd;
    }
    if (cursor < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(cursor)));
    }

    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onLongPress: _copyAll,
      child: Text.rich(
        TextSpan(style: baseStyle, children: spans),
      ),
    );
  }
}


