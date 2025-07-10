import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'Video Converter';
  static const String appVersion = '1.0.0';
  
  static const List<String> supportedInputFormats = [
    'mp4', 'avi', 'mov', 'mkv', 'wmv', 'flv', 'webm', '3gp'
  ];
  
  static const List<String> supportedOutputFormats = [
    'mp4', 'avi', 'mov', 'mkv', 'webm'
  ];
  
  static const List<Map<String, String>> qualityPresets = [
    {'name': 'Low', 'resolution': '480p'},
    {'name': 'Medium', 'resolution': '720p'},
    {'name': 'High', 'resolution': '1080p'},
  ];
}

enum SwipeAction {
  none,
  delete,
  openDirectory,
  copyToClipboard,
  moveToDirectory,
}

class SwipeActionHelper {
  static const Map<SwipeAction, String> actionNames = {
    SwipeAction.none: 'No Action',
    SwipeAction.delete: 'Delete',
    SwipeAction.openDirectory: 'Open Directory',
    SwipeAction.copyToClipboard: 'Copy to Clipboard',
    SwipeAction.moveToDirectory: 'Move to Directory',
  };

  static const Map<SwipeAction, IconData> actionIcons = {
    SwipeAction.none: Icons.block,
    SwipeAction.delete: Icons.delete,
    SwipeAction.openDirectory: Icons.folder_open,
    SwipeAction.copyToClipboard: Icons.copy,
    SwipeAction.moveToDirectory: Icons.drive_file_move,
  };

  static const Map<SwipeAction, Color> actionColors = {
    SwipeAction.none: Colors.grey,
    SwipeAction.delete: Colors.red,
    SwipeAction.openDirectory: Colors.blue,
    SwipeAction.copyToClipboard: Colors.green,
    SwipeAction.moveToDirectory: Colors.orange,
  };

  static String actionToString(SwipeAction action) {
    return action.toString().split('.').last;
  }

  static SwipeAction actionFromString(String actionString) {
    for (SwipeAction action in SwipeAction.values) {
      if (actionToString(action) == actionString) {
        return action;
      }
    }
    return SwipeAction.none;
  }
}