import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptionsPlaceholder {
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR_ANDROID_API_KEY',
    appId: 'YOUR_ANDROID_APP_ID',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
    projectId: 'cashlyze-b156c',
    storageBucket: 'cashlyze-b156c.firebasestorage.app',
    databaseURL: 'https://cashlyze-b156c-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',
    appId: 'YOUR_IOS_APP_ID',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
    projectId: 'cashlyze-b156c',
    storageBucket: 'cashlyze-b156c.firebasestorage.app',
    iosBundleId: 'com.aspiredesignovation.cashlyze',
    databaseURL: 'https://cashlyze-b156c-default-rtdb.asia-southeast1.firebasedatabase.app',
  );
}
