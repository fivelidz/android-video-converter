import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/video_file.dart';

class VideoConverterService {
  Future<String> convertVideo(ConversionTask task) async {
    final outputDir = await getApplicationDocumentsDirectory();
    final outputFileName = '${task.inputFile.displayName}_converted.${task.outputFormat}';
    final outputPath = '${outputDir.path}/$outputFileName';
    
    String command = _buildFFmpegCommand(
      task.inputFile.path,
      outputPath,
      task.outputFormat,
      task.quality,
    );
    
    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();
    
    if (ReturnCode.isSuccess(returnCode)) {
      return outputPath;
    } else {
      final failStackTrace = await session.getFailStackTrace();
      throw Exception('Conversion failed: $failStackTrace');
    }
  }
  
  String _buildFFmpegCommand(String inputPath, String outputPath, String format, String quality) {
    String videoCodec = 'libx264';
    String audioCodec = 'aac';
    String resolution = _getResolutionForQuality(quality);
    
    return '-i "$inputPath" -c:v $videoCodec -c:a $audioCodec -s $resolution -y "$outputPath"';
  }
  
  String _getResolutionForQuality(String quality) {
    switch (quality) {
      case 'High':
        return '1920x1080';
      case 'Medium':
        return '1280x720';
      case 'Low':
        return '854x480';
      default:
        return '1280x720';
    }
  }
  
  Future<bool> isFFmpegSupported() async {
    try {
      final session = await FFmpegKit.execute('-version');
      final returnCode = await session.getReturnCode();
      return ReturnCode.isSuccess(returnCode);
    } catch (e) {
      return false;
    }
  }
}