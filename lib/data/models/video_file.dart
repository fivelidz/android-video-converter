class VideoFile {
  final String path;
  final String name;
  final String extension;
  final int size;
  final DateTime createdAt;

  VideoFile({
    required this.path,
    required this.name,
    required this.extension,
    required this.size,
    required this.createdAt,
  });

  String get displayName => name.split('.').first;
  String get sizeFormatted => '${(size / 1024 / 1024).toStringAsFixed(2)} MB';
}

class ConversionTask {
  final VideoFile inputFile;
  final String outputFormat;
  final String quality;
  final String outputPath;
  final ConversionStatus status;
  final double progress;
  final String? errorMessage;

  ConversionTask({
    required this.inputFile,
    required this.outputFormat,
    required this.quality,
    required this.outputPath,
    this.status = ConversionStatus.pending,
    this.progress = 0.0,
    this.errorMessage,
  });

  ConversionTask copyWith({
    ConversionStatus? status,
    double? progress,
    String? errorMessage,
  }) {
    return ConversionTask(
      inputFile: inputFile,
      outputFormat: outputFormat,
      quality: quality,
      outputPath: outputPath,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

enum ConversionStatus {
  pending,
  processing,
  completed,
  failed,
}