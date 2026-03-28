import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Service for registering and managing domains via Cloudflare
/// for companies during onboarding.
class DomainProvisioningService {
  DomainProvisioningService._();
  static final instance = DomainProvisioningService._();

  final _functions = FirebaseFunctions.instance;

  /// Check if a domain is available for registration.
  ///
  /// Returns availability, price, and suggested alternatives.
  Future<Map<String, dynamic>> checkAvailability({
    required String companyId,
    required String domainName,
  }) async {
    final callable = _functions.httpsCallable('domainCheckAvailability');
    final result = await callable.call<Map<String, dynamic>>({
      'companyId': companyId,
      'domainName': domainName,
    });
    return Map<String, dynamic>.from(result.data);
  }

  /// Register a domain via Cloudflare Registrar.
  ///
  /// [registrant] sets the customer as the legal owner of the domain.
  /// Should contain: firstName, lastName, organization, email, phone,
  /// address1, city, state, zip, country.
  Future<Map<String, dynamic>> register({
    required String companyId,
    required String domainName,
    bool autoRenew = true,
    Map<String, dynamic>? registrant,
  }) async {
    final callable = _functions.httpsCallable('domainRegister');
    final result = await callable.call<Map<String, dynamic>>({
      'companyId': companyId,
      'domainName': domainName,
      'autoRenew': autoRenew,
      if (registrant != null) 'registrant': registrant,
    });
    return Map<String, dynamic>.from(result.data);
  }

  /// Get the current status of a registered domain.
  Future<Map<String, dynamic>> getStatus({
    required String companyId,
    required String domainDocId,
  }) async {
    final callable = _functions.httpsCallable('domainGetStatus');
    final result = await callable.call<Map<String, dynamic>>({
      'companyId': companyId,
      'domainDocId': domainDocId,
    });
    return Map<String, dynamic>.from(result.data);
  }

  /// Configure DNS records for a domain.
  ///
  /// [records] is a list of maps with: action (create/update/delete),
  /// type, name, content, ttl, priority, proxied.
  Future<Map<String, dynamic>> configureDns({
    required String companyId,
    required String domainDocId,
    required List<Map<String, dynamic>> records,
  }) async {
    final callable = _functions.httpsCallable('domainConfigureDns');
    final result = await callable.call<Map<String, dynamic>>({
      'companyId': companyId,
      'domainDocId': domainDocId,
      'records': records,
    });
    return Map<String, dynamic>.from(result.data);
  }

  /// List all domains for a company.
  Future<List<Map<String, dynamic>>> listProvisioned({
    required String companyId,
  }) async {
    final callable = _functions.httpsCallable('domainListProvisioned');
    final result = await callable.call<Map<String, dynamic>>({
      'companyId': companyId,
    });
    final data = Map<String, dynamic>.from(result.data);
    final domains = (data['domains'] as List?) ?? [];
    return domains.cast<Map<String, dynamic>>();
  }

  /// Request a transfer authorization code to move the domain
  /// to another registrar. Unlocks the domain for transfer.
  Future<Map<String, dynamic>> requestTransfer({
    required String companyId,
    required String domainDocId,
  }) async {
    final callable = _functions.httpsCallable('domainRequestTransfer');
    final result = await callable.call<Map<String, dynamic>>({
      'companyId': companyId,
      'domainDocId': domainDocId,
    });
    return Map<String, dynamic>.from(result.data);
  }

  /// Watch domains for a company in real time.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchProvisioned(
    DocumentReference<Map<String, dynamic>> companyRef,
  ) {
    return companyRef
        .collection('domain')
        .where('status', whereIn: ['active', 'pending'])
        .orderBy('registeredAt', descending: true)
        .snapshots();
  }
}
