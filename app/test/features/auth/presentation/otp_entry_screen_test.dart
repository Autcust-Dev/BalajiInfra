import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostels/features/auth/application/auth_flow_controller.dart';
import 'package:hostels/features/auth/application/auth_flow_state.dart';
import 'package:hostels/features/auth/presentation/otp_entry_screen.dart';

class _FakeAuthFlowController extends AuthFlowController {
  _FakeAuthFlowController(this._nextState);

  final AuthFlowState _nextState;
  ({String verificationId, String smsCode})? submittedOtp;

  @override
  AuthFlowState build() =>
      const AuthFlowState.otpSent('fake-verification-id', '+919876500001');

  @override
  Future<void> submitOtp(String verificationId, String smsCode) async {
    submittedOtp = (verificationId: verificationId, smsCode: smsCode);
    state = _nextState;
  }
}

void main() {
  testWidgets('shows the phone number and an OTP field', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authFlowControllerProvider.overrideWith(
            () => _FakeAuthFlowController(const AuthFlowState.verifyingOtp()),
          ),
        ],
        child: const MaterialApp(
          home: OtpEntryScreen(
            verificationId: 'fake-verification-id',
            phone: '+919876500001',
          ),
        ),
      ),
    );

    expect(find.textContaining('+919876500001'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Verify'), findsOneWidget);
  });

  testWidgets('submits the entered code with the verificationId it was given', (
    tester,
  ) async {
    late _FakeAuthFlowController controller;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authFlowControllerProvider.overrideWith(() {
            controller = _FakeAuthFlowController(
              const AuthFlowState.signedIn(),
            );
            return controller;
          }),
        ],
        child: const MaterialApp(
          home: OtpEntryScreen(
            verificationId: 'fake-verification-id',
            phone: '+919876500001',
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.widgetWithText(FilledButton, 'Verify'));
    await tester.pump();

    expect(controller.submittedOtp, (
      verificationId: 'fake-verification-id',
      smsCode: '123456',
    ));
  });

  testWidgets('shows an error message without navigating away on failure', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authFlowControllerProvider.overrideWith(
            () => _FakeAuthFlowController(
              const AuthFlowState.error('Invalid code'),
            ),
          ),
        ],
        child: const MaterialApp(
          home: OtpEntryScreen(
            verificationId: 'fake-verification-id',
            phone: '+919876500001',
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Verify'));
    await tester.pump();

    expect(find.text('Invalid code'), findsOneWidget);
  });
}
