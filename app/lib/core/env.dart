// Values are supplied at build/run time via --dart-define-from-file=.env
// (see .env.example). Never hardcode real project values here.
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
}
