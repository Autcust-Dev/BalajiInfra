import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/tenant_not_resolvable_exception.dart';
import '../../app_config/application/min_version_provider.dart';
import '../../tenant_status/application/tenant_status_provider.dart';
import '../../tenant_status/data/tenant_status.dart';
import 'startup_resolution.dart';
import 'startup_retry_backoff_provider.dart';
import 'tenant_link_provider.dart';

/// How long a single startup step may take before it's treated as unreachable/hung rather
/// than awaited forever (this is what fixes the "black screen on app start" failure mode —
/// see startup_resolution_provider.dart's doc comment). Overridden with a short duration in
/// tests so "slow server" cases don't actually wait seconds.
final startupStepTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 10),
);

void _debugLog(String message) {
  // Debug builds only (CLAUDE.md §4 rule 22: never log personal data — this only ever logs
  // booleans/enums/step names/error types, never a phone number, uid, name, or token).
  if (kDebugMode) debugPrint('[guard-chain] $message');
}

Future<T> _withStepTimeout<T>(
  Ref ref,
  String step,
  Future<T> Function() action,
) async {
  _debugLog('$step: starting');
  try {
    final result = await action().timeout(
      ref.read(startupStepTimeoutProvider),
      onTimeout: () => throw GuardChainStepTimeoutException(step),
    );
    _debugLog('$step: ok');
    return result;
  } catch (error) {
    _debugLog('$step: failed ($error)');
    rethrow;
  }
}

/// Resolves every check the go_router guard chain needs (CLAUDE.md §4 rule 28) as a single
/// bounded, retriable unit instead of awaiting each one directly inside `redirect` — an
/// unbounded await there (the original Phase 3 bug) means one hung network call blocks
/// go_router from ever building a page: no error, no navigation, just a black screen
/// forever. Each step now has a timeout ([startupStepTimeoutProvider]); the router shows a
/// splash screen while this is [AsyncLoading] and a friendly Retry screen if it becomes
/// [StartupResolution.startupError] (timeout, or any transport-level failure) — see
/// router.dart.
///
/// Re-verifies the tenant link on every resolution, including when Firebase already has a
/// signed-in user at cold start (not just right after OTP entry) — linkFirebaseUid is
/// idempotent, so this is safe to repeat.
///
/// This provider never throws — every startup failure is caught here and carried as
/// [StartupResolution.startupError] data instead of an [AsyncError]. On-device testing
/// (real USB device, unreachable local Supabase) found that letting the failure propagate
/// as a thrown error made Riverpod 3's automatic retry-with-backoff kick in underneath this
/// provider's own bounded timeout: even with `retry: null` set on every leaf provider in
/// this chain (min-version, tenant link, tenant status) *and* on this provider itself, the
/// watched-dependency error path re-entered `AsyncLoading(retrying: true)` a handful of
/// times before settling — each leaf provider's own network call still only ran once (its
/// own `retry: null` held), but this provider's body re-ran a few times for free, which is
/// wasted work and risks UI flicker between the splash and error screens. Never throwing at
/// all sidesteps that machinery entirely rather than depending on it doing nothing.
final startupResolutionProvider = FutureProvider.autoDispose<StartupResolution>((
  ref,
) async {
  try {
    final belowMinVersion = await _withStepTimeout(
      ref,
      'min-version check',
      () => ref.watch(belowMinVersionProvider.future),
    );

    final user = await _withStepTimeout(
      ref,
      'firebase auth state',
      () => ref.watch(authStateProvider.future),
    );

    if (user == null) {
      _debugLog('resolved: signed out');
      ref.read(startupRetryBackoffProvider.notifier).recordSuccess();
      return StartupResolution(
        belowMinVersion: belowMinVersion,
        isSignedIn: false,
        tenantResolutionFailed: false,
      );
    }

    var tenantResolutionFailed = false;
    TenantStatus? tenantStatus;
    try {
      await _withStepTimeout(
        ref,
        'tenant link',
        () => ref.watch(linkTenantProvider.future),
      );
      tenantStatus = await _withStepTimeout(
        ref,
        'tenant status',
        () => ref.watch(tenantStatusProvider.future),
      );
    } on TenantNotResolvableException {
      tenantResolutionFailed = true;
    }

    _debugLog(
      'resolved: signed in, tenantResolutionFailed=$tenantResolutionFailed, '
      'tenantStatus=$tenantStatus',
    );
    ref.read(startupRetryBackoffProvider.notifier).recordSuccess();
    return StartupResolution(
      belowMinVersion: belowMinVersion,
      isSignedIn: true,
      tenantResolutionFailed: tenantResolutionFailed,
      tenantStatus: tenantStatus,
    );
  } catch (error) {
    _debugLog('resolved: startup error ($error)');
    ref.read(startupRetryBackoffProvider.notifier).recordFailure();
    return StartupResolution(
      belowMinVersion: false,
      isSignedIn: false,
      tenantResolutionFailed: false,
      startupError: error,
    );
  }
});
