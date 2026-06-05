// lib/common/communications/messageboard/services/message_board_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_board_post.dart';

/// Timeline category ID for message board posts.
const String kMessageBoardTimelineCategoryId = 'message_board_category';

/// Service for managing message board posts.
class MessageBoardService {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final DocumentReference<Map<String, dynamic>> memberRef;
  final String memberName;
  final String? memberAvatarUrl;

  MessageBoardService({
    required this.companyRef,
    required this.memberRef,
    required this.memberName,
    this.memberAvatarUrl,
  });

  /// Collection reference for message board posts.
  CollectionReference<Map<String, dynamic>> get _postsRef =>
      companyRef.collection('messageBoardPost');

  /// Stream of active (non-archived) board posts for accessible teams.
  ///
  /// Expired posts are filtered client-side and auto-archived.
  Stream<List<MessageBoardPost>> watchPosts({
    List<DocumentReference>? teamRefs,
  }) {
    Query<Map<String, dynamic>> query =
        _postsRef.where('isArchived', isEqualTo: false);

    if (teamRefs != null && teamRefs.isNotEmpty) {
      query = query.where('teamRefs',
          arrayContainsAny: teamRefs.take(10).toList());
    }

    return query
        .orderBy('isPinned', descending: true)
        .orderBy('priority', descending: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
      final posts = snap.docs
          .map((doc) => MessageBoardPost.fromFirestore(doc))
          .toList();

      // Auto-archive expired posts in the background
      for (final post in posts) {
        if (post.isExpired) {
          _postsRef.doc(post.id).update({
            'isArchived': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // Return only non-expired posts
      return posts.where((p) => !p.isExpired).toList();
    });
  }

  /// Stream of archived (expired or manually removed) posts â€” the history view.
  Stream<List<MessageBoardPost>> watchArchivedPosts({
    List<DocumentReference>? teamRefs,
  }) {
    Query<Map<String, dynamic>> query =
        _postsRef.where('isArchived', isEqualTo: true);

    if (teamRefs != null && teamRefs.isNotEmpty) {
      query = query.where('teamRefs',
          arrayContainsAny: teamRefs.take(10).toList());
    }

    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => MessageBoardPost.fromFirestore(doc))
            .toList());
  }

  /// Stream of only pinned posts.
  Stream<List<MessageBoardPost>> watchPinnedPosts({
    List<DocumentReference>? teamRefs,
  }) {
    Query<Map<String, dynamic>> query = _postsRef
        .where('isPinned', isEqualTo: true)
        .where('isArchived', isEqualTo: false);

    if (teamRefs != null && teamRefs.isNotEmpty) {
      query = query.where('teamRefs',
          arrayContainsAny: teamRefs.take(10).toList());
    }

    return query
        .orderBy('priority', descending: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => MessageBoardPost.fromFirestore(doc))
            .toList());
  }

  /// Archive a post (remove from the active board).
  Future<void> archivePost(String postId) async {
    await _postsRef.doc(postId).update({
      'isArchived': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Restore an archived post back to the active board.
  Future<void> restorePost(String postId) async {
    await _postsRef.doc(postId).update({
      'isArchived': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Create a new message board post.
  Future<MessageBoardPost> createPost({
    required String title,
    String? content,
    required MessageBoardPostType type,
    bool isPinned = false,
    int priority = 0,
    String? noteColor,
    String? fileUrl,
    String? thumbnailUrl,
    String? fileName,
    String? mimeType,
    int? fileSizeBytes,
    String? linkUrl,
    required List<DocumentReference<Map<String, dynamic>>> teamRefs,
    required List<String> teamNames,
    List<String> tags = const [],
    DateTime? expiresAt,
  }) async {
    final payload = {
      'title': title,
      if (content != null) 'content': content,
      'type': type.name,
      'isPinned': isPinned,
      'priority': priority,
      'isArchived': false,
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt),
      if (noteColor != null) 'noteColor': noteColor,
      if (fileUrl != null) 'fileUrl': fileUrl,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      if (fileName != null) 'fileName': fileName,
      if (mimeType != null) 'mimeType': mimeType,
      if (fileSizeBytes != null) 'fileSizeBytes': fileSizeBytes,
      if (linkUrl != null) 'linkUrl': linkUrl,
      'createdByRef': memberRef,
      'createdByName': memberName,
      if (memberAvatarUrl != null) 'createdByAvatarUrl': memberAvatarUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'teamRefs': teamRefs,
      'teamNames': teamNames,
      'tags': tags,
    };

    final docRef = await _postsRef.add(payload);

    // Create timeline entry
    await _createTimelineEntry(
      postRef: docRef,
      title: title,
      type: type,
      teamRefs: teamRefs,
    );

    // Create file entry if applicable
    if (fileUrl != null) {
      await _createFileEntry(
        postRef: docRef,
        fileUrl: fileUrl,
        thumbnailUrl: thumbnailUrl,
        fileName: fileName,
        mimeType: mimeType,
        fileSizeBytes: fileSizeBytes,
        type: type,
      );
    }

    final doc = await docRef.get();
    return MessageBoardPost.fromFirestore(doc);
  }

  /// Update an existing message board post.
  Future<void> updatePost({
    required String postId,
    String? title,
    String? content,
    bool? isPinned,
    int? priority,
    String? noteColor,
    String? fileUrl,
    String? thumbnailUrl,
    String? fileName,
    String? mimeType,
    int? fileSizeBytes,
    String? linkUrl,
    List<DocumentReference<Map<String, dynamic>>>? teamRefs,
    List<String>? teamNames,
    List<String>? tags,
    DateTime? expiresAt,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (title != null) updates['title'] = title;
    if (content != null) updates['content'] = content;
    if (isPinned != null) updates['isPinned'] = isPinned;
    if (priority != null) updates['priority'] = priority;
    if (noteColor != null) updates['noteColor'] = noteColor;
    if (fileUrl != null) updates['fileUrl'] = fileUrl;
    if (thumbnailUrl != null) updates['thumbnailUrl'] = thumbnailUrl;
    if (fileName != null) updates['fileName'] = fileName;
    if (mimeType != null) updates['mimeType'] = mimeType;
    if (fileSizeBytes != null) updates['fileSizeBytes'] = fileSizeBytes;
    if (linkUrl != null) updates['linkUrl'] = linkUrl;
    if (teamRefs != null) updates['teamRefs'] = teamRefs;
    if (teamNames != null) updates['teamNames'] = teamNames;
    if (tags != null) updates['tags'] = tags;
    if (expiresAt != null) updates['expiresAt'] = Timestamp.fromDate(expiresAt);

    await _postsRef.doc(postId).update(updates);
  }

  /// Toggle pin status for a post.
  Future<void> togglePin(String postId, bool isPinned) async {
    await _postsRef.doc(postId).update({
      'isPinned': isPinned,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete a message board post.
  Future<void> deletePost(String postId) async {
    // Delete associated file entries
    final fileSnap = await companyRef
        .collection('file')
        .where('messageBoardPostId', isEqualTo: _postsRef.doc(postId))
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in fileSnap.docs) {
      batch.delete(doc.reference);
    }

    // Delete the post
    batch.delete(_postsRef.doc(postId));

    await batch.commit();
  }

  /// Create a timeline entry for the message board post.
  Future<void> _createTimelineEntry({
    required DocumentReference postRef,
    required String title,
    required MessageBoardPostType type,
    required List<DocumentReference<Map<String, dynamic>>> teamRefs,
  }) async {
    final timelineCategoryRef = FirebaseFirestore.instance
        .collection('timelineCategory')
        .doc(kMessageBoardTimelineCategoryId);

    await companyRef.collection('timeline').add({
      'timelineCategory': kMessageBoardTimelineCategoryId,
      'timelineCategoryId': timelineCategoryRef,
      'messageBoardPostId': postRef,
      'title': title,
      'name': title,
      'description': 'Message board post: $title',
      'snippet': 'New ${type.name} posted to message board',
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': memberRef,
      'createdByName': memberName,
      'memberId': memberRef,
      'teamIds': teamRefs,
    });
  }

  /// Create a file entry for document/image/video posts.
  Future<void> _createFileEntry({
    required DocumentReference postRef,
    required String fileUrl,
    String? thumbnailUrl,
    String? fileName,
    String? mimeType,
    int? fileSizeBytes,
    required MessageBoardPostType type,
  }) async {
    String mediaType;
    switch (type) {
      case MessageBoardPostType.image:
        mediaType = 'image';
        break;
      case MessageBoardPostType.video:
        mediaType = 'video';
        break;
      default:
        mediaType = 'document';
    }

    await companyRef.collection('file').add({
      'messageBoardPostId': postRef,
      'url': fileUrl,
      'fileUrl': fileUrl,
      'downloadUrl': fileUrl,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      if (fileName != null) 'fileName': fileName,
      if (fileName != null) 'name': fileName,
      if (mimeType != null) 'mimeType': mimeType,
      if (mimeType != null) 'contentType': mimeType,
      if (fileSizeBytes != null) 'sizeBytes': fileSizeBytes,
      'mediaType': mediaType,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get file info for a message board post.
  Future<Map<String, dynamic>?> getFileInfo(String postId) async {
    final snap = await companyRef
        .collection('file')
        .where('messageBoardPostId', isEqualTo: _postsRef.doc(postId))
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return snap.docs.first.data();
  }
}

