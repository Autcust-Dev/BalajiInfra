import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_flow_controller.dart';
import '../application/auth_flow_state.dart';

class OtpEntryScreen extends ConsumerStatefulWidget {
  const OtpEntryScreen({
    super.key,
    required this.verificationId,
    required this.phone,
  });

  final String verificationId;
  final String phone;

  @override
  ConsumerState<OtpEntryScreen> createState() => _OtpEntryScreenState();
}

class _OtpEntryScreenState extends ConsumerState<OtpEntryScreen> {
  final _otpController = TextEditingController();

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authFlowControllerProvider, (previous, next) {
      next.maybeWhen(
        signedIn: () =>
            Navigator.of(context).popUntil((route) => route.isFirst),
        error: (message) => ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message))),
        orElse: () {},
      );
    });

    final state = ref.watch(authFlowControllerProvider);
    final isBusy = state.maybeWhen(
      verifyingOtp: () => true,
      linkingTenant: () => true,
      orElse: () => false,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Enter OTP')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Code sent to ${widget.phone}'),
            const SizedBox(height: 16),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '6-digit code'),
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
                  : const Text('Verify'),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    ref
        .read(authFlowControllerProvider.notifier)
        .submitOtp(widget.verificationId, _otpController.text.trim());
  }
}
