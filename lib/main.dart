import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/converter_screen.dart';
import 'presentation/screens/settings_screen.dart';
import 'data/models/video_file.dart';

final themeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

// Accent color provider - default to null for dynamic colors from wallpaper
final accentColorProvider = StateProvider<Color?>((ref) => null);

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

void main() {
  runApp(const ProviderScope(child: MyApp()));
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
  ],
);

