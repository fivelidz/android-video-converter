import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../widgets/format_selector.dart';
import '../widgets/quality_selector.dart';
import '../widgets/conversion_progress.dart';
import '../../data/models/video_file.dart';
import '../../core/constants/app_constants.dart';
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

  Future<void> _pickVideoFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp4', 'avi', 'mov', 'mkv', 'wmv', 'flv', 'webm', '3gp'],
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

  Future<void> _startConversion() async {
    if (selectedFile == null) return;

    setState(() {
      isConverting = true;
      conversionProgress = 0.0;
    });

    try {
      final outputDir = await getApplicationDocumentsDirectory();
      final outputFileName = '${selectedFile!.displayName}_converted.$selectedFormat';
      final outputPath = '${outputDir.path}/$outputFileName';
      
      await Future.delayed(const Duration(seconds: 3));
      
      setState(() {
        isConverting = false;
        conversionProgress = 1.0;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Conversion completed!\nSaved to: $outputPath'),
            duration: const Duration(seconds: 5),
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
          SnackBar(content: Text('Conversion failed: $e')),
        );
      }
    }
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
              const SizedBox(height: 24),
              if (isConverting)
                ConversionProgress(progress: conversionProgress)
              else
                ElevatedButton.icon(
                  onPressed: _startConversion,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Conversion'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}