// IMPORTANTE: Este archivo es generado automáticamente por FlutterFire CLI.
// Ejecuta: flutterfire configure
// para generar este archivo con las credenciales reales de tu proyecto Firebase.
//
// Pasos:
// 1. dart pub global activate flutterfire_cli
// 2. flutterfire configure
// 3. Selecciona tu proyecto Firebase o crea uno nuevo
//
// Este archivo será reemplazado con tus credenciales reales.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions no está configurado para esta plataforma. '
          'Ejecuta: flutterfire configure',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDbCMxm-qQMZ7WOGl9t5Fw8sPlZTvqaQ8A',
    appId: '1:434928723163:android:6c3db1c6b58056cb3a98fe',
    messagingSenderId: '434928723163',
    projectId: 'app-taxi-25305',
    storageBucket: 'app-taxi-25305.firebasestorage.app',
  );

  // REEMPLAZAR con valores reales de flutterfire configure

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDksrHZY5USvLjKX71EQLP0oAagGN_oGzI',
    appId: '1:434928723163:ios:d984dae822d4438c3a98fe',
    messagingSenderId: '434928723163',
    projectId: 'app-taxi-25305',
    storageBucket: 'app-taxi-25305.firebasestorage.app',
    iosBundleId: 'com.taxiapp.taxiApp',
  );

}