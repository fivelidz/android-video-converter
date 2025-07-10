import 'dart:convert';

class ConversionLogEntry {
  final String id;
  final String originalPath;
  final String convertedPath;
  final String originalFormat;
  final String convertedFormat;
  final String quality;
  final int originalSize;
  final int convertedSize;
  final DateTime convertedAt;
  final bool isAccessible;

  ConversionLogEntry({
    required this.id,
    required this.originalPath,
    required this.convertedPath,
    required this.originalFormat,
    required this.convertedFormat,
    required this.quality,
    required this.originalSize,
    required this.convertedSize,
    required this.convertedAt,
    this.isAccessible = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'originalPath': originalPath,
      'convertedPath': convertedPath,
      'originalFormat': originalFormat,
      'convertedFormat': convertedFormat,
      'quality': quality,
      'originalSize': originalSize,
      'convertedSize': convertedSize,
      'convertedAt': convertedAt.toIso8601String(),
      'isAccessible': isAccessible,
    };
  }

  factory ConversionLogEntry.fromJson(Map<String, dynamic> json) {
    return ConversionLogEntry(
      id: json['id'],
      originalPath: json['originalPath'],
      convertedPath: json['convertedPath'],
      originalFormat: json['originalFormat'],
      convertedFormat: json['convertedFormat'],
      quality: json['quality'],
      originalSize: json['originalSize'],
      convertedSize: json['convertedSize'],
      convertedAt: DateTime.parse(json['convertedAt']),
      isAccessible: json['isAccessible'] ?? true,
    );
  }

  ConversionLogEntry copyWith({
    String? id,
    String? originalPath,
    String? convertedPath,
    String? originalFormat,
    String? convertedFormat,
    String? quality,
    int? originalSize,
    int? convertedSize,
    DateTime? convertedAt,
    bool? isAccessible,
  }) {
    return ConversionLogEntry(
      id: id ?? this.id,
      originalPath: originalPath ?? this.originalPath,
      convertedPath: convertedPath ?? this.convertedPath,
      originalFormat: originalFormat ?? this.originalFormat,
      convertedFormat: convertedFormat ?? this.convertedFormat,
      quality: quality ?? this.quality,
      originalSize: originalSize ?? this.originalSize,
      convertedSize: convertedSize ?? this.convertedSize,
      convertedAt: convertedAt ?? this.convertedAt,
      isAccessible: isAccessible ?? this.isAccessible,
    );
  }

  String get fileName => convertedPath.split('/').last;
  
  String get convertedSizeFormatted {
    if (convertedSize < 1024) return '${convertedSize}B';
    if (convertedSize < 1024 * 1024) return '${(convertedSize / 1024).toStringAsFixed(1)}KB';
    if (convertedSize < 1024 * 1024 * 1024) return '${(convertedSize / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(convertedSize / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}