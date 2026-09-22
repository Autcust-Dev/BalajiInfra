import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks how many consecutive times startup resolution has failed, so the Retry button
/// (startup_error_screen.dart) can back off instead of letting the user hammer an
/// unreachable server with taps. Reset to 0 the moment resolution succeeds.
///
/// Deliberately NOT autoDispose, unlike `startupResolutionProvider`: it has to survive that
/// provider being invalidated and recreated on every retry, since the whole point is to
/// count failures *across* those recreations.
class StartupRetryBackoff extends Notifier<int> {
  @override
  int build() => 0;

  void recordFailure() => state++;

  void recordSuccess() {
    if (state != 0) state = 0;
  }
}

final startupRetryBackoffProvider = NotifierProvider<StartupRetryBackoff, int>(
  StartupRetryBackoff.new,
);

/// Exponential backoff before the Retry button is usable again, capped at 30s: the first
/// failure gets no cooldown (people expect an immediate retry to be available), then
/// 2s, 4s, 8s, 16s, 30s, 30s, ...
Duration startupRetryCooldown(int consecutiveFailures) {
  if (consecutiveFailures <= 1) return Duration.zero;
  final exponent = (consecutiveFailures - 1).clamp(1, 5);
  return Duration(seconds: (1 << exponent).clamp(0, 30));
}
