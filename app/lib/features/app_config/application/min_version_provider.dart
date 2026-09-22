import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/providers.dart';
import '../data/app_config_repository.dart';

final appConfigRepositoryProvider = Provider<AppConfigRepository>((ref) {
  return AppConfigRepository(ref.watch(supabaseClientProvider));
});

/// True if the installed build is older than `app_config.min_app_version` for this
/// platform (CLAUDE.md §4 rule 30). `false` (never block) if no minimum is configured yet
/// or the platform is neither Android nor iOS (e.g. running tests).
///
/// `retry: (_, __) => null` disables Riverpod 3's default automatic-retry-with-backoff —
/// this provider is watched from `startupResolutionProvider`'s guard chain
/// (startup_resolution_provider.dart), which already wraps every step in its own bounded
/// timeout; a Riverpod-level retry underneath would keep this provider "loading" well past
/// that timeout, so the outer wrapper would see a timeout instead of the real error/result.
final belowMinVersionProvider = FutureProvider.autoDispose<bool>((ref) async {
  if (!Platform.isAndroid && !Platform.isIOS) return false;

  final minVersion = await ref
      .watch(appConfigRepositoryProvider)
      .fetchMinVersion(isAndroid: Platform.isAndroid);
  if (minVersion == null) return false;

  final packageInfo = await PackageInfo.fromPlatform();
  return _isOlder(packageInfo.version, minVersion);
}, retry: (retryCount, error) => null);

/// Compares dotted version strings ("1.2.0" vs "1.10.0") numerically per segment, not
/// lexicographically.
bool _isOlder(String current, String minimum) {
  final currentParts = current.split('.').map(int.parse).toList();
  final minimumParts = minimum.split('.').map(int.parse).toList();
  final length = currentParts.length > minimumParts.length
      ? currentParts.length
      : minimumParts.length;

  for (var i = 0; i < length; i++) {
    final currentSegment = i < currentParts.length ? currentParts[i] : 0;
    final minimumSegment = i < minimumParts.length ? minimumParts[i] : 0;
    if (currentSegment != minimumSegment) {
      return currentSegment < minimumSegment;
    }
  }
  return false;
}
