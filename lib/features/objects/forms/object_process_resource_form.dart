import 'package:cloud_firestore/cloud_firestore.dart';

import '../../processes/forms/processes_resources_form.dart';

/// Object-process wrapper for the shared resources form.
class ObjectProcessResourceFormContent extends ProcessesResourcesFormContent {
  const ObjectProcessResourceFormContent({
    super.key,
    required DocumentReference companyId,
    String? docId,
    String? companyObjectIdPath,
  }) : super(
          companyId: companyId,
          docId: docId,
          companyObjectIdPath: companyObjectIdPath,
        );
}
