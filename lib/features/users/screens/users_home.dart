// lib/features/users/screens/users_home.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/tiles/standard_bubble_tile.dart';

import '../../../app/routes.dart';
import '../../../services/admin_firebase_service.dart';
import '../../../theme/palette.dart';

class UsersHome extends StatelessWidget {
  const UsersHome({super.key});

  @override
  Widget build(BuildContext context) {
    const palette = adminPalette;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Platform Users'),
        backgroundColor: palette.primary1,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutePaths.dashboard),
        ),
      ),
      body: StandardCanvas(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: AdminFirebaseService.instance.allUsers(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return const Center(child: Text('No users found.'));
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data();
                final email = data['email'] as String? ?? '';
                final name = data['name'] as String? ?? email;

                return StandardBubbleTile(
                  title: name,
                  description: email,
                  leadingIcon: Icons.person,
                  trailing: Text(doc.id.substring(0, 8),
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey)),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
