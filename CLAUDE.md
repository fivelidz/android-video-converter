# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Development Commands

### Essential Flutter Commands
```bash
# Development
flutter pub get                    # Install dependencies
flutter run                       # Run in development mode
flutter run --release            # Run in release mode

# Build
flutter build apk                 # Build APK for Android
flutter build apk --release       # Build release APK

# Quality Assurance
flutter test                      # Run unit tests
flutter analyze                   # Run static analysis
dart format .                     # Format code

# Dependencies
flutter pub upgrade               # Update dependencies
flutter pub deps                  # Show dependency tree
```

### Android-Specific Commands
```bash
# Build for specific architecture
flutter build apk --target-platform android-arm64

# Install on connected device
flutter install
```

## Project Architecture

### Clean Architecture with Layer Separation
The project follows Clean Architecture principles with three main layers:

- **Core Layer** (`/lib/core/`): App constants and shared utilities
- **Data Layer** (`/lib/data/`): Models and services for business logic
- **Presentation Layer** (`/lib/presentation/`): UI screens and reusable widgets

### State Management
- **Flutter Riverpod** is used for state management
- Use `ConsumerStatefulWidget` for screens requiring state
- Callback-based communication between parent and child widgets

### Navigation
- **GoRouter** handles declarative routing with two main routes:
  - `/` - HomeScreen
  - `/converter` - ConverterScreen

## Key Dependencies

### Core Video Processing
- `flutter_ffmpeg: ^0.4.2` - Video conversion using FFmpeg
- `video_player: ^2.7.0` - Video playback functionality

### File Management
- `file_picker: ^5.3.2` - File selection from device storage
- `path_provider: ^2.0.15` - Access to device directories
- `permission_handler: ^10.4.3` - Runtime permission handling

### State & Navigation
- `flutter_riverpod: ^2.3.6` - State management
- `go_router: ^10.1.2` - Navigation and routing

## Video Conversion Implementation

The app implements a complete video conversion workflow:

1. **File Selection**: Uses `file_picker` to select video files
2. **Format Selection**: Custom widgets for choosing output format (MP4, AVI, MOV, MKV, WebM)
3. **Quality Selection**: Three quality presets (High: 1080p, Medium: 720p, Low: 480p)
4. **Conversion Process**: FFmpeg service with proper command generation
5. **Progress Tracking**: Real-time conversion progress with UI feedback

### FFmpeg Command Generation
The `VideoConverterService` builds FFmpeg commands with:
- Video codec: `libx264`
- Audio codec: `aac` 
- Resolution based on quality preset
- Output to app documents directory

## Android Configuration

### Required Permissions (AndroidManifest.xml)
- `READ_EXTERNAL_STORAGE`
- `WRITE_EXTERNAL_STORAGE`
- `MANAGE_EXTERNAL_STORAGE`

### App Settings
- Single-top launch mode
- Hardware acceleration enabled
- Material Design 3 theme

## File Structure Conventions

```
/lib/
├── core/constants/          # App-wide constants (formats, quality presets)
├── data/
│   ├── models/             # VideoFile, ConversionTask, ConversionStatus
│   └── services/           # VideoConverterService for FFmpeg operations
├── presentation/
│   ├── screens/            # HomeScreen, ConverterScreen
│   └── widgets/            # FormatSelector, QualitySelector, ConversionProgress
└── main.dart               # App entry point with routing setup
```

## Development Notes

- Uses `snake_case` for file names, `PascalCase` for class names
- Conversion service currently includes placeholder implementation that needs FFmpeg integration
- App saves converted files to device's documents directory
- Error handling and state persistence can be enhanced for production use