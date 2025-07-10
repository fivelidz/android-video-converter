import 'package:video_compress/video_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';
import '../models/video_file.dart';

class VideoConverterService {
  Function(double)? onProgress;
  
  Future<String> convertVideo(ConversionTask task) async {
    // Validate input file exists
    final inputFile = File(task.inputFile.path);
    if (!await inputFile.exists()) {
      throw Exception('Input video file not found: ${task.inputFile.path}');
    }
    
    // Check if input file is readable
    try {
      final size = await inputFile.length();
      if (size == 0) {
        throw Exception('Input video file is empty');
      }
    } catch (e) {
      throw Exception('Cannot read input video file: $e');
    }
    
    // Use the custom output directory from the task if provided
    final outputDir = task.outputPath.contains('/') 
        ? Directory(task.outputPath).parent.path
        : (await getApplicationDocumentsDirectory()).path;
    
    final outputFileName = task.outputPath.contains('/') 
        ? task.outputPath.split('/').last
        : '${task.inputFile.displayName}_converted.${task.outputFormat}';
    
    final outputPath = task.outputPath.contains('/') 
        ? task.outputPath 
        : '$outputDir/$outputFileName';
    
    // Ensure the output directory exists
    final outputDirectory = Directory(outputDir);
    if (!await outputDirectory.exists()) {
      try {
        await outputDirectory.create(recursive: true);
      } catch (e) {
        throw Exception('Failed to create output directory: $e');
      }
    }
    
    // Verify we can write to the directory
    try {
      final testFile = File('$outputDir/.test_write');
      await testFile.writeAsString('test');
      await testFile.delete();
    } catch (e) {
      throw Exception('Cannot write to output directory: $e');
    }
    
    // Set up progress callback
    VideoCompress.setLogLevel(0); // Disable logs for cleaner output
    
    // Get video quality setting
    VideoQuality quality = _getVideoQuality(task.quality);
    
    try {
      // Set up progress subscription
      final subscription = VideoCompress.compressProgress$.subscribe((progress) {
        onProgress?.call(progress);
      });
      
      final info = await VideoCompress.compressVideo(
        task.inputFile.path,
        quality: quality,
        deleteOrigin: false,
        includeAudio: true,
      );
      
      // Clean up subscription
      subscription.unsubscribe();
      
      if (info != null && info.file != null) {
        // Verify the compressed file exists and is valid
        if (!await info.file!.exists()) {
          throw Exception('Compressed video file was not created');
        }
        
        final compressedSize = await info.file!.length();
        if (compressedSize == 0) {
          throw Exception('Compressed video file is empty');
        }
        
        try {
          // video_compress always outputs MP4, so we need to handle format conversion
          if (task.outputFormat.toLowerCase() == 'mp4' || task.outputFormat.toLowerCase() == 'mov') {
            // For MP4/MOV, we can use the compressed file directly
            await info.file!.copy(outputPath);
            await info.file!.delete(); // Clean up temp file
            
            // Verify the output file was created successfully
            final outputFile = File(outputPath);
            if (!await outputFile.exists()) {
              throw Exception('Failed to create output file at: $outputPath');
            }
            
            return outputPath;
          } else {
            // For other formats, we'll use the compressed MP4 as is
            // Note: video_compress doesn't support other formats natively
            // This is a limitation of the library - true format conversion requires FFmpeg
            final mp4Path = outputPath.replaceAll('.${task.outputFormat}', '.mp4');
            await info.file!.copy(mp4Path);
            await info.file!.delete(); // Clean up temp file
            
            // Verify the output file was created successfully
            final outputFile = File(mp4Path);
            if (!await outputFile.exists()) {
              throw Exception('Failed to create output file at: $mp4Path');
            }
            
            // Return the MP4 path and notify user about format limitation
            return mp4Path;
          }
        } catch (e) {
          // Clean up temp file if copy failed
          try {
            if (await info.file!.exists()) {
              await info.file!.delete();
            }
          } catch (_) {}
          throw Exception('Failed to copy converted file: $e');
        }
      } else {
        throw Exception('Video compression failed - no output file generated');
      }
    } catch (e) {
      throw Exception('Video conversion failed: $e');
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