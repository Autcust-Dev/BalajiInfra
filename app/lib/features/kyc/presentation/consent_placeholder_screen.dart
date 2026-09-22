import 'package:flutter/material.dart';

/// Placeholder for the real consent screen (CLAUDE.md §4 rule 21), built in Phase 4. This
/// phase only needs the route to exist so the go_router guard chain has somewhere to send a
/// tenant with no consent row yet.
class ConsentPlaceholderScreen extends StatelessWidget {
  const ConsentPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('KYC consent — coming in Phase 4')),
    );
  }
}
