import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/startup_resolution_provider.dart';
import '../../auth/application/startup_retry_backoff_provider.dart';

/// Shown at [startupErrorPath] (router_paths.dart) when `startupResolutionProvider`
/// resolves with a [StartupResolution.startupError] set — a startup step timed out or a
/// transport-level error occurred (min-version check, tenant link, or tenant status).
/// Never left as a silent hang: Retry re-invalidates the provider, which sends the router
/// back to the splash screen while it re-resolves.
///
/// The Retry button backs off after repeated failures ([startupRetryBackoffProvider]) —
/// instead of letting someone hammer an unreachable server with taps, each consecutive
/// failure imposes a longer cooldown (capped at 30s) before Retry is tappable again.
class StartupErrorScreen extends ConsumerStatefulWidget {
  const StartupErrorScreen({super.key});

  @override
  ConsumerState<StartupErrorScreen> createState() => _StartupErrorScreenState();
}

class _StartupErrorScreenState extends ConsumerState<StartupErrorScreen> {
  Timer? _cooldownTicker;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startCooldownIfNeeded();
  }

  @override
  void dispose() {
    _cooldownTicker?.cancel();
    super.dispose();
  }

  void _startCooldownIfNeeded() {
    final cooldown = startupRetryCooldown(
      ref.read(startupRetryBackoffProvider),
    );
    if (cooldown == Duration.zero) return;

    setState(() => _remaining = cooldown);
    _cooldownTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      final next = _remaining - const Duration(seconds: 1);
      if (next <= Duration.zero) {
        timer.cancel();
        setState(() => _remaining = Duration.zero);
      } else {
        setState(() => _remaining = next);
      }
    });
  }

  void _retry() {
    _cooldownTicker?.cancel();
    ref.invalidate(startupResolutionProvider);
  }

  @override
  Widget build(BuildContext context) {
    final onCooldown = _remaining > Duration.zero;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off, size: 48),
              const SizedBox(height: 16),
              const Text(
                "Couldn't connect. Check your connection and try again.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onCooldown ? null : _retry,
                child: Text(
                  onCooldown ? 'Retry in ${_remaining.inSeconds}s' : 'Retry',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
