import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
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
  VideoFile? selectedFile;
  String selectedFormat = 'mp4';
  String selectedQuality = 'Medium';
  bool isConverting = false;
  double conversionProgress = 0.0;
  String? customOutputDirectory;
  final TextEditingController _filenameController = TextEditingController();
  final VideoConverterService _converterService = VideoConverterService();

  Future<void> _pickVideoFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result != null) {
        final file = result.files.first;
        if (file.path != null) {
          setState(() {
            selectedFile = VideoFile(
              path: file.path!,
              name: file.name,
              extension: file.extension ?? '',
              size: file.size,
              createdAt: DateTime.now(),
            );
            _filenameController.text = selectedFile!.displayName;
          });
        }
      }
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
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
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
    if (selectedFile == null) return;

    setState(() {
      isConverting = true;
      conversionProgress = 0.0;
    });

    try {
      final outputDir = customOutputDirectory ?? 
                        (await getApplicationDocumentsDirectory()).path;
      final outputFileName = '${_filenameController.text}.$selectedFormat';
      final outputPath = '$outputDir/$outputFileName';
      
      final conversionTask = ConversionTask(
        inputFile: selectedFile!,
        outputFormat: selectedFormat,
        quality: selectedQuality,
        outputPath: outputPath,
      );
      
      final progressTimer = Stream.periodic(
        const Duration(milliseconds: 500),
        (i) => (i * 5).clamp(0, 95) / 100.0,
      ).take(20);
      
      progressTimer.listen((progress) {
        if (mounted && isConverting) {
          setState(() {
            conversionProgress = progress;
          });
        }
      });
      
      final convertedPath = await _converterService.convertVideo(conversionTask);
      
      setState(() {
        isConverting = false;
        conversionProgress = 1.0;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Conversion completed!\nSaved to: $convertedPath'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Open Folder',
              onPressed: () async {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('File saved to: ${File(convertedPath).parent.path}')),
                );
              },
            ),
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

  @override
  void dispose() {
    _filenameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Converter'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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
                      if (selectedFile != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.video_file, size: 40),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      selectedFile!.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      selectedFile!.sizeFormatted,
                                      style: const TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        const Text('No file selected'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _pickVideoFile,
                        icon: const Icon(Icons.folder_open),
                        label: const Text('Choose File'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Conversion options (only show if file is selected)
              if (selectedFile != null) ...[
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
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            customOutputDirectory ?? 'Documents (default)',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _pickOutputDirectory,
                          icon: const Icon(Icons.folder_open),
                          label: const Text('Choose Directory'),
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
                      ElevatedButton.icon(
                        onPressed: _startConversion,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start Conversion'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Back'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                selectedFile = null;
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
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                            ),
                          ),
                        ],
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