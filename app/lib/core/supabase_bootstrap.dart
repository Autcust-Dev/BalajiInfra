import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'env.dart';

// Supabase third-party auth (Firebase provider, CLAUDE.md §4 rule 14): tenants never get a
// Supabase-issued session. Instead, every request is authenticated by handing Supabase the
// live Firebase ID token via this callback — Supabase validates it directly against
// Firebase's JWKS (configured in supabase/config.toml locally, the dashboard when hosted).
//
// NOTE(Phase 3): verify the `accessToken` override is still the current documented pattern
// for supabase_flutter third-party auth before relying on it further — Supabase APIs
// change (rule 14).
Future<void> bootstrapSupabase() async {
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabasePublishableKey,
    accessToken: () async => FirebaseAuth.instance.currentUser?.getIdToken(),
  );
}
