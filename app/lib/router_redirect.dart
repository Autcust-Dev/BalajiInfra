import 'features/tenant_status/data/tenant_status.dart';
import 'router_paths.dart';

/// Pure decision function for the go_router guard chain (CLAUDE.md §4 rule 28): below min
/// version → update screen; not logged in → login; no consent → consent; KYC not approved
/// → pending; approved → home. Kept side-effect-free and separate from router.dart so it's
/// unit-testable without go_router/riverpod/BuildContext.
///
/// Returns the path to redirect to, or `null` to stay on [matchedLocation]. This is the
/// client-side half only — the backend refuses the same data via RLS regardless of what the
/// client navigates to.
String? resolveRedirect({
  required bool belowMinVersion,
  required String matchedLocation,
  required bool isSignedIn,
  required bool tenantResolutionFailed,
  TenantStatus? tenantStatus,
  Object? startupError,
}) {
  // A timeout or transport failure on any startup step (min-version check, tenant link,
  // tenant status) — none of the other fields are trustworthy yet, so this takes priority
  // over everything else below.
  if (startupError != null) {
    return matchedLocation == startupErrorPath ? null : startupErrorPath;
  }

  if (belowMinVersion) {
    return matchedLocation == updateRequiredPath ? null : updateRequiredPath;
  }
  if (matchedLocation == updateRequiredPath) {
    return homePath;
  }

  final atLogin = matchedLocation == loginPath;

  if (!isSignedIn) {
    return atLogin ? null : loginPath;
  }

  if (tenantResolutionFailed || tenantStatus == null) {
    // Linking or the tenant-status query failed (e.g. moved out, network error) — send
    // back to login rather than show a broken main-app shell.
    return atLogin ? null : loginPath;
  }

  if (!tenantStatus.hasConsent) {
    return matchedLocation == consentPath ? null : consentPath;
  }
  if (tenantStatus.kycStatus != KycStatus.approved) {
    return matchedLocation == kycPendingPath ? null : kycPendingPath;
  }

  final onGateRoute =
      atLogin ||
      matchedLocation == consentPath ||
      matchedLocation == kycPendingPath ||
      matchedLocation == splashPath ||
      matchedLocation == startupErrorPath;
  return onGateRoute ? homePath : null;
}
