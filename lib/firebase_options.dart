// File generated from the Firebase project `absensascom`, in the format of
// FlutterFire CLI (`flutterfire configure --project=absensascom`).
// Values come from `firebase apps:sdkconfig` for the apps registered there.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
///
/// Keep in step with `android/app/google-services.json` and
/// `ios/Runner/GoogleService-Info.plist`: the native SDKs read those files
/// before Dart runs (push, the Google sign-in client IDs), so a mismatch is
/// two Firebase projects in one process.
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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
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

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA3QDGSbsrpzOkVyZk9k7OkKbRdAWd2ck0',
    appId: '1:873945632876:web:296b94a01117d33a138849',
    messagingSenderId: '873945632876',
    projectId: 'absensascom',
    authDomain: 'absensascom.firebaseapp.com',
    storageBucket: 'absensascom.firebasestorage.app',
    measurementId: 'G-L3RM300QLG',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAIHQtplreVHn648SQPCNpEqvLv91tCu8E',
    appId: '1:873945632876:android:201fc1f973509f84138849',
    messagingSenderId: '873945632876',
    projectId: 'absensascom',
    storageBucket: 'absensascom.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAMsw02gNMaP6Tl2H24zum5XjbSk8XWEz0',
    appId: '1:873945632876:ios:5711102a80f4ee7b138849',
    messagingSenderId: '873945632876',
    projectId: 'absensascom',
    storageBucket: 'absensascom.firebasestorage.app',
    androidClientId:
        '873945632876-a5khis8bnkcmd2uis158ir5ch0o7f12g.apps.googleusercontent.com',
    iosClientId:
        '873945632876-7ric420gt9qmjus0000ckue72r3e84dd.apps.googleusercontent.com',
    iosBundleId: 'com.example.esas',
  );
}
