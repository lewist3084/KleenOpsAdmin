// gemini_bookkeeper_service.dart
//
// Batch "AI Bookkeeper" pass. Given the distinct merchants in the imported
// bank transactions, the existing chart (sections + accounts), the model
// assigns each merchant to a GL account — reusing an existing account where it
// fits, otherwise PROPOSING a new account (name + section + type). One Gemini
// call covers all merchants (far cheaper than per-transaction), and the
// merchant→account result doubles as the learned-rule set.

import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';

/// A merchant the model needs to place, with a representative direction +
/// Plaid category to inform the decision.
class BookkeeperMerchant {
  final String name;
  final bool isIncome; // amount < 0 in Plaid convention
  final String? plaidCategory;
  final String? plaidCategoryDetailed;
  const BookkeeperMerchant({
    required this.name,
    required this.isIncome,
    this.plaidCategory,
    this.plaidCategoryDetailed,
  });
}

/// An existing GL account the model may reuse.
class BookkeeperAccount {
  final String name;
  final String section;
  final String type;
  const BookkeeperAccount({
    required this.name,
    required this.section,
    required this.type,
  });
}

/// The model's decision for one merchant.
class BookkeeperDecision {
  final String merchant;
  final String accountName;
  final bool isNew;
  final String? section; // section for a new account
  final String? type; // Revenue/Expense/Asset/Liability/Equity for a new account
  const BookkeeperDecision({
    required this.merchant,
    required this.accountName,
    required this.isNew,
    this.section,
    this.type,
  });
}

class GeminiBookkeeperService {
  GeminiBookkeeperService({FirebaseAI? firebaseAI})
      : _ai = firebaseAI ?? FirebaseAI.vertexAI();

  static const String _model = 'gemini-2.5-flash';
  final FirebaseAI _ai;

  Future<List<BookkeeperDecision>> propose({
    required List<BookkeeperMerchant> merchants,
    required List<String> sectionNames,
    required List<BookkeeperAccount> existingAccounts,
  }) async {
    if (merchants.isEmpty) return const [];

    final systemPrompt = [
      'You are a bookkeeper categorizing a business\'s bank transactions into a',
      'general-ledger chart of accounts. For EACH merchant, pick the single best',
      'account. Strongly prefer reusing an existing account (return its name',
      'verbatim, is_new=false). Only propose a NEW account (is_new=true) when no',
      'existing account reasonably fits — then give a concise standard account',
      'name, the best-fitting section (choose from the provided section list',
      'verbatim), and the account type (Revenue, Expense, Asset, Liability, or',
      'Equity). Income (money in) is usually Revenue; expenses (money out) map to',
      'an expense account; credit-card payments and transfers map to a balance',
      'sheet account (e.g. Credit Card Payable). Return JSON matching the schema.',
    ].join(' ');

    final buf = StringBuffer()
      ..writeln('Sections (use these names verbatim for new accounts):')
      ..writeln(sectionNames.map((s) => '- $s').join('\n'))
      ..writeln()
      ..writeln('Existing accounts (name — section — type):')
      ..writeln(existingAccounts
          .map((a) => '- ${a.name} — ${a.section} — ${a.type}')
          .join('\n'))
      ..writeln()
      ..writeln('Merchants to categorize:');
    for (final m in merchants) {
      buf.writeln(
          '- ${m.name.isEmpty ? '(unknown)' : m.name} | '
          '${m.isIncome ? 'INCOME (money in)' : 'EXPENSE (money out)'} | '
          'plaid: ${m.plaidCategory ?? '(none)'} / ${m.plaidCategoryDetailed ?? '(none)'}');
    }

    final responseSchema = Schema.object(
      properties: {
        'decisions': Schema.array(
          items: Schema.object(
            properties: {
              'merchant': Schema.string(),
              'account_name': Schema.string(),
              'is_new': Schema.boolean(),
              'section': Schema.string(),
              'type': Schema.string(),
            },
            optionalProperties: ['section', 'type'],
          ),
        ),
      },
    );

    final model = _ai.generativeModel(
      model: _model,
      generationConfig: GenerationConfig(
        temperature: 0.0,
        responseMimeType: 'application/json',
        responseSchema: responseSchema,
      ),
      systemInstruction: Content.system(systemPrompt),
    );

    final response =
        await model.generateContent(<Content>[Content.text(buf.toString())]);
    final text = response.text;
    if (text == null || text.trim().isEmpty) return const [];

    final jsonText = _stripFences(text);
    Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(jsonText) as Map<String, dynamic>;
    } catch (_) {
      return const [];
    }

    final raw = (parsed['decisions'] as List?) ?? const [];
    final out = <BookkeeperDecision>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final merchant = (item['merchant'] ?? '').toString();
      final accountName = (item['account_name'] ?? '').toString().trim();
      if (accountName.isEmpty) continue;
      final isNew = item['is_new'] == true;
      out.add(BookkeeperDecision(
        merchant: merchant,
        accountName: accountName,
        isNew: isNew,
        section: (item['section'] ?? '').toString().trim().isEmpty
            ? null
            : (item['section']).toString().trim(),
        type: (item['type'] ?? '').toString().trim().isEmpty
            ? null
            : (item['type']).toString().trim(),
      ));
    }
    return out;
  }

  String _stripFences(String text) {
    var t = text.trim();
    if (t.startsWith('```')) {
      final firstNl = t.indexOf('\n');
      if (firstNl != -1) t = t.substring(firstNl + 1);
      if (t.endsWith('```')) t = t.substring(0, t.length - 3);
    }
    return t.trim();
  }
}
