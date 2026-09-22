import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_flow_state.freezed.dart';

@freezed
sealed class AuthFlowState with _$AuthFlowState {
  const factory AuthFlowState.enteringPhone() = _EnteringPhone;
  const factory AuthFlowState.checkingPhone() = _CheckingPhone;
  const factory AuthFlowState.notAllowed() = _NotAllowed;
  const factory AuthFlowState.otpSent(String verificationId, String phone) =
      _OtpSent;
  const factory AuthFlowState.verifyingOtp() = _VerifyingOtp;
  const factory AuthFlowState.linkingTenant() = _LinkingTenant;
  const factory AuthFlowState.signedIn() = _SignedIn;
  const factory AuthFlowState.error(String message) = _Error;
}
