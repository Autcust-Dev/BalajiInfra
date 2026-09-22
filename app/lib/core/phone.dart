// Mirrors the server-side check in supabase/functions/check-phone/index.ts — kept in sync
// manually since one is Dart and the other TypeScript.
final _phonePattern = RegExp(r'^\+91[0-9]{10}$');

bool isValidPhoneE164(String phone) => _phonePattern.hasMatch(phone);
