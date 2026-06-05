import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/dialogs/dialog_action.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:kleenops_admin/widgets/fields/google_address.dart';
import 'package:kleenops_admin/app/shared_widgets/forms/form_ai_bottom_bar.dart';
import 'package:kleenops_admin/common/communications/calendar/calendar.dart'
    show kCalendarEventCategoryId;
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/services/ai_text_adapter.dart';
import 'package:kleenops_admin/widgets/layout/bookended_canvas.dart';
import 'package:shared_widgets/containers/container_action.dart';
import 'package:shared_widgets/dialogs/dialog_select.dart';
import 'package:shared_widgets/labels/text_info_checkbox.dart';
import 'package:shared_widgets/utils/google_api_key.dart';
import 'package:kleenops_admin/common/utils/snackbar_service.dart';

const Map<String, String> _absenceTypes = {
  'vacation': 'Vacation / PTO',
  'sick': 'Sick Leave',
  'personal': 'Personal Day',
  'bereavement': 'Bereavement',
  'jury_duty': 'Jury Duty',
  'family_medical': 'Family / Medical Leave',
  'unpaid': 'Unpaid Leave',
  'other': 'Other',
};

const Map<String, String> _repeatRules = {
  'none': 'Does not repeat',
  'daily': 'Daily',
  'weekly': 'Weekly',
  'monthly': 'Monthly',
  'annually': 'Annually',
  'weekday': 'Every weekday (Monâ€“Fri)',
};

const List<int> _groupColorPalette = [
  0xFF4285F4,
  0xFF34A853,
  0xFFFBBC05,
  0xFFEA4335,
  0xFF9C27B0,
  0xFFFF7043,
  0xFF00ACC1,
  0xFF8D6E63,
];

/// Create or edit a calendar (timeline) event.
///
/// Pass a `docId` query parameter to edit an existing event; omit it to
/// create a new one. Writes to `company/{id}/timeline`.
class CalendarEventFormScreen extends ConsumerStatefulWidget {
  const CalendarEventFormScreen({super.key, this.docId, this.initialDate});

  final String? docId;
  /// Pre-fills the start (and a default 1-hour end) when creating a new
  /// event â€” e.g. from the calendar's tap-to-add empty-cell affordance.
  final DateTime? initialDate;

  bool get isEditing => docId != null;

  @override
  ConsumerState<CalendarEventFormScreen> createState() =>
      _CalendarEventFormScreenState();
}

class _CalendarEventFormScreenState
    extends ConsumerState<CalendarEventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtl = TextEditingController();
  final _descCtl = TextEditingController();
  late DateTime _start;
  late DateTime _end;
  final List<PlatformFile> _files = [];
  bool _saving = false;
  bool _loaded = false;
  bool _memberLoaded = false;

  bool _isAbsence = false;
  bool _allDay = false;
  String? _absenceType;
  List<String> _selectedTeamIds = [];

  String? _primaryTeamId;
  String _memberName = '';
  List<DocumentReference<Map<String, dynamic>>> _teamAccess = const [];
  Map<String, String> _teamNames = {};

  List<String> _selectedGroupIds = [];
  Map<String, Map<String, dynamic>> _groups = {};

  String _repeatRule = 'none';

  final _locationCtl = TextEditingController();
  double? _locationLat;
  double? _locationLng;
  String? _locationPlaceId;

  List<DocumentReference<Map<String, dynamic>>> _memberGuests = [];
  Map<String, String> _memberGuestNames = {};
  final List<String> _externalGuestEmails = [];
  final _guestEmailCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final seed = widget.initialDate;
    if (seed != null) {
      _start = seed;
    } else {
      final now = DateTime.now();
      _start = DateTime(now.year, now.month, now.day, now.hour + 1);
    }
    _end = _start.add(const Duration(hours: 1));
    if (!widget.isEditing) _loaded = true;
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _descCtl.dispose();
    _locationCtl.dispose();
    _guestEmailCtl.dispose();
    super.dispose();
  }

  Future<void> _loadExisting(DocumentReference companyRef) async {
    if (_loaded) return;
    final doc = await FirebaseFirestore.instance
        .collection('company')
        .doc(companyRef.id)
        .collection('timeline')
        .doc(widget.docId)
        .get();
    final data = doc.data();
    if (!mounted) return;
    if (data != null) {
      setState(() {
        _nameCtl.text = data['name'] as String? ?? '';
        _descCtl.text = data['description'] as String? ?? '';
        _start = (data['startTime'] as Timestamp?)?.toDate() ?? _start;
        _end = (data['endTime'] as Timestamp?)?.toDate() ?? _end;
        _allDay = data['isAllDay'] as bool? ?? false;
        _isAbsence = data['isAbsence'] as bool? ?? false;
        _absenceType = data['absenceType'] as String?;
        final rawTeamIds = (data['teamIds'] as List?) ?? const [];
        _selectedTeamIds = rawTeamIds.whereType<String>().toList();
        if (_selectedTeamIds.isEmpty) {
          final legacy = data['teamId'] as String?;
          if (legacy != null && legacy.isNotEmpty) {
            _selectedTeamIds = [legacy];
          }
        }
        _selectedGroupIds = ((data['groupIds'] as List?) ?? const [])
            .whereType<String>()
            .toList();
        _repeatRule = (data['repeatRule'] as String?) ?? 'none';
        final loc = data['location'];
        if (loc is Map) {
          final addr = (loc['address'] as String?) ?? '';
          _locationCtl.text = addr;
          _locationLat = (loc['lat'] as num?)?.toDouble();
          _locationLng = (loc['lng'] as num?)?.toDouble();
          _locationPlaceId = loc['placeId'] as String?;
        }
        final memberRefs = (data['memberGuestIds'] as List?) ?? const [];
        _memberGuests = memberRefs
            .whereType<DocumentReference>()
            .map((r) => r.withConverter<Map<String, dynamic>>(
                  fromFirestore: (s, _) => s.data()!,
                  toFirestore: (m, _) => m,
                ))
            .toList();
        _externalGuestEmails
          ..clear()
          ..addAll(((data['externalGuestEmails'] as List?) ?? const [])
              .whereType<String>());
        _loaded = true;
      });
      if (_memberGuests.isNotEmpty) {
        _loadMemberGuestNames();
      }
    } else {
      setState(() => _loaded = true);
    }
  }

  Future<void> _loadMemberGuestNames() async {
    final names = <String, String>{};
    for (final ref in _memberGuests) {
      try {
        final snap = await ref.get();
        final n = (snap.data()?['name'] as String?)?.trim();
        if (n != null && n.isNotEmpty) names[ref.id] = n;
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() => _memberGuestNames = names);
  }

  Future<void> _loadMember(
    DocumentReference<Map<String, dynamic>> memberRef,
  ) async {
    if (_memberLoaded) return;
    final snap = await memberRef.get();
    final data = snap.data();
    final access = <DocumentReference<Map<String, dynamic>>>[];
    String? primaryTeamId;
    final memberName = (data?['name'] as String?)?.trim() ?? '';
    if (data != null) {
      final raw = data['teamAccess'];
      if (raw is List) {
        for (final entry in raw) {
          if (entry is DocumentReference) {
            access.add(entry.withConverter<Map<String, dynamic>>(
              fromFirestore: (s, _) => s.data()!,
              toFirestore: (m, _) => m,
            ));
          }
        }
      }
      final primaryRaw = data['primaryTeamId'] ?? data['primaryTeam'];
      if (primaryRaw is DocumentReference) {
        primaryTeamId = primaryRaw.id;
      } else if (primaryRaw is String && primaryRaw.isNotEmpty) {
        primaryTeamId = primaryRaw.split('/').last;
      }
    }

    final names = <String, String>{};
    for (final teamRef in access) {
      try {
        final t = await teamRef.get();
        final n = t.data()?['name'] as String?;
        if (n != null && n.isNotEmpty) names[teamRef.id] = n;
      } catch (_) {}
    }

    final groupsSnap = await memberRef.collection('calendarGroup').get();
    final groupsMap = <String, Map<String, dynamic>>{};
    for (final doc in groupsSnap.docs) {
      groupsMap[doc.id] = doc.data();
    }

    if (!mounted) return;
    setState(() {
      _teamAccess = access;
      _teamNames = names;
      _primaryTeamId = primaryTeamId;
      _memberName = memberName;
      _groups = groupsMap;
      // Default the team selection to the member's primary team when no
      // existing selection is loaded. If there's no primary but the member
      // belongs to exactly one team, default to that team.
      if (_selectedTeamIds.isEmpty) {
        if (primaryTeamId != null &&
            access.any((r) => r.id == primaryTeamId)) {
          _selectedTeamIds = [primaryTeamId];
        } else if (access.length == 1) {
          _selectedTeamIds = [access.first.id];
        }
      }
      _memberLoaded = true;
    });
  }

  Future<void> _pickStart() async {
    final picked = _allDay
        ? await _pickDateOnly(_start)
        : await _pickDateTime(_start);
    if (picked == null) return;
    setState(() {
      if (_allDay) {
        _start = _startOfDay(picked);
        if (_end.isBefore(_start)) {
          _end = _endOfDay(_start);
        }
      } else {
        _start = picked;
        if (!_end.isAfter(_start)) {
          _end = _start.add(const Duration(hours: 1));
        }
      }
    });
  }

  Future<void> _pickEnd() async {
    final picked = _allDay
        ? await _pickDateOnly(_end)
        : await _pickDateTime(_end);
    if (picked == null || !mounted) return;
    final normalized = _allDay ? _endOfDay(picked) : picked;
    if (!normalized.isAfter(_start)) {
      SnackbarService.instance.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: Text(
            _allDay
                ? 'End date must be on or after start date.'
                : 'End must be after start.',
          ),
        ),
      );
      return;
    }
    setState(() => _end = normalized);
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 5),
      lastDate: DateTime(initial.year + 5),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<DateTime?> _pickDateOnly(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 5),
      lastDate: DateTime(initial.year + 5),
    );
    if (date == null) return null;
    return DateTime(date.year, date.month, date.day);
  }

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59);

  void _toggleAllDay(bool v) {
    setState(() {
      _allDay = v;
      if (v) {
        // Collapse to a single-day span (or preserve multi-day if user already
        // spanned multiple dates) and snap to midnight / end-of-day.
        final endDate = _end.isBefore(_start) ? _start : _end;
        _start = _startOfDay(_start);
        _end = _endOfDay(endDate);
      } else {
        // Restore a sensible 1-hour timed window on the same start date.
        final base = _startOfDay(_start).add(const Duration(hours: 9));
        _start = base;
        _end = base.add(const Duration(hours: 1));
      }
    });
  }

  Future<void> _pickRepeat() async {
    final keys = _repeatRules.keys.toList();
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => DialogSelect<String>(
        title: 'Repeat',
        items: keys,
        itemLabel: (k) => _repeatRules[k] ?? k,
        tileType: DialogSelectTileType.radio,
        initialSelection: _repeatRule,
        onCancel: () => Navigator.of(dialogCtx).pop(),
        onSubmit: (res) => Navigator.of(dialogCtx).pop(res.firstOrNull),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _repeatRule = selected);
    }
  }

  Future<void> _pickMemberGuests() async {
    final companyRef = ref.read(companyIdProvider).value;
    if (companyRef == null) return;
    final teamIds = _teamAccess.map((r) => r.id).toList();
    if (teamIds.isEmpty) {
      SnackbarService.instance.showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 5),
          content: Text('No teams available to pick members from.'),
        ),
      );
      return;
    }
    // Load active members across the user's accessible teams.
    final byId = <String, String>{};
    final refsById = <String, DocumentReference<Map<String, dynamic>>>{};
    for (var i = 0; i < teamIds.length; i += 10) {
      final chunk = teamIds.sublist(i, (i + 10).clamp(0, teamIds.length));
      final snap = await FirebaseFirestore.instance
          .collection('company')
          .doc(companyRef.id)
          .collection('member')
          .where('primaryTeamId', whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        if (data['active'] == false) continue;
        byId[doc.id] = (data['name'] as String?)?.trim().isNotEmpty == true
            ? data['name'] as String
            : doc.id;
        refsById[doc.id] = doc.reference;
      }
    }
    if (byId.isEmpty || !mounted) {
      if (mounted) {
        SnackbarService.instance.showSnackBar(
          const SnackBar(duration: Duration(seconds: 5), content: Text('No members found.')),
        );
      }
      return;
    }
    final ids = byId.keys.toList()
      ..sort((a, b) =>
          byId[a]!.toLowerCase().compareTo(byId[b]!.toLowerCase()));
    final result = await showDialog<List<String>>(
      context: context,
      builder: (dialogCtx) => DialogSelect<String>(
        title: 'Members',
        items: ids,
        itemLabel: (id) => byId[id] ?? id,
        tileType: DialogSelectTileType.checkbox,
        initialSelections: _memberGuests.map((r) => r.id).toList(),
        onCancel: () => Navigator.of(dialogCtx).pop(),
        onSubmit: (res) => Navigator.of(dialogCtx).pop(res.values),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _memberGuests = result
            .map((id) => refsById[id])
            .whereType<DocumentReference<Map<String, dynamic>>>()
            .toList();
        _memberGuestNames = {
          for (final id in result) id: byId[id] ?? id,
        };
      });
    }
  }

  void _addExternalGuestEmail() {
    final raw = _guestEmailCtl.text.trim();
    if (raw.isEmpty) return;
    // Permissive check â€” just require an "@" and a "." after it. We avoid
    // strict RFC validation since users will paste real-world variants.
    final atIdx = raw.indexOf('@');
    if (atIdx <= 0 || raw.indexOf('.', atIdx) <= atIdx + 1) {
      SnackbarService.instance.showSnackBar(
        const SnackBar(duration: Duration(seconds: 5), content: Text('Enter a valid email address.')),
      );
      return;
    }
    if (_externalGuestEmails.contains(raw)) {
      _guestEmailCtl.clear();
      return;
    }
    setState(() {
      _externalGuestEmails.add(raw);
      _guestEmailCtl.clear();
    });
  }

  void _removeExternalGuestEmail(String email) {
    setState(() => _externalGuestEmails.remove(email));
  }

  Future<void> _pickAbsenceType() async {
    final keys = _absenceTypes.keys.toList();
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => DialogSelect<String>(
        title: 'Absence Type',
        items: keys,
        itemLabel: (k) => _absenceTypes[k] ?? k,
        tileType: DialogSelectTileType.radio,
        initialSelection: _absenceType,
        onCancel: () => Navigator.of(dialogCtx).pop(),
        onSubmit: (result) => Navigator.of(dialogCtx).pop(result.firstOrNull),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _absenceType = selected);
    }
  }

  Future<void> _pickTeams() async {
    final ids = _teamAccess.map((r) => r.id).toList();
    if (ids.isEmpty) {
      SnackbarService.instance.showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 5),
          content: Text('Add at least one team to your access list first.'),
        ),
      );
      return;
    }
    final result = await showDialog<List<String>>(
      context: context,
      builder: (dialogCtx) => DialogSelect<String>(
        title: 'Teams',
        items: ids,
        itemLabel: (id) => _teamNames[id] ?? id,
        tileType: DialogSelectTileType.checkbox,
        initialSelections: _selectedTeamIds,
        onCancel: () => Navigator.of(dialogCtx).pop(),
        onSubmit: (res) => Navigator.of(dialogCtx).pop(res.values),
      ),
    );
    if (result != null && mounted) {
      setState(() => _selectedTeamIds = result);
    }
  }

  Future<void> _pickCalendars() async {
    final memberRef = ref.read(memberDocRefProvider).value;
    if (memberRef == null) return;
    final ids = _groups.keys.toList();
    final result = await showDialog<List<String>>(
      context: context,
      builder: (dialogCtx) => DialogSelect<String>(
        title: 'Calendars',
        items: ids,
        itemLabel: (id) => (_groups[id]?['name'] as String?) ?? id,
        tileType: DialogSelectTileType.checkbox,
        initialSelections: _selectedGroupIds,
        emptyStateText: 'No calendars yet. Tap + to add one.',
        onCancel: () => Navigator.of(dialogCtx).pop(),
        onSubmit: (res) => Navigator.of(dialogCtx).pop(res.values),
        onAdd: () async {
          final created = await _createGroup(memberRef);
          if (created == null || !dialogCtx.mounted) return;
          Navigator.of(dialogCtx).pop([..._selectedGroupIds, created]);
        },
        addTooltip: 'Add Calendar',
      ),
    );
    if (result != null && mounted) {
      setState(() => _selectedGroupIds = result);
    }
  }

  Future<String?> _createGroup(
    DocumentReference<Map<String, dynamic>> memberRef,
  ) async {
    final nameCtl = TextEditingController();
    int colorChoice = _groupColorPalette.first;
    final id = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return DialogAction(
              title: 'New Calendar',
              cancelText: 'Cancel',
              onCancel: () => Navigator.pop(ctx),
              actionText: 'Create',
              onAction: () async {
                final name = nameCtl.text.trim();
                if (name.isEmpty) return;
                final docRef = await memberRef
                    .collection('calendarGroup')
                    .add({
                  'name': name,
                  'color': colorChoice,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (!ctx.mounted) return;
                Navigator.pop(ctx, docRef.id);
              },
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.done,
                    onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                  ),
                  const SizedBox(height: 12),
                  const Text('Color'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in _groupColorPalette)
                        GestureDetector(
                          onTap: () => setLocal(() => colorChoice = c),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Color(c),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colorChoice == c
                                    ? Colors.black
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    nameCtl.dispose();
    if (id == null) return null;
    final snap = await memberRef.collection('calendarGroup').doc(id).get();
    if (!mounted) return id;
    setState(() {
      final data = snap.data();
      if (data != null) _groups[id] = data;
    });
    return id;
  }

  void _showAbsenceInfo() {
    showDialog<void>(
      context: context,
      builder: (ctx) => DialogAction(
        title: 'Absence',
        content: const Text(
          'Mark this entry as an absence to request time off. Your selected '
          'team(s) will see the request and a manager can approve it.',
        ),
        cancelText: 'OK',
        onCancel: () => Navigator.pop(ctx),
        showActionButton: false,
      ),
    );
  }

  Future<void> _addFile() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null || result.files.isEmpty) return;
    setState(() => _files.addAll(result.files));
  }

  void _removeFile(int index) {
    setState(() => _files.removeAt(index));
  }

  /// Label written to an absence's `name` field so it renders as a plain
  /// calendar entry naming the individual (no description). Falls back to the
  /// absence type, then a generic label, if the member has no name on file.
  String _absenceName() {
    if (_memberName.isNotEmpty) return _memberName;
    return _absenceTypes[_absenceType] ?? 'Absence';
  }

  Future<void> _confirmDelete(DocumentReference companyRef) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => DialogAction(
        title: 'Delete event?',
        content: const Text(
          'This will permanently remove the event from your calendar.',
        ),
        cancelText: 'Cancel',
        onCancel: () => Navigator.of(ctx).pop(false),
        actionText: 'Delete',
        onAction: () => Navigator.of(ctx).pop(true),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('company')
          .doc(companyRef.id)
          .collection('timeline')
          .doc(widget.docId)
          .delete();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      SnackbarService.instance.showSnackBar(
        SnackBar(duration: const Duration(seconds: 5), content: Text('Failed to delete: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save(DocumentReference companyRef) async {
    if (!_formKey.currentState!.validate()) return;
    if (_isAbsence && _selectedTeamIds.isEmpty) {
      SnackbarService.instance.showSnackBar(
        const SnackBar(duration: Duration(seconds: 5), content: Text('Pick at least one team for the absence.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final memberRef = ref.read(memberDocRefProvider).value;
      final col = FirebaseFirestore.instance
          .collection('company')
          .doc(companyRef.id)
          .collection('timeline');
      final payload = <String, dynamic>{
        'name': _isAbsence ? _absenceName() : _nameCtl.text.trim(),
        'description': _isAbsence ? '' : _descCtl.text.trim(),
        'startTime': Timestamp.fromDate(_start),
        'endTime': Timestamp.fromDate(_end),
        'isAllDay': _allDay,
        'isAbsence': _isAbsence,
        'absenceType': _isAbsence ? (_absenceType ?? 'other') : '',
        'teamIds': _isAbsence ? _selectedTeamIds : <String>[],
        'groupIds': _isAbsence ? <String>[] : _selectedGroupIds,
        'repeatRule': _isAbsence ? 'none' : _repeatRule,
        'location': _isAbsence
            ? null
            : {
                'address': _locationCtl.text.trim(),
                'lat': _locationLat,
                'lng': _locationLng,
                'placeId': _locationPlaceId,
              },
        'memberGuestIds':
            _isAbsence ? <DocumentReference>[] : _memberGuests,
        'externalGuestEmails':
            _isAbsence ? <String>[] : List<String>.from(_externalGuestEmails),
        if (_isAbsence) 'memberName': _memberName,
        if (_isAbsence && memberRef != null) 'memberId': memberRef,
        // Stamp non-absence events with the Calendar Events category so the
        // layered calendar can query them server-side. Absences are keyed
        // off `isAbsence` instead and must not carry a category.
        if (!_isAbsence) 'timelineCategory': kCalendarEventCategoryId,
      };
      if (_isAbsence) {
        payload['status'] = 'pending';
      }
      if (!widget.isEditing && memberRef != null) {
        payload['createdByMemberId'] = memberRef.id;
      }
      if (widget.isEditing) {
        await col.doc(widget.docId).update(payload);
      } else {
        await col.add({
          ...payload,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      SnackbarService.instance.showSnackBar(
        SnackBar(duration: const Duration(seconds: 5), content: Text('Failed to save: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final companyAsync = ref.watch(companyIdProvider);
    final memberRefAsync = ref.watch(memberDocRefProvider);
    return companyAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (companyRef) {
        if (companyRef == null) {
          return const Scaffold(
            body: Center(child: Text('No company selected.')),
          );
        }
        if (widget.isEditing && !_loaded) {
          _loadExisting(companyRef);
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final memberRef = memberRefAsync.value;
        if (memberRef != null && !_memberLoaded) {
          _loadMember(memberRef);
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return _buildForm(context, companyRef);
      },
    );
  }

  Widget _buildForm(BuildContext context, DocumentReference companyRef) {
    final title = widget.isEditing ? 'Edit Event' : 'New Event';

    return Scaffold(
      appBar: null,
      body: BookendedCanvas(
        child: Column(
          children: [
            if (_saving) const LinearProgressIndicator(),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _buildAbsenceContainer(),
                    if (!_isAbsence) _buildTitleDescriptionContainer(),
                    _buildDatesContainer(),
                    if (!_isAbsence) _buildRepeatContainer(),
                    if (!_isAbsence) _buildGuestsContainer(),
                    if (!_isAbsence) _buildLocationContainer(),
                    if (!_isAbsence) _buildCalendarsContainer(),
                    if (!_isAbsence) _buildFilesContainer(),
                    if (widget.isEditing) _buildDeleteContainer(companyRef),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: FormAiBottomBar(
        title: title,
        onCancel: () {
          if (_saving) return;
          Navigator.of(context).maybePop();
        },
        onSave: _saving ? null : () => _save(companyRef),
        isSaving: _saving,
      ),
    );
  }

  Widget _buildAbsenceContainer() {
    final hasTeams = _teamAccess.isNotEmpty;
    final children = <Widget>[
      TextInfoCheckbox(
        text: 'Absence',
        value: _isAbsence,
        onChanged: hasTeams
            ? (v) {
                if (v == null) return;
                setState(() {
                  _isAbsence = v;
                  if (v) {
                    _absenceType ??= 'vacation';
                    if (_selectedTeamIds.isEmpty) {
                      if (_primaryTeamId != null &&
                          _teamAccess.any((r) => r.id == _primaryTeamId)) {
                        _selectedTeamIds = [_primaryTeamId!];
                      } else if (_teamAccess.length == 1) {
                        _selectedTeamIds = [_teamAccess.first.id];
                      }
                    }
                  } else {
                    _absenceType = null;
                  }
                });
              }
            : null,
        onInfoPressed: _showAbsenceInfo,
      ),
    ];

    if (_isAbsence) {
      children.add(const SizedBox(height: 12));
      children.add(
        _BorderedSelectField(
          label: 'Type',
          value: _absenceType == null ? null : _absenceTypes[_absenceType!],
          placeholder: 'Tap to pick a type',
          icon: Icons.category_outlined,
          onTap: _pickAbsenceType,
        ),
      );
      // Only show the team picker when the member has access to more than
      // one team â€” otherwise the single team is auto-selected silently.
      if (_teamAccess.length > 1) {
        children.add(const SizedBox(height: 12));
        children.add(
          _BorderedSelectField(
            label: 'Team',
            value: _selectedTeamIds.isEmpty
                ? null
                : _selectedTeamIds
                    .map((id) => _teamNames[id] ?? id)
                    .join(', '),
            placeholder: 'Tap to pick teams',
            icon: Icons.groups,
            onTap: _pickTeams,
          ),
        );
      }
    }

    return ContainerActionWidget(
      actionText: '',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _buildTitleDescriptionContainer() {
    return ContainerActionWidget(
      actionText: '',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AITextField(
            controller: _nameCtl,
            labelText: 'Title',
            minLines: 1,
            maxLines: 1,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Title is required'
                : null,
          ),
          const SizedBox(height: 12),
          AITextField(
            controller: _descCtl,
            labelText: 'Description',
            minLines: 3,
            maxLines: 6,
          ),
        ],
      ),
    );
  }

  Widget _buildDatesContainer() {
    final dateFmt =
        _allDay ? DateFormat.yMMMd() : DateFormat.yMMMd().add_jm();
    return ContainerActionWidget(
      actionText: '',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextInfoCheckbox(
            text: 'All day',
            value: _allDay,
            onChanged: (v) {
              if (v == null) return;
              _toggleAllDay(v);
            },
          ),
          const SizedBox(height: 12),
          _BorderedSelectField(
            label: 'Start',
            value: dateFmt.format(_start),
            icon: Icons.calendar_today,
            onTap: _pickStart,
          ),
          const SizedBox(height: 12),
          _BorderedSelectField(
            label: 'End',
            value: dateFmt.format(_end),
            icon: Icons.calendar_today,
            onTap: _pickEnd,
          ),
        ],
      ),
    );
  }

  Widget _buildRepeatContainer() {
    return ContainerActionWidget(
      actionText: '',
      content: _BorderedSelectField(
        label: 'Repeat',
        value: _repeatRules[_repeatRule] ?? 'Does not repeat',
        icon: Icons.repeat,
        onTap: _pickRepeat,
      ),
    );
  }

  Widget _buildGuestsContainer() {
    final memberSummary = _memberGuests.isEmpty
        ? null
        : _memberGuests
            .map((r) => _memberGuestNames[r.id] ?? r.id)
            .join(', ');
    return ContainerActionWidget(
      title: 'Guests',
      actionText: '',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BorderedSelectField(
            label: 'Members',
            value: memberSummary,
            placeholder: 'Tap to pick members',
            icon: Icons.people_outline,
            onTap: _pickMemberGuests,
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _guestEmailCtl,
                  decoration: const InputDecoration(
                    labelText: 'Add guest email',
                    hintText: 'name@example.com',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  onSubmitted: (_) => _addExternalGuestEmail(),
                  textInputAction: TextInputAction.done,
                  onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Add email',
                icon: const Icon(Icons.add_circle_outline),
                onPressed: _addExternalGuestEmail,
              ),
            ],
          ),
          if (_externalGuestEmails.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final email in _externalGuestEmails)
                  InputChip(
                    label: Text(email),
                    onDeleted: () => _removeExternalGuestEmail(email),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationContainer() {
    return ContainerActionWidget(
      actionText: '',
      content: GoogleAddressField(
        apiKey: kGoogleApiKey,
        controller: _locationCtl,
        labelText: 'Location',
        onSelected: (m) {
          setState(() {
            _locationCtl.text = (m['address'] as String?) ?? _locationCtl.text;
            _locationLat = (m['lat'] as num?)?.toDouble();
            _locationLng = (m['lng'] as num?)?.toDouble();
            _locationPlaceId = m['placeId'] as String?;
          });
        },
      ),
    );
  }

  Widget _buildCalendarsContainer() {
    final selectedLabels = _selectedGroupIds
        .map((id) => (_groups[id]?['name'] as String?) ?? id)
        .toList();
    return ContainerActionWidget(
      actionText: '',
      content: _BorderedSelectField(
        label: 'Calendars',
        value: selectedLabels.isEmpty ? null : selectedLabels.join(', '),
        placeholder: 'Tap to pick calendars',
        icon: Icons.folder_outlined,
        onTap: _pickCalendars,
      ),
    );
  }

  Widget _buildDeleteContainer(DocumentReference companyRef) {
    return ContainerActionWidget(
      actionText: '',
      content: TextButton.icon(
        onPressed: _saving ? null : () => _confirmDelete(companyRef),
        icon: const Icon(Icons.delete_outline, color: Colors.red),
        label: const Text(
          'Delete event',
          style: TextStyle(color: Colors.red),
        ),
      ),
    );
  }

  Widget _buildFilesContainer() {
    return ContainerActionWidget(
      title: 'Files',
      actionText: 'Add',
      onAction: _addFile,
      content: _files.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No files attached.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < _files.length; i++)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.insert_drive_file),
                    title: Text(_files[i].name),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => _removeFile(i),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _BorderedSelectField extends StatelessWidget {
  const _BorderedSelectField({
    required this.label,
    required this.value,
    this.placeholder,
    this.icon,
    this.onTap,
  });

  final String label;
  final String? value;
  final String? placeholder;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasValue = value != null && value!.trim().isNotEmpty;
    final display = hasValue ? value! : (placeholder ?? 'Tap to select');
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      color: hasValue ? null : Colors.grey,
    );
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          enabled: onTap != null,
          suffixIcon: icon == null ? null : Icon(icon),
        ),
        child: Text(display, style: textStyle),
      ),
    );
  }
}

