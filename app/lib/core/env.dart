// Values are supplied at build/run time via --dart-define-from-file=.env.local or
// --dart-define-from-file=.env.prod (see .env.example and README.md's "Local setup — app").
// Never hardcode real project values here.
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  /// 'local' or 'prod', matching whichever .env.* file was passed to
  /// --dart-define-from-file. 'unknown' only if the app was somehow run without one — see
  /// EnvironmentLabel (core/environment_label.dart), which surfaces this in debug builds so
  /// it's always obvious which backend a running app is pointed at (CLAUDE.md §4 rule 22
  /// note: this is a plain build-config string, not personal data).
  static const appEnv = String.fromEnvironment('APP_ENV', defaultValue: 'unknown');
}
