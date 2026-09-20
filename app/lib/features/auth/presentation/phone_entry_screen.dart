import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_flow_controller.dart';
import '../application/auth_flow_state.dart';
import 'otp_entry_screen.dart';

class PhoneEntryScreen extends ConsumerStatefulWidget {
  const PhoneEntryScreen({super.key});

  @override
  ConsumerState<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends ConsumerState<PhoneEntryScreen> {
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authFlowControllerProvider, (previous, next) {
      next.maybeWhen(
        otpSent: (verificationId, phone) {
          Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) =>
                  OtpEntryScreen(verificationId: verificationId, phone: phone),
            ),
          );
        },
        notAllowed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'This number is not registered. Contact your hostel admin.',
              ),
            ),
          );
          ref.read(authFlowControllerProvider.notifier).reset();
        },
        error: (message) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
          ref.read(authFlowControllerProvider.notifier).reset();
        },
        orElse: () {},
      );
    });

    final state = ref.watch(authFlowControllerProvider);
    final isBusy = state.maybeWhen(
      checkingPhone: () => true,
      orElse: () => false,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Log in')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                prefixText: '+91 ',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: isBusy ? null : _submit,
              child: isBusy
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send OTP'),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final digits = _phoneController.text.trim();
    ref.read(authFlowControllerProvider.notifier).submitPhone('+91$digits');
  }
}
