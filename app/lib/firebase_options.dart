// PLACEHOLDER — not real Firebase config. Run:
//   flutterfire configure --project=balajiinfraandhostel --platforms=android,ios
// from app/ to overwrite this file with the real, FlutterFire-CLI-generated output before
// running against actual Firebase. Committed (unlike .env) because Firebase's client
// config is not a secret — it's protected by App Check + security rules, not by being
// hidden (CLAUDE.md §4 rule 12 is about server-side secrets, not this file).
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web is not a supported platform for this app.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for $defaultTargetPlatform.',
        );
    }
  }

  static const android = FirebaseOptions(
    apiKey: 'placeholder-run-flutterfire-configure',
    appId: '1:000000000000:android:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'balajiinfraandhostel',
    storageBucket: 'balajiinfraandhostel.appspot.com',
  );

  static const ios = FirebaseOptions(
    apiKey: 'placeholder-run-flutterfire-configure',
    appId: '1:000000000000:ios:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'balajiinfraandhostel',
    storageBucket: 'balajiinfraandhostel.appspot.com',
    iosBundleId: 'com.balajiinfra.hostels',
  );
}
