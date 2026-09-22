/// Thrown by the tenant link/status data layer for an *expected* "not usable" outcome —
/// moved out, or a firebase_uid link conflict — never for a transport/timeout failure.
/// Deliberately its own type rather than a generic [StateError]:
/// `startupResolutionProvider` catches this specifically to route to login, and a plain
/// StateError is too broad a net (framework internals — e.g. Riverpod's own "provider
/// disposed" error — also throw StateError, and catching those the same way would
/// silently misreport a real bug as "tenant moved out").
class TenantNotResolvableException implements Exception {
  TenantNotResolvableException(this.message);

  final String message;

  @override
  String toString() => message;
}
