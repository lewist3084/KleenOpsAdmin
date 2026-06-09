// lib/common/communications/email/screens/email_compose_screen.dart
// Ported from the kleenops app to mirror its look & workflow exactly. ADMIN
// ADAPTATIONS are backend-only: company resolved via mailboxCompanyRefProvider;
// snackbars via ScaffoldMessenger. The AI canvas chrome (AiScreenContext +
// BookendedCanvas) is a no-op stub in admin but keeps the identical
// bookend/home-nav-bar look, and the subject/body use the same AITextField.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/services/ai/ai_context_service.dart';
import 'package:kleenops_admin/services/ai_text_adapter.dart';
import 'package:kleenops_admin/widgets/ai/ai_screen_context.dart';
import 'package:kleenops_admin/widgets/layout/bookended_canvas.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:shared_widgets/fields/ai_text.dart' show StreamingSpeechFieldHeight;
import 'package:shared_widgets/theme/app_palette.dart';
import '../models/email_attachment.dart';
import '../models/email_message.dart';
import '../providers/email_providers.dart';
import '../widgets/compose_email_control_strip.dart';
import '../widgets/email_attachment_chip.dart';
import '../widgets/email_attachment_picker_sheet.dart';
import 'email_recipient_picker_screen.dart';

class EmailComposeScreen extends ConsumerStatefulWidget {
  final String? replyToId;
  final String? forwardId;
  final bool replyAll;
  final String? prefillTo;
  final String? prefillCc;
  final String? prefillBcc;
  final String? prefillSubject;
  final String? prefillBody;

  const EmailComposeScreen({
    super.key,
    this.replyToId,
    this.forwardId,
    this.replyAll = false,
    this.prefillTo,
    this.prefillCc,
    this.prefillBcc,
    this.prefillSubject,
    this.prefillBody,
  });

  @override
  ConsumerState<EmailComposeScreen> createState() => _EmailComposeScreenState();
}

class _EmailComposeScreenState extends ConsumerState<EmailComposeScreen> {
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();

  final List<String> _to = [];
  final List<String> _cc = [];
  final List<String> _bcc = [];
  final List<EmailAttachment> _attachments = [];

  static const int _kMaxAttachmentBytes = 25 * 1024 * 1024;

  EmailMessage? _originalEmail;
  String? _quotedOriginal;

  @override
  void initState() {
    super.initState();
    _loadOriginalEmail();
    _applyPrefillData();
  }

  void _applyPrefillData() {
    _to.addAll(_splitEmails(widget.prefillTo));
    _cc.addAll(_splitEmails(widget.prefillCc));
    _bcc.addAll(_splitEmails(widget.prefillBcc));
    if (widget.prefillSubject != null && widget.prefillSubject!.isNotEmpty) {
      _subjectController.text = widget.prefillSubject!;
    }
    if (widget.prefillBody != null && widget.prefillBody!.isNotEmpty) {
      _bodyController.text = widget.prefillBody!;
    }
  }

  List<String> _splitEmails(String? raw) {
    if (raw == null || raw.isEmpty) return const <String>[];
    return raw
        .split(RegExp(r'[,;]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<void> _loadOriginalEmail() async {
    final id = widget.replyToId ?? widget.forwardId;
    if (id == null) return;

    final email = await ref.read(emailByIdProvider(id).future);
    if (email == null || !mounted) return;

    setState(() {
      _originalEmail = email;

      if (widget.replyToId != null) {
        if (email.from.isNotEmpty) _to.add(email.from);
        if (widget.replyAll) {
          for (final addr in [...email.to, ...email.cc]) {
            if (addr != email.from && !_cc.contains(addr)) _cc.add(addr);
          }
        }
        _subjectController.text = email.subject.startsWith('Re:')
            ? email.subject
            : 'Re: ${email.subject}';
        _quotedOriginal = _buildReplyBody(email);
      } else if (widget.forwardId != null) {
        _subjectController.text = email.subject.startsWith('Fwd:')
            ? email.subject
            : 'Fwd: ${email.subject}';
        _quotedOriginal = _buildForwardBody(email);
      }
    });
  }

  String _buildReplyBody(EmailMessage email) {
    return '---------- Original Message ----------\n'
        'From: ${email.from}\n'
        'Date: ${email.receivedAt}\n'
        'Subject: ${email.subject}\n\n'
        '${email.bodyPlain}';
  }

  String _buildForwardBody(EmailMessage email) {
    return '---------- Forwarded Message ----------\n'
        'From: ${email.from}\n'
        'Date: ${email.receivedAt}\n'
        'Subject: ${email.subject}\n'
        'To: ${email.to.join(", ")}\n\n'
        '${email.bodyPlain}';
  }

  String _composeOutgoingBody() {
    final typed = _bodyController.text;
    if (_quotedOriginal == null) return typed;
    final separator = typed.isEmpty ? '' : '\n\n';
    return '$typed$separator$_quotedOriginal';
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  List<String> _listFor(EmailRecipientField field) {
    switch (field) {
      case EmailRecipientField.to:
        return _to;
      case EmailRecipientField.cc:
        return _cc;
      case EmailRecipientField.bcc:
        return _bcc;
    }
  }

  Future<void> _openPicker(EmailRecipientField field) async {
    final selected = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => EmailRecipientPickerScreen(
          field: field,
          initialEmails: List<String>.from(_listFor(field)),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      final list = _listFor(field);
      list
        ..clear()
        ..addAll(selected);
    });
  }

  void _removeEmail(EmailRecipientField field, String email) {
    setState(() => _listFor(field).remove(email));
  }

  void _sendEmail() {
    final messenger = ScaffoldMessenger.of(context);
    if (_to.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
            duration: Duration(seconds: 5),
            content: Text('Please enter at least one recipient')),
      );
      return;
    }

    final account = ref.read(currentEmailAccountProvider);
    final companyRef = ref.read(mailboxCompanyRefProvider);
    if (account == null || companyRef == null) {
      messenger.showSnackBar(
        const SnackBar(
            duration: Duration(seconds: 5),
            content: Text('No mailbox selected')),
      );
      return;
    }

    // Fire-and-forget: the `emailSend` callable can take several seconds, so we
    // kick off the send, optimistically close the composer, and only surface a
    // snackbar if it actually fails.
    ref
        .read(kleenopsEmailServiceProvider)
        .send(
          companyId: companyRef.id,
          fromAddress: account.emailAddress,
          fromName:
              account.displayName.isNotEmpty ? account.displayName : null,
          to: _to,
          cc: _cc.isNotEmpty ? _cc : null,
          bcc: _bcc.isNotEmpty ? _bcc : null,
          subject: _subjectController.text,
          bodyPlain: _composeOutgoingBody(),
          inReplyTo: _originalEmail?.messageId,
          attachments: _attachments.isEmpty
              ? null
              : _attachments.map((a) => a.toMap()).toList(),
        )
        .catchError((Object e) {
      messenger.showSnackBar(
        SnackBar(
            duration: const Duration(seconds: 6),
            content: Text('Failed to send email: $e')),
      );
      return <String, dynamic>{};
    });

    messenger.showSnackBar(
      const SnackBar(
          duration: Duration(seconds: 3), content: Text('Sending email…')),
    );
    Navigator.of(context).pop();
  }

  void _discardDraft() {
    final empty = _to.isEmpty &&
        _cc.isEmpty &&
        _bcc.isEmpty &&
        _attachments.isEmpty &&
        _subjectController.text.isEmpty &&
        _bodyController.text.isEmpty &&
        _quotedOriginal == null;
    if (empty) {
      Navigator.of(context).pop();
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => DialogAction(
        title: 'Discard Draft',
        content: const Text('Are you sure you want to discard this draft?'),
        cancelText: 'Cancel',
        onCancel: () => Navigator.of(ctx).pop(),
        actionText: 'Discard',
        onAction: () {
          Navigator.of(ctx).pop();
          Navigator.of(context).pop();
        },
        actionButtonColor: Colors.red[600],
        buttonTextColor: Colors.white,
      ),
    );
  }

  int get _attachmentBytes => _attachments.fold<int>(
        0,
        (acc, a) => acc + (a.sizeBytes ?? 0),
      );

  Future<void> _pickAttachment() async {
    final messenger = ScaffoldMessenger.of(context);
    final companyRef = ref.read(mailboxCompanyRefProvider);
    if (companyRef == null) {
      messenger.showSnackBar(
        const SnackBar(
            duration: Duration(seconds: 5),
            content: Text('No company selected.')),
      );
      return;
    }
    final userRef = ref.read(userDocRefProvider);
    final memberRef = ref.read(mailboxMemberRefProvider).value;

    final added = await showEmailAttachmentPickerSheet(
      context,
      companyRef: companyRef,
      userRef: userRef,
      memberRef: memberRef,
      maxTotalBytes: _kMaxAttachmentBytes,
      currentTotalBytes: _attachmentBytes,
    );
    if (added == null || added.isEmpty || !mounted) return;

    setState(() {
      for (final att in added) {
        if (_attachments.any((existing) => existing.id == att.id)) continue;
        _attachments.add(att);
      }
    });
  }

  void _removeAttachment(EmailAttachment attachment) {
    setState(() {
      _attachments.removeWhere((a) => a.id == attachment.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(currentEmailAccountProvider);
    final controller = ref.read(aiCanvasControllerProvider);

    final title = widget.replyToId != null
        ? 'Reply'
        : widget.forwardId != null
            ? 'Forward'
            : 'Compose';

    return Scaffold(
      body: AiScreenContext(
        context: AiContextPresets.emailCompose(),
        child: BookendedCanvas(
          child: Column(
            children: [
              if (account != null)
                _HeaderRow(
                  label: 'From',
                  child: Text(
                    '${account.displayName} <${account.emailAddress}>',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              if (_to.isNotEmpty)
                _RecipientRow(
                  label: 'To',
                  emails: _to,
                  onRemove: (e) => _removeEmail(EmailRecipientField.to, e),
                  onTap: () => _openPicker(EmailRecipientField.to),
                ),
              if (_cc.isNotEmpty)
                _RecipientRow(
                  label: 'Cc',
                  emails: _cc,
                  onRemove: (e) => _removeEmail(EmailRecipientField.cc, e),
                  onTap: () => _openPicker(EmailRecipientField.cc),
                ),
              if (_bcc.isNotEmpty)
                _RecipientRow(
                  label: 'Bcc',
                  emails: _bcc,
                  onRemove: (e) => _removeEmail(EmailRecipientField.bcc, e),
                  onTap: () => _openPicker(EmailRecipientField.bcc),
                ),
              if (widget.replyToId != null)
                _HeaderRow(
                  label: 'Subject',
                  child: Text(
                    _subjectController.text,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: AITextField(
                    labelText: 'Subject',
                    controller: _subjectController,
                    height: StreamingSpeechFieldHeight.singleLine,
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    children: [
                      Expanded(
                        child: AITextField(
                          labelText: 'Compose email',
                          controller: _bodyController,
                        ),
                      ),
                      if (_quotedOriginal != null)
                        _QuotedOriginalBlock(text: _quotedOriginal!),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_attachments.isNotEmpty)
            _AttachmentsBar(
              attachments: _attachments,
              onRemove: _removeAttachment,
            ),
          ComposeEmailControlStrip(
            onTapField: _openPicker,
            onClose: _discardDraft,
            onAttach: _pickAttachment,
            onSend: _sendEmail,
          ),
          DetailsAppBar(
            title: title,
            onAiPressed: controller.toggle,
          ),
          const HomeNavBarAdapter(),
        ],
      ),
    );
  }
}

class _AttachmentsBar extends StatelessWidget {
  const _AttachmentsBar({required this.attachments, required this.onRemove});

  final List<EmailAttachment> attachments;
  final ValueChanged<EmailAttachment> onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteScope.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: attachments
            .map(
              (att) => Stack(
                clipBehavior: Clip.none,
                children: [
                  EmailAttachmentChip(attachment: att),
                  Positioned(
                    top: -6,
                    right: -6,
                    child: Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => onRemove(att),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(
                            Icons.close,
                            size: 14,
                            color: palette.primary2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _QuotedOriginalBlock extends StatelessWidget {
  const _QuotedOriginalBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 220),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          left: BorderSide(color: Colors.grey.shade400, width: 3),
          top: BorderSide(color: Colors.grey.shade300),
          right: BorderSide(color: Colors.grey.shade300),
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Scrollbar(
        child: SingleChildScrollView(
          child: SelectableText(
            text,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _RecipientRow extends StatelessWidget {
  const _RecipientRow({
    required this.label,
    required this.emails,
    required this.onRemove,
    required this.onTap,
  });

  final String label;
  final List<String> emails;
  final ValueChanged<String> onRemove;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteScope.of(context);
    final accent = palette.primary2;

    return _HeaderRow(
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: emails
                .map(
                  (e) => Chip(
                    label: Text(
                      e,
                      style: TextStyle(fontSize: 12, color: accent),
                    ),
                    backgroundColor: Colors.transparent,
                    side: BorderSide(color: accent, width: 1),
                    deleteIcon: Icon(Icons.close, size: 16, color: accent),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onDeleted: () => onRemove(e),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}
