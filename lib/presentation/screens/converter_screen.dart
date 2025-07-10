import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../widgets/format_selector.dart';
import '../widgets/quality_selector.dart';
import '../widgets/conversion_progress.dart';
import '../../data/models/video_file.dart';
import '../../data/services/video_converter_service.dart';
import '../../main.dart';

class ConverterScreen extends ConsumerStatefulWidget {
  const ConverterScreen({super.key});

  @override
  ConsumerState<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends ConsumerState<ConverterScreen> {
  List<VideoFile> selectedFiles = [];
  String selectedFormat = 'mp4';
  String selectedQuality = 'Medium';
  bool isConverting = false;
  double conversionProgress = 0.0;
  int currentFileIndex = 0;
  int totalFiles = 0;
  String? customOutputDirectory;
  String? defaultOutputDirectory;
  final TextEditingController _filenameController = TextEditingController();
  final VideoConverterService _converterService = VideoConverterService();

  @override
  void initState() {
    super.initState();
    _initializeDirectories();
  }

  Future<void> _initializeDirectories() async {
    try {
      // Create and set default conversion directory
      defaultOutputDirectory = await _getOrCreateConversionDirectory();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error setting up directories: $e')),
        );
      }
    }
  }

  Future<String> _getOrCreateConversionDirectory() async {
    try {
      // Create directory in accessible Downloads folder
      final downloadDir = Directory('/storage/emulated/0/Download/VideoConverter');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      return downloadDir.path;
    } catch (e) {
      try {
        // Fallback to external storage
        final Directory? externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          final conversionDir = Directory('${externalDir.path}/VideoConverter');
          if (!await conversionDir.exists()) {
            await conversionDir.create(recursive: true);
          }
          return conversionDir.path;
        }
      } catch (e2) {
        // Final fallback to documents
        final documentsDir = await getApplicationDocumentsDirectory();
        final conversionDir = Directory('${documentsDir.path}/VideoConverter');
        if (!await conversionDir.exists()) {
          await conversionDir.create(recursive: true);
        }
        return conversionDir.path;
      }
    }
    
    // Last resort
    final documentsDir = await getApplicationDocumentsDirectory();
    return documentsDir.path;
  }

  Future<String?> _getVideosDirectory() async {
    try {
      // Try multiple common video directory paths on Android
      final List<String> videoPaths = [
        '/storage/emulated/0/Movies',           // Standard Movies folder
        '/storage/emulated/0/DCIM/Camera',     // Camera recordings
        '/storage/emulated/0/Download',        // Downloaded videos
        '/storage/emulated/0/Pictures/Screenshots', // Screen recordings
      ];
      
      for (String path in videoPaths) {
        final dir = Directory(path);
        if (await dir.exists()) {
          // Check if directory has any video files to prioritize
          try {
            final files = await dir.list().where((entity) {
              return entity is File && 
                     (entity.path.toLowerCase().endsWith('.mp4') ||
                      entity.path.toLowerCase().endsWith('.mov') ||
                      entity.path.toLowerCase().endsWith('.avi') ||
                      entity.path.toLowerCase().endsWith('.mkv'));
            }).take(1).toList();
            
            if (files.isNotEmpty) {
              return path; // Prioritize directories with video files
            }
          } catch (e) {
            // Continue if we can't list files
          }
        }
      }
      
      // Return first existing directory even if no videos found
      for (String path in videoPaths) {
        final dir = Directory(path);
        if (await dir.exists()) {
          return path;
        }
      }
    } catch (e) {
      // Continue with fallback
    }
    return null;
  }

  Future<List<String>?> _pickVideoFileNative() async {
    try {
      // Use Android's native intent to open Videos category
      const platform = MethodChannel('video_converter/file_picker');
      final dynamic result = await platform.invokeMethod('pickVideoFromGallery');
      
      if (result is List) {
        return result.cast<String>();
      } else if (result is String) {
        return [result];
      }
      return null;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Native picker error: $e')),
        );
      }
      return null;
    }
  }

  Future<void> _pickVideoFile() async {
    try {
      // Try native picker first for Videos category (supports multiple files)
      List<String>? nativePaths = await _pickVideoFileNative();
      
      if (nativePaths != null && nativePaths.isNotEmpty) {
        List<VideoFile> newFiles = [];
        for (String path in nativePaths) {
          final file = File(path);
          if (await file.exists()) {
            final stat = await file.stat();
            newFiles.add(VideoFile(
              path: file.path,
              name: file.path.split('/').last,
              extension: file.path.split('.').last,
              size: stat.size,
              createdAt: stat.modified,
            ));
          }
        }
        
        if (newFiles.isNotEmpty) {
          setState(() {
            selectedFiles = newFiles;
            totalFiles = selectedFiles.length;
            _filenameController.clear();
          });
          return;
        }
      }
      
      // Fallback to file_picker without initialDirectory to avoid cache issues
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: true,
        dialogTitle: 'Select Video Files',
      );

      if (result != null && result.files.isNotEmpty) {
        List<VideoFile> newFiles = [];
        for (var file in result.files) {
          if (file.path != null) {
            newFiles.add(VideoFile(
              path: file.path!,
              name: file.name,
              extension: file.extension ?? '',
              size: file.size,
              createdAt: DateTime.now(),
            ));
          }
        }
        setState(() {
          selectedFiles = newFiles;
          totalFiles = selectedFiles.length;
          _filenameController.clear(); // Clear for batch processing
        });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e')),
        );
      }
    }
  }

  Future<void> _pickOutputDirectory() async {
    try {
      // Start from Android storage base for easy navigation
      String? initialDirectory = '/storage/emulated/0';
      
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        initialDirectory: initialDirectory,
        dialogTitle: 'Choose Output Directory',
      );
      if (selectedDirectory != null) {
        setState(() {
          customOutputDirectory = selectedDirectory;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting directory: $e')),
        );
      }
    }
  }

  Future<void> _startConversion() async {
    if (selectedFiles.isEmpty) return;

    setState(() {
      isConverting = true;
      conversionProgress = 0.0;
      currentFileIndex = 0;
    });

    List<String> convertedPaths = [];
    List<String> failedFiles = [];

    try {
      final outputDir = customOutputDirectory ?? 
                        defaultOutputDirectory ?? 
                        (await getApplicationDocumentsDirectory()).path;
      
      // Set up progress tracking for batch conversion
      _converterService.onProgress = (progress) {
        if (mounted && isConverting) {
          // Calculate overall progress: (completed files + current file progress) / total files
          final overallProgress = (currentFileIndex + (progress / 100.0)) / totalFiles;
          setState(() {
            conversionProgress = overallProgress;
          });
        }
      };
      
      // Convert each file
      for (int i = 0; i < selectedFiles.length; i++) {
        if (!isConverting) break; // Stop if conversion was cancelled
        
        setState(() {
          currentFileIndex = i;
        });
        
        final file = selectedFiles[i];
        final outputFileName = _filenameController.text.isNotEmpty 
            ? '${_filenameController.text}_${i + 1}.$selectedFormat'
            : '${file.displayName}_converted.$selectedFormat';
        final outputPath = '$outputDir/$outputFileName';
        
        final conversionTask = ConversionTask(
          inputFile: file,
          outputFormat: selectedFormat,
          quality: selectedQuality,
          outputPath: outputPath,
        );
        
        try {
          final convertedPath = await _converterService.convertVideo(conversionTask);
          convertedPaths.add(convertedPath);
        } catch (e) {
          failedFiles.add(file.name);
        }
      }
      
      setState(() {
        isConverting = false;
        conversionProgress = 1.0;
      });
      
      if (mounted) {
        String message;
        if (convertedPaths.isNotEmpty) {
          if (failedFiles.isEmpty) {
            message = 'All ${convertedPaths.length} video${convertedPaths.length > 1 ? 's' : ''} converted successfully!\n';
          } else {
            message = '${convertedPaths.length} video${convertedPaths.length > 1 ? 's' : ''} converted successfully.\n${failedFiles.length} failed: ${failedFiles.join(', ')}\n';
          }
          
          if (convertedPaths.isNotEmpty) {
            final outputDir = File(convertedPaths.first).parent.path;
            message += 'Saved to: $outputDir';
            
            // Check format limitation
            final actualFormat = convertedPaths.first.split('.').last;
            final requestedFormat = selectedFormat.toLowerCase();
            if (actualFormat != requestedFormat && requestedFormat != 'mp4' && requestedFormat != 'mov') {
              message += '\n\nNote: Output saved as MP4 format. Other formats require FFmpeg for true conversion.';
            }
          }
        } else {
          message = 'All conversions failed. Please check your files and try again.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 8),
            action: convertedPaths.isNotEmpty ? SnackBarAction(
              label: 'Open Folder',
              onPressed: () async {
                final outputDir = File(convertedPaths.first).parent.path;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Files saved to: $outputDir')),
                );
              },
            ) : null,
          ),
        );
      }
    } catch (e) {
      setState(() {
        isConverting = false;
        conversionProgress = 0.0;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Conversion failed: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  String _getTotalSizeFormatted() {
    if (selectedFiles.isEmpty) return '0 MB';
    
    int totalBytes = selectedFiles.fold(0, (sum, file) => sum + file.size);
    double totalMB = totalBytes / 1024 / 1024;
    
    if (totalMB >= 1024) {
      return '${(totalMB / 1024).toStringAsFixed(2)} GB';
    } else {
      return '${totalMB.toStringAsFixed(2)} MB';
    }
  }

  @override
  void dispose() {
    _filenameController.dispose();
    _converterService.onProgress = null; // Clean up progress callback
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
        title: const Text('Video Converter'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6),
            onPressed: () {
              final currentTheme = ref.read(themeProvider);
              ref.read(themeProvider.notifier).state = 
                currentTheme == ThemeMode.light 
                  ? ThemeMode.dark 
                  : ThemeMode.light;
            },
          ),
        ],
      ),
        body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // File Selection Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'Select Video File',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (selectedFiles.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey.shade800
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.video_library, size: 40),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${selectedFiles.length} video${selectedFiles.length > 1 ? 's' : ''} selected',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          'Total size: ${_getTotalSizeFormatted()}',
                                          style: TextStyle(
                                            color: Theme.of(context).brightness == Brightness.dark
                                                ? Colors.grey[400]
                                                : Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (selectedFiles.length <= 3) ...[
                                const SizedBox(height: 8),
                                ...selectedFiles.map((file) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    '• ${file.name}',
                                    style: const TextStyle(fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )),
                              ] else ...[
                                const SizedBox(height: 8),
                                ...selectedFiles.take(2).map((file) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    '• ${file.name}',
                                    style: const TextStyle(fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )),
                                Text(
                                  '• ... and ${selectedFiles.length - 2} more files',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.grey[400]
                                        : Colors.grey,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      else
                        const Text('No files selected'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _pickVideoFile,
                        icon: const Icon(Icons.folder_open),
                        label: const Text('Choose File'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Conversion options (only show if file is selected)
              if (selectedFiles.isNotEmpty) ...[
                FormatSelector(
                  selectedFormat: selectedFormat,
                  onFormatChanged: (format) {
                    setState(() {
                      selectedFormat = format;
                    });
                  },
                ),
                const SizedBox(height: 16),
                QualitySelector(
                  selectedQuality: selectedQuality,
                  onQualityChanged: (quality) {
                    setState(() {
                      selectedQuality = quality;
                    });
                  },
                ),
                const SizedBox(height: 16),
                
                // Output filename editor
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Output Filename',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _filenameController,
                          decoration: InputDecoration(
                            hintText: 'Enter filename (without extension)',
                            border: const OutlineInputBorder(),
                            suffixText: '.$selectedFormat',
                            fillColor: Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey.shade900
                                : Colors.white,
                            filled: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Output directory selector
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Output Directory',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey.shade800
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            customOutputDirectory ?? 
                            (defaultOutputDirectory != null 
                                ? 'VideoConverter (default)' 
                                : 'Documents (default)'),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _pickOutputDirectory,
                          icon: const Icon(Icons.folder_open),
                          label: const Text('Choose Directory'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Conversion progress or controls
                if (isConverting)
                  ConversionProgress(progress: conversionProgress)
                else
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _startConversion,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Start Conversion'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              selectedFiles = [];
                              selectedFormat = 'mp4';
                              selectedQuality = 'Medium';
                              isConverting = false;
                              conversionProgress = 0.0;
                              customOutputDirectory = null;
                              _filenameController.clear();
                            });
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reset'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            foregroundColor: Theme.of(context).colorScheme.primary,
                            side: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}