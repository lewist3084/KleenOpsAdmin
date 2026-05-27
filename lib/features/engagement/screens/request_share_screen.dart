// lib/features/requests/screens/request_share_screen.dart

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:qr_plugin/qr_plugin.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/services/ai/ai_context_service.dart';
import 'package:kleenops_admin/widgets/ai/ai_screen_context.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/lists/standardView.dart';
import 'package:shared_widgets/theme/app_palette.dart';
import 'package:kleenops_admin/widgets/layout/bookended_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';

class RequestShareScreen extends StatefulWidget {
  const RequestShareScreen({
    super.key,
    required this.requestName,
    required this.shareUrl,
  });

  final String requestName;
  final String shareUrl;

  @override
  State<RequestShareScreen> createState() => _RequestShareScreenState();
}

class _RequestShareScreenState extends State<RequestShareScreen> {
  late final Future<Uint8List?> _qrBytesFuture;
  File? _qrFile;

  @override
  void initState() {
    super.initState();
    _qrBytesFuture = _buildQrBytes();
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.requestName.trim().isEmpty ? 'Share Request' : widget.requestName;
    final shareUrl = widget.shareUrl.trim();
    final hasShareUrl = shareUrl.isNotEmpty;
    const bottomInset = 16.0;

    final content = StandardView<Widget>(
      items: [
        if (!hasShareUrl)
          ContainerActionWidget(
            title: 'Share',
            actionText: '',
            content: const _ShareMessage(
              icon: Icons.link_off,
              message:
                  'Share link not available for this request. Save the request again to refresh share data.',
            ),
          )
        else ...[
          _buildLinkBlock(context, shareUrl),
          const SizedBox(height: 12),
          _buildQrBlock(context, shareUrl),
        ],
        const SizedBox(height: 16),
      ],
      groupBy: (_) => null,
      itemBuilder: (child) => child,
      disableGrouping: true,
      padding: EdgeInsets.only(bottom: bottomInset),
      shrinkWrap: false,
      physics: const ClampingScrollPhysics(),
      showDividersInFlat: false,
    );

    return Scaffold(
      appBar: null,
      body: AiScreenContext(
        context: AiContextPresets.engagementSurveys(),
        child: BookendedCanvas(child: content),
      ),
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final controller = ref.read(aiCanvasControllerProvider);
          final menuSections = MenuDrawerSections(
            actions: [
              ContentMenuItem(
                icon: Icons.home_outlined,
                label: 'Engagement Home',
                onTap: () => context.push(AppRoutePaths.engagementHome),
              ),
              ContentMenuItem(
                icon: Icons.receipt_long_outlined,
                label: 'Reports',
                onTap: () => context.push(AppRoutePaths.engagementReports),
              ),
              ContentMenuItem(
                icon: Icons.bar_chart_outlined,
                label: 'Stats',
                onTap: () => context.push(AppRoutePaths.engagementStats),
              ),
            ],
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DetailsAppBar(
                title: title,
                onAiPressed: controller.toggle,
                menuSections: menuSections,
              ),
              const HomeNavBarAdapter(highlightSelected: false),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLinkBlock(BuildContext context, String shareUrl) {
    return ContainerActionWidget(
      title: 'Link',
      actionText: '',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            shareUrl,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ShareActionButton(
                icon: Icons.copy,
                label: 'Copy',
                onPressed: () => _copyText(shareUrl),
              ),
              _ShareActionButton(
                icon: Icons.open_in_new,
                label: 'Open',
                onPressed: () => _openLink(shareUrl),
              ),
              _ShareActionButton(
                icon: Icons.sms_outlined,
                label: 'Text',
                onPressed: () => _textLink(shareUrl),
              ),
              _ShareActionButton(
                icon: Icons.email_outlined,
                label: 'Email',
                onPressed: () => _emailLink(shareUrl),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQrBlock(BuildContext context, String shareUrl) {
    return ContainerActionWidget(
      title: 'QR Code',
      actionText: '',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: QrImageView(
              data: shareUrl,
              size: 200,
              backgroundColor: Colors.white,
              errorStateBuilder: (ctx, err) => const Text(
                'QR unavailable',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ShareActionButton(
                icon: Icons.copy,
                label: 'Copy Image',
                onPressed: _copyQrImagePath,
              ),
              _ShareActionButton(
                icon: Icons.sms_outlined,
                label: 'Text Image',
                onPressed: () => _shareQrImage(subject: 'Request QR'),
              ),
              _ShareActionButton(
                icon: Icons.email_outlined,
                label: 'Email Image',
                onPressed: () => _shareQrImage(subject: 'Request QR'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<Uint8List?> _buildQrBytes() async {
    final data = widget.shareUrl.trim();
    if (data.isEmpty) return null;
    final painter = QrPainter(
      data: data,
      version: QrVersions.auto,
      gapless: true,
      color: Colors.black,
      emptyColor: Colors.white,
    );
    final imageData = await painter.toImageData(512);
    return imageData?.buffer.asUint8List();
  }

  Future<File?> _ensureQrFile() async {
    if (_qrFile != null) return _qrFile;
    final bytes = await _qrBytesFuture;
    if (bytes == null) return null;
    final dir = await getTemporaryDirectory();
    final filename = '${_safeFilename(widget.requestName)}_qr.png';
    final file = File(p.join(dir.path, filename));
    await file.writeAsBytes(bytes, flush: true);
    _qrFile = file;
    return file;
  }

  String _safeFilename(String raw) {
    final trimmed = raw.trim();
    final base = trimmed.isEmpty ? 'request' : trimmed;
    final sanitized = base.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    return sanitized.isEmpty ? 'request' : sanitized;
  }

  Future<void> _copyText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    _showSnack('Copied to clipboard.');
  }

  Future<void> _copyQrImagePath() async {
    final file = await _ensureQrFile();
    if (file == null) {
      _showSnack('QR image unavailable.');
      return;
    }
    await Clipboard.setData(ClipboardData(text: file.path));
    _showSnack('QR image saved. File path copied.');
  }

  Future<void> _openLink(String shareUrl) async {
    final uri = Uri.tryParse(shareUrl);
    if (uri == null) {
      _showSnack('Invalid share link.');
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      _showSnack('Unable to open link.');
    }
  }

  Future<void> _textLink(String shareUrl) async {
    final uri = Uri(
      scheme: 'sms',
      queryParameters: {'body': shareUrl},
    );
    final ok = await launchUrl(uri);
    if (!ok) {
      _showSnack('Unable to open SMS.');
    }
  }

  Future<void> _emailLink(String shareUrl) async {
    final uri = Uri(
      scheme: 'mailto',
      queryParameters: {
        'subject': 'Request link',
        'body': shareUrl,
      },
    );
    final ok = await launchUrl(uri);
    if (!ok) {
      _showSnack('Unable to open email.');
    }
  }

  Future<void> _shareQrImage({String? subject}) async {
    final file = await _ensureQrFile();
    if (file == null) {
      _showSnack('QR image unavailable.');
      return;
    }
    final shareText =
        'Scan this QR code or use this link: ${widget.shareUrl.trim()}';
    try {
      await Share.shareXFiles(
        [XFile(file.path)],
        text: shareText,
        subject: subject,
      );
    } catch (_) {
      _showSnack('Unable to share QR image.');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    SnackbarService.instance.showSnackBar(
      SnackBar(duration: const Duration(seconds: 5), content: Text(message)),
    );
  }
}

class _ShareActionButton extends StatelessWidget {
  const _ShareActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

class _ShareMessage extends StatelessWidget {
  const _ShareMessage({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: AppPaletteScope.of(context).primary2),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
