import 'package:flutter_test/flutter_test.dart';
import 'package:hostels/features/tenant_status/data/tenant_status.dart';
import 'package:hostels/router_paths.dart';
import 'package:hostels/router_redirect.dart';

void main() {
  group('resolveRedirect', () {
    test(
      'sends a below-min-version session to the update screen from anywhere',
      () {
        expect(
          resolveRedirect(
            belowMinVersion: true,
            matchedLocation: homePath,
            isSignedIn: true,
            tenantResolutionFailed: false,
            tenantStatus: const TenantStatus(
              hasConsent: true,
              kycStatus: KycStatus.approved,
            ),
          ),
          updateRequiredPath,
        );
      },
    );

    test('does not loop once already on the update screen', () {
      expect(
        resolveRedirect(
          belowMinVersion: true,
          matchedLocation: updateRequiredPath,
          isSignedIn: false,
          tenantResolutionFailed: false,
        ),
        isNull,
      );
    });

    test('bounces a signed-out user to login', () {
      expect(
        resolveRedirect(
          belowMinVersion: false,
          matchedLocation: homePath,
          isSignedIn: false,
          tenantResolutionFailed: false,
        ),
        loginPath,
      );
    });

    test('does not loop once already on login', () {
      expect(
        resolveRedirect(
          belowMinVersion: false,
          matchedLocation: loginPath,
          isSignedIn: false,
          tenantResolutionFailed: false,
        ),
        isNull,
      );
    });

    test(
      'sends a signed-in user with no consent row to the consent screen',
      () {
        expect(
          resolveRedirect(
            belowMinVersion: false,
            matchedLocation: homePath,
            isSignedIn: true,
            tenantResolutionFailed: false,
            tenantStatus: const TenantStatus(
              hasConsent: false,
              kycStatus: KycStatus.notStarted,
            ),
          ),
          consentPath,
        );
      },
    );

    test(
      'sends a consented, not-yet-approved tenant to the KYC pending screen',
      () {
        expect(
          resolveRedirect(
            belowMinVersion: false,
            matchedLocation: homePath,
            isSignedIn: true,
            tenantResolutionFailed: false,
            tenantStatus: const TenantStatus(
              hasConsent: true,
              kycStatus: KycStatus.submitted,
            ),
          ),
          kycPendingPath,
        );
      },
    );

    test(
      'sends a rejected tenant to the KYC pending screen too (re-upload lives there)',
      () {
        expect(
          resolveRedirect(
            belowMinVersion: false,
            matchedLocation: homePath,
            isSignedIn: true,
            tenantResolutionFailed: false,
            tenantStatus: const TenantStatus(
              hasConsent: true,
              kycStatus: KycStatus.rejected,
            ),
          ),
          kycPendingPath,
        );
      },
    );

    test('lets an approved tenant reach home', () {
      expect(
        resolveRedirect(
          belowMinVersion: false,
          matchedLocation: homePath,
          isSignedIn: true,
          tenantResolutionFailed: false,
          tenantStatus: const TenantStatus(
            hasConsent: true,
            kycStatus: KycStatus.approved,
          ),
        ),
        isNull,
      );
    });

    test(
      'bounces an approved tenant off login/consent/pending/splash/startup-error '
      'back to home',
      () {
        const approved = TenantStatus(
          hasConsent: true,
          kycStatus: KycStatus.approved,
        );
        for (final stale in [
          loginPath,
          consentPath,
          kycPendingPath,
          splashPath,
          startupErrorPath,
        ]) {
          expect(
            resolveRedirect(
              belowMinVersion: false,
              matchedLocation: stale,
              isSignedIn: true,
              tenantResolutionFailed: false,
              tenantStatus: approved,
            ),
            homePath,
            reason: 'stale location $stale should bounce to home once approved',
          );
        }
      },
    );

    test(
      'sends back to login when tenant resolution fails (e.g. moved out)',
      () {
        expect(
          resolveRedirect(
            belowMinVersion: false,
            matchedLocation: homePath,
            isSignedIn: true,
            tenantResolutionFailed: true,
          ),
          loginPath,
        );
      },
    );

    test('moves a signed-out user off the splash screen to login once resolved', () {
      expect(
        resolveRedirect(
          belowMinVersion: false,
          matchedLocation: splashPath,
          isSignedIn: false,
          tenantResolutionFailed: false,
        ),
        loginPath,
      );
    });

    test(
      'moves a signed-in, not-yet-resolved tenant off the splash screen to consent',
      () {
        expect(
          resolveRedirect(
            belowMinVersion: false,
            matchedLocation: splashPath,
            isSignedIn: true,
            tenantResolutionFailed: false,
            tenantStatus: const TenantStatus(
              hasConsent: false,
              kycStatus: KycStatus.notStarted,
            ),
          ),
          consentPath,
        );
      },
    );

    test('sends a startupError to the startup-error screen from anywhere', () {
      expect(
        resolveRedirect(
          belowMinVersion: false,
          matchedLocation: splashPath,
          isSignedIn: false,
          tenantResolutionFailed: false,
          startupError: Exception('unreachable'),
        ),
        startupErrorPath,
      );
    });

    test('does not loop once already on the startup-error screen', () {
      expect(
        resolveRedirect(
          belowMinVersion: false,
          matchedLocation: startupErrorPath,
          isSignedIn: false,
          tenantResolutionFailed: false,
          startupError: Exception('unreachable'),
        ),
        isNull,
      );
    });

    test(
      'startupError takes priority over belowMinVersion and every other field',
      () {
        expect(
          resolveRedirect(
            belowMinVersion: true,
            matchedLocation: homePath,
            isSignedIn: true,
            tenantResolutionFailed: true,
            tenantStatus: const TenantStatus(
              hasConsent: true,
              kycStatus: KycStatus.approved,
            ),
            startupError: Exception('unreachable'),
          ),
          startupErrorPath,
        );
      },
    );
  });
}
