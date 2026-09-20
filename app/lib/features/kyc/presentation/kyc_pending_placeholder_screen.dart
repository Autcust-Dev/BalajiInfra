import 'package:flutter/material.dart';

/// Placeholder for the real pending-review screen (CLAUDE.md §4 rule 29: Realtime + FCM +
/// resume-check unlock), built in Phase 4. This phase only needs the route to exist so the
/// go_router guard chain has somewhere to send a tenant whose KYC isn't approved yet.
class KycPendingPlaceholderScreen extends StatelessWidget {
  const KycPendingPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('KYC pending review — coming in Phase 4')),
    );
  }
}
