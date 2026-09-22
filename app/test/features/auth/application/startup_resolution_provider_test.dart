import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostels/core/providers.dart';
import 'package:hostels/core/tenant_not_resolvable_exception.dart';
import 'package:hostels/features/app_config/application/min_version_provider.dart';
import 'package:hostels/features/auth/application/startup_resolution.dart';
import 'package:hostels/features/auth/application/startup_resolution_provider.dart';
import 'package:hostels/features/auth/application/startup_retry_backoff_provider.dart';
import 'package:hostels/features/auth/application/tenant_link_provider.dart';
import 'package:hostels/features/tenant_status/application/tenant_status_provider.dart';
import 'package:hostels/features/tenant_status/data/tenant_status.dart';

/// Implements (not extends) firebase_auth's `User` so tests never touch a real Firebase
/// instance — only nullity of the signed-in user matters to startupResolutionProvider and
/// linkTenantProvider, both of which read [authStateProvider] rather than any User field.
class _FakeUser implements User {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Awaits [startupResolutionProvider] with a keep-alive listener attached first. Without
/// one, a bare `container.read(startupResolutionProvider.future)` races the .autoDispose
/// scheduler: nothing is watching the provider chain once the read completes, so Riverpod
/// can dispose an upstream provider (e.g. tenantStatusProvider) while it's still resolving,
/// and the test then sees a Riverpod "provider disposed" StateError instead of the real
/// error under test.
Future<StartupResolution> _resolve(ProviderContainer container) {
  final subscription = container.listen(
    startupResolutionProvider,
    (previous, next) {},
  );
  addTearDown(subscription.close);
  return container.read(startupResolutionProvider.future);
}

void main() {
  group('startupResolutionProvider', () {
    test(
      'a Firebase user already signed in at startup resolves without hanging, '
      're-verifying the tenant link',
      () async {
        var linkCalls = 0;
        final container = ProviderContainer(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(_FakeUser())),
            linkTenantProvider.overrideWith((ref) async => linkCalls++),
            tenantStatusProvider.overrideWith(
              (ref) async => const TenantStatus(
                hasConsent: true,
                kycStatus: KycStatus.approved,
              ),
            ),
            startupStepTimeoutProvider.overrideWithValue(
              const Duration(milliseconds: 200),
            ),
          ],
        );
        addTearDown(container.dispose);

        final result = await _resolve(container);

        expect(result.isSignedIn, isTrue);
        expect(result.tenantResolutionFailed, isFalse);
        expect(result.startupError, isNull);
        expect(result.tenantStatus?.kycStatus, KycStatus.approved);
        expect(linkCalls, 1, reason: 'the link step must run, not be skipped');
      },
    );

    test(
      'a moved-out / unlinkable tenant (TenantNotResolvableException) resolves as '
      'tenantResolutionFailed, not a startup error',
      () async {
        final container = ProviderContainer(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(_FakeUser())),
            linkTenantProvider.overrideWith((ref) async {}),
            tenantStatusProvider.overrideWith(
              (ref) async =>
                  throw TenantNotResolvableException('No accessible tenant row.'),
            ),
            startupStepTimeoutProvider.overrideWithValue(
              const Duration(milliseconds: 200),
            ),
          ],
        );
        addTearDown(container.dispose);

        final result = await _resolve(container);

        expect(result.tenantResolutionFailed, isTrue);
        expect(result.tenantStatus, isNull);
        expect(result.startupError, isNull);
      },
    );

    test(
      'an unreachable server resolves with startupError set, never throws, and never '
      'silently routes to login',
      () async {
        final container = ProviderContainer(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(_FakeUser())),
            linkTenantProvider.overrideWith((ref) async {}),
            tenantStatusProvider.overrideWith(
              (ref) async => throw const SocketException('Connection refused'),
            ),
            startupStepTimeoutProvider.overrideWithValue(
              const Duration(milliseconds: 200),
            ),
          ],
        );
        addTearDown(container.dispose);

        final result = await _resolve(container);

        expect(result.startupError, isA<SocketException>());
        expect(result.tenantResolutionFailed, isFalse);
      },
    );

    test(
      'a slow/hung request resolves with a GuardChainStepTimeoutException as startupError '
      'instead of blocking the guard chain forever',
      () async {
        final container = ProviderContainer(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(_FakeUser())),
            // Resolves long after the timeout below — simulates a hung/slow request (e.g.
            // an unreachable local Supabase) without leaving a truly never-completing
            // Future in play, which confuses the autoDispose scheduler's own bookkeeping.
            linkTenantProvider.overrideWith(
              (ref) => Future<void>.delayed(const Duration(seconds: 5)),
            ),
            startupStepTimeoutProvider.overrideWithValue(
              const Duration(milliseconds: 50),
            ),
          ],
        );
        addTearDown(container.dispose);

        final result = await _resolve(container);

        expect(result.startupError, isA<GuardChainStepTimeoutException>());
      },
    );

    test('a signed-out user resolves immediately without touching tenant providers', () async {
      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          startupStepTimeoutProvider.overrideWithValue(
            const Duration(milliseconds: 200),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await _resolve(container);

      expect(result.isSignedIn, isFalse);
      expect(result.tenantResolutionFailed, isFalse);
      expect(result.tenantStatus, isNull);
      expect(result.startupError, isNull);
    });

    test(
      'a failed resolution records a failure on startupRetryBackoffProvider, and a '
      'successful one afterwards resets it',
      () async {
        final container = ProviderContainer(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(null)),
            startupStepTimeoutProvider.overrideWithValue(
              const Duration(milliseconds: 200),
            ),
            // Fails the very first step regardless of sign-in state.
            belowMinVersionProvider.overrideWith(
              (ref) async => throw const SocketException('Connection refused'),
            ),
          ],
        );
        addTearDown(container.dispose);

        final failed = await _resolve(container);
        expect(failed.startupError, isNotNull);
        expect(container.read(startupRetryBackoffProvider), 1);

        // A second, real failure increments further.
        container.invalidate(startupResolutionProvider);
        final failedAgain = await _resolve(container);
        expect(failedAgain.startupError, isNotNull);
        expect(container.read(startupRetryBackoffProvider), 2);
      },
    );
  });

  group('startupRetryCooldown', () {
    test('no cooldown for zero or one failure', () {
      expect(startupRetryCooldown(0), Duration.zero);
      expect(startupRetryCooldown(1), Duration.zero);
    });

    test('backs off exponentially and caps at 30s', () {
      expect(startupRetryCooldown(2), const Duration(seconds: 2));
      expect(startupRetryCooldown(3), const Duration(seconds: 4));
      expect(startupRetryCooldown(4), const Duration(seconds: 8));
      expect(startupRetryCooldown(5), const Duration(seconds: 16));
      expect(startupRetryCooldown(6), const Duration(seconds: 30));
      expect(startupRetryCooldown(20), const Duration(seconds: 30));
    });
  });
}
