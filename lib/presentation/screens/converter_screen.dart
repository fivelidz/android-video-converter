import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../widgets/format_selector.dart';
import '../widgets/quality_selector.dart';
import '../widgets/conversion_progress.dart';
import '../../data/models/video_file.dart';
import '../../data/services/video_converter_service.dart';

class ConverterScreen extends ConsumerStatefulWidget {
  final List<VideoFile>? preSelectedFiles;
  
  const ConverterScreen({super.key, this.preSelectedFiles});

  @override
  ConsumerState<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends ConsumerState<ConverterScreen> with WidgetsBindingObserver {
  List<VideoFile> selectedFiles = [];
  String selectedFormat = 'mp4';
  String selectedQuality = 'High';
  bool isConverting = false;
  double conversionProgress = 0.0;
  int currentFileIndex = 0;
  int totalFiles = 0;
  String? customOutputDirectory;
  String? defaultOutputDirectory;
  final TextEditingController _filenameController = TextEditingController();
  final FocusNode _filenameFocusNode = FocusNode();
  bool _isFilenameFocused = false;
  final VideoConverterService _converterService = VideoConverterService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.preSelectedFiles != null) {
      selectedFiles = widget.preSelectedFiles!;
      totalFiles = selectedFiles.length;
    }
    _filenameFocusNode.addListener(() {
      setState(() {
        _isFilenameFocused = _filenameFocusNode.hasFocus;
      });
    });
    _initializeDirectories();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reload settings when app resumes (e.g., coming back from settings)
      _loadUserDefaultDirectory();
    }
  }

  Future<void> _initializeDirectories() async {
    try {
      // Load user's preferred default directory from settings
      await _loadUserDefaultDirectory();
      
      // Create and set default conversion directory if no user preference
      if (customOutputDirectory == null) {
        defaultOutputDirectory = await _getOrCreateConversionDirectory();
      }
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        _showFloatingPopup(
          'Error setting up directories: $e',
          isError: true,
        );
      }
    }
  }

  Future<void> _loadUserDefaultDirectory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDefaultDir = prefs.getString('default_output_directory');
      if (userDefaultDir != null && await Directory(userDefaultDir).exists()) {
        setState(() {
          customOutputDirectory = userDefaultDir;
        });
        print('Loaded user default directory: $userDefaultDir');
      }
    } catch (e) {
      print('Error loading user default directory: $e');
    }
  }

  Future<String> _getOrCreateConversionDirectory() async {
    print('*** CONVERTER: _getOrCreateConversionDirectory() called ***');
    
    // Priority 1: Check if Movies/VideoConverter already exists (created by main.dart)
    final moviesDir = Directory('/storage/emulated/0/Movies/VideoConverter');
    print('*** CONVERTER: Checking Movies directory: ${moviesDir.path} ***');
    
    if (await moviesDir.exists()) {
      print('*** CONVERTER: Movies directory EXISTS ***');
      try {
        // Test write permissions
        final testFile = File('${moviesDir.path}/.test_write_converter');
        await testFile.writeAsString('converter_test');
        await testFile.delete();
        
        print('*** CONVERTER: Using existing Movies directory: ${moviesDir.path} ***');
        return moviesDir.path;
      } catch (e) {
        print('*** CONVERTER: Movies directory exists but no write permissions: $e ***');
      }
    } else {
      print('*** CONVERTER: Movies directory does NOT exist ***');
    }
    
    // Priority 2: Try to create Movies folder if it doesn't exist
    try {
      print('*** CONVERTER: Attempting to create Movies directory ***');
      if (!await moviesDir.exists()) {
        // Try to create parent directory first
        final parentDir = Directory('/storage/emulated/0/Movies');
        if (!await parentDir.exists()) {
          await parentDir.create(recursive: true);
          print('*** CONVERTER: Created Movies parent directory ***');
        }
        
        await moviesDir.create(recursive: true);
        print('*** CONVERTER: Created Movies directory: ${moviesDir.path} ***');
      }
      
      // Test write permissions
      final testFile = File('${moviesDir.path}/.test_write_converter2');
      await testFile.writeAsString('converter_test2');
      await testFile.delete();
      
      print('*** CONVERTER: Successfully using Movies directory: ${moviesDir.path} ***');
      return moviesDir.path;
    } catch (e) {
      print('*** CONVERTER: Failed to create/use Movies directory: $e ***');
    }
    
    // Priority 3: Fallback to Downloads folder only if Movies fails
    try {
      final downloadDir = Directory('/storage/emulated/0/Download/VideoConverter');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
        print('Created Downloads directory: ${downloadDir.path}');
      }
      
      // Test write permissions
      final testFile = File('${downloadDir.path}/.test_write');
      await testFile.writeAsString('test');
      await testFile.delete();
      
      print('Using Downloads directory (fallback): ${downloadDir.path}');
      return downloadDir.path;
    } catch (e) {
      print('Failed to create/use Downloads directory: $e');
    }
    
    // Priority 4: Try external storage app directory
    try {
      final Directory? externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        final conversionDir = Directory('${externalDir.path}/VideoConverter');
        if (!await conversionDir.exists()) {
          await conversionDir.create(recursive: true);
          print('Created external storage directory: ${conversionDir.path}');
        }
        
        // Test write permissions
        final testFile = File('${conversionDir.path}/.test_write');
        await testFile.writeAsString('test');
        await testFile.delete();
        
        print('Using external storage directory: ${conversionDir.path}');
        return conversionDir.path;
      }
    } catch (e) {
      print('Failed to create/use external storage directory: $e');
    }
    
    // Last resort: App documents directory
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final conversionDir = Directory('${documentsDir.path}/VideoConverter');
      if (!await conversionDir.exists()) {
        await conversionDir.create(recursive: true);
        print('Created documents directory: ${conversionDir.path}');
      }
      
      print('Using documents directory (last resort): ${conversionDir.path}');
      return conversionDir.path;
    } catch (e) {
      print('Failed to create documents directory: $e');
      throw Exception('Could not create any output directory: $e');
    }
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
    } on Exception catch (e) {
      // Check if it's a cancellation error
      if (e.toString().contains('CANCELLED')) {
        // User cancelled - return empty list to indicate cancellation
        return [];
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Native picker error: $e',
              style: TextStyle(color: Theme.of(context).colorScheme.onError),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            showCloseIcon: true,
          ),
        );
      }
      return null;
    }
  }

  Future<void> _pickVideoFile() async {
    try {
      // Try native picker first for Videos category (supports multiple files)
      List<String>? nativePaths = await _pickVideoFileNative();
      
      // Handle cancellation - return early without fallback
      if (nativePaths != null && nativePaths.isEmpty) {
        return; // User cancelled, just return
      }
      
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
      
      // Fallback to file_picker - try to reset to root to avoid directory cache
      try {
        // First try to clear cache by attempting to pick with a neutral directory
        await FilePicker.platform.clearTemporaryFiles();
      } catch (e) {
        // Ignore if clearTemporaryFiles fails
      }
      
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: true,
        dialogTitle: 'Select Video Files',
        initialDirectory: '/storage/emulated/0', // Force start from root
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
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error picking file: $e',
              style: TextStyle(color: Theme.of(context).colorScheme.onError),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            showCloseIcon: true,
          ),
        );
      }
    }
  }

  Future<void> _pickOutputDirectory() async {
    try {
      // Try to clear cache and start from Movies folder
      try {
        await FilePicker.platform.clearTemporaryFiles();
        // Force a small delay to ensure cache is cleared
        await Future.delayed(Duration(milliseconds: 100));
      } catch (e) {
        // Ignore if clearTemporaryFiles fails
      }
      
      // Try multiple directory options in order of preference
      List<String> directoryOptions = [
        '/storage/emulated/0/Movies',
        '/storage/emulated/0/Download', 
        '/storage/emulated/0/DCIM',
        '/storage/emulated/0'
      ];
      
      String? initialDirectory;
      for (String dir in directoryOptions) {
        if (await Directory(dir).exists()) {
          initialDirectory = dir;
          break;
        }
      }
      
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
          SnackBar(
            content: Text(
              'Error selecting directory: $e',
              style: TextStyle(color: Theme.of(context).colorScheme.onError),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            showCloseIcon: true,
          ),
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
      String outputDir = (await getApplicationDocumentsDirectory()).path; // Initialize with safe default
      
      print('*** CONVERSION START: Determining output directory ***');
      print('*** customOutputDirectory: $customOutputDirectory ***');
      print('*** defaultOutputDirectory: $defaultOutputDirectory ***');
      
      if (customOutputDirectory != null) {
        outputDir = customOutputDirectory!;
        print('*** CONVERSION: Using custom output directory: $outputDir ***');
      } else {
        // Try accessible directories in order of preference
        final directoryOptions = [
          '/storage/emulated/0/Download/VideoConverter',
          '/storage/emulated/0/Movies/VideoConverter',
        ];
        
        bool foundAccessibleDir = false;
        
        for (String dirPath in directoryOptions) {
          try {
            final dir = Directory(dirPath);
            
            // Try to create directory if it doesn't exist
            if (!await dir.exists()) {
              await dir.create(recursive: true);
              print('*** CONVERSION: Created directory: $dirPath ***');
            }
            
            // Test write permissions
            final testFile = File('$dirPath/.test_conversion');
            await testFile.writeAsString('conversion_test');
            await testFile.delete();
            
            outputDir = dirPath;
            foundAccessibleDir = true;
            print('*** CONVERSION: Using accessible directory: $outputDir ***');
            break;
            
          } catch (e) {
            print('*** CONVERSION: Cannot access $dirPath: $e ***');
            continue;
          }
        }
        
        if (!foundAccessibleDir) {
          if (defaultOutputDirectory != null) {
            outputDir = defaultOutputDirectory!;
            print('*** CONVERSION: Using fallback default directory: $outputDir ***');
          } else {
            // Last resort: app-specific external directory
            try {
              final Directory? externalDir = await getExternalStorageDirectory();
              if (externalDir != null) {
                final conversionDir = Directory('${externalDir.path}/VideoConverter');
                if (!await conversionDir.exists()) {
                  await conversionDir.create(recursive: true);
                }
                outputDir = conversionDir.path;
                print('*** CONVERSION: Using app external directory: $outputDir ***');
              } else {
                outputDir = (await getApplicationDocumentsDirectory()).path;
                print('*** CONVERSION: Using documents directory: $outputDir ***');
              }
            } catch (e) {
              outputDir = (await getApplicationDocumentsDirectory()).path;
              print('*** CONVERSION: Using final fallback documents directory: $outputDir ***');
            }
          }
        }
      }
      
      // Ensure the output directory exists
      final outputDirectory = Directory(outputDir);
      if (!await outputDirectory.exists()) {
        print('Output directory does not exist, creating: $outputDir');
        try {
          await outputDirectory.create(recursive: true);
          print('Successfully created output directory: $outputDir');
        } catch (e) {
          print('Failed to create output directory: $e');
          throw Exception('Cannot create output directory: $outputDir. Error: $e');
        }
      } else {
        print('Output directory exists: $outputDir');
      }
      
      // Test write permissions
      try {
        final testFile = File('$outputDir/.test_write');
        await testFile.writeAsString('test');
        await testFile.delete();
        print('Write permissions verified for: $outputDir');
      } catch (e) {
        print('No write permissions for directory: $outputDir');
        throw Exception('Cannot write to output directory: $outputDir. Please choose a different directory.');
      }
      
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
          print('Converting file ${i + 1}/${selectedFiles.length}: ${file.name}');
          print('Input path: ${file.path}');
          print('Output path: $outputPath');
          
          final convertedPath = await _converterService.convertVideo(conversionTask);
          convertedPaths.add(convertedPath);
          print('Successfully converted: ${file.name}');
          
          // Add small delay between conversions to ensure video_compress library stabilizes
          if (i < selectedFiles.length - 1) {
            await Future.delayed(Duration(milliseconds: 500));
          }
        } catch (e) {
          print('Failed to convert ${file.name}: $e');
          failedFiles.add(file.name);
          
          // Add delay even on failure to ensure library state is stable
          if (i < selectedFiles.length - 1) {
            await Future.delayed(Duration(milliseconds: 500));
          }
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
        
        final outputDirectory = convertedPaths.isNotEmpty 
          ? File(convertedPaths.first).parent.path 
          : null;
        
        _showFloatingPopup(
          message,
          isError: convertedPaths.isEmpty,
          outputDir: outputDirectory,
          convertedPaths: convertedPaths,
        );
      }
    } catch (e) {
      setState(() {
        isConverting = false;
        conversionProgress = 0.0;
      });
      
      if (mounted) {
        _showFloatingPopup(
          'Conversion failed: $e',
          isError: true,
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

  String _getFilenameHint() {
    if (_isFilenameFocused || _filenameController.text.isNotEmpty) {
      return 'Enter filename (without extension)';
    } else if (selectedFiles.isEmpty) {
      return 'No files selected';
    } else if (selectedFiles.length == 1) {
      return '${selectedFiles.first.displayName}.$selectedFormat';
    } else {
      return '${selectedFiles.first.displayName}.$selectedFormat (+ ${selectedFiles.length - 1} more)';
    }
  }

  Future<void> _openFolder(String folderPath) async {
    try {
      const platform = MethodChannel('video_converter/folder_opener');
      await platform.invokeMethod('openFolder', {'path': folderPath});
    } catch (e) {
      if (mounted) {
        _showFloatingPopup(
          'Could not open file manager: $e',
          isError: true,
        );
      }
    }
  }

  void _showFloatingPopup(String message, {bool isError = false, String? outputDir, List<String>? convertedPaths}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Theme.of(context).colorScheme.surface,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isError ? Icons.error_outline : Icons.check_circle_outline,
                  size: 48,
                  color: isError 
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  isError ? 'Error' : 'Success',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: isError 
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (outputDir != null && convertedPaths != null && convertedPaths.isNotEmpty) ...[
                      TextButton.icon(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await _openFolder(outputDir);
                        },
                        icon: const Icon(Icons.folder_open),
                        label: const Text('Open Folder'),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _filenameController.dispose();
    _filenameFocusNode.dispose();
    _converterService.onProgress = null; // Clean up progress callback
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.go('/');
        }
      },
      child: Scaffold(
          appBar: AppBar(
          title: const Text('Video Converter'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              context.go('/');
            },
          ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.go('/settings'),
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
                          focusNode: _filenameFocusNode,
                          decoration: InputDecoration(
                            hintText: _getFilenameHint(),
                            border: const OutlineInputBorder(),
                            suffixText: (_isFilenameFocused || _filenameController.text.isNotEmpty) 
                                ? '.$selectedFormat' 
                                : null,
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
                              selectedQuality = 'High';
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
    ));
  }
}