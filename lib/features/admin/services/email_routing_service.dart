import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Service for managing email routing (Cloudflare) and outbound
/// sending (SendGrid) for company domains.
class EmailRoutingService {
  EmailRoutingService._();
  static final instance = EmailRoutingService._();

  final _functions = FirebaseFunctions.instance;

  /// Enable Cloudflare Email Routing on a domain.
  Future<void> enableRouting({
    required String companyId,
    required String domainDocId,
  }) async {
    final callable = _functions.httpsCallable('emailEnableRouting');
    await callable.call({
      'companyId': companyId,
      'domainDocId': domainDocId,
    });
  }

  /// Create an email routing rule (e.g. info@ → owner@gmail.com).
  Future<Map<String, dynamic>> createRoute({
    required String companyId,
    required String domainDocId,
    required String fromAddress,
    required String toAddress,
    String? label,
  }) async {
    final callable = _functions.httpsCallable('emailCreateRoute');
    final result = await callable.call<Map<String, dynamic>>({
      'companyId': companyId,
      'domainDocId': domainDocId,
      'fromAddress': fromAddress,
      'toAddress': toAddress,
      'label': label,
    });
    return Map<String, dynamic>.from(result.data);
  }

  /// Delete an email routing rule.
  Future<void> deleteRoute({
    required String companyId,
    required String emailDocId,
  }) async {
    final callable = _functions.httpsCallable('emailDeleteRoute');
    await callable.call({
      'companyId': companyId,
      'emailDocId': emailDocId,
    });
  }

  /// List all email addresses/routes for a company.
  Future<List<Map<String, dynamic>>> listRoutes({
    required String companyId,
  }) async {
    final callable = _functions.httpsCallable('emailListRoutes');
    final result = await callable.call<Map<String, dynamic>>({
      'companyId': companyId,
    });
    final data = Map<String, dynamic>.from(result.data);
    final addresses = (data['addresses'] as List?) ?? [];
    return addresses.cast<Map<String, dynamic>>();
  }

  /// Add domain to SendGrid for outbound sending and auto-configure DNS.
  Future<Map<String, dynamic>> verifySendDomain({
    required String companyId,
    required String domainDocId,
  }) async {
    final callable = _functions.httpsCallable('emailVerifySendDomain');
    final result = await callable.call<Map<String, dynamic>>({
      'companyId': companyId,
      'domainDocId': domainDocId,
    });
    return Map<String, dynamic>.from(result.data);
  }

  /// Check if SendGrid domain verification is complete.
  Future<Map<String, dynamic>> getSendDomainStatus({
    required String companyId,
    required String domainDocId,
  }) async {
    final callable = _functions.httpsCallable('emailGetSendDomainStatus');
    final result = await callable.call<Map<String, dynamic>>({
      'companyId': companyId,
      'domainDocId': domainDocId,
    });
    return Map<String, dynamic>.from(result.data);
  }

  /// Set up SendGrid Inbound Parse for a domain.
  /// This enables email capture in the KleenOps app.
  Future<void> setupInboundParse({
    required String companyId,
    required String domainDocId,
  }) async {
    final callable = _functions.httpsCallable('emailSetupInboundParse');
    await callable.call({
      'companyId': companyId,
      'domainDocId': domainDocId,
    });
  }

  /// Generate SMTP credentials for outbound sending via Gmail/Outlook.
  ///
  /// Returns server, port, username, password. The password (API key)
  /// is only shown once — store it or the customer must regenerate.
  Future<Map<String, dynamic>> createSmtpKey({
    required String companyId,
    required String domainDocId,
  }) async {
    final callable = _functions.httpsCallable('emailCreateSmtpKey');
    final result = await callable.call<Map<String, dynamic>>({
      'companyId': companyId,
      'domainDocId': domainDocId,
    });
    return Map<String, dynamic>.from(result.data);
  }

  /// Watch email addresses for a company in real time.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchRoutes(
    DocumentReference<Map<String, dynamic>> companyRef,
  ) {
    return companyRef
        .collection('emailAddress')
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
