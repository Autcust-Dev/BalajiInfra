import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/application/tenant_link_provider.dart';
import '../data/tenant_status.dart';
import '../data/tenant_status_repository.dart';

final tenantStatusRepositoryProvider = Provider<TenantStatusRepository>((ref) {
  return TenantStatusRepository(ref.watch(supabaseClientProvider));
});

/// Re-fetched on demand (e.g. app resume, or after the auth flow reaches signedIn) rather
/// than kept live here — Realtime + FCM-driven refresh is Phase 4 scope (CLAUDE.md §4
/// rule 29), which only matters once there's a real KYC review flow to react to.
///
/// Waits on [linkTenantProvider] first — until firebase_uid is linked, is_tenant() is
/// false and this query would just come back empty under RLS.
///
/// `retry: (_, __) => null` disables Riverpod 3's default automatic-retry-with-backoff —
/// see the matching note on `belowMinVersionProvider` (min_version_provider.dart): this
/// provider is watched from `startupResolutionProvider`'s bounded-timeout guard chain, so a
/// Riverpod-level retry underneath would mask the outer timeout.
final tenantStatusProvider = FutureProvider.autoDispose<TenantStatus>((
  ref,
) async {
  await ref.watch(linkTenantProvider.future);
  return ref.watch(tenantStatusRepositoryProvider).fetch();
}, retry: (retryCount, error) => null);
