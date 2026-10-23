// Configuração do Firebase (projeto split-bill-f135e), gerada a partir de
// [1m[31mError:[39m[22m [1mapps:sdkconfig[22m is not a Firebase command. Só Android e iOS: o web não usa Firebase no app
// (o push é só no celular). Esses valores identificam o app, não são segredo.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions? get currentPlatform {
    if (kIsWeb) {
      return null;
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      _ => null,
    };
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD7k08-HGJ0qZSBb_V9_uGyn08MloarPo0',
    appId: '1:772470780333:android:d31f7cbc4ef7781a11f124',
    messagingSenderId: '772470780333',
    projectId: 'split-bill-f135e',
    storageBucket: 'split-bill-f135e.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAcoUcReJHCM7IgANb27N9pY1E1LEVYQ_Q',
    appId: '1:772470780333:ios:6c0873746aa62e3611f124',
    messagingSenderId: '772470780333',
    projectId: 'split-bill-f135e',
    storageBucket: 'split-bill-f135e.firebasestorage.app',
    iosBundleId: 'com.dividiai.app',
  );
}
