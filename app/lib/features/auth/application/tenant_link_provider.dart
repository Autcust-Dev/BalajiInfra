import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import 'auth_flow_controller.dart';

/// Ensures the signed-in Firebase user's UID is linked onto their `tenants` row before
/// anything else queries tenant data (see the "Trusted backend role" comment on
/// tenants.firebase_uid in supabase/migrations/20260918200112_tenants.sql). Runs once per
/// signed-in user — cached by riverpod until [authStateProvider]'s user changes — and is a
/// no-op (never throws) when signed out.
///
/// `retry: (_, __) => null` disables Riverpod 3's default automatic-retry-with-backoff —
/// see the matching note on [belowMinVersionProvider] (min_version_provider.dart): this
/// provider is watched from `startupResolutionProvider`'s bounded-timeout guard chain, so a
/// Riverpod-level retry underneath would mask the outer timeout.
final linkTenantProvider = FutureProvider.autoDispose<void>((ref) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) return;
  await ref.watch(authRepositoryProvider).linkFirebaseUid();
}, retry: (retryCount, error) => null);
