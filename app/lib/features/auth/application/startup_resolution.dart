import '../../tenant_status/data/tenant_status.dart';

/// Thrown by [startupResolutionProvider] when a single startup network call (min-version
/// check, tenant link, tenant status) doesn't finish within [startupStepTimeoutProvider] —
/// distinguishes "the server is unreachable/slow" from a genuine business-logic outcome
/// (e.g. a moved-out tenant), so the two can be routed to different screens. Caught inside
/// [startupResolutionProvider] itself (see [StartupResolution.startupError]) rather than
/// left to propagate out of the provider.
class GuardChainStepTimeoutException implements Exception {
  GuardChainStepTimeoutException(this.step);

  final String step;

  @override
  String toString() => 'Guard chain step "$step" timed out';
}

/// Combined result of every startup check the go_router guard chain needs (CLAUDE.md §4
/// rule 28) — resolved once by [startupResolutionProvider] per app start/retry rather than
/// awaited piecemeal inside `redirect`, so the router always has an immediate answer
/// (loading/data/error) to build a screen from instead of blocking on a hung network call.
class StartupResolution {
  const StartupResolution({
    required this.belowMinVersion,
    required this.isSignedIn,
    required this.tenantResolutionFailed,
    this.tenantStatus,
    this.startupError,
  });

  final bool belowMinVersion;
  final bool isSignedIn;

  /// True for an *expected* business-logic outcome only (no matching/usable tenant row —
  /// e.g. moved out, or a link conflict) — never for a timeout or transport error, which
  /// instead sets [startupError].
  final bool tenantResolutionFailed;
  final TenantStatus? tenantStatus;

  /// A timeout ([GuardChainStepTimeoutException]) or transport-level failure (e.g.
  /// unreachable server) from any startup step. Set instead of letting
  /// [startupResolutionProvider] itself throw: a thrown/AsyncError provider is subject to
  /// Riverpod's own automatic retry-with-backoff, which fights with this app's own
  /// bounded-timeout-plus-manual-Retry design (see startup_resolution_provider.dart's doc
  /// comment). Carrying the failure as plain data instead means
  /// `startupResolutionProvider` only ever completes with [AsyncData] (or, in genuinely
  /// unexpected cases, an [AsyncError] router.dart still handles defensively) — never an
  /// error Riverpod might decide to retry on its own.
  final Object? startupError;
}
