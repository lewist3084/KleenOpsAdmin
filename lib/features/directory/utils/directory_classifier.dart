// lib/features/directory/utils/directory_classifier.dart
//
// Helpers for classifying an email counterparty as an organization (business
// domain) vs an individual (personal/free email domain).

/// Free / personal email providers. Mail from these is treated as an external
/// *person*, never an organization (otherwise every individual would spawn a
/// junk org like "gmail").
const Set<String> kPersonalEmailDomains = {
  'gmail.com',
  'googlemail.com',
  'yahoo.com',
  'ymail.com',
  'rocketmail.com',
  'outlook.com',
  'hotmail.com',
  'live.com',
  'msn.com',
  'icloud.com',
  'me.com',
  'mac.com',
  'aol.com',
  'proton.me',
  'protonmail.com',
  'pm.me',
  'gmx.com',
  'gmx.net',
  'zoho.com',
  'mail.com',
  'yandex.com',
  'comcast.net',
  'verizon.net',
  'att.net',
  'sbcglobal.net',
  'bellsouth.net',
  'cox.net',
  'charter.net',
};

/// Generic / role mailbox local-parts. Mail from these is the *organization*
/// speaking, not a person — so we link it to the org but don't spin up a
/// personal contact (no "service" or "info" person).
const Set<String> kRoleMailboxLocalParts = {
  'info', 'service', 'services', 'support', 'sales', 'billing', 'accounts',
  'accounting', 'noreply', 'no-reply', 'donotreply', 'do-not-reply', 'admin',
  'administrator', 'hello', 'contact', 'contactus', 'office', 'team', 'help',
  'helpdesk', 'jobs', 'careers', 'hr', 'marketing', 'notifications',
  'notification', 'alerts', 'news', 'newsletter', 'mailer-daemon',
  'postmaster', 'webmaster', 'enquiries', 'inquiries', 'orders', 'feedback',
  'partners', 'partner',
};

/// Lowercased local-part (before the @, with any +tag stripped).
String? localPartOf(String email) {
  final at = email.indexOf('@');
  if (at <= 0) return null;
  return email.substring(0, at).trim().toLowerCase().split('+').first;
}

/// True when [email]'s local-part is a generic/role mailbox (→ org only, no
/// personal contact).
bool isRoleMailbox(String email) {
  final lp = localPartOf(email);
  return lp != null && kRoleMailboxLocalParts.contains(lp);
}

/// Lowercased domain part of an email address, or null if not parseable.
String? domainOf(String email) {
  final at = email.lastIndexOf('@');
  if (at < 0 || at == email.length - 1) return null;
  return email.substring(at + 1).trim().toLowerCase();
}

/// True when [email]'s domain is a personal/free provider (→ track as a person).
bool isPersonalEmail(String email) {
  final d = domainOf(email);
  return d != null && kPersonalEmailDomains.contains(d);
}

/// A human-friendly default organization name derived from a domain, e.g.
/// "northwestregisteredagent.com" → "Northwestregisteredagent". Best-effort;
/// the real display name is refined from the sender name when available.
String orgNameFromDomain(String domain) {
  var base = domain.toLowerCase();
  // Drop a leading "www." and the public suffix (last dotted segment).
  if (base.startsWith('www.')) base = base.substring(4);
  final dot = base.indexOf('.');
  final core = dot > 0 ? base.substring(0, dot) : base;
  if (core.isEmpty) return domain;
  return core[0].toUpperCase() + core.substring(1);
}
