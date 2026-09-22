import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/provider_refresh_listenable.dart';
import 'features/app_config/presentation/update_required_screen.dart';
import 'features/auth/application/startup_resolution_provider.dart';
import 'features/auth/presentation/phone_entry_screen.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/kyc/presentation/consent_placeholder_screen.dart';
import 'features/kyc/presentation/kyc_pending_placeholder_screen.dart';
import 'features/startup/presentation/splash_screen.dart';
import 'features/startup/presentation/startup_error_screen.dart';
import 'router_paths.dart';
import 'router_redirect.dart';

// Starts at splashPath, not homePath: `redirect` below only ever reads the *current*
// snapshot of startupResolutionProvider (never awaits it directly), so there is always an
// immediate page to build — splash while loading, the error screen on failure/timeout, and
// only then the real destination. This is the fix for the "black screen on app start"
// failure mode: the previous version awaited belowMinVersionProvider/linkTenantProvider/
// tenantStatusProvider directly inside `redirect`, so a single hung network call (e.g. an
// unreachable local Supabase from a device) blocked go_router from ever building any page.
final routerProvider = Provider<GoRouter>((ref) {
  final refreshListenable = ProviderRefreshListenable();
  final subscription = ref.listen(
    startupResolutionProvider,
    (previous, next) => refreshListenable.notify(),
  );
  ref.onDispose(subscription.close);
  ref.onDispose(refreshListenable.dispose);

  return GoRouter(
    initialLocation: splashPath,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final resolution = ref.read(startupResolutionProvider);
      return resolution.when(
        data: (r) => resolveRedirect(
          belowMinVersion: r.belowMinVersion,
          matchedLocation: state.matchedLocation,
          isSignedIn: r.isSignedIn,
          tenantResolutionFailed: r.tenantResolutionFailed,
          tenantStatus: r.tenantStatus,
          startupError: r.startupError,
        ),
        loading: () =>
            state.matchedLocation == splashPath ? null : splashPath,
        // startupResolutionProvider never actually throws (it catches every startup
        // failure itself and carries it as StartupResolution.startupError, handled by the
        // `data` branch above) — this is a defensive fallback only, for a genuinely
        // unexpected Riverpod-level error.
        error: (error, stackTrace) =>
            state.matchedLocation == startupErrorPath ? null : startupErrorPath,
      );
    },
    routes: [
      GoRoute(path: homePath, builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: splashPath,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: startupErrorPath,
        builder: (context, state) => const StartupErrorScreen(),
      ),
      GoRoute(
        path: loginPath,
        builder: (context, state) => const PhoneEntryScreen(),
      ),
      GoRoute(
        path: consentPath,
        builder: (context, state) => const ConsentPlaceholderScreen(),
      ),
      GoRoute(
        path: kycPendingPath,
        builder: (context, state) => const KycPendingPlaceholderScreen(),
      ),
      GoRoute(
        path: updateRequiredPath,
        builder: (context, state) => const UpdateRequiredScreen(),
      ),
    ],
  );
});
