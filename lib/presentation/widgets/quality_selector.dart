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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppConstants.qualityPresets.map((preset) {
                return ChoiceChip(
                  label: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(preset['name']!),
                      Text(
                        preset['resolution']!,
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[400]
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  selected: selectedQuality == preset['name'],
                  onSelected: (selected) {
                    if (selected) {
                      onQualityChanged(preset['name']!);
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