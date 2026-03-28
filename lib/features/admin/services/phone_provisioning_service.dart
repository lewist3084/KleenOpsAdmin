import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Service for provisioning and managing Twilio phone numbers
/// for companies during onboarding.
class PhoneProvisioningService {
  PhoneProvisioningService._();
  static final instance = PhoneProvisioningService._();

  final _functions = FirebaseFunctions.instance;

  /// Create a Twilio subaccount for a company.
  /// This is called automatically during provisioning if needed.
  Future<Map<String, dynamic>> createSubaccount({
    required String companyId,
  }) async {
    final callable = _functions.httpsCallable('phoneCreateSubaccount');
    final result = await callable.call<Map<String, dynamic>>({
      'companyId': companyId,
    });
    return Map<String, dynamic>.from(result.data);
  }

  /// Search for available phone numbers by area code, state, etc.
  ///
  /// Returns a list of available numbers with their capabilities.
  Future<List<Map<String, dynamic>>> searchAvailable({
    required String companyId,
    String? areaCode,
    String? state,
    String? contains,
    bool sms = true,
    bool voice = true,
    bool mms = false,
  }) async {
    final callable = _functions.httpsCallable('phoneSearchAvailable');
    final result = await callable.call<Map<String, dynamic>>({
      'companyId': companyId,
      'areaCode': areaCode,
      'state': state,
      'contains': contains,
      'capabilities': {
        'sms': sms,
        'voice': voice,
        'mms': mms,
      },
    });

    final data = Map<String, dynamic>.from(result.data);
    final numbers = (data['numbers'] as List?) ?? [];
    return numbers.cast<Map<String, dynamic>>();
  }

  /// Provision (purchase) a specific phone number for a company.
  ///
  /// Returns the created phone number document data including its Firestore ID.
  Future<Map<String, dynamic>> provision({
    required String companyId,
    required String phoneNumber,
    String? forwardTo,
    String? label,
  }) async {
    final callable = _functions.httpsCallable('phoneProvision');
    final result = await callable.call<Map<String, dynamic>>({
      'companyId': companyId,
      'phoneNumber': phoneNumber,
      'forwardTo': forwardTo,
      'label': label,
    });

    return Map<String, dynamic>.from(result.data);
  }

  /// Release a provisioned phone number.
  Future<void> release({
    required String companyId,
    required String phoneDocId,
  }) async {
    final callable = _functions.httpsCallable('phoneRelease');
    await callable.call({
      'companyId': companyId,
      'phoneDocId': phoneDocId,
    });
  }

  /// Update call forwarding for an existing provisioned number.
  Future<void> configureForwarding({
    required String companyId,
    required String phoneDocId,
    String? forwardTo,
  }) async {
    final callable = _functions.httpsCallable('phoneConfigureForwarding');
    await callable.call({
      'companyId': companyId,
      'phoneDocId': phoneDocId,
      'forwardTo': forwardTo,
    });
  }

  /// List all provisioned numbers for a company.
  Future<List<Map<String, dynamic>>> listProvisioned({
    required String companyId,
    bool includeReleased = false,
  }) async {
    final callable = _functions.httpsCallable('phoneListProvisioned');
    final result = await callable.call<Map<String, dynamic>>({
      'companyId': companyId,
      'includeReleased': includeReleased,
    });

    final data = Map<String, dynamic>.from(result.data);
    final numbers = (data['numbers'] as List?) ?? [];
    return numbers.cast<Map<String, dynamic>>();
  }

  /// Request port-out info for transferring a number to another carrier.
  Future<Map<String, dynamic>> requestPortOut({
    required String companyId,
    required String phoneDocId,
  }) async {
    final callable = _functions.httpsCallable('phoneRequestPortOut');
    final result = await callable.call<Map<String, dynamic>>({
      'companyId': companyId,
      'phoneDocId': phoneDocId,
    });
    return Map<String, dynamic>.from(result.data);
  }

  /// Watch provisioned numbers for a company in real time.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchProvisioned(
    DocumentReference<Map<String, dynamic>> companyRef,
  ) {
    return companyRef
        .collection('phoneNumber')
        .where('status', isEqualTo: 'active')
        .orderBy('provisionedAt', descending: true)
        .snapshots();
  }
}
