// lib/widgets/viewers/video_viewer.dart
//
// Admin port placeholder. The kleenops VideoViewer plays the clip inline via
// the video_player/chewie stack, which the admin app doesn't ship. This
// lightweight viewer shows the source URL so the task-alert "Videos" list
// stays navigable; wire in real playback if/when the admin app adds the deps.
import 'package:flutter/material.dart';

class VideoViewer extends StatelessWidget {
  const VideoViewer({super.key, required this.videoUrl});

  final String videoUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Video')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off_outlined, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Inline video playback is not available in the admin app yet.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              SelectableText(
                videoUrl,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
