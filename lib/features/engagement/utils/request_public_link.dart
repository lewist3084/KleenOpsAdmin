// lib/features/engagement/utils/request_public_link.dart
//
// Helpers for generating shareable public request URLs/paths and QR payloads.

const String _kDefaultPublicBaseUrl = 'https://kleenops.web.app';

String _publicBaseUrl() {
  const envBase = String.fromEnvironment('PUBLIC_WEB_BASE_URL');
  if (envBase.trim().isNotEmpty) return envBase.trim();
  return _kDefaultPublicBaseUrl;
}

String buildRequestPublicPath({
  required String userId,
  required String requestId,
}) {
  return '/requests/public/$userId/$requestId';
}

String buildRequestPublicUrl({
  required String userId,
  required String requestId,
}) {
  final base = Uri.parse(_publicBaseUrl());
  final path = buildRequestPublicPath(userId: userId, requestId: requestId);
  final normalizedPath = path.startsWith('/') ? path : '/$path';
  return base.replace(path: normalizedPath).toString();
}

String buildRequestQrPayload({
  required String userId,
  required String requestId,
}) {
  return buildRequestPublicUrl(userId: userId, requestId: requestId);
}

String resolveRequestPublicUrl({
  required Map<String, dynamic> data,
  required String requestId,
  required String? userId,
}) {
  if (userId == null || userId.isEmpty) return '';
  final raw = data['publicShareUrl'];
  if (raw is String && raw.trim().isNotEmpty) {
    return raw.trim();
  }
  return buildRequestPublicUrl(userId: userId, requestId: requestId);
}
