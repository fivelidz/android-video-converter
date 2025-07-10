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
                final isNative = format == 'mp4' || format == 'mov';
                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(format.toUpperCase()),
                      if (!isNative) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.info_outline,
                          size: 14,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.orange[300]
                              : Colors.orange,
                        ),
                      ],
                    ],
                  ),
                  selected: selectedFormat == format,
                  onSelected: (selected) {
                    if (selected) {
                      onFormatChanged(format);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Text(
              '💡 MP4 and MOV formats are natively supported. Other formats will be converted to MP4.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[400]
                    : Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}