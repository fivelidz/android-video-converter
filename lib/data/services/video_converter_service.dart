import 'package:video_compress/video_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';
import '../models/video_file.dart';
import 'ffmpeg_video_converter_service.dart';

class VideoConverterService {
  Function(double)? onProgress;
  final FFmpegVideoConverterService _ffmpegService = FFmpegVideoConverterService();
  
  Future<String> convertVideo(ConversionTask task) async {
    // Try FFmpeg first for better format support
    try {
      if (await _ffmpegService.isFFmpegAvailable()) {
        print('Using FFmpeg for video conversion');
        _ffmpegService.onProgress = onProgress;
        return await _ffmpegService.convertVideo(task);
      }
    } catch (e) {
      print('FFmpeg conversion failed, falling back to video_compress: $e');
    }
    
    // Fallback to video_compress for basic MP4 conversion
    print('Using video_compress for video conversion');
    return await _convertWithVideoCompress(task);
  }
  
  Future<String> _convertWithVideoCompress(ConversionTask task) async {
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
    final outputFileName = outputPath.split('/').last;
    
    print('Video Converter - Input: ${task.inputFile.path}');
    print('Video Converter - Output Dir: $outputDir');
    print('Video Converter - Output Path: $outputPath');
    
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
    } else {
      print('Output directory already exists: $outputDir');
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
      // Cancel any previous operations to ensure clean state
      await VideoCompress.cancelCompression();
      
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
          print('Compressed file created at: ${info.file!.path}');
          print('Compressed file size: ${await info.file!.length()} bytes');
          
          // video_compress always outputs MP4, so we need to handle format conversion
          if (task.outputFormat.toLowerCase() == 'mp4' || task.outputFormat.toLowerCase() == 'mov') {
            // For MP4/MOV, we can use the compressed file directly
            print('Copying compressed file to: $outputPath');
            await info.file!.copy(outputPath);
            print('File copied successfully');
            
            await info.file!.delete(); // Clean up temp file
            print('Temp file cleaned up');
            
            // Verify the output file was created successfully
            final outputFile = File(outputPath);
            if (!await outputFile.exists()) {
              throw Exception('Failed to create output file at: $outputPath');
            }
            
            final outputSize = await outputFile.length();
            print('Output file created successfully: $outputPath (${outputSize} bytes)');
            return outputPath;
          } else {
            // For other formats, we'll use the compressed MP4 as is
            // Note: video_compress doesn't support other formats natively
            // This is a limitation of the library - true format conversion requires FFmpeg
            final mp4Path = outputPath.replaceAll('.${task.outputFormat}', '.mp4');
            print('Copying compressed file to: $mp4Path (format converted to MP4)');
            await info.file!.copy(mp4Path);
            print('File copied successfully');
            
            await info.file!.delete(); // Clean up temp file
            print('Temp file cleaned up');
            
            // Verify the output file was created successfully
            final outputFile = File(mp4Path);
            if (!await outputFile.exists()) {
              throw Exception('Failed to create output file at: $mp4Path');
            }
            
            final outputSize = await outputFile.length();
            print('Output file created successfully: $mp4Path (${outputSize} bytes)');
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
      // Check if FFmpeg is available first
      if (await _ffmpegService.isFFmpegAvailable()) {
        return true;
      }
      // Fallback to video_compress
      return true;
    } catch (e) {
      return false;
    }
  }
  
  Future<Map<String, dynamic>> getVideoInfo(String videoPath) async {
    try {
      if (await _ffmpegService.isFFmpegAvailable()) {
        return await _ffmpegService.getVideoInfo(videoPath);
      }
    } catch (e) {
      print('Failed to get video info via FFmpeg: $e');
    }
    return {};
  }
}