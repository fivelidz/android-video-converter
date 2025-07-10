import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../models/conversion_log.dart';

class ConversionLogService {
  static const String _logKey = 'conversion_log';
  static const String _logFileName = 'conversion_log.json';
  
  static Future<String> get _logFilePath async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$_logFileName';
  }

  /// Add a new conversion log entry
  static Future<void> addConversionEntry({
    required String originalPath,
    required String convertedPath,
    required String originalFormat,
    required String convertedFormat,
    required String quality,
    required int originalSize,
    required int convertedSize,
  }) async {
    final entry = ConversionLogEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      originalPath: originalPath,
      convertedPath: convertedPath,
      originalFormat: originalFormat,
      convertedFormat: convertedFormat,
      quality: quality,
      originalSize: originalSize,
      convertedSize: convertedSize,
      convertedAt: DateTime.now(),
    );

    final entries = await getAllEntries();
    entries.insert(0, entry); // Add to beginning for newest first
    
    // Keep only last 1000 entries to prevent excessive storage
    if (entries.length > 1000) {
      entries.removeRange(1000, entries.length);
    }
    
    await _saveEntries(entries);
  }

  /// Get all conversion log entries
  static Future<List<ConversionLogEntry>> getAllEntries() async {
    try {
      final logFile = File(await _logFilePath);
      if (!await logFile.exists()) {
        return [];
      }

      final content = await logFile.readAsString();
      final List<dynamic> jsonList = json.decode(content);
      
      return jsonList.map((json) => ConversionLogEntry.fromJson(json)).toList();
    } catch (e) {
      print('Error reading conversion log: $e');
      return [];
    }
  }

  /// Get entries that are still accessible on the device
  static Future<List<ConversionLogEntry>> getAccessibleEntries() async {
    final entries = await getAllEntries();
    final accessibleEntries = <ConversionLogEntry>[];
    
    for (final entry in entries) {
      final file = File(entry.convertedPath);
      final isAccessible = await file.exists();
      
      if (isAccessible) {
        accessibleEntries.add(entry);
      } else {
        // Update the entry to mark as not accessible
        await _updateEntryAccessibility(entry.id, false);
      }
    }
    
    return accessibleEntries;
  }

  /// Update entry accessibility status
  static Future<void> _updateEntryAccessibility(String id, bool isAccessible) async {
    final entries = await getAllEntries();
    final updatedEntries = entries.map((entry) {
      if (entry.id == id) {
        return entry.copyWith(isAccessible: isAccessible);
      }
      return entry;
    }).toList();
    
    await _saveEntries(updatedEntries);
  }

  /// Remove entry from log
  static Future<void> removeEntry(String id) async {
    final entries = await getAllEntries();
    entries.removeWhere((entry) => entry.id == id);
    await _saveEntries(entries);
  }

  /// Clear all entries
  static Future<void> clearAllEntries() async {
    try {
      final logFile = File(await _logFilePath);
      if (await logFile.exists()) {
        await logFile.delete();
      }
    } catch (e) {
      print('Error clearing conversion log: $e');
    }
  }

  /// Save entries to file
  static Future<void> _saveEntries(List<ConversionLogEntry> entries) async {
    try {
      final logFile = File(await _logFilePath);
      final jsonList = entries.map((entry) => entry.toJson()).toList();
      await logFile.writeAsString(json.encode(jsonList));
    } catch (e) {
      print('Error saving conversion log: $e');
    }
  }

  /// Get entries by date range
  static Future<List<ConversionLogEntry>> getEntriesByDateRange(
    DateTime startDate, 
    DateTime endDate
  ) async {
    final entries = await getAllEntries();
    return entries.where((entry) {
      return entry.convertedAt.isAfter(startDate) && 
             entry.convertedAt.isBefore(endDate);
    }).toList();
  }

  /// Get entries by format
  static Future<List<ConversionLogEntry>> getEntriesByFormat(String format) async {
    final entries = await getAllEntries();
    return entries.where((entry) => 
      entry.convertedFormat.toLowerCase() == format.toLowerCase()
    ).toList();
  }

  /// Get total number of conversions
  static Future<int> getTotalConversions() async {
    final entries = await getAllEntries();
    return entries.length;
  }

  /// Get total size of converted files
  static Future<int> getTotalConvertedSize() async {
    final entries = await getAccessibleEntries();
    return entries.fold<int>(0, (total, entry) => total + entry.convertedSize);
  }
}