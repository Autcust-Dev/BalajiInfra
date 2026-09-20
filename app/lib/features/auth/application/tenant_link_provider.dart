import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import 'auth_flow_controller.dart';

/// Ensures the signed-in Firebase user's UID is linked onto their `tenants` row before
/// anything else queries tenant data (see the "Trusted backend role" comment on
/// tenants.firebase_uid in supabase/migrations/20260918200112_tenants.sql). Runs once per
/// signed-in user — cached by riverpod until [authStateProvider]'s user changes — and is a
/// no-op (never throws) when signed out.
final linkTenantProvider = FutureProvider.autoDispose<void>((ref) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) return;
  await ref.watch(authRepositoryProvider).linkFirebaseUid();
});
