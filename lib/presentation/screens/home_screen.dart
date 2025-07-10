import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../../core/constants/app_constants.dart';
import '../../data/models/video_file.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  List<VideoFile> defaultDirectoryFiles = [];
  bool isLoading = true;
  String? defaultDirectory;
  bool isSelectionMode = false;
  Set<int> selectedIndices = {};

  @override
  void initState() {
    super.initState();
    _loadDefaultDirectoryFiles();
  }

  Future<void> _loadDefaultDirectoryFiles() async {
    setState(() {
      isLoading = true;
    });

    try {
      defaultDirectory = await _getDefaultOutputDirectory();
      if (defaultDirectory != null) {
        final files = await _getVideoFilesFromDirectory(defaultDirectory!);
        setState(() {
          defaultDirectoryFiles = files;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<String?> _getDefaultOutputDirectory() async {
    try {
      // First try to get user's preferred directory from settings
      final prefs = await SharedPreferences.getInstance();
      final userDefaultDir = prefs.getString('default_output_directory');
      if (userDefaultDir != null && await Directory(userDefaultDir).exists()) {
        return userDefaultDir;
      }
      
      // Fallback to app's default output directory (same logic as converter)
      final directoryOptions = [
        '/storage/emulated/0/Movies/VideoConverter',
        '/storage/emulated/0/Download/VideoConverter',
      ];
      
      for (String dir in directoryOptions) {
        if (await Directory(dir).exists()) {
          return dir;
        }
      }
      
      // If VideoConverter directories don't exist, try creating Movies/VideoConverter
      final moviesDir = Directory('/storage/emulated/0/Movies/VideoConverter');
      if (!await moviesDir.exists()) {
        try {
          await moviesDir.create(recursive: true);
          return moviesDir.path;
        } catch (e) {
          // Failed to create, continue to fallback
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<VideoFile>> _getVideoFilesFromDirectory(String directoryPath) async {
    try {
      final directory = Directory(directoryPath);
      final List<FileSystemEntity> entities = await directory.list().toList();
      
      List<VideoFile> videoFiles = [];
      
      for (var entity in entities) {
        if (entity is File) {
          final path = entity.path.toLowerCase();
          if (path.endsWith('.mp4') || 
              path.endsWith('.mov') || 
              path.endsWith('.avi') || 
              path.endsWith('.mkv') ||
              path.endsWith('.webm')) {
            
            final stat = await entity.stat();
            videoFiles.add(VideoFile(
              path: entity.path,
              name: entity.path.split('/').last,
              extension: entity.path.split('.').last,
              size: stat.size,
              createdAt: stat.modified,
            ));
          }
        }
      }
      
      // Sort by modified date, newest first
      videoFiles.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return videoFiles.take(10).toList(); // Limit to 10 most recent files
    } catch (e) {
      return [];
    }
  }

  Future<List<String>?> _pickVideoFileNative() async {
    try {
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
      return null;
    }
  }

  Future<void> _pickVideoFiles() async {
    try {
      // Try native picker first
      List<String>? nativePaths = await _pickVideoFileNative();
      
      // Handle cancellation - return early without fallback
      if (nativePaths != null && nativePaths.isEmpty) {
        return; // User cancelled, just return to home screen
      }
      
      List<VideoFile> selectedFiles = [];
      
      if (nativePaths != null && nativePaths.isNotEmpty) {
        for (String path in nativePaths) {
          final file = File(path);
          if (await file.exists()) {
            final stat = await file.stat();
            selectedFiles.add(VideoFile(
              path: file.path,
              name: file.path.split('/').last,
              extension: file.path.split('.').last,
              size: stat.size,
              createdAt: stat.modified,
            ));
          }
        }
      } else {
        // Fallback to file_picker
        try {
          await FilePicker.platform.clearTemporaryFiles();
        } catch (e) {}
        
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.video,
          allowMultiple: true,
          dialogTitle: 'Select Video Files',
          initialDirectory: '/storage/emulated/0',
        );

        if (result != null && result.files.isNotEmpty) {
          for (var file in result.files) {
            if (file.path != null) {
              selectedFiles.add(VideoFile(
                path: file.path!,
                name: file.name,
                extension: file.extension ?? '',
                size: file.size,
                createdAt: DateTime.now(),
              ));
            }
          }
        }
      }
      
      if (selectedFiles.isNotEmpty) {
        // Navigate to converter with selected files
        context.go('/converter', extra: selectedFiles);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error picking files: $e',
              style: TextStyle(color: Theme.of(context).colorScheme.onError),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            showCloseIcon: true,
          ),
        );
      }
    }
  }

  void _enterSelectionMode(int index) {
    setState(() {
      isSelectionMode = true;
      selectedIndices.add(index);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      isSelectionMode = false;
      selectedIndices.clear();
    });
  }

  void _toggleSelection(int index) {
    setState(() {
      if (selectedIndices.contains(index)) {
        selectedIndices.remove(index);
        if (selectedIndices.isEmpty) {
          isSelectionMode = false;
        }
      } else {
        selectedIndices.add(index);
      }
    });
  }

  void _selectAll() {
    setState(() {
      selectedIndices = Set.from(List.generate(defaultDirectoryFiles.length, (index) => index));
    });
  }

  void _deleteSelectedFiles() async {
    try {
      final filesToDelete = selectedIndices.map((index) => defaultDirectoryFiles[index]).toList();
      for (final file in filesToDelete) {
        final fileToDelete = File(file.path);
        if (await fileToDelete.exists()) {
          await fileToDelete.delete();
        }
      }
      
      // Refresh the list
      await _loadDefaultDirectoryFiles();
      _exitSelectionMode();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${filesToDelete.length} file(s) deleted'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting files: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<bool> _showDeleteConfirmation(VideoFile file) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Video'),
          content: Text('Are you sure you want to delete "${file.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        );
      },
    ) ?? false;
  }

  Future<void> _openFileLocation(VideoFile file) async {
    try {
      final directory = File(file.path).parent.path;
      const platform = MethodChannel('video_converter/folder_opener');
      await platform.invokeMethod('openFolder', {'path': directory});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open file location: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isSelectionMode 
          ? '${selectedIndices.length} selected' 
          : AppConstants.appName),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: isSelectionMode 
          ? IconButton(
              icon: const Icon(Icons.close),
              onPressed: _exitSelectionMode,
            )
          : null,
        actions: isSelectionMode 
          ? [
              IconButton(
                icon: const Icon(Icons.select_all),
                onPressed: _selectAll,
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: selectedIndices.isNotEmpty ? _deleteSelectedFiles : null,
              ),
            ]
          : [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => context.go('/settings'),
              ),
            ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Converted Videos',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              defaultDirectory != null 
                ? 'From ${defaultDirectory!.split('/').last}' 
                : 'No output directory found',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[400]
                    : Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : defaultDirectoryFiles.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.video_library_outlined,
                            size: 64,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[600]
                                : Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No videos found',
                            style: TextStyle(
                              fontSize: 18,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey[400]
                                  : Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap the button below to select videos',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey[500]
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadDefaultDirectoryFiles,
                      child: ListView.builder(
                        itemCount: defaultDirectoryFiles.length,
                        itemBuilder: (context, index) {
                          final file = defaultDirectoryFiles[index];
                          final isSelected = selectedIndices.contains(index);
                          
                          return Dismissible(
                            key: Key(file.path),
                            background: Container(
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: 20),
                              color: Colors.blue,
                              child: const Icon(
                                Icons.folder_open,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                            secondaryBackground: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: Colors.red,
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                            confirmDismiss: (direction) async {
                              if (direction == DismissDirection.endToStart) {
                                // Right swipe (delete)
                                return await _showDeleteConfirmation(file);
                              } else if (direction == DismissDirection.startToEnd) {
                                // Left swipe (open folder)
                                await _openFileLocation(file);
                                return false; // Don't dismiss
                              }
                              return false;
                            },
                            child: Card(
                              child: ListTile(
                              leading: isSelectionMode 
                                ? Checkbox(
                                    value: isSelected,
                                    onChanged: (bool? value) {
                                      _toggleSelection(index);
                                    },
                                  )
                                : const Icon(Icons.video_file, size: 40),
                              title: Text(
                                file.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(file.sizeFormatted),
                                  Text(
                                    file.createdAt.toString().split('.')[0],
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? Colors.grey[500]
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              trailing: isSelectionMode 
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.arrow_forward),
                                    onPressed: () {
                                      if (!isSelectionMode) {
                                        context.go('/converter', extra: [file]);
                                      }
                                    },
                                  ),
                              selected: isSelected,
                              onTap: () {
                                if (isSelectionMode) {
                                  _toggleSelection(index);
                                } else {
                                  context.go('/converter', extra: [file]);
                                }
                              },
                              onLongPress: () {
                                if (!isSelectionMode) {
                                  _enterSelectionMode(index);
                                }
                              },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickVideoFiles,
        label: const Text('Select Videos'),
        icon: const Icon(Icons.video_file),
      ),
    );
  }
}