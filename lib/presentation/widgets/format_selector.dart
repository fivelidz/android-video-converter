import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../data/services/video_converter_service.dart';

class FormatSelector extends StatefulWidget {
  final String selectedFormat;
  final ValueChanged<String> onFormatChanged;

  const FormatSelector({
    super.key,
    required this.selectedFormat,
    required this.onFormatChanged,
  });

  @override
  State<FormatSelector> createState() => _FormatSelectorState();
}

class _FormatSelectorState extends State<FormatSelector> {
  bool _ffmpegAvailable = false;
  final VideoConverterService _converterService = VideoConverterService();

  @override
  void initState() {
    super.initState();
    _checkFFmpegAvailability();
  }

  Future<void> _checkFFmpegAvailability() async {
    try {
      final available = await _converterService.isVideoCompressionSupported();
      if (mounted) {
        setState(() {
          _ffmpegAvailable = available;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _ffmpegAvailable = false;
        });
      }
    }
  }

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
                final isVideoCompressSupported = format == 'mp4' || format == 'mov';
                final needsFFmpeg = !isVideoCompressSupported;
                final showWarning = needsFFmpeg && !_ffmpegAvailable;
                
                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(format.toUpperCase()),
                      if (showWarning) ...[
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
                  selected: widget.selectedFormat == format,
                  onSelected: (selected) {
                    if (selected) {
                      widget.onFormatChanged(format);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Text(
              _getFormatHelpText(),
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

  String _getFormatHelpText() {
    if (_ffmpegAvailable) {
      return '✅ All formats supported via FFmpeg. MP4/MOV also have native support.';
    } else {
      return '💡 MP4 and MOV are natively supported. Other formats will convert to MP4 (requires FFmpeg for true format conversion).';
    }
  }
}