import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/phone.dart';

class AuthRepository {
  AuthRepository(this._firebaseAuth, this._supabase);

  final FirebaseAuth _firebaseAuth;
  final SupabaseClient _supabase;

  bool isValidPhone(String phone) => isValidPhoneE164(phone);

  /// Calls the `check-phone` Edge Function (CLAUDE.md §4 rule 31). Only ever returns
  /// whether an OTP should be sent — never any tenant detail.
  Future<bool> checkPhoneAllowed(String phone) async {
    final response = await _supabase.functions.invoke(
      'check-phone',
      body: {'phone': phone},
    );
    final data = response.data;
    return data is Map && data['allowed'] == true;
  }

  /// Starts Firebase Phone Auth verification. Resolves with the `verificationId` once the
  /// SMS has been sent, or throws on failure. Android auto-retrieval (verificationCompleted
  /// firing before the user types anything) signs in directly and is surfaced via
  /// [onAutoVerified] instead of the returned verificationId.
  Future<String> sendOtp(
    String phone, {
    required void Function(UserCredential credential) onAutoVerified,
  }) {
    final completer = Completer<String>();

    unawaited(
      _firebaseAuth.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) async {
          final userCredential = await _firebaseAuth.signInWithCredential(
            credential,
          );
          onAutoVerified(userCredential);
        },
        verificationFailed: (error) {
          if (!completer.isCompleted) completer.completeError(error);
        },
        codeSent: (verificationId, resendToken) {
          if (!completer.isCompleted) completer.complete(verificationId);
        },
        codeAutoRetrievalTimeout: (verificationId) {},
      ),
    );

    return completer.future;
  }

  Future<UserCredential> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return _firebaseAuth.signInWithCredential(credential);
  }

  /// Links the just-authenticated Firebase UID onto the matching `tenants` row (Phase 3
  /// first-login flow). Idempotent — safe to call again on every app start once signed in.
  Future<void> linkFirebaseUid() async {
    final response = await _supabase.functions.invoke('link-firebase-uid');
    final data = response.data;
    if (data is! Map || data['linked'] != true) {
      throw StateError('Failed to link tenant account: ${response.data}');
    }
  }

  Future<void> signOut() => _firebaseAuth.signOut();
}
