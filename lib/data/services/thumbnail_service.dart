import 'dart:io';
import 'dart:typed_data';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';

class ThumbnailService {
  static const String _thumbnailCacheDir = 'thumbnails';
  
  static Future<String> get _thumbnailDirectoryPath async {
    final directory = await getApplicationDocumentsDirectory();
    final thumbnailDir = Directory('${directory.path}/$_thumbnailCacheDir');
    
    if (!await thumbnailDir.exists()) {
      await thumbnailDir.create(recursive: true);
    }
    
    return thumbnailDir.path;
  }

  /// Generate thumbnail for a video file
  static Future<String?> generateThumbnail(String videoPath) async {
    try {
      // Create a unique filename for the thumbnail
      final videoFile = File(videoPath);
      final videoStat = await videoFile.stat();
      final thumbnailFileName = '${videoFile.path.hashCode}_${videoStat.modified.millisecondsSinceEpoch}.jpg';
      final thumbnailDir = await _thumbnailDirectoryPath;
      final thumbnailPath = '$thumbnailDir/$thumbnailFileName';
      
      // Check if thumbnail already exists
      if (await File(thumbnailPath).exists()) {
        return thumbnailPath;
      }
      
      // Generate thumbnail
      final uint8list = await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 200,
        quality: 75,
      );
      
      if (uint8list != null) {
        final file = File(thumbnailPath);
        await file.writeAsBytes(uint8list);
        return thumbnailPath;
      }
    } catch (e) {
      print('Error generating thumbnail for $videoPath: $e');
    }
    
    return null;
  }

  /// Get cached thumbnail path if exists
  static Future<String?> getCachedThumbnail(String videoPath) async {
    try {
      final videoFile = File(videoPath);
      if (!await videoFile.exists()) return null;
      
      final videoStat = await videoFile.stat();
      final thumbnailFileName = '${videoFile.path.hashCode}_${videoStat.modified.millisecondsSinceEpoch}.jpg';
      final thumbnailDir = await _thumbnailDirectoryPath;
      final thumbnailPath = '$thumbnailDir/$thumbnailFileName';
      
      if (await File(thumbnailPath).exists()) {
        return thumbnailPath;
      }
    } catch (e) {
      print('Error getting cached thumbnail: $e');
    }
    
    return null;
  }

  /// Clear all cached thumbnails
  static Future<void> clearThumbnailCache() async {
    try {
      final thumbnailDir = await _thumbnailDirectoryPath;
      final directory = Directory(thumbnailDir);
      
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    } catch (e) {
      print('Error clearing thumbnail cache: $e');
    }
  }

  /// Get thumbnail cache size
  static Future<int> getThumbnailCacheSize() async {
    try {
      final thumbnailDir = await _thumbnailDirectoryPath;
      final directory = Directory(thumbnailDir);
      
      if (!await directory.exists()) return 0;
      
      int totalSize = 0;
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          final stat = await entity.stat();
          totalSize += stat.size;
        }
      }
      
      return totalSize;
    } catch (e) {
      print('Error calculating thumbnail cache size: $e');
      return 0;
    }
  }

  /// Clean up old thumbnails that no longer have corresponding videos
  static Future<void> cleanupOrphanedThumbnails(List<String> validVideoPaths) async {
    try {
      final thumbnailDir = await _thumbnailDirectoryPath;
      final directory = Directory(thumbnailDir);
      
      if (!await directory.exists()) return;
      
      // Create a set of valid thumbnail filenames
      final validThumbnailNames = <String>{};
      
      for (final videoPath in validVideoPaths) {
        try {
          final videoFile = File(videoPath);
          if (await videoFile.exists()) {
            final videoStat = await videoFile.stat();
            final thumbnailFileName = '${videoFile.path.hashCode}_${videoStat.modified.millisecondsSinceEpoch}.jpg';
            validThumbnailNames.add(thumbnailFileName);
          }
        } catch (e) {
          // Skip invalid video paths
          continue;
        }
      }
      
      // Remove thumbnails that don't correspond to valid videos
      await for (final entity in directory.list()) {
        if (entity is File && entity.path.endsWith('.jpg')) {
          final fileName = entity.path.split('/').last;
          if (!validThumbnailNames.contains(fileName)) {
            await entity.delete();
            print('Deleted orphaned thumbnail: $fileName');
          }
        }
      }
    } catch (e) {
      print('Error cleaning up orphaned thumbnails: $e');
    }
  }
}