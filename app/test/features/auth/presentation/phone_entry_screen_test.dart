import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostels/features/auth/application/auth_flow_controller.dart';
import 'package:hostels/features/auth/application/auth_flow_state.dart';
import 'package:hostels/features/auth/presentation/phone_entry_screen.dart';

/// Drives the UI through controller states without touching Firebase/Supabase — real
/// network calls have no place in a widget test.
class _FakeAuthFlowController extends AuthFlowController {
  _FakeAuthFlowController(this._nextState);

  final AuthFlowState _nextState;
  String? submittedPhone;

  @override
  AuthFlowState build() => const AuthFlowState.enteringPhone();

  @override
  Future<void> submitPhone(String phone) async {
    submittedPhone = phone;
    state = _nextState;
  }
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required AuthFlowState nextState,
  required _FakeAuthFlowController Function() controllerBuilder,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authFlowControllerProvider.overrideWith(controllerBuilder)],
      child: const MaterialApp(home: PhoneEntryScreen()),
    ),
  );
}

void main() {
  testWidgets('renders a phone field with the +91 prefix and a send button', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      nextState: const AuthFlowState.enteringPhone(),
      controllerBuilder: () =>
          _FakeAuthFlowController(const AuthFlowState.enteringPhone()),
    );

    expect(find.text('+91 '), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Send OTP'), findsOneWidget);
  });

  testWidgets('submitting a phone number navigates to OTP entry once otpSent', (
    tester,
  ) async {
    late _FakeAuthFlowController controller;
    await _pumpScreen(
      tester,
      nextState: const AuthFlowState.otpSent(
        'fake-verification-id',
        '+919876500001',
      ),
      controllerBuilder: () {
        controller = _FakeAuthFlowController(
          const AuthFlowState.otpSent('fake-verification-id', '+919876500001'),
        );
        return controller;
      },
    );

    await tester.enterText(find.byType(TextField), '9876500001');
    await tester.tap(find.widgetWithText(FilledButton, 'Send OTP'));
    await tester.pumpAndSettle();

    expect(controller.submittedPhone, '+919876500001');
    expect(find.text('Enter OTP'), findsOneWidget);
  });

  testWidgets('shows a message and resets when the number is not registered', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      nextState: const AuthFlowState.notAllowed(),
      controllerBuilder: () =>
          _FakeAuthFlowController(const AuthFlowState.notAllowed()),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Send OTP'));
    await tester.pump();

    expect(find.textContaining('not registered'), findsOneWidget);
  });
}
