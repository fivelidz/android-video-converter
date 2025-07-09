import 'package:flutter/material.dart';
import '../../data/models/video_file.dart';

class VideoFileCard extends StatelessWidget {
  final VideoFile videoFile;
  final VoidCallback? onTap;

  const VideoFileCard({
    super.key,
    required this.videoFile,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: const Icon(
          Icons.video_file,
          size: 40,
          color: Colors.deepPurple,
        ),
        title: Text(
          videoFile.displayName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Format: ${videoFile.extension.toUpperCase()}'),
            Text('Size: ${videoFile.sizeFormatted}'),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}