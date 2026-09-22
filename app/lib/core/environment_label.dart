import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'env.dart';

/// Debug-only corner label showing which backend a running app is pointed at (LOCAL vs
/// PROD, from [Env.appEnv]) — the app looks identical either way otherwise, and pointing a
/// debug build at the wrong backend is an easy, consequential mistake now that manual
/// testing targets hosted directly pre-launch (CLAUDE.md §3). Never shown in release
/// builds; `Env.appEnv` itself is a plain build-config string, not personal data.
class EnvironmentLabel extends StatelessWidget {
  const EnvironmentLabel({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return child;

    const env = Env.appEnv;
    final color = switch (env) {
      'prod' => Colors.red,
      'local' => Colors.blue,
      _ => Colors.orange,
    };

    return Stack(
      children: [
        child,
        Positioned(
          top: 32,
          left: 0,
          child: IgnorePointer(
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(6),
                    bottomRight: Radius.circular(6),
                  ),
                ),
                child: Text(
                  env.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
