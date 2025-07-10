import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/converter_screen.dart';
import 'presentation/screens/settings_screen.dart';
import 'presentation/screens/license_screen.dart';
import 'presentation/screens/privacy_policy_screen.dart';
import 'data/models/video_file.dart';

final themeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

// Predefined accent colors
class AccentColors {
  static const List<Color> presets = [
    Colors.deepPurple,
    Colors.blue,
    Colors.teal,
    Colors.green,
    Colors.orange,
    Colors.red,
    Colors.pink,
    Colors.indigo,
  ];
  
  static final Map<Color, String> names = {
    Colors.deepPurple: 'Purple',
    Colors.blue: 'Blue',
    Colors.teal: 'Teal',
    Colors.green: 'Green',
    Colors.orange: 'Orange',
    Colors.red: 'Red',
    Colors.pink: 'Pink',
    Colors.indigo: 'Indigo',
  };
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize app directories and settings
  await _initializeApp();
  
  runApp(const ProviderScope(child: MyApp()));
}

Future<void> _initializeApp() async {
  try {
    // Create default output directory if it doesn't exist
    await _ensureDefaultDirectoryExists();
    
    // Load saved accent color
    await _loadAccentColorSetting();
  } catch (e) {
    print('Initialization error: $e');
    // Continue loading app even if initialization fails
  }
}

Future<void> _ensureDefaultDirectoryExists() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final userDefaultDir = prefs.getString('default_output_directory');
    
    // If user has custom directory, ensure it exists
    if (userDefaultDir != null) {
      final userDir = Directory(userDefaultDir);
      if (!await userDir.exists()) {
        try {
          await userDir.create(recursive: true);
        } catch (e) {
          // If user directory creation fails, fall back to default
          await prefs.remove('default_output_directory');
        }
      }
    }
    
    // Try to create accessible directories
    final directoryOptions = [
      '/storage/emulated/0/Download/VideoConverter', // More accessible on Android 11+
      '/storage/emulated/0/Movies/VideoConverter',   // Try this as secondary
    ];
    
    for (String dirPath in directoryOptions) {
      try {
        print('*** App Init: Trying to create $dirPath ***');
        final dir = Directory(dirPath);
        
        if (!await dir.exists()) {
          await dir.create(recursive: true);
          print('*** App Init: Created directory: $dirPath ***');
        }
        
        // Test write permissions
        final testFile = File('$dirPath/.test_app_init');
        await testFile.writeAsString('app_init_test');
        await testFile.delete();
        print('*** App Init: Successfully initialized: $dirPath ***');
        break; // Success, stop trying other directories
        
      } catch (e) {
        print('*** App Init: Failed to initialize $dirPath: $e ***');
        continue; // Try next directory
      }
    }
  } catch (e) {
    print('Error ensuring default directory: $e');
  }
}

final accentColorProvider = StateNotifierProvider<AccentColorNotifier, Color?>((ref) {
  return AccentColorNotifier();
});

class AccentColorNotifier extends StateNotifier<Color?> {
  AccentColorNotifier() : super(Colors.deepPurple); // Default to deep purple
  
  void setColor(Color? color) {
    state = color ?? Colors.deepPurple;
  }
}

Future<void> _loadAccentColorSetting() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt('accent_color');
    // Color will be loaded in settings screen when needed
  } catch (e) {
    print('Error loading accent color: $e');
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final accentColor = ref.watch(accentColorProvider);

    // Use custom accent color if set, otherwise use Material 3 dynamic colors (from wallpaper)
    final seedColor = accentColor ?? Colors.deepPurple;

    return MaterialApp.router(
      title: 'Video Converter',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: themeMode,
      routerConfig: _router,
    );
  }
}

final GoRouter _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/converter',
      builder: (context, state) => ConverterScreen(
        preSelectedFiles: state.extra as List<VideoFile>?,
      ),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/license',
      builder: (context, state) => const LicenseScreen(),
    ),
    GoRoute(
      path: '/privacy',
      builder: (context, state) => const PrivacyPolicyScreen(),
    ),
  ],
);

