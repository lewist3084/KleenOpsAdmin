import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

/// Analyzes incoming emails using Gemini to produce summaries and junk scores.
///
/// Mirrors FuLi's GeminiMailAnalyzer but adapted for KleenOps company context.
class GeminiEmailAnalyzer {
  GeminiEmailAnalyzer._();
  static final instance = GeminiEmailAnalyzer._();

  // gemini-2.5-flash-lite: cheapest tier + highest rate limits, matched to the
  // server-side summarizer. This client path is now only a fallback for emails
  // the server trigger hasn't stamped yet.
  static final GenerativeModel _model =
      FirebaseAI.vertexAI().generativeModel(
    model: 'gemini-2.5-flash-lite',
    generationConfig: GenerationConfig(
      temperature: 0.2,
      maxOutputTokens: 300,
      responseMimeType: 'application/json',
    ),
  );

  /// Strip quoted reply history / forwarded-header blocks so we only summarize
  /// the new content. Mirrors `stripQuotedReply` in functions/inboundEmail.js.
  static String _stripQuotedReply(String text) {
    if (text.isEmpty) return '';
    final boundaries = <RegExp>[
      RegExp(r'^\s*>'),
      RegExp(r'^\s*on .{0,200}wrote:\s*$', caseSensitive: false),
      RegExp(r'^\s*on .{0,200}<[^>]+@[^>]+>\s*$', caseSensitive: false),
      RegExp(r'^\s*-----\s*original message\s*-----', caseSensitive: false),
      RegExp(r'^\s*________+\s*$'),
      RegExp(r'^\s*from:\s.+$', caseSensitive: false),
    ];
    final lines = text.split(RegExp(r'\r?\n'));
    var cut = lines.length;
    for (var i = 0; i < lines.length; i++) {
      if (boundaries.any((re) => re.hasMatch(lines[i]))) {
        cut = i;
        break;
      }
    }
    final head = lines.sublist(0, cut).join('\n').trim();
    return head.length >= 20 ? head : text.trim();
  }

  bool _circuitOpen = false;
  DateTime? _circuitResetAt;
  int _consecutiveFailures = 0;

  /// Outcome of an analysis attempt — lets callers distinguish a transient
  /// block (circuit open, try again later) from a hard failure (give up and
  /// mark this email so we don't loop forever).
  Future<EmailAnalysisOutcome> analyzeEmail({
    required String subject,
    required String from,
    required String snippet,
    String? body,
    bool isSent = false,
  }) async {
    if (_circuitOpen) {
      if (_circuitResetAt != null &&
          DateTime.now().isAfter(_circuitResetAt!)) {
        _circuitOpen = false;
        _consecutiveFailures = 0;
      } else {
        return const EmailAnalysisOutcome.skipped();
      }
    }

    try {
      final prompt = StringBuffer()
        ..writeln('Analyze this email and return a JSON object with these fields:')
        ..writeln('- "summary": A 1-2 sentence summary of the email.')
        ..writeln('- "summaryList": An array of up to 3 short bullet points.')
        ..writeln('- "junkConfidence": A float 0.0-1.0 indicating junk/spam likelihood.')
        ..writeln('- "hasActionItem": Boolean, true if there is an action item or task.')
        ..writeln('- "senderName": The actual person who wrote this email, taken'
            ' from the sign-off/signature (e.g. "Angie Wells"), or null if'
            ' unknown. Not the company/mailbox name.')
        ..writeln('')
        ..writeln('Email:')
        ..writeln('From: $from')
        ..writeln('Subject: $subject')
        ..writeln(isSent ? '(This is a sent email)' : '')
        ..writeln('')
        ..writeln(() {
          final clean =
              body != null && body.isNotEmpty ? _stripQuotedReply(body) : '';
          if (clean.isEmpty) return snippet;
          return clean.substring(0, clean.length.clamp(0, 1200));
        }());

      final response = await _model.generateContent(
        [Content.text(prompt.toString())],
      );

      final text = response.text?.trim();
      if (text == null || text.isEmpty) {
        debugPrint('[GeminiEmailAnalyzer] Empty response for "$subject"');
        return _recordFailure('empty response');
      }

      final json = jsonDecode(text) as Map<String, dynamic>;
      _consecutiveFailures = 0;

      return EmailAnalysisOutcome.success(EmailAnalysisResult(
        summary: json['summary'] as String? ?? '',
        summaryList: (json['summaryList'] as List<dynamic>?)
                ?.whereType<String>()
                .toList() ??
            [],
        junkConfidence: (json['junkConfidence'] as num?)?.toDouble() ?? 0.0,
        hasActionItem: json['hasActionItem'] as bool? ?? false,
        senderName: (json['senderName'] as String?)?.trim().isNotEmpty == true
            ? (json['senderName'] as String).trim()
            : null,
      ));
    } catch (e, st) {
      debugPrint('[GeminiEmailAnalyzer] Analysis failed for "$subject": $e');
      debugPrint('$st');
      return _recordFailure(e.toString());
    }
  }

  EmailAnalysisOutcome _recordFailure(String reason) {
    _consecutiveFailures++;
    if (_consecutiveFailures >= 3) {
      _circuitOpen = true;
      final backoffSeconds = (60 * _consecutiveFailures).clamp(60, 600);
      _circuitResetAt =
          DateTime.now().add(Duration(seconds: backoffSeconds));
      debugPrint(
        '[GeminiEmailAnalyzer] Circuit opened after $_consecutiveFailures failures. '
        'Reset at $_circuitResetAt',
      );
    }
    return EmailAnalysisOutcome.failed(reason);
  }

  /// Analyze an email and persist the results to its Firestore document.
  ///
  /// On hard failure, stamps `emailSummaryEngine: 'failed'` so the tile stops
  /// looping. On circuit-breaker skip, leaves the doc untouched so a later
  /// rebuild can retry.
  Future<void> analyzeAndPersist({
    required DocumentReference<Map<String, dynamic>> emailRef,
    required String subject,
    required String from,
    required String snippet,
    String? body,
    bool isSent = false,
  }) async {
    final outcome = await analyzeEmail(
      subject: subject,
      from: from,
      snippet: snippet,
      body: body,
      isSent: isSent,
    );

    if (outcome.isSkipped) return;
    if (outcome.isFailed) {
      await emailRef.update({
        'emailSummaryEngine': 'failed',
        'emailSummaryError': outcome.failureReason,
      });
      return;
    }
    final result = outcome.result!;
    await emailRef.update({
      'emailSummary': result.summary,
      'emailSummaryList': result.summaryList,
      // If the model returned no usable summary, stamp 'failed' so the
      // re-summarize-empty trigger doesn't loop on it forever (tile then
      // falls back to the raw preview as a last resort).
      'emailSummaryEngine':
          result.summary.trim().isEmpty ? 'failed' : 'gemini_2_5_flash_lite',
      'junkConfidence': result.junkConfidence,
      'emailHasActionItem': result.hasActionItem,
      if (result.senderName != null) 'emailSenderPerson': result.senderName,
    });
    // High-confidence junk is routed straight to Trash so it leaves the
    // inbox, but stays reviewable in the Trash tab (the retained
    // junkConfidence drives a "Junk %" badge there). The user can restore it.
    if (!isSent && result.junkConfidence >= 0.75) {
      await emailRef.update({'folder': 'Trash', 'isDeleted': true});
    }
  }
}

class EmailAnalysisOutcome {
  final EmailAnalysisResult? result;
  final String? failureReason;
  final bool isSkipped;

  const EmailAnalysisOutcome._({
    this.result,
    this.failureReason,
    this.isSkipped = false,
  });

  const EmailAnalysisOutcome.success(EmailAnalysisResult r)
      : this._(result: r);
  const EmailAnalysisOutcome.failed(String reason)
      : this._(failureReason: reason);
  const EmailAnalysisOutcome.skipped() : this._(isSkipped: true);

  bool get isFailed => failureReason != null;
}

class EmailAnalysisResult {
  final String summary;
  final List<String> summaryList;
  final double junkConfidence;
  final bool hasActionItem;
  final String? senderName;

  const EmailAnalysisResult({
    required this.summary,
    required this.summaryList,
    required this.junkConfidence,
    required this.hasActionItem,
    this.senderName,
  });
}
