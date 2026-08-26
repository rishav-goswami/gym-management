import 'package:firebase_core/firebase_core.dart';

/// Public client configuration for the dedicated platform console Web App.
/// Authorization is enforced by custom claims, Functions, and Firestore rules.
abstract final class PlatformFirebaseOptions {
  static const web = FirebaseOptions(
    apiKey: 'AIzaSyB1kkvEhiRF8zOVlnrOcDjnlO703i1ii80',
    appId: '1:818455248956:web:2c806f83bc91e051ae8339',
    messagingSenderId: '818455248956',
    projectId: 'recipe-app-cdeef',
    authDomain: 'recipe-app-cdeef.firebaseapp.com',
    storageBucket: 'recipe-app-cdeef.appspot.com',
    measurementId: 'G-MDQMK3F6L2',
  );
}
