import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/auth_repository.dart';
import 'auth_flow_state.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(firebaseAuthProvider),
    ref.watch(supabaseClientProvider),
  );
});

final authFlowControllerProvider =
    NotifierProvider<AuthFlowController, AuthFlowState>(AuthFlowController.new);

class AuthFlowController extends Notifier<AuthFlowState> {
  @override
  AuthFlowState build() => const AuthFlowState.enteringPhone();

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  Future<void> submitPhone(String phone) async {
    if (!_repository.isValidPhone(phone)) {
      state = const AuthFlowState.error('Enter a valid 10-digit phone number.');
      return;
    }

    state = const AuthFlowState.checkingPhone();
    final allowed = await _guard(() => _repository.checkPhoneAllowed(phone));
    if (allowed == null) return;

    if (!allowed) {
      state = const AuthFlowState.notAllowed();
      return;
    }

    final verificationId = await _guard(
      () => _repository.sendOtp(phone, onAutoVerified: (_) => _onSignedIn()),
    );
    if (verificationId == null) return;

    state = AuthFlowState.otpSent(verificationId, phone);
  }

  Future<void> submitOtp(String verificationId, String smsCode) async {
    state = const AuthFlowState.verifyingOtp();
    final result = await _guard(
      () => _repository.verifyOtp(
        verificationId: verificationId,
        smsCode: smsCode,
      ),
    );
    if (result == null) return;
    await _onSignedIn();
  }

  Future<void> _onSignedIn() async {
    state = const AuthFlowState.linkingTenant();
    try {
      await _repository.linkFirebaseUid();
    } catch (error) {
      state = AuthFlowState.error(error.toString());
      return;
    }
    state = const AuthFlowState.signedIn();
  }

  void reset() => state = const AuthFlowState.enteringPhone();

  Future<T?> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      state = AuthFlowState.error(error.toString());
      return null;
    }
  }
}
