// lib/common/communications/email/models/email_thread.dart
// Ported from the kleenops app — identical threading semantics.

import 'email_message.dart';

/// A conversation thread: all emails that share a normalized subject, grouped
/// so the inbox can collapse a long "Re: Re: Re:" chain into a single
/// expandable tile.
class EmailThread {
  /// Member emails, newest-first (matches the inbox/sent query ordering).
  final List<EmailMessage> emails;

  /// Stable key for this thread within a list (used for ValueKey + dedupe).
  final String key;

  const EmailThread({required this.emails, required this.key});

  /// The most recent email in the conversation.
  EmailMessage get latest => emails.first;

  /// The first email in the conversation (oldest).
  EmailMessage get root => emails.last;

  int get count => emails.length;

  bool get isSingle => emails.length == 1;

  bool get hasUnread => emails.any((e) => !e.isRead);

  bool get hasAction => emails.any((e) => e.emailHasActionItem);

  /// Highest junk confidence across the thread (null if none scored).
  double? get junkConfidence {
    double? max;
    for (final e in emails) {
      final c = e.junkConfidence;
      if (c != null && (max == null || c > max)) max = c;
    }
    return max;
  }

  bool get hasAttachments => emails.any((e) => e.hasAttachments);

  /// Subject with leading Re:/Fwd: prefixes stripped, original casing kept.
  String get subjectClean => stripSubjectPrefixes(latest.subject);

  /// Emails ordered oldest → newest, for reading the conversation top-down.
  List<EmailMessage> get chronological =>
      emails.reversed.toList(growable: false);

  /// Distinct sender display names across the thread, most-recent first.
  List<String> get senderNames {
    final seen = <String>{};
    final names = <String>[];
    for (final e in emails) {
      final name = e.senderDisplayName;
      if (seen.add(name.toLowerCase())) names.add(name);
    }
    return names;
  }

  /// Distinct participant email addresses (from + to of every message),
  /// most-recent first — used for the contact footer.
  List<String> get participantAddresses {
    final seen = <String>{};
    final addrs = <String>[];
    void add(String a) {
      final t = a.trim();
      if (t.isEmpty) return;
      if (seen.add(t.toLowerCase())) addrs.add(t);
    }

    for (final e in emails) {
      add(e.from);
      for (final t in e.to) {
        add(t);
      }
    }
    return addrs;
  }
}

/// Strip any run of leading reply/forward prefixes (Re:, Fwd:, Fw:) plus
/// surrounding whitespace, case-insensitively. "Re: Re: Fwd: Hello" -> "Hello".
String stripSubjectPrefixes(String subject) {
  var s = subject.trim();
  final re = RegExp(r'^(re|fwd|fw)\s*:\s*', caseSensitive: false);
  while (true) {
    final m = re.firstMatch(s);
    if (m == null) break;
    s = s.substring(m.end).trimLeft();
  }
  return s.isEmpty ? subject.trim() : s;
}

/// Group a newest-first list of emails into conversation threads, preserving
/// order by most-recent activity (the thread of the newest email comes first).
List<EmailThread> groupEmailThreads(List<EmailMessage> emails) {
  final order = <String>[];
  final buckets = <String, List<EmailMessage>>{};

  for (final email in emails) {
    final normalized = stripSubjectPrefixes(email.subject).toLowerCase();
    // Unmergeable subjects key off the doc id so they stay standalone.
    final key = normalized.isEmpty ? 'id:${email.id}' : 'subj:$normalized';
    final bucket = buckets[key];
    if (bucket == null) {
      buckets[key] = [email];
      order.add(key);
    } else {
      bucket.add(email);
    }
  }

  return [
    for (final key in order) EmailThread(key: key, emails: buckets[key]!),
  ];
}
