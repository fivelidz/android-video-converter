class AppConstants {
  static const String appName = 'Video Converter';
  static const String appVersion = '1.0.0';
  
  static const List<String> supportedInputFormats = [
    'mp4', 'avi', 'mov', 'mkv', 'wmv', 'flv', 'webm', '3gp'
  ];
  
  static const List<String> supportedOutputFormats = [
    'mp4', 'avi', 'mov', 'mkv', 'webm'
  ];
  
  static const Map<String, String> qualityPresets = {
    'High': '1080p',
    'Medium': '720p',
    'Low': '480p',
  };
}