import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';
import '../models/video_file.dart';

class FFmpegVideoConverterService {
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
    
    // Use the full output path provided by the task
    final outputPath = task.outputPath;
    final outputDir = Directory(outputPath).parent.path;
    
    print('FFmpeg Converter - Input: ${task.inputFile.path}');
    print('FFmpeg Converter - Output Dir: $outputDir');
    print('FFmpeg Converter - Output Path: $outputPath');
    
    // Ensure the output directory exists
    final outputDirectory = Directory(outputDir);
    if (!await outputDirectory.exists()) {
      try {
        print('Creating output directory: $outputDir');
        await outputDirectory.create(recursive: true);
        print('Successfully created directory: $outputDir');
      } catch (e) {
        print('Failed to create output directory: $e');
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
    
    // Build FFmpeg command based on output format and quality
    final command = _buildFFmpegCommand(
      task.inputFile.path,
      outputPath,
      task.outputFormat,
      task.quality,
    );
    
    print('FFmpeg command: $command');
    
    try {
      // Set up progress tracking
      double totalDuration = 0;
      
      // Get video duration first
      final durationCommand = '-i "${task.inputFile.path}" -f null -';
      final durationSession = await FFmpegKit.execute(durationCommand);
      final durationOutput = await durationSession.getOutput();
      if (durationOutput != null) {
        final durationMatch = RegExp(r'Duration: (\d+):(\d+):(\d+)\.(\d+)').firstMatch(durationOutput);
        if (durationMatch != null) {
          final hours = int.parse(durationMatch.group(1)!);
          final minutes = int.parse(durationMatch.group(2)!);
          final seconds = int.parse(durationMatch.group(3)!);
          totalDuration = (hours * 3600 + minutes * 60 + seconds).toDouble();
        }
      }
      
      // Execute conversion with progress tracking
      final session = await FFmpegKit.executeAsync(
        command,
        (FFmpegSession session) async {
          final returnCode = await session.getReturnCode();
          print('FFmpeg completed with return code: $returnCode');
        },
        (log) {
          print('FFmpeg log: ${log.getMessage()}');
        },
        (statistics) {
          if (totalDuration > 0) {
            final currentTime = statistics.getTime() / 1000.0; // Convert to seconds
            final progress = (currentTime / totalDuration * 100).clamp(0.0, 100.0);
            onProgress?.call(progress);
          }
        },
      );
      
      // Wait for completion
      final returnCode = await session.getReturnCode();
      
      if (returnCode?.isValueSuccess() == true) {
        // Verify the output file was created
        final outputFile = File(outputPath);
        if (!await outputFile.exists()) {
          throw Exception('Output file was not created: $outputPath');
        }
        
        final outputSize = await outputFile.length();
        if (outputSize == 0) {
          throw Exception('Output file is empty');
        }
        
        print('Conversion successful: $outputPath (${outputSize} bytes)');
        
        // Add small delay to ensure file system sync on Android
        await Future.delayed(Duration(milliseconds: 500));
        
        return outputPath;
      } else {
        final failureReason = await session.getFailStackTrace();
        throw Exception('FFmpeg conversion failed with code: $returnCode, reason: $failureReason');
      }
    } catch (e) {
      throw Exception('Video conversion failed: $e');
    }
  }
  
  String _buildFFmpegCommand(String inputPath, String outputPath, String format, String quality) {
    final buffer = StringBuffer();
    
    // Input file with timestamp preservation
    buffer.write('-i "$inputPath" -avoid_negative_ts make_zero ');
    
    // Video codec and settings based on format
    switch (format.toLowerCase()) {
      case 'mp4':
        buffer.write('-c:v libx264 -c:a aac ');
        break;
      case 'webm':
        buffer.write('-c:v libvpx-vp9 -c:a libvorbis ');
        break;
      case 'avi':
        buffer.write('-c:v libx264 -c:a aac ');
        break;
      case 'mov':
        buffer.write('-c:v libx264 -c:a aac ');
        break;
      case 'mkv':
        buffer.write('-c:v libx264 -c:a aac ');
        break;
      default:
        buffer.write('-c:v libx264 -c:a aac ');
    }
    
    // Quality settings
    final (videoFilter, crf) = _getQualitySettings(quality);
    if (videoFilter.isNotEmpty) {
      buffer.write('-vf "$videoFilter" ');
    }
    buffer.write('-crf $crf ');
    
    // Additional settings for better compatibility
    buffer.write('-preset medium ');
    
    // Add container-specific optimizations
    if (format.toLowerCase() == 'mp4' || format.toLowerCase() == 'mov') {
      buffer.write('-movflags +faststart ');
    }
    
    // Output file
    buffer.write('"$outputPath"');
    
    return buffer.toString();
  }
  
  (String, int) _getQualitySettings(String quality) {
    switch (quality) {
      case 'High':
        return ('scale=-2:1080', 18); // 1080p, high quality
      case 'Medium':
        return ('scale=-2:720', 23); // 720p, medium quality
      case 'Low':
        return ('scale=-2:480', 28); // 480p, lower quality
      default:
        return ('scale=-2:720', 23); // Default to medium
    }
  }
  
  Future<bool> isFFmpegAvailable() async {
    try {
      final session = await FFmpegKit.execute('-version');
      final returnCode = await session.getReturnCode();
      return returnCode?.isValueSuccess() == true;
    } catch (e) {
      return false;
    }
  }
  
  Future<Map<String, dynamic>> getVideoInfo(String videoPath) async {
    try {
      final command = '-i "$videoPath" -f null -';
      final session = await FFmpegKit.execute(command);
      final output = await session.getOutput();
      
      if (output != null) {
        // Parse video information from FFmpeg output
        final durationMatch = RegExp(r'Duration: (\d+):(\d+):(\d+)\.(\d+)').firstMatch(output);
        final resolutionMatch = RegExp(r'(\d+)x(\d+)').firstMatch(output);
        final bitrateMatch = RegExp(r'bitrate: (\d+) kb/s').firstMatch(output);
        
        return {
          'duration': durationMatch?.group(0),
          'resolution': resolutionMatch?.group(0),
          'bitrate': bitrateMatch?.group(1),
        };
      }
      
      return {};
    } catch (e) {
      return {};
    }
  }
}