// Firestore-based message board service for admin app.
// Mirrors the kleenops MessageBoardService operating on the same collections.
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/message_board_post.dart';

class MessageBoardService {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final DocumentReference<Map<String, dynamic>> memberRef;
  final String memberName;

  MessageBoardService({
    required this.companyRef,
    required this.memberRef,
    required this.memberName,
  });

  CollectionReference<Map<String, dynamic>> get _postsRef =>
      companyRef.collection('messageBoardPost');

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

      for (final post in posts) {
        if (post.isExpired) {
          _postsRef.doc(post.id).update({
            'isArchived': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      return posts.where((p) => !p.isExpired).toList();
    });
  }

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

  Future<void> archivePost(String postId) async {
    await _postsRef.doc(postId).update({
      'isArchived': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> restorePost(String postId) async {
    await _postsRef.doc(postId).update({
      'isArchived': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deletePost(String postId) async {
    await _postsRef.doc(postId).delete();
  }

  Future<void> togglePin(String postId, bool isPinned) async {
    await _postsRef.doc(postId).update({
      'isPinned': isPinned,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
