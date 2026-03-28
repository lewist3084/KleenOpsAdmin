import 'package:cloud_functions/cloud_functions.dart';

/// Service for generating and deploying company landing page websites
/// via Cloudflare Pages.
class WebsiteService {
  WebsiteService._();
  static final instance = WebsiteService._();

  final _functions = FirebaseFunctions.instance;

  /// Generate and deploy a website for a company.
  ///
  /// Pulls company data from Firestore, generates HTML from template,
  /// deploys to Cloudflare Pages, and optionally configures a custom domain.
  Future<Map<String, dynamic>> generateAndDeploy({
    required String companyId,
    String? domainDocId,
    Map<String, dynamic>? options,
  }) async {
    final callable = _functions.httpsCallable(
      'websiteGenerateAndDeploy',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
    );
    final result = await callable.call<Map<String, dynamic>>({
      'companyId': companyId,
      'domainDocId': domainDocId,
      'options': options,
    });
    return Map<String, dynamic>.from(result.data);
  }

  /// Check website deployment status for a company.
  Future<Map<String, dynamic>> getStatus({
    required String companyId,
  }) async {
    final callable = _functions.httpsCallable('websiteGetStatus');
    final result = await callable.call<Map<String, dynamic>>({
      'companyId': companyId,
    });
    return Map<String, dynamic>.from(result.data);
  }
}
