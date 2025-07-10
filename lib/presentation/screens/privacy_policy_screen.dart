import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/settings'),
        ),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy Policy',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Last updated: January 2024',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 24),
            
            Text(
              'Data Collection',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Text(
              '''Video Converter is designed with privacy in mind. We do not collect, store, or transmit any personal data or video content to external servers.

• All video processing is performed locally on your device
• No video files are uploaded to any servers
• No personal information is collected or stored
• No analytics or tracking data is gathered''',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 24),
            
            Text(
              'Local Storage',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Text(
              '''The app stores the following data locally on your device:

• App preferences and settings
• Conversion history and logs
• Custom output directory preferences
• Theme and appearance settings

This data remains on your device and is not shared with any third parties.''',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 24),
            
            Text(
              'Permissions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Text(
              '''The app requests the following permissions:

• Storage Access: Required to read video files for conversion and save converted files
• Media Access: Required to access video files on Android 13+

These permissions are used solely for the app's core functionality and no data is transmitted externally.''',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 24),
            
            Text(
              'Third-Party Services',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Text(
              '''Video Converter does not use any third-party analytics, advertising, or tracking services. All processing is performed locally using the open-source FFmpeg library.''',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 24),
            
            Text(
              'Data Security',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Text(
              '''Your video files and data remain secure on your device:

• No network transmission of video content
• All processing happens locally
• No cloud storage or backup of your files
• You maintain full control over your data''',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 24),
            
            Text(
              'Contact',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Text(
              '''If you have any questions about this Privacy Policy, please contact us through the app store or our official website.''',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}