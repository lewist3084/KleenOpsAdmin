// Thin client over the externalSms Cloud Functions. External SMS conversations
// are sent through the backend (which calls Twilio) rather than written
// directly to Firestore, so the message both persists AND leaves as a real SMS.

import 'package:cloud_functions/cloud_functions.dart';

import '../models/text_message.dart';

class ExternalSmsService {
  ExternalSmsService._();
  static final ExternalSmsService instance = ExternalSmsService._();

  FirebaseFunctions get _fns =>
      FirebaseFunctions.instanceFor(region: 'us-central1');

  /// Send an SMS/MMS into an existing external conversation. Attachments must
  /// already be uploaded to Storage (pass their download URLs). The backend
  /// writes the outbound message doc and dispatches via Twilio.
  Future<void> sendSms({
    required String companyId,
    required String conversationId,
    required String text,
    List<TextMessageAttachment> attachments = const [],
  }) async {
    await _fns.httpsCallable('sendExternalSms').call(<String, dynamic>{
      'companyId': companyId,
      'conversationId': conversationId,
      'text': text,
      'mediaUrls': attachments
          .map((a) => {
                'url': a.url,
                if (a.fileName != null) 'fileName': a.fileName,
                if (a.mimeType != null) 'mimeType': a.mimeType,
                if (a.sizeBytes != null) 'sizeBytes': a.sizeBytes,
                'type': a.type.name,
              })
          .toList(),
    });
  }

  /// Find or create the current member's external SMS conversation for
  /// [toPhone]; returns the conversation id. Requires the member to have an
  /// assigned texting number (else the callable throws failed-precondition).
  Future<String> getOrCreateConversation({
    required String companyId,
    required String toPhone,
    String? title,
  }) async {
    final res =
        await _fns.httpsCallable('getOrCreateExternalSmsConversation').call(
      <String, dynamic>{
        'companyId': companyId,
        'toPhone': toPhone,
        if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
      },
    );
    final data = Map<String, dynamic>.from(res.data as Map);
    return data['conversationId'] as String;
  }
}

