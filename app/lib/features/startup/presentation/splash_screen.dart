import 'package:flutter/material.dart';

/// Shown at [splashPath] (router_paths.dart) while `startupResolutionProvider` is
/// [AsyncLoading] — the fix for the "black screen on app start" failure mode: go_router's
/// `initialLocation` now points here, so there is always a page to build immediately,
/// instead of nothing being rendered while the guard chain resolves.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
