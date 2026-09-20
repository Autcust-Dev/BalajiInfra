import 'package:freezed_annotation/freezed_annotation.dart';

part 'tenant_status.freezed.dart';

/// Mirrors the `kyc_status` Postgres enum (CLAUDE.md §4 rule 4).
enum KycStatus {
  notStarted,
  submitted,
  approved,
  rejected;

  static KycStatus fromDb(String value) => switch (value) {
    'not_started' => KycStatus.notStarted,
    'submitted' => KycStatus.submitted,
    'approved' => KycStatus.approved,
    'rejected' => KycStatus.rejected,
    _ => throw ArgumentError('Unknown kyc_status: $value'),
  };
}

@freezed
abstract class TenantStatus with _$TenantStatus {
  const factory TenantStatus({
    required bool hasConsent,
    required KycStatus kycStatus,
  }) = _TenantStatus;
}
