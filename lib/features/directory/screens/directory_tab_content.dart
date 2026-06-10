// lib/features/directory/screens/directory_tab_content.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shared_widgets/lists/standardView.dart';
import 'package:shared_widgets/lists/standardViewGroup.dart';
import 'package:shared_widgets/tiles/standard_tile_small.dart';

import '../models/external_contact.dart';
import '../models/organization.dart';
import '../providers/directory_providers.dart';
import 'directory_entity_detail_screen.dart';
import 'external_contact_form_screen.dart';

/// A single row in the unified People list — an internal staff member, a
/// confirmed external contact, or a suggested (unconfirmed) external contact.
class _DirectoryPerson {
  final String name;
  final String subtitle;
  final bool external;
  final bool suggested;

  /// Contact id used to open the detail screen (external + suggested only).
  final String? contactId;

  /// Doc reference used for confirm/dismiss of a suggested contact.
  final ExternalContact? contact;

  const _DirectoryPerson({
    required this.name,
    required this.subtitle,
    required this.external,
    this.suggested = false,
    this.contactId,
    this.contact,
  });

  /// Section bucket for [StandardViewGroup]: suggested contacts first, then
  /// the Internal / External groups.
  String get group => suggested
      ? 'Suggested Contacts'
      : (external ? 'External' : 'Internal');
}

/// Unified People list: internal staff + external contacts grouped into
/// Suggested Contacts / Internal / External, each tagged, with an
/// All/Internal/External filter and a name search both surfaced on the
/// DetailsAppBar.
class PeopleTabContent extends ConsumerStatefulWidget {
  const PeopleTabContent({super.key});

  @override
  ConsumerState<PeopleTabContent> createState() => _PeopleTabContentState();
}

class _PeopleTabContentState extends ConsumerState<PeopleTabContent> {
  static String _memberName(Map<String, dynamic> d) {
    String pick(dynamic v) => v is String ? v.trim() : '';
    final combined = [pick(d['firstName']), pick(d['lastName'])]
        .where((p) => p.isNotEmpty)
        .join(' ');
    for (final c in [
      d['name'],
      d['displayName'],
      d['preferredName'],
      combined,
      d['email'],
    ]) {
      final v = pick(c);
      if (v.isNotEmpty) return v;
    }
    return 'No Name';
  }

  static String _memberSubtitle(Map<String, dynamic> d) {
    final email = (d['email'] as String?)?.trim();
    if (email != null && email.isNotEmpty) return email;
    final emails = (d['emails'] as List<dynamic>?)?.whereType<String>();
    return emails != null && emails.isNotEmpty ? emails.first : '';
  }

  static int _groupSort(String a, String b) {
    int rank(String g) => g == 'Suggested Contacts'
        ? 0
        : g == 'Internal'
            ? 1
            : 2;
    final byRank = rank(a).compareTo(rank(b));
    return byRank != 0 ? byRank : a.toLowerCase().compareTo(b.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(directoryPeopleFilterProvider);
    final members = ref.watch(companyMembersProvider).value ?? const [];
    final contacts = ref.watch(externalContactsProvider);
    final suggested = ref.watch(suggestedContactsProvider);

    final showInternal = filter != DirectoryPeopleFilter.external;
    final showExternal = filter != DirectoryPeopleFilter.internal;

    // Text search handled app-wide by StandardView (AppSearchController).
    final people = <_DirectoryPerson>[
      if (showExternal)
        for (final c in suggested)
          _DirectoryPerson(
            name: c.name,
            subtitle: c.emails.join(', '),
            external: true,
            suggested: true,
            contactId: c.id,
            contact: c,
          ),
      if (showInternal)
        for (final m in members)
          _DirectoryPerson(
            name: _memberName(m),
            subtitle: _memberSubtitle(m),
            external: false,
          ),
      if (showExternal)
        for (final c in contacts)
          _DirectoryPerson(
            name: c.name,
            subtitle: c.emails.isNotEmpty
                ? c.emails.first
                : (c.organizationId ?? ''),
            external: true,
            contactId: c.id,
            contact: c,
          ),
    ];

    return StandardViewGroup.buildViewFromItems<_DirectoryPerson>(
      items: people,
      emptyMessage: 'No people yet.',
      groupBy: (p) => p.group,
      groupSort: _groupSort,
      itemSort: (a, b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      groupCollapsible: true,
      initialGroupExpanded: true,
      enableReorder: false,
      padding: const EdgeInsets.only(bottom: 16),
      itemBuilder: (p) => _PersonTile(person: p),
    );
  }
}

class _PersonTile extends ConsumerWidget {
  const _PersonTile({required this.person});
  final _DirectoryPerson person;

  void _open(BuildContext context) {
    final id = person.contactId;
    if (id == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          DirectoryEntityDetailScreen(entityKind: 'contact', entityId: id),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = person.external ? Colors.teal : theme.colorScheme.primary;
    final tappable = person.contactId != null;

    return StandardTileSmallDart(
      label: person.name,
      labelStyle: const TextStyle(fontSize: 14, color: Colors.black),
      secondaryText: person.subtitle.isEmpty ? null : person.subtitle,
      leadingWidget: CircleAvatar(
        radius: 18,
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(
          person.external ? Icons.person_outline : Icons.badge_outlined,
          color: color,
          size: 20,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      tileColor: Colors.white,
      onTap: tappable ? () => _open(context) : null,
      trailingWidget: person.suggested
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Confirm',
                  icon: const Icon(Icons.check_circle, color: Colors.green),
                  onPressed: () {
                    final c = person.contact;
                    if (c?.ref != null) {
                      ref.read(directoryServiceProvider).confirm(c!.ref!);
                    }
                  },
                ),
                IconButton(
                  tooltip: 'Dismiss',
                  icon: Icon(Icons.cancel, color: Colors.grey.shade500),
                  onPressed: () {
                    final c = person.contact;
                    if (c?.ref != null) {
                      ref.read(directoryServiceProvider).dismiss(c!.ref!);
                    }
                  },
                ),
              ],
            )
          : (person.external && person.contact != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Edit',
                      icon: Icon(Icons.edit_outlined,
                          color: Colors.grey.shade600, size: 20),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ExternalContactFormScreen(
                              existing: person.contact),
                        ),
                      ),
                    ),
                    _KindBadge(external: person.external),
                  ],
                )
              : _KindBadge(external: person.external)),
    );
  }
}

class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.external});
  final bool external;

  @override
  Widget build(BuildContext context) {
    final color = external ? Colors.teal : Colors.blueGrey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        external ? 'External' : 'Internal',
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

/// Organizations tab: suggested orgs (confirm/dismiss) above confirmed ones.
class OrganizationsTabContent extends ConsumerWidget {
  const OrganizationsTabContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final suggested = ref.watch(suggestedOrganizationsProvider);
    final active = ref.watch(organizationsProvider);

    if (suggested.isEmpty && active.isEmpty) {
      return _emptyState(
        Icons.business_outlined,
        'No organizations yet',
        'Archive an email (swipe left in the inbox) to start tracking the '
            'company it came from.',
      );
    }

    // Suggested first, then confirmed. The group headers are dropped entirely
    // when nothing is awaiting confirmation (the tab itself already reads
    // "Organizations"). Tiles are plain selectable rows — tap opens the detail
    // screen; the only trailing controls are confirm/dismiss on suggested ones.
    final items = <Organization>[...suggested, ...active];
    return StandardView<Organization>(
      items: items,
      shrinkWrap: false,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      disableGrouping: suggested.isEmpty,
      groupBy: (o) => o.status == 'suggested' ? 'Suggested' : 'Organizations',
      groupSort: (a, b) => a == b ? 0 : (a == 'Suggested' ? -1 : 1),
      searchableText: (o) => '${o.name} ${o.domains.join(' ')}',
      onTap: (o) => _open(context, 'organization', o.id),
      itemBuilder: (o) => StandardTileSmallDart(
        label: o.name,
        secondaryText: o.domains.isNotEmpty ? o.domains.join(', ') : null,
        leadingIcon: Icons.business,
        leadingIconColor: theme.colorScheme.primary,
        trailingWidget: o.status == 'suggested'
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Confirm',
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    onPressed: () =>
                        ref.read(directoryServiceProvider).confirm(o.ref!),
                  ),
                  IconButton(
                    tooltip: 'Dismiss',
                    icon: Icon(Icons.cancel, color: Colors.grey.shade400),
                    onPressed: () =>
                        ref.read(directoryServiceProvider).dismiss(o.ref!),
                  ),
                ],
              )
            : null,
      ),
    );
  }

  void _open(BuildContext context, String kind, String id) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          DirectoryEntityDetailScreen(entityKind: kind, entityId: id),
    ));
  }
}

Widget _emptyState(IconData icon, String title, String body) => Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(title,
                style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            Text(body,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );

