import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../../core/constants/app_constants.dart';
import '../../data/models/video_file.dart';
import '../../data/models/conversion_log.dart';
import '../../data/services/conversion_log_service.dart';
import '../../data/services/thumbnail_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  List<ConversionLogEntry> convertedVideos = [];
  bool isLoading = true;
  bool isSelectionMode = false;
  Set<int> selectedIndices = {};
  SwipeAction leftSwipeAction = SwipeAction.openDirectory;
  SwipeAction rightSwipeAction = SwipeAction.delete;
  bool useThumbnails = true;
  Map<String, String?> thumbnailCache = {};

  @override
  void initState() {
    super.initState();
    _loadConvertedVideos();
    _loadSwipeActions();
    _loadDisplaySettings();
  }

  Future<void> _loadSwipeActions() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final leftActionString = prefs.getString('left_swipe_action');
      if (leftActionString != null) {
        leftSwipeAction = SwipeActionHelper.actionFromString(leftActionString);
      }
      
      final rightActionString = prefs.getString('right_swipe_action');
      if (rightActionString != null) {
        rightSwipeAction = SwipeActionHelper.actionFromString(rightActionString);
      }
    });
  }

  Future<void> _loadDisplaySettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      useThumbnails = prefs.getBool('use_thumbnails') ?? true;
    });
  }

  Future<void> _loadConvertedVideos() async {
    setState(() {
      isLoading = true;
    });

    try {
      final entries = await ConversionLogService.getAccessibleEntries();
      setState(() {
        convertedVideos = entries;
        isLoading = false;
      });
      
      // Load thumbnails in background if enabled
      if (useThumbnails) {
        _loadThumbnails();
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Error loading converted videos: $e');
    }
  }

  Future<void> _loadThumbnails() async {
    for (final entry in convertedVideos) {
      if (thumbnailCache.containsKey(entry.convertedPath)) continue;
      
      try {
        // First check if thumbnail already exists
        String? thumbnailPath = await ThumbnailService.getCachedThumbnail(entry.convertedPath);
        
        // If not, generate it
        thumbnailPath ??= await ThumbnailService.generateThumbnail(entry.convertedPath);
        
        if (mounted) {
          setState(() {
            thumbnailCache[entry.convertedPath] = thumbnailPath;
          });
        }
      } catch (e) {
        print('Error loading thumbnail for ${entry.convertedPath}: $e');
        if (mounted) {
          setState(() {
            thumbnailCache[entry.convertedPath] = null;
          });
        }
      }
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
      selectedIndices = Set.from(List.generate(convertedVideos.length, (index) => index));
    });
  }

  void _deleteSelectedFiles() async {
    try {
      final filesToDelete = selectedIndices.map((index) => convertedVideos[index]).toList();
      for (final entry in filesToDelete) {
        final fileToDelete = File(entry.convertedPath);
        if (await fileToDelete.exists()) {
          await fileToDelete.delete();
        }
        // Remove from conversion log
        await ConversionLogService.removeEntry(entry.id);
      }
      
      // Refresh the list
      await _loadConvertedVideos();
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

  Future<bool> _showDeleteConfirmation(ConversionLogEntry entry) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Video'),
          content: Text('Are you sure you want to delete "${entry.fileName}"?'),
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

  Future<void> _openFileLocation(ConversionLogEntry entry) async {
    try {
      final directory = File(entry.convertedPath).parent.path;
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

  Future<void> _copyToClipboard(ConversionLogEntry entry) async {
    try {
      // Copy file to Downloads folder for easy access
      final sourceFile = File(entry.convertedPath);
      if (!await sourceFile.exists()) {
        throw Exception('Source file not found');
      }
      
      // Create a copy in Downloads with a unique name
      final downloadsDir = '/storage/emulated/0/Download';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = entry.fileName;
      final baseName = fileName.substring(0, fileName.lastIndexOf('.'));
      final extension = fileName.substring(fileName.lastIndexOf('.'));
      final copyPath = '$downloadsDir/${baseName}_copy_$timestamp$extension';
      
      await sourceFile.copy(copyPath);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File copied to Downloads folder'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            action: SnackBarAction(
              label: 'Open',
              onPressed: () async {
                try {
                  const platform = MethodChannel('video_converter/folder_opener');
                  await platform.invokeMethod('openFolder', {'path': downloadsDir});
                } catch (e) {
                  // Fallback: copy path to clipboard
                  await Clipboard.setData(ClipboardData(text: copyPath));
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not copy file: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _moveToDirectory(ConversionLogEntry entry) async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select destination folder',
        initialDirectory: '/storage/emulated/0',
      );
      
      if (selectedDirectory != null) {
        final sourceFile = File(entry.convertedPath);
        final destinationPath = '$selectedDirectory/${entry.fileName}';
        final destinationFile = File(destinationPath);
        
        // Check if destination file already exists
        if (await destinationFile.exists()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('File already exists in destination folder'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
          return;
        }
        
        await sourceFile.copy(destinationPath);
        await sourceFile.delete();
        
        // Remove from conversion log
        await ConversionLogService.removeEntry(entry.id);
        
        // Refresh the list
        await _loadConvertedVideos();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File moved to $selectedDirectory'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not move file: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _performSwipeAction(SwipeAction action, ConversionLogEntry entry) async {
    switch (action) {
      case SwipeAction.none:
        break;
      case SwipeAction.delete:
        final confirmed = await _showDeleteConfirmation(entry);
        if (confirmed) {
          await _deleteFile(entry);
        }
        break;
      case SwipeAction.openDirectory:
        await _openFileLocation(entry);
        break;
      case SwipeAction.copyToClipboard:
        await _copyToClipboard(entry);
        break;
      case SwipeAction.moveToDirectory:
        await _moveToDirectory(entry);
        break;
    }
  }

  Future<void> _deleteFile(ConversionLogEntry entry) async {
    try {
      final fileToDelete = File(entry.convertedPath);
      if (await fileToDelete.exists()) {
        await fileToDelete.delete();
      }
      
      // Remove from conversion log
      await ConversionLogService.removeEntry(entry.id);
      
      // Refresh the list
      await _loadConvertedVideos();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File deleted'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting file: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Widget _buildLeadingWidget(ConversionLogEntry entry) {
    if (!useThumbnails) {
      return const Icon(Icons.video_file, size: 40);
    }

    final thumbnailPath = thumbnailCache[entry.convertedPath];
    
    if (thumbnailPath == null) {
      // Loading thumbnail
      return Container(
        width: 60,
        height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    
    return Container(
      width: 60,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: thumbnailPath.isNotEmpty
          ? Image.file(
              File(thumbnailPath),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.video_file, size: 24);
              },
            )
          : const Icon(Icons.video_file, size: 24),
      ),
    );
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
              convertedVideos.isNotEmpty 
                ? '${convertedVideos.length} videos found' 
                : 'No converted videos found',
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
                : convertedVideos.isEmpty
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
                            'No converted videos found',
                            style: TextStyle(
                              fontSize: 18,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey[400]
                                  : Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Convert videos to see them here',
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
                      onRefresh: _loadConvertedVideos,
                      child: ListView.builder(
                        itemCount: convertedVideos.length,
                        itemBuilder: (context, index) {
                          final entry = convertedVideos[index];
                          final isSelected = selectedIndices.contains(index);
                          
                          return Dismissible(
                            key: Key(entry.convertedPath),
                            background: leftSwipeAction != SwipeAction.none ? Container(
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: 20),
                              color: SwipeActionHelper.actionColors[leftSwipeAction],
                              child: Icon(
                                SwipeActionHelper.actionIcons[leftSwipeAction],
                                color: Colors.white,
                                size: 30,
                              ),
                            ) : null,
                            secondaryBackground: rightSwipeAction != SwipeAction.none ? Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: SwipeActionHelper.actionColors[rightSwipeAction],
                              child: Icon(
                                SwipeActionHelper.actionIcons[rightSwipeAction],
                                color: Colors.white,
                                size: 30,
                              ),
                            ) : null,
                            confirmDismiss: (direction) async {
                              if (direction == DismissDirection.endToStart && rightSwipeAction != SwipeAction.none) {
                                // Right swipe
                                if (rightSwipeAction == SwipeAction.delete) {
                                  return await _showDeleteConfirmation(entry);
                                } else {
                                  await _performSwipeAction(rightSwipeAction, entry);
                                  return false; // Don't dismiss unless deleting
                                }
                              } else if (direction == DismissDirection.startToEnd && leftSwipeAction != SwipeAction.none) {
                                // Left swipe
                                if (leftSwipeAction == SwipeAction.delete) {
                                  return await _showDeleteConfirmation(entry);
                                } else {
                                  await _performSwipeAction(leftSwipeAction, entry);
                                  return false; // Don't dismiss unless deleting
                                }
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
                                : _buildLeadingWidget(entry),
                              title: Text(
                                entry.fileName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${entry.convertedSizeFormatted} • ${entry.convertedFormat.toUpperCase()}'),
                                  Text(
                                    entry.convertedAt.toString().split('.')[0],
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
                                    icon: const Icon(Icons.play_arrow),
                                    onPressed: () {
                                      if (!isSelectionMode) {
                                        // Convert ConversionLogEntry to VideoFile for compatibility
                                        final videoFile = VideoFile(
                                          path: entry.convertedPath,
                                          name: entry.fileName,
                                          extension: entry.convertedFormat,
                                          size: entry.convertedSize,
                                          createdAt: entry.convertedAt,
                                        );
                                        context.go('/converter', extra: [videoFile]);
                                      }
                                    },
                                  ),
                              selected: isSelected,
                              onTap: () {
                                if (isSelectionMode) {
                                  _toggleSelection(index);
                                } else {
                                  // Convert ConversionLogEntry to VideoFile for compatibility
                                  final videoFile = VideoFile(
                                    path: entry.convertedPath,
                                    name: entry.fileName,
                                    extension: entry.convertedFormat,
                                    size: entry.convertedSize,
                                    createdAt: entry.convertedAt,
                                  );
                                  context.go('/converter', extra: [videoFile]);
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