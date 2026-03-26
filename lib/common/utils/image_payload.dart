const String kImageRoleSource = 'source';
const String kImageRoleAnalysis = 'analysis';
const String kImageRolePreview = 'preview';
const String kImageRoleThumb = 'thumb';

String _normalizeImageRole(Object? value) {
  if (value is! String) return '';
  return value.trim().toLowerCase();
}

String? _extractImageUrl(Object? item) {
  if (item is Map<String, dynamic>) {
    final candidate = item['url'] ??
        item['downloadUrl'] ??
        item['downloadURL'] ??
        item['imageUrl'] ??
        item['uri'] ??
        item['storagePath'] ??
        item['path'];
    if (candidate is String) {
      final trimmed = candidate.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
  } else if (item is String) {
    final trimmed = item.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return null;
}

bool _entryIsMaster(Object? item) {
  if (item is! Map) return false;
  final masterFlag = item['isMaster'] ??
      item['master'] ??
      item['primary'] ??
      item['isPrimary'];
  return masterFlag is bool && masterFlag;
}

int? _entryOrder(Object? item) {
  if (item is! Map) return null;
  final ord = item['order'];
  if (ord is int) return ord;
  if (ord is num) return ord.toInt();
  return null;
}

Map<String, dynamic>? imageEntryForRole(
  dynamic rawImages,
  List<String> roles,
) {
  if (rawImages is! Iterable || roles.isEmpty) return null;
  final roleSet = roles.map((r) => r.toLowerCase()).toSet();
  Map<String, dynamic>? best;
  bool bestIsMaster = false;
  int bestOrder = 1 << 30;

  for (final item in rawImages) {
    if (item is! Map<String, dynamic>) continue;
    final role = _normalizeImageRole(item['role']);
    if (!roleSet.contains(role)) continue;
    final url = _extractImageUrl(item);
    if (url == null) continue;
    final isMaster = _entryIsMaster(item);
    final order = _entryOrder(item) ?? 1 << 30;
    if (best == null ||
        (isMaster && !bestIsMaster) ||
        (isMaster == bestIsMaster && order < bestOrder)) {
      best = item;
      bestIsMaster = isMaster;
      bestOrder = order;
    }
  }
  return best;
}

String? imageUrlForRole(
  dynamic rawImages, {
  required List<String> roles,
  String? fallback,
}) {
  final entry = imageEntryForRole(rawImages, roles);
  final url = entry != null ? _extractImageUrl(entry) : null;
  if (url != null && url.isNotEmpty) return url;
  return primaryImageUrl(rawImages, fallback: fallback);
}

List<Map<String, dynamic>> imageEntriesForRoles(
  dynamic rawImages,
  List<String> roles, {
  bool includeUnlabeled = false,
}) {
  if (rawImages is! Iterable) return const [];
  final roleSet = roles.map((r) => r.toLowerCase()).toSet();
  final filtered = <Map<String, dynamic>>[];
  for (final item in rawImages) {
    if (item is! Map<String, dynamic>) continue;
    final role = _normalizeImageRole(item['role']);
    if (roleSet.contains(role) || (includeUnlabeled && role.isEmpty)) {
      filtered.add(Map<String, dynamic>.from(item));
    }
  }
  filtered.sort((a, b) {
    final aOrder = _entryOrder(a) ?? 0;
    final bOrder = _entryOrder(b) ?? 0;
    return aOrder.compareTo(bOrder);
  });
  return filtered;
}

String? primaryImageUrl(
  dynamic rawImages, {
  String? fallback,
}) {
  String? firstUrl;

  if (rawImages is Iterable) {
    for (final item in rawImages) {
      final url = _extractImageUrl(item);
      if (url == null || url.isEmpty) {
        continue;
      }

      firstUrl ??= url;

      if (_entryIsMaster(item)) {
        return url;
      }
      final order = _entryOrder(item);
      if (order == 0) {
        return url;
      }
    }
  }

  final trimmedFallback = fallback?.trim();
  if (trimmedFallback != null && trimmedFallback.isNotEmpty) {
    return trimmedFallback;
  }

  return firstUrl;
}

List<String> galleryImageUrls(
  dynamic rawImages, {
  Iterable<String?> fallbacks = const [],
}) {
  final entries = <_ImagePayloadEntry>[];
  var fallbackOrder = 0;

  void addEntry({
    required String url,
    int? order,
    bool isMaster = false,
  }) {
    entries.add(
      _ImagePayloadEntry(
        url: url,
        order: order ?? fallbackOrder,
        isMaster: isMaster,
      ),
    );
    final nextBase = order ?? fallbackOrder;
    fallbackOrder = nextBase + 1;
  }

  if (rawImages is Iterable) {
    for (final item in rawImages) {
      String? url;
      bool isMaster = false;
      int? order;

      if (item is Map<String, dynamic>) {
        url = _extractImageUrl(item);
        final masterFlag =
            item['isMaster'] ?? item['master'] ?? item['primary'] ?? item['isPrimary'];
        if (masterFlag is bool && masterFlag) {
          isMaster = true;
        }
        final ord = item['order'];
        if (ord is num) {
          order = ord.toInt();
        }
      } else if (item is String) {
        final trimmed = item.trim();
        if (trimmed.isNotEmpty) {
          url = trimmed;
          order = fallbackOrder;
          isMaster = fallbackOrder == 0;
        }
      }

      if (url != null) {
        addEntry(url: url, order: order, isMaster: isMaster);
      }
    }
  }

  entries.sort((a, b) => a.order.compareTo(b.order));

  if (entries.isNotEmpty) {
    final masterIndex = entries.indexWhere((e) => e.isMaster);
    if (masterIndex > 0) {
      final master = entries.removeAt(masterIndex);
      entries.insert(0, master.copyWith(order: 0, isMaster: true));
    } else if (masterIndex == -1) {
      entries[0] = entries[0].copyWith(order: 0, isMaster: true);
    } else {
      entries[0] = entries[0].copyWith(order: 0, isMaster: true);
    }
  }

  final urls = <String>[];
  for (final entry in entries) {
    if (!urls.contains(entry.url)) {
      urls.add(entry.url);
    }
  }

  for (final fallback in fallbacks) {
    final trimmed = fallback?.trim();
    if (trimmed == null || trimmed.isEmpty) continue;
    if (!urls.contains(trimmed)) {
      urls.add(trimmed);
    }
  }

  return urls;
}

List<Map<String, dynamic>> buildSingleImageGallery(String? url) {
  final trimmed = url?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return const <Map<String, dynamic>>[];
  }
  return [
    {
      'url': trimmed,
      'isMaster': true,
      'order': 0,
    },
  ];
}

class _ImagePayloadEntry {
  const _ImagePayloadEntry({
    required this.url,
    required this.order,
    required this.isMaster,
  });

  final String url;
  final int order;
  final bool isMaster;

  _ImagePayloadEntry copyWith({
    String? url,
    int? order,
    bool? isMaster,
  }) {
    return _ImagePayloadEntry(
      url: url ?? this.url,
      order: order ?? this.order,
      isMaster: isMaster ?? this.isMaster,
    );
  }
}

List<Map<String, dynamic>> canonicalImageGallery(
  List<Map<String, dynamic>> maps,
) {
  final copy = <Map<String, dynamic>>[];
  final seen = <String>{};

  for (var i = 0; i < maps.length; i++) {
    final raw = maps[i];
    final trimmed = _extractImageUrl(raw);
    if (trimmed == null || trimmed.isEmpty) continue;
    if (seen.contains(trimmed)) continue;
    seen.add(trimmed);

    copy.add({
      'url': trimmed,
      'isMaster': raw['isMaster'] == true ||
          raw['master'] == true ||
          raw['primary'] == true ||
          raw['isPrimary'] == true ||
          (raw['order'] is num && (raw['order'] as num).toInt() == 0),
      'order': raw['order'] is num ? (raw['order'] as num).toInt() : copy.length,
      if (raw['caption'] is String && (raw['caption'] as String).trim().isNotEmpty)
        'caption': (raw['caption'] as String).trim(),
      if (raw['altText'] is String && (raw['altText'] as String).trim().isNotEmpty)
        'altText': (raw['altText'] as String).trim(),
    });
  }

  if (copy.isEmpty) return copy;

  copy.sort((a, b) => (a['order'] as int?)?.compareTo((b['order'] as int?) ?? 0) ?? 0);
  for (var i = 0; i < copy.length; i++) {
    copy[i]['order'] = i;
    copy[i]['isMaster'] = i == 0;
  }
  return copy;
}
