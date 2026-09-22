import 'package:supabase_flutter/supabase_flutter.dart';

class AppConfigRepository {
  AppConfigRepository(this._supabase);

  final SupabaseClient _supabase;

  /// Reads `app_config.min_app_version`, e.g. `{"android": "1.2.0", "ios": "1.2.0"}`
  /// (CLAUDE.md §4 rule 30). Readable by `anon`, so this can run before login.
  Future<String?> fetchMinVersion({required bool isAndroid}) async {
    final row = await _supabase
        .from('app_config')
        .select('value')
        .eq('key', 'min_app_version')
        .maybeSingle();

    final value = row?['value'];
    if (value is! Map) return null;
    return value[isAndroid ? 'android' : 'ios'] as String?;
  }
}
