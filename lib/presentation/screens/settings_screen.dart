import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'dart:io';
import '../../main.dart';
import '../../core/constants/app_constants.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? customOutputDirectory;
  SwipeAction leftSwipeAction = SwipeAction.openDirectory;
  SwipeAction rightSwipeAction = SwipeAction.delete;
  bool useThumbnails = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      customOutputDirectory = prefs.getString('default_output_directory');
      useThumbnails = prefs.getBool('use_thumbnails') ?? true;
      
      // Load swipe actions
      final leftActionString = prefs.getString('left_swipe_action');
      if (leftActionString != null) {
        leftSwipeAction = SwipeActionHelper.actionFromString(leftActionString);
      }
      
      final rightActionString = prefs.getString('right_swipe_action');
      if (rightActionString != null) {
        rightSwipeAction = SwipeActionHelper.actionFromString(rightActionString);
      }
    });
    
    // Load accent color
    final colorValue = prefs.getInt('accent_color');
    if (colorValue != null) {
      ref.read(accentColorProvider.notifier).setColor(Color(colorValue));
    }
  }

  Future<void> _saveAccentColor(Color? color) async {
    final prefs = await SharedPreferences.getInstance();
    if (color != null) {
      await prefs.setInt('accent_color', color.value);
    } else {
      await prefs.remove('accent_color');
    }
    ref.read(accentColorProvider.notifier).setColor(color);
  }

  Future<void> _showCustomColorPicker() async {
    Color currentColor = ref.read(accentColorProvider) ?? Colors.deepPurple;
    
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Choose Custom Color'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ColorPicker(
                  pickerColor: currentColor,
                  onColorChanged: (Color color) {
                    currentColor = color;
                  },
                  pickerAreaHeightPercent: 0.8,
                  enableAlpha: false,
                  displayThumbColor: true,
                  showLabel: true,
                  paletteType: PaletteType.hsvWithHue,
                ),
                const SizedBox(height: 16),
                // Hex input field
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Hex Color Code',
                    hintText: '#FF5722',
                    border: OutlineInputBorder(),
                    prefixText: '#',
                  ),
                  onChanged: (String value) {
                    try {
                      if (value.length == 6) {
                        final hexColor = int.parse('FF$value', radix: 16);
                        currentColor = Color(hexColor);
                      }
                    } catch (e) {
                      // Invalid hex input, ignore
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _saveAccentColor(currentColor);
                Navigator.of(context).pop();
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveOutputDirectory(String? directory) async {
    final prefs = await SharedPreferences.getInstance();
    if (directory != null) {
      await prefs.setString('default_output_directory', directory);
    } else {
      await prefs.remove('default_output_directory');
    }
    setState(() {
      customOutputDirectory = directory;
    });
  }

  Future<void> _saveSwipeActions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('left_swipe_action', SwipeActionHelper.actionToString(leftSwipeAction));
    await prefs.setString('right_swipe_action', SwipeActionHelper.actionToString(rightSwipeAction));
  }

  Future<void> _saveThumbnailSetting(bool useThumbnails) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_thumbnails', useThumbnails);
    setState(() {
      this.useThumbnails = useThumbnails;
    });
  }

  Future<void> _pickOutputDirectory() async {
    try {
      // Try to clear cache and start from Movies folder
      try {
        await FilePicker.platform.clearTemporaryFiles();
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
        dialogTitle: 'Choose Default Output Directory',
      );
      
      if (selectedDirectory != null) {
        await _saveOutputDirectory(selectedDirectory);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Default output directory updated',
                style: TextStyle(color: Theme.of(context).colorScheme.onInverseSurface),
              ),
              backgroundColor: Theme.of(context).colorScheme.inverseSurface,
              showCloseIcon: true,
            ),
          );
        }
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

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.go('/');
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Theme Settings
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Appearance',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.brightness_6),
                      title: const Text('Dark Mode'),
                      subtitle: Text(
                        themeMode == ThemeMode.dark 
                          ? 'Dark theme enabled' 
                          : themeMode == ThemeMode.light 
                            ? 'Light theme enabled'
                            : 'System theme'
                      ),
                      trailing: DropdownButton<ThemeMode>(
                        value: themeMode,
                        onChanged: (ThemeMode? newMode) {
                          if (newMode != null) {
                            ref.read(themeProvider.notifier).state = newMode;
                          }
                        },
                        items: const [
                          DropdownMenuItem(
                            value: ThemeMode.system,
                            child: Text('System'),
                          ),
                          DropdownMenuItem(
                            value: ThemeMode.light,
                            child: Text('Light'),
                          ),
                          DropdownMenuItem(
                            value: ThemeMode.dark,
                            child: Text('Dark'),
                          ),
                        ],
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.image),
                      title: const Text('Video Thumbnails'),
                      subtitle: Text(
                        useThumbnails 
                          ? 'Show video preview thumbnails' 
                          : 'Show video file icons'
                      ),
                      trailing: Switch(
                        value: useThumbnails,
                        onChanged: (bool value) {
                          _saveThumbnailSetting(value);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Accent Color Settings
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Accent Color',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.palette),
                      title: const Text('Accent Color'),
                      subtitle: Row(
                        children: [
                          Expanded(
                            child: DropdownButton<Color>(
                              value: AccentColors.presets.contains(ref.watch(accentColorProvider)) 
                                  ? ref.watch(accentColorProvider) 
                                  : null,
                              hint: const Text('Select a color'),
                              isExpanded: true,
                              items: AccentColors.presets.map((color) {
                                return DropdownMenuItem<Color>(
                                  value: color,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: color,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: Theme.of(context).colorScheme.outline,
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(AccentColors.names[color] ?? 'Color'),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (Color? color) {
                                if (color != null) {
                                  _saveAccentColor(color);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            onPressed: _showCustomColorPicker,
                            icon: const Icon(Icons.color_lens),
                            tooltip: 'Custom Color',
                            style: IconButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                              foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Swipe Action Settings
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Swipe Actions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.swipe_left),
                      title: const Text('Left Swipe Action'),
                      subtitle: DropdownButton<SwipeAction>(
                        value: leftSwipeAction,
                        isExpanded: true,
                        items: SwipeAction.values.map((action) {
                          return DropdownMenuItem<SwipeAction>(
                            value: action,
                            child: Row(
                              children: [
                                Icon(
                                  SwipeActionHelper.actionIcons[action],
                                  size: 18,
                                  color: SwipeActionHelper.actionColors[action],
                                ),
                                const SizedBox(width: 8),
                                Text(SwipeActionHelper.actionNames[action] ?? 'Unknown'),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (SwipeAction? newAction) {
                          if (newAction != null) {
                            setState(() {
                              leftSwipeAction = newAction;
                            });
                            _saveSwipeActions();
                          }
                        },
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.swipe_right),
                      title: const Text('Right Swipe Action'),
                      subtitle: DropdownButton<SwipeAction>(
                        value: rightSwipeAction,
                        isExpanded: true,
                        items: SwipeAction.values.map((action) {
                          return DropdownMenuItem<SwipeAction>(
                            value: action,
                            child: Row(
                              children: [
                                Icon(
                                  SwipeActionHelper.actionIcons[action],
                                  size: 18,
                                  color: SwipeActionHelper.actionColors[action],
                                ),
                                const SizedBox(width: 8),
                                Text(SwipeActionHelper.actionNames[action] ?? 'Unknown'),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (SwipeAction? newAction) {
                          if (newAction != null) {
                            setState(() {
                              rightSwipeAction = newAction;
                            });
                            _saveSwipeActions();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Output Directory Settings
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Output Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.folder_open),
                      title: const Text('Default Output Directory'),
                      subtitle: Text(
                        customOutputDirectory ?? 'Movies/VideoConverter (default)'
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (customOutputDirectory != null)
                            IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () async {
                                await _saveOutputDirectory(null);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Reset to default directory',
                                        style: TextStyle(color: Theme.of(context).colorScheme.onInverseSurface),
                                      ),
                                      backgroundColor: Theme.of(context).colorScheme.inverseSurface,
                                      showCloseIcon: true,
                                    ),
                                  );
                                }
                              },
                              tooltip: 'Reset to default',
                            ),
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: _pickOutputDirectory,
                            tooltip: 'Change directory',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}