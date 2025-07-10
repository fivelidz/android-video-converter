import 'package:video_compress/video_compress.dart';
import 'package:path_provider/path_provider.dart';
import '../models/video_file.dart';

class VideoConverterService {
  Future<String> convertVideo(ConversionTask task) async {
    final outputDir = await getApplicationDocumentsDirectory();
    final outputFileName = '${task.inputFile.displayName}_converted.${task.outputFormat}';
    final outputPath = '${outputDir.path}/$outputFileName';
    
    // Use video_compress for video processing
    VideoQuality quality = _getVideoQuality(task.quality);
    
    final info = await VideoCompress.compressVideo(
      task.inputFile.path,
      quality: quality,
      deleteOrigin: false,
      includeAudio: true,
    );
    
    if (info != null && info.file != null) {
      // Move compressed file to desired output path
      await info.file!.copy(outputPath);
      await info.file!.delete(); // Clean up temp file
      return outputPath;
    } else {
      throw Exception('Video compression failed');
    }
  }
  
  VideoQuality _getVideoQuality(String quality) {
    switch (quality) {
      case 'High':
        return VideoQuality.HighestQuality;
      case 'Medium':
        return VideoQuality.DefaultQuality;
      case 'Low':
        return VideoQuality.LowQuality;
      default:
        return VideoQuality.DefaultQuality;
    }
  }
  
  Future<bool> isVideoCompressionSupported() async {
    try {
      // video_compress is always available on Android
      return true;
    } catch (e) {
      return false;
    }
  }
}