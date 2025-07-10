# Android Video Converter

A powerful Flutter-based Android application for converting video files between multiple formats with professional-grade quality and performance.

## 🎯 Features

### Core Functionality
- **Multi-Format Support**: Convert between MP4, WebM, AVI, MOV, and MKV formats
- **Quality Presets**: High (1080p), Medium (720p), and Low (480p) conversion options
- **Real-Time Progress**: Live conversion progress tracking with detailed statistics
- **Batch Processing**: Support for multiple video file conversions
- **Modern UI**: Clean, intuitive Material Design 3 interface

### Advanced Capabilities
- **FFmpeg Integration**: Professional video processing with libvpx-vp9 for WebM
- **Hybrid Architecture**: Intelligent fallback system for maximum compatibility
- **Hardware Optimization**: Leverages device capabilities for optimal performance
- **File Management**: Automatic output directory creation and file organization

## 🛠️ Technology Stack

### Framework & Language
- **Flutter**: Cross-platform mobile development framework
- **Dart**: Primary programming language
- **Android SDK**: Native Android integration

### Video Processing
- **FFmpeg**: Primary video conversion engine via `ffmpeg_kit_flutter_new`
- **Video Compress**: Lightweight fallback for basic MP4 operations
- **Native Android MediaCodec**: Hardware-accelerated processing support

### Architecture
- **Clean Architecture**: Separation of concerns with Core/Data/Presentation layers
- **State Management**: Flutter Riverpod for reactive state handling
- **Navigation**: GoRouter for declarative routing

## 📱 System Requirements

- **Android**: 7.0 (API level 24) or higher
- **RAM**: Minimum 2GB recommended for video processing
- **Storage**: Variable based on video file sizes
- **Permissions**: Storage access for file reading/writing

## 🚀 Installation

### Prerequisites
- Flutter 3.32.5 or higher
- Android Studio with Android SDK
- Dart SDK (included with Flutter)

### Setup
1. **Clone the repository**
   ```bash
   git clone https://github.com/fivelidz/android-video-converter.git
   cd android-video-converter
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Android**
   - Ensure Android SDK is properly installed
   - Connect an Android device or start an emulator

4. **Run the application**
   ```bash
   flutter run
   ```

## 📁 Project Structure

```
lib/
├── core/
│   └── constants/           # App-wide constants and configuration
│       └── app_constants.dart
├── data/
│   ├── models/             # Data models and entities
│   │   └── video_file.dart
│   └── services/           # Business logic and data processing
│       ├── video_converter_service.dart
│       └── ffmpeg_video_converter_service.dart
├── presentation/
│   ├── screens/            # UI screens and pages
│   │   ├── home_screen.dart
│   │   ├── converter_screen.dart
│   │   └── settings_screen.dart
│   └── widgets/            # Reusable UI components
│       ├── conversion_progress.dart
│       ├── format_selector.dart
│       ├── quality_selector.dart
│       └── video_file_card.dart
└── main.dart              # Application entry point
```

## 🔧 Configuration

### Supported Input Formats
- MP4, AVI, MOV, MKV, WMV, FLV, WebM, 3GP

### Supported Output Formats
- **MP4**: H.264/AAC encoding for universal compatibility
- **WebM**: VP9/Vorbis encoding for web optimization
- **AVI**: Legacy format support
- **MOV**: QuickTime format for Apple ecosystems
- **MKV**: Matroska container for high-quality video

### Quality Settings
| Preset | Resolution | Target Bitrate | Use Case |
|--------|------------|----------------|----------|
| High   | 1080p      | CRF 18        | Archive/Professional |
| Medium | 720p       | CRF 23        | General use/Sharing |
| Low    | 480p       | CRF 28        | Quick sharing/Storage |

## 🔄 Conversion Process

1. **File Selection**: Choose video files using the built-in file picker
2. **Format Selection**: Select desired output format from supported options
3. **Quality Configuration**: Choose quality preset based on requirements
4. **Processing**: Monitor real-time conversion progress
5. **Output**: Access converted files in the app's designated directory

## 🏗️ Development

### Key Dependencies
```yaml
dependencies:
  flutter_riverpod: ^2.3.6        # State management
  go_router: ^16.0.0              # Navigation
  ffmpeg_kit_flutter_new: ^2.0.0  # Video conversion
  video_compress: ^3.1.3          # Fallback processing
  file_picker: ^8.1.2             # File selection
  path_provider: ^2.0.15          # Directory access
  permission_handler: ^11.3.1     # Runtime permissions
```

### Build Commands
```bash
# Development build
flutter run --debug

# Release build
flutter build apk --release

# Analyze code quality
flutter analyze

# Run tests
flutter test

# Format code
dart format .
```

## 📊 Performance

### Conversion Speed
- **Hardware Acceleration**: Utilizes device GPU when available
- **Multi-threading**: Parallel processing for improved performance
- **Memory Management**: Efficient handling of large video files

### App Size
- **Base APK**: ~15MB (without video processing libraries)
- **With FFmpeg**: ~115MB (includes comprehensive codec support)
- **Optimization**: ProGuard enabled for release builds

## 🔒 Permissions

The app requires the following Android permissions:
- `READ_EXTERNAL_STORAGE`: Access video files
- `WRITE_EXTERNAL_STORAGE`: Save converted videos
- `MANAGE_EXTERNAL_STORAGE`: Full file system access (Android 11+)

## 🐛 Troubleshooting

### Common Issues
1. **Build Failures**: Ensure Android SDK and NDK are properly configured
2. **Permission Denied**: Enable storage permissions in device settings
3. **Conversion Errors**: Check input file format and integrity
4. **Memory Issues**: Close other apps during large file conversions

### Debug Mode
Enable detailed logging by setting debug flags in `main.dart`:
```dart
VideoCompress.setLogLevel(1); // Enable FFmpeg logs
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/enhancement`)
3. Commit changes (`git commit -am 'Add new feature'`)
4. Push to branch (`git push origin feature/enhancement`)
5. Create a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **FFmpeg Team**: For the powerful video processing library
- **Flutter Community**: For the excellent ecosystem and packages
- **Contributors**: All developers who have contributed to this project

## 📞 Support

For issues, questions, or contributions:
- **GitHub Issues**: [Report bugs or request features](https://github.com/fivelidz/android-video-converter/issues)
- **Discussions**: [Join community discussions](https://github.com/fivelidz/android-video-converter/discussions)

---

**Built with ❤️ using Flutter and FFmpeg**