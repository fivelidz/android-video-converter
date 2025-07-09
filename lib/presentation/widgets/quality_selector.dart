import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

class QualitySelector extends StatelessWidget {
  final String selectedQuality;
  final ValueChanged<String> onQualityChanged;

  const QualitySelector({
    super.key,
    required this.selectedQuality,
    required this.onQualityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quality',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Column(
              children: AppConstants.qualityPresets.entries.map((entry) {
                return RadioListTile<String>(
                  title: Text(entry.key),
                  subtitle: Text(entry.value),
                  value: entry.key,
                  groupValue: selectedQuality,
                  onChanged: (value) {
                    if (value != null) {
                      onQualityChanged(value);
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}