import 'package:flutter/foundation.dart';

/// Drives go_router's `refreshListenable` off a Riverpod provider's state changes (loading,
/// data, or error) rather than a raw Stream — a `ref.listen(provider, (_, __) =>
/// refreshListenable.notify())` subscription (set up by the caller, since typing that
/// subscription generically here would need `ProviderListenable`, which flutter_riverpod's
/// public API doesn't export) feeds this. Used for `startupResolutionProvider` so the
/// redirect guard chain re-runs the moment startup resolution finishes or changes (sign-in,
/// sign-out, a Retry re-invalidating it), not just on Firebase auth events.
class ProviderRefreshListenable extends ChangeNotifier {
  void notify() => notifyListeners();
}
