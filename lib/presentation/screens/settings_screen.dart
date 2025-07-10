import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../../main.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? customOutputDirectory;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      customOutputDirectory = prefs.getString('default_output_directory');
    });
    
    // Load accent color
    final colorValue = prefs.getInt('accent_color');
    if (colorValue != null) {
      ref.read(accentColorProvider.notifier).state = Color(colorValue);
    }
  }

  Future<void> _saveAccentColor(Color? color) async {
    final prefs = await SharedPreferences.getInstance();
    if (color != null) {
      await prefs.setInt('accent_color', color.value);
    } else {
      await prefs.remove('accent_color');
    }
    ref.read(accentColorProvider.notifier).state = color;
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
                      title: const Text('System (from wallpaper)'),
                      subtitle: const Text('Use dynamic colors from your wallpaper'),
                      trailing: Radio<Color?>(
                        value: null,
                        groupValue: ref.watch(accentColorProvider),
                        onChanged: (value) => _saveAccentColor(value),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Or choose a custom color:',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: AccentColors.presets.map((color) {
                        final isSelected = ref.watch(accentColorProvider) == color;
                        return GestureDetector(
                          onTap: () => _saveAccentColor(color),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(24),
                              border: isSelected
                                  ? Border.all(
                                      color: Theme.of(context).colorScheme.outline,
                                      width: 3,
                                    )
                                  : null,
                            ),
                            child: isSelected
                                ? Icon(
                                    Icons.check,
                                    color: color.computeLuminance() > 0.5
                                        ? Colors.black
                                        : Colors.white,
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
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