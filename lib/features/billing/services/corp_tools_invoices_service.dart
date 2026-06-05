import 'package:cloud_functions/cloud_functions.dart';

/// Reads + pays the wholesale invoices Northwest Registered Agent bills the
/// KleenOps partner account (platformAdmin-only; backed by the
/// `corpToolsListInvoices` / `corpToolsPayInvoices` Cloud Functions).
class CorpToolsInvoicesService {
  CorpToolsInvoicesService._();
  static final instance = CorpToolsInvoicesService._();

  final _functions = FirebaseFunctions.instance;

  Future<List<Map<String, dynamic>>> list({List<String>? companyIds}) async {
    final callable = _functions.httpsCallable('corpToolsListInvoices');
    final result = await callable.call<Map<String, dynamic>>({
      if (companyIds != null && companyIds.isNotEmpty) 'companyIds': companyIds,
    });
    final data = Map<String, dynamic>.from(result.data);
    final invoices = (data['invoices'] as List?) ?? const [];
    return invoices.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> pay(List<String> invoiceIds) async {
    final callable = _functions.httpsCallable('corpToolsPayInvoices');
    await callable.call<Map<String, dynamic>>({'invoiceIds': invoiceIds});
  }
}
