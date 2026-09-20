import 'package:supabase_flutter/supabase_flutter.dart';

import 'tenant_status.dart';

class TenantStatusRepository {
  TenantStatusRepository(this._supabase);

  final SupabaseClient _supabase;

  /// Reads the signed-in tenant's own consent + KYC status. RLS scopes both queries to the
  /// current tenant (`public.is_tenant()` + `current_tenant_id()`) — no tenant id is passed
  /// explicitly (CLAUDE.md §4 rule 13).
  Future<TenantStatus> fetch() async {
    final tenantRow = await _supabase
        .from('tenants')
        .select('kyc_status')
        .maybeSingle();
    if (tenantRow == null) {
      // firebase_uid was linked but the row is no longer visible (e.g. moved out) — RLS
      // already refuses this tenant's data; treat as "not usable" rather than crashing.
      throw StateError('No accessible tenant row for the signed-in account.');
    }

    final consentRow = await _supabase
        .from('consents')
        .select('id')
        .limit(1)
        .maybeSingle();

    return TenantStatus(
      hasConsent: consentRow != null,
      kycStatus: KycStatus.fromDb(tenantRow['kyc_status'] as String),
    );
  }
}
