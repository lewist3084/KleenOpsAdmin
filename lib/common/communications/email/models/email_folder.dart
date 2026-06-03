// lib/common/communications/email/models/email_folder.dart
// Ported from the kleenops app.

/// Represents an email folder/mailbox.
class EmailFolder {
  final String name;
  final String path;
  final int messageCount;
  final int unreadCount;
  final bool isSelectable;
  final bool hasChildren;
  final EmailFolderType type;

  const EmailFolder({
    required this.name,
    required this.path,
    this.messageCount = 0,
    this.unreadCount = 0,
    this.isSelectable = true,
    this.hasChildren = false,
    this.type = EmailFolderType.custom,
  });

  factory EmailFolder.fromMap(Map<String, dynamic> map) {
    final typeStr = (map['type'] as String?) ?? 'custom';
    final type = EmailFolderType.values.firstWhere(
      (t) => t.name == typeStr,
      orElse: () => EmailFolderType.custom,
    );

    return EmailFolder(
      name: (map['name'] as String?) ?? '',
      path: (map['path'] as String?) ?? '',
      messageCount: map['messageCount'] as int? ?? 0,
      unreadCount: map['unreadCount'] as int? ?? 0,
      isSelectable: map['isSelectable'] as bool? ?? true,
      hasChildren: map['hasChildren'] as bool? ?? false,
      type: type,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'path': path,
        'messageCount': messageCount,
        'unreadCount': unreadCount,
        'isSelectable': isSelectable,
        'hasChildren': hasChildren,
        'type': type.name,
      };

  EmailFolder copyWith({
    String? name,
    String? path,
    int? messageCount,
    int? unreadCount,
    bool? isSelectable,
    bool? hasChildren,
    EmailFolderType? type,
  }) {
    return EmailFolder(
      name: name ?? this.name,
      path: path ?? this.path,
      messageCount: messageCount ?? this.messageCount,
      unreadCount: unreadCount ?? this.unreadCount,
      isSelectable: isSelectable ?? this.isSelectable,
      hasChildren: hasChildren ?? this.hasChildren,
      type: type ?? this.type,
    );
  }

  /// Standard inbox folder.
  static const EmailFolder inbox = EmailFolder(
    name: 'Inbox',
    path: 'INBOX',
    type: EmailFolderType.inbox,
  );
}

/// Email folder types.
enum EmailFolderType {
  inbox,
  sent,
  drafts,
  trash,
  spam,
  archive,
  starred,
  important,
  custom,
}

/// Get display name for folder type.
extension EmailFolderTypeExtension on EmailFolderType {
  String get displayName {
    switch (this) {
      case EmailFolderType.inbox:
        return 'Inbox';
      case EmailFolderType.sent:
        return 'Sent';
      case EmailFolderType.drafts:
        return 'Drafts';
      case EmailFolderType.trash:
        return 'Trash';
      case EmailFolderType.spam:
        return 'Spam';
      case EmailFolderType.archive:
        return 'Archive';
      case EmailFolderType.starred:
        return 'Starred';
      case EmailFolderType.important:
        return 'Important';
      case EmailFolderType.custom:
        return 'Folder';
    }
  }

  String get iconName {
    switch (this) {
      case EmailFolderType.inbox:
        return 'inbox';
      case EmailFolderType.sent:
        return 'send';
      case EmailFolderType.drafts:
        return 'drafts';
      case EmailFolderType.trash:
        return 'delete';
      case EmailFolderType.spam:
        return 'report';
      case EmailFolderType.archive:
        return 'archive';
      case EmailFolderType.starred:
        return 'star';
      case EmailFolderType.important:
        return 'label_important';
      case EmailFolderType.custom:
        return 'folder';
    }
  }
}
