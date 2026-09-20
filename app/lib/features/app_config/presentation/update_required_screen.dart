import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Please update the app to continue.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => _openStore(),
                child: const Text('Update now'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Placeholder store link — point at the real Play Store / App Store listing once
  // published (Phase 5/6).
  Future<void> _openStore() async {
    final uri = Uri.parse(
      'https://play.google.com/store/apps/details?id=com.balajiinfra.hostels',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
