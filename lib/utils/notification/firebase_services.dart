import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // NOTE: Keep your other platform configurations (web, iOS, macOS, Windows) as they are,
  // unless you also have updated google-services.json/GoogleService-Info.plist for them.
  // The 'web' and 'windows' options are currently linked to 'esasa-app' and 'esas-7d76f'.
  // Ensure consistency across all platforms if they are meant to be for the same project.

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBmvtydFeuYjJ1dWXPHR_Sz6bJ1ANU7G_A',
    appId: '1:938219814194:web:933e2a97ef42ac9e836b2b',
    messagingSenderId: '938219814194',
    projectId: 'esasa-app',
    authDomain: 'esasa-app.firebaseapp.com',
    storageBucket: 'esasa-app.firebasestorage.app',
    measurementId: 'G-NS66LZ1RM2',
  );

  // --- THIS IS THE CORRECTED ANDROID CONFIG ---
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBB8hFCENgoDRvt69qJEkJ5X0faC_uXAPk', // From current_key
    appId:
        '1:437545364197:android:a58220e725cefafc0a020c', // From mobilesdk_app_id
    messagingSenderId: '437545364197', // From project_number
    projectId: 'esas-44d5d', // From project_id
    storageBucket: 'esas-44d5d.firebasestorage.app', // From storage_bucket
    // authDomain and measurementId are not typically in google-services.json for Android
    // unless explicitly configured in Firebase and included by FlutterFire CLI.
    // If you need them for specific features, add them if they appear in your project settings.
  );
  // ------------------------------------------

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAqWLd_KkE5yt8_kkhD_uQ4C5YdW5vWADI',
    appId: '1:938219814194:ios:85aaa16207b38091836b2b',
    messagingSenderId: '938219814194',
    projectId: 'esasa-app',
    storageBucket: 'esasa-app.firebasestorage.app',
    iosBundleId: 'com.sas.esasFlutter',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyB1FsQNASYDQKuDD-1Pbog-2qKDz9w8Ltk',
    appId:
        '1:834167435213:ios:f10b3e5dcf994d2c975e84', // Note: This appId looks like iOS, check if correct for macOS
    messagingSenderId: '834167435213',
    projectId:
        'esas-7d76f', // Inconsistent with other platforms if they are for the same project
    storageBucket: 'esas-7d76f.firebasestorage.app',
    iosBundleId:
        'com.example.esasFlutter', // Ensure this matches your macOS bundle ID
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAwaoLeHambBSYcBCw7iMbkH8I_yjL2-XE',
    appId:
        '1:834167435213:web:fd769b7a61a994ad975e84', // Note: This appId looks like web, check if correct for Windows
    messagingSenderId: '834167435213',
    projectId:
        'esas-7d76f', // Inconsistent with other platforms if they are for the same project
    authDomain: 'esas-7d76f.firebaseapp.com',
    storageBucket: 'esas-7d76f.firebasestorage.app',
    measurementId: 'G-2HTWLTD68P',
  );
}
