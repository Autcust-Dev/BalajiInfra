import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/go_router_refresh_stream.dart';
import 'core/providers.dart';
import 'features/app_config/application/min_version_provider.dart';
import 'features/app_config/presentation/update_required_screen.dart';
import 'features/auth/application/tenant_link_provider.dart';
import 'features/auth/presentation/phone_entry_screen.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/kyc/presentation/consent_placeholder_screen.dart';
import 'features/kyc/presentation/kyc_pending_placeholder_screen.dart';
import 'features/tenant_status/application/tenant_status_provider.dart';
import 'features/tenant_status/data/tenant_status.dart';
import 'router_paths.dart';
import 'router_redirect.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: homePath,
    refreshListenable: GoRouterRefreshStream(
      ref.watch(firebaseAuthProvider).authStateChanges(),
    ),
    redirect: (context, state) async {
      final belowMinVersion = await ref.read(belowMinVersionProvider.future);
      final user = ref.read(firebaseAuthProvider).currentUser;

      TenantStatus? tenantStatus;
      var tenantResolutionFailed = false;
      if (user != null) {
        try {
          await ref.read(linkTenantProvider.future);
          tenantStatus = await ref.read(tenantStatusProvider.future);
        } catch (_) {
          tenantResolutionFailed = true;
        }
      }

      return resolveRedirect(
        belowMinVersion: belowMinVersion,
        matchedLocation: state.matchedLocation,
        isSignedIn: user != null,
        tenantResolutionFailed: tenantResolutionFailed,
        tenantStatus: tenantStatus,
      );
    },
    routes: [
      GoRoute(path: homePath, builder: (context, state) => const HomeScreen()),
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
