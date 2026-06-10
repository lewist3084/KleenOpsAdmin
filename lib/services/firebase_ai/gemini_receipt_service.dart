import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';

/// One receipt image to analyze. Passing more than one image means the photos
/// are pages/sections of a SINGLE long receipt — they are analyzed together as
/// one transaction (one vendor, one total, one combined line-item list).
class ReceiptImageInput {
  ReceiptImageInput(this.bytes, {this.mimeType});

  final Uint8List bytes;
  final String? mimeType;
}

class GeminiReceiptService {
  GeminiReceiptService({FirebaseAI? firebaseAI})
      : _firebaseAI = firebaseAI ?? FirebaseAI.vertexAI();

  static const String _model = 'gemini-2.5-flash';
  static const int _defaultMaxOutputTokens = 2048;

  final FirebaseAI _firebaseAI;

  /// Reads one or more receipt images and returns the ledger fields plus a
  /// per-item breakdown ([ReceiptExtractionResult.lineItems]).
  Future<ReceiptExtractionResult> extractLedgerFields(
    List<ReceiptImageInput> images, {
    String? usageSource,
    String? usageSourceContext,
  }) async {
    final usable = images.where((i) => i.bytes.isNotEmpty).toList();
    if (usable.isEmpty) {
      throw GeminiReceiptException('No receipt image to analyze.');
    }

    final systemPrompt = [
      'You are an accounting assistant that reads receipts and fills finance ledger entries.',
      'Always respond with valid JSON that matches the response schema.',
      'If a field is not present in the document, omit it.',
    ].join(' ');

    final userPrompt = [
      if (usable.length > 1)
        'The ${usable.length} images are pages/sections of ONE receipt — '
            'combine them into a single transaction.',
      'Extract the total transaction amount (number), a short memo/description,',
      'the vendor/supplier name, the most likely debit account name, and the',
      'most likely credit account name.',
      'Also list every individual purchased item under "line_items": for each',
      'item give its description, its amount (number), and the expense',
      'account/category it most likely belongs to ("account").',
      'Group similar items under the same account name so they can be totaled.',
      'If the receipt shows the service date, return it as YYYY-MM-DD under transaction_date.',
    ].join(' ');

    final lineItemSchema = Schema.object(
      properties: {
        'description': Schema.string(),
        'amount': Schema.number(),
        'account': Schema.string(),
      },
      optionalProperties: ['amount', 'account'],
    );

    final responseSchema = Schema.object(
      properties: {
        'amount': Schema.number(),
        'memo': Schema.string(),
        'vendor': Schema.string(),
        'debit_account': Schema.string(),
        'credit_account': Schema.string(),
        'transaction_date': Schema.string(),
        'line_items': Schema.array(items: lineItemSchema),
      },
      optionalProperties: [
        'amount',
        'memo',
        'vendor',
        'debit_account',
        'credit_account',
        'transaction_date',
        'line_items',
      ],
    );

    final model = _firebaseAI.generativeModel(
      model: _model,
      generationConfig: GenerationConfig(
        temperature: 0.0,
        maxOutputTokens: _defaultMaxOutputTokens,
        responseMimeType: 'application/json',
        responseSchema: responseSchema,
      ),
      systemInstruction: Content.system(systemPrompt),
    );

    final parts = <Part>[TextPart(userPrompt)];
    for (final image in usable) {
      final mime = _normalizeMimeType(image.mimeType) ?? 'image/jpeg';
      parts.add(InlineDataPart(mime, image.bytes));
    }

    final response =
        await model.generateContent(<Content>[Content.multi(parts)]);

    final jsonText = _extractJson(response.text);
    if (jsonText == null || jsonText.isEmpty) {
      throw GeminiReceiptException(
        'Receipt response did not include JSON content.',
      );
    }

    Map<String, dynamic> parsed;
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is! Map) {
        throw const FormatException('Expected a JSON object.');
      }
      parsed = decoded.map((key, value) => MapEntry(key.toString(), value));
    } catch (err) {
      throw GeminiReceiptException('Unable to decode receipt JSON: $err');
    }

    return ReceiptExtractionResult(
      amount: _asDouble(parsed['amount']),
      memo: _asString(parsed['memo']),
      vendorName: _asString(parsed['vendor']),
      debitAccountName: _asString(parsed['debit_account']),
      creditAccountName: _asString(parsed['credit_account']),
      transactionDate: _parseDate(parsed['transaction_date']),
      lineItems: _parseLineItems(parsed['line_items']),
      rawJson: jsonText,
    );
  }

  String? _normalizeMimeType(String? mimeType) {
    final trimmed = mimeType?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed.split(';').first.trim();
  }

  /// Pulls the JSON payload out of a model response, tolerating ```json fences.
  static String? _extractJson(String? text) {
    if (text == null) return null;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    final fenced = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```', caseSensitive: false)
        .firstMatch(trimmed);
    if (fenced != null) {
      final payload = fenced.group(1)?.trim();
      if (payload != null && payload.isNotEmpty) return payload;
    }
    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      return trimmed.substring(start, end + 1);
    }
    return trimmed;
  }

  static List<ReceiptLineItem> _parseLineItems(dynamic value) {
    if (value is! List) return const [];
    final items = <ReceiptLineItem>[];
    for (final raw in value) {
      if (raw is! Map) continue;
      final description = _asString(raw['description']);
      if (description == null) continue;
      items.add(
        ReceiptLineItem(
          description: description,
          amount: _asDouble(raw['amount']),
          account: _asString(raw['account']),
        ),
      );
    }
    return items;
  }

  static double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(RegExp(r'[^0-9.+-]'), ''));
    }
    return null;
  }

  static String? _asString(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}

/// One extracted purchase line with the account/category the model suggests.
class ReceiptLineItem {
  const ReceiptLineItem({
    required this.description,
    this.amount,
    this.account,
  });

  final String description;
  final double? amount;

  /// The suggested expense account/category name. May be null when the model
  /// could not categorize the item.
  final String? account;

  /// Account label used for grouping, falling back to a generic bucket.
  String get accountLabel => (account != null && account!.trim().isNotEmpty)
      ? account!.trim()
      : 'Uncategorized';

  Map<String, dynamic> toMap() => <String, dynamic>{
        'description': description,
        if (amount != null) 'amount': amount,
        if (account != null && account!.trim().isNotEmpty)
          'account': account!.trim(),
      };
}

class ReceiptExtractionResult {
  const ReceiptExtractionResult({
    required this.amount,
    required this.memo,
    required this.vendorName,
    required this.debitAccountName,
    required this.creditAccountName,
    required this.transactionDate,
    required this.lineItems,
    required this.rawJson,
  });

  final double? amount;
  final String? memo;
  final String? vendorName;
  final String? debitAccountName;
  final String? creditAccountName;
  final DateTime? transactionDate;
  final List<ReceiptLineItem> lineItems;
  final String rawJson;

  bool get hasAnyData =>
      amount != null ||
      memo != null ||
      vendorName != null ||
      debitAccountName != null ||
      creditAccountName != null ||
      transactionDate != null ||
      lineItems.isNotEmpty;
}

class GeminiReceiptException implements Exception {
  GeminiReceiptException(this.message);
  final String message;

  @override
  String toString() => 'GeminiReceiptException: $message';
}
