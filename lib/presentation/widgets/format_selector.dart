import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

class FormatSelector extends StatelessWidget {
  final String selectedFormat;
  final ValueChanged<String> onFormatChanged;

  const FormatSelector({
    super.key,
    required this.selectedFormat,
    required this.onFormatChanged,
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
              'Output Format',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppConstants.supportedOutputFormats.map((format) {
                return ChoiceChip(
                  label: Text(format.toUpperCase()),
                  selected: selectedFormat == format,
                  onSelected: (selected) {
                    if (selected) {
                      onFormatChanged(format);
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