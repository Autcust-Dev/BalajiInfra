import 'dart:async';

import 'package:flutter/foundation.dart';

/// Standard go_router recipe for driving `refreshListenable` off a Stream — re-runs the
/// router's `redirect` callback every time [stream] emits, e.g. on Firebase sign-in/out.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
