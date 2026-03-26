import 'dart:async';
import 'dart:collection';

import 'package:cloud_firestore/cloud_firestore.dart';

// ── Stubs for AI types not available in the admin app ──────────────

class GeminiFinanceService {
  Future<FinanceCategorizationResult> suggestProfitLossPlacement({
    required String question,
    required Map<String, dynamic> companyContext,
    required String usageSource,
    required String usageSourceContext,
  }) async {
    return FinanceCategorizationResult(
      placement: '',
      accountFound: false,
    );
  }
}

class FinanceCategorizationResult {
  final String placement;
  final bool accountFound;
  final String? existingAccountPath;
  final String? recommendedSection;
  final String? recommendedAccount;
  final String? reasoning;
  final String? notes;

  FinanceCategorizationResult({
    required this.placement,
    required this.accountFound,
    this.existingAccountPath,
    this.recommendedSection,
    this.recommendedAccount,
    this.reasoning,
    this.notes,
  });
}

class SearchFieldAssistantReply {
  final String displayText;
  final Map<String, dynamic>? metadata;
  final List<SearchFieldAssistantAction> actions;

  SearchFieldAssistantReply({
    required this.displayText,
    this.metadata,
    this.actions = const [],
  });
}

class SearchFieldAssistantAction {
  final String id;
  final String label;
  final String description;
  final Map<String, dynamic> payload;

  SearchFieldAssistantAction({
    required this.id,
    required this.label,
    required this.description,
    this.payload = const {},
  });
}

// ── End stubs ──────────────────────────────────────────────────────

class ProfitLossAssistant {
  ProfitLossAssistant({
    GeminiFinanceService? financeService,
  }) : _financeService = financeService ?? GeminiFinanceService();

  final GeminiFinanceService _financeService;

  Future<SearchFieldAssistantReply> handleQuestion({
    required DocumentReference<Map<String, dynamic>> companyRef,
    required String question,
  }) async {
    final prompt = question.trim();
    if (prompt.isEmpty) {
      throw ArgumentError('Provide a question for the assistant.');
    }

    final contextBundle = await _buildCompanyContext(companyRef);
    final result = await _financeService.suggestProfitLossPlacement(
      question: prompt,
      companyContext: contextBundle.payload,
      usageSource: 'finances',
      usageSourceContext: 'profit_loss_assistant',
    );

    final metadata = <String, dynamic>{
      'placement': result.placement,
      'account_found': result.accountFound,
      if (result.existingAccountPath != null)
        'existing_account_path': result.existingAccountPath,
      if (result.recommendedSection != null)
        'recommended_section': result.recommendedSection,
      if (result.recommendedAccount != null)
        'recommended_account': result.recommendedAccount,
      if (result.reasoning != null) 'reasoning': result.reasoning,
      if (result.notes != null) 'notes': result.notes,
    };

    final actions = <SearchFieldAssistantAction>[];
    final createAction = _buildCreateAccountAction(result, contextBundle);
    if (createAction != null) {
      actions.add(createAction);
    }

    var responseText = _composeNarrative(result);
    if (actions.isNotEmpty) {
      const followUp = 'Would you like me to create it now?';
      responseText =
          responseText.trim().isEmpty ? followUp : '$responseText\n\n$followUp';
    }

    return SearchFieldAssistantReply(
      displayText: responseText,
      metadata: metadata.isEmpty ? null : metadata,
      actions: actions,
    );
  }

  Future<_CompanyProfitLossContext> _buildCompanyContext(
    DocumentReference<Map<String, dynamic>> companyRef,
  ) async {
    final sectionsSnap = await FirebaseFirestore.instance
        .collection('companyProfitLossSection')
        .where('active', isEqualTo: true)
        .get();
    final sections = sectionsSnap.docs
        .map((doc) => _SectionInfo.fromDoc(doc))
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));

    final accountsSnap = await FirebaseFirestore.instance
        .collection('account')
        .where('profitLoss', isEqualTo: true)
        .get();

    final accountInfos = <String, _AccountInfo>{};
    for (final doc in accountsSnap.docs) {
      accountInfos[doc.reference.path] = _AccountInfo.fromDoc(doc);
    }

    final sectionNameByPath = {
      for (final section in sections) section.path: section.name,
    };

    final List<Map<String, dynamic>> accountsPayload = [];
    for (final entry in accountInfos.entries) {
      final info = entry.value;
      final sectionName =
          _resolveSectionName(info, accountInfos, sectionNameByPath);
      final trail = _resolveNameTrail(info, accountInfos);
      if (trail.isEmpty) {
        continue;
      }

      final segments = <String>[];
      if (sectionName != null && sectionName.isNotEmpty) {
        segments.add(sectionName);
      }
      segments.addAll(trail);
      accountsPayload.add({
        'name': info.name,
        'path': segments.join(' > '),
        'section': sectionName ?? 'Uncategorized',
        if (info.hasChildren(accountInfos)) 'has_children': true,
      });
    }

    accountsPayload.sort((a, b) {
      final sectionComp =
          (a['section'] as String).compareTo(b['section'] as String);
      if (sectionComp != 0) return sectionComp;
      return (a['path'] as String).compareTo(b['path'] as String);
    });

    final payload = <String, dynamic>{
      'sections': sections
          .map((s) => {
                'name': s.name,
                'position': s.position,
              })
          .toList(growable: false),
      'accounts': accountsPayload,
    };

    return _CompanyProfitLossContext(
      payload: payload,
      sections: sections,
      accounts: accountInfos,
    );
  }

  SearchFieldAssistantAction? _buildCreateAccountAction(
    FinanceCategorizationResult result,
    _CompanyProfitLossContext context,
  ) {
    if (result.accountFound) {
      return null;
    }

    final accountName = result.recommendedAccount?.trim();
    final sectionHint = result.recommendedSection?.trim();
    if (accountName == null || accountName.isEmpty) {
      return null;
    }
    if (sectionHint == null || sectionHint.isEmpty) {
      return null;
    }

    final segments = sectionHint
        .split('>')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    if (segments.isEmpty) {
      segments.add(sectionHint.trim());
    }

    final sectionSegment = segments.first;
    final matchedSection = _findSectionByName(context.sections, sectionSegment);

    final payload = <String, dynamic>{
      'account_name': accountName,
      'section_hint': sectionHint,
    };

    String? sectionName = matchedSection?.name ?? sectionSegment;
    if (matchedSection != null) {
      payload['section_path'] = matchedSection.path;
      payload['section_name'] = matchedSection.name;
    }

    _AccountInfo? parentInfo;
    if (segments.length > 1) {
      final parentTrail = segments.sublist(1);
      parentInfo = _findAccountByTrail(parentTrail, context.accounts);
      if (parentInfo != null) {
        payload['parent_account_path'] = parentInfo.path;
        payload['parent_account_name'] = parentInfo.name;
        if (payload['section_path'] == null) {
          final parentSection = _firstWhereOrNull<_SectionInfo>(
            context.sections,
            (section) => section.path == parentInfo!.sectionPath,
          );
          if (parentSection != null) {
            payload['section_path'] = parentSection.path;
            payload['section_name'] = parentSection.name;
            sectionName = parentSection.name;
          }
        }
      }
    }

    payload['section_name'] ??= sectionName;
    if (parentInfo != null) {
      payload['parent_account_name'] = parentInfo.name;
    } else if (segments.isNotEmpty) {
      payload['parent_account_name_hint'] = segments.first;
    }

    final description = _buildCreateActionDescription(
      accountName: accountName,
      sectionName: payload['section_name'] as String?,
      parentName: parentInfo?.name,
    );

    return SearchFieldAssistantAction(
      id: 'finance.create_account',
      label: 'Create account',
      description: description,
      payload: payload,
    );
  }

  _SectionInfo? _findSectionByName(
    List<_SectionInfo> sections,
    String name,
  ) {
    final target = name.toLowerCase();
    for (final section in sections) {
      if (section.name.toLowerCase() == target) {
        return section;
      }
    }
    return null;
  }

  _AccountInfo? _findAccountByTrail(
    List<String> trail,
    Map<String, _AccountInfo> accounts,
  ) {
    if (trail.isEmpty) {
      return null;
    }
    final normalized =
        trail.map((segment) => segment.toLowerCase()).toList(growable: false);

    for (final info in accounts.values) {
      final names = _resolveNameTrail(info, accounts);
      if (names.length != normalized.length) {
        continue;
      }
      var matches = true;
      for (var i = 0; i < names.length; i++) {
        if (names[i].toLowerCase() != normalized[i]) {
          matches = false;
          break;
        }
      }
      if (matches) {
        return info;
      }
    }
    return null;
  }

  String _buildCreateActionDescription({
    required String accountName,
    String? sectionName,
    String? parentName,
  }) {
    final location = parentName != null
        ? 'under $parentName'
        : sectionName != null
            ? 'in $sectionName'
            : 'in the recommended section';
    return 'Create "$accountName" $location.';
  }

  T? _firstWhereOrNull<T>(Iterable<T> items, bool Function(T item) test) {
    for (final item in items) {
      if (test(item)) {
        return item;
      }
    }
    return null;
  }

  String _composeNarrative(FinanceCategorizationResult result) {
    final buffer = StringBuffer();
    final placement = result.placement.trim();
    if (placement.isNotEmpty) {
      buffer.writeln('This expense fits under $placement.');
    }

    if (result.accountFound && result.existingAccountPath != null) {
      buffer.writeln(
        'Use the existing account "${result.existingAccountPath}".',
      );
    } else if (result.recommendedAccount != null &&
        result.recommendedSection != null) {
      buffer.writeln(
        'No perfect match found. Create a new account named '
        '"${result.recommendedAccount}" under ${result.recommendedSection}.',
      );
    }

    if (result.reasoning != null && result.reasoning!.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(result.reasoning);
    }

    if (result.notes != null && result.notes!.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Notes: ${result.notes}');
    }

    final output = buffer.toString().trim();
    return output.isEmpty
        ? 'The assistant could not determine a recommendation.'
        : output;
  }

  String? _resolveSectionName(
    _AccountInfo account,
    Map<String, _AccountInfo> accountInfos,
    Map<String, String> sectionNameByPath,
  ) {
    if (account.sectionPath != null) {
      final cached = sectionNameByPath[account.sectionPath!];
      if (cached != null) {
        return cached;
      }
    }

    var current = account;
    final visited = HashSet<String>();
    while (true) {
      if (current.sectionPath != null) {
        final name = sectionNameByPath[current.sectionPath!];
        if (name != null) {
          account.sectionPath ??= current.sectionPath;
          return name;
        }
      }
      if (current.parentPath == null) {
        break;
      }
      if (!visited.add(current.parentPath!)) {
        break;
      }
      final parent = accountInfos[current.parentPath!];
      if (parent == null) {
        break;
      }
      current = parent;
    }
    return null;
  }

  List<String> _resolveNameTrail(
    _AccountInfo account,
    Map<String, _AccountInfo> accountInfos,
  ) {
    if (account.nameTrail != null) {
      return account.nameTrail!;
    }
    final trail = <String>[];
    final stack = <_AccountInfo>[];
    _AccountInfo? current = account;
    final visited = HashSet<String>();
    while (current != null) {
      stack.add(current);
      final parentPath = current.parentPath;
      if (parentPath == null || !visited.add(parentPath)) {
        break;
      }
      current = accountInfos[parentPath];
    }
    for (var i = stack.length - 1; i >= 0; i--) {
      final name = stack[i].name;
      if (name.isEmpty) continue;
      trail.add(name);
    }
    account.nameTrail = trail;
    return trail;
  }
}

class _CompanyProfitLossContext {
  _CompanyProfitLossContext({
    required this.payload,
    required this.sections,
    required this.accounts,
  });

  final Map<String, dynamic> payload;
  final List<_SectionInfo> sections;
  final Map<String, _AccountInfo> accounts;
}

class _SectionInfo {
  _SectionInfo({
    required this.path,
    required this.name,
    required this.position,
  });

  final String path;
  final String name;
  final int position;

  factory _SectionInfo.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return _SectionInfo(
      path: doc.reference.path,
      name: (data['name'] as String?)?.trim() ?? '',
      position: (data['position'] as num?)?.toInt() ?? 0,
    );
  }
}

class _AccountInfo {
  _AccountInfo({
    required this.path,
    required this.name,
    required this.parentPath,
    required this.sectionPath,
  });

  final String path;
  final String name;
  final String? parentPath;
  String? sectionPath;
  List<String>? nameTrail;

  factory _AccountInfo.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final parentRef = data['parentAccountId'] as DocumentReference?;
    final sectionRef = data['profitLossId'] as DocumentReference?;
    return _AccountInfo(
      path: doc.reference.path,
      name: (data['name'] as String?)?.trim() ?? '',
      parentPath: parentRef?.path,
      sectionPath: sectionRef?.path,
    );
  }

  bool hasChildren(Map<String, _AccountInfo> accountInfos) {
    for (final info in accountInfos.values) {
      if (info.parentPath == path) {
        return true;
      }
    }
    return false;
  }
}
