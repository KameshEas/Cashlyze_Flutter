# Firebase Setup Guide for Cashlyze

This guide will help you configure Firebase for your Cashlyze Flutter application.

## Prerequisites

1. A Firebase account (create one at [firebase.google.com](https://firebase.google.com))
2. Flutter SDK installed
3. FlutterFire CLI installed (optional but recommended)

## Installation

The following Firebase packages have been added to your project:

- `firebase_core: ^4.2.1` - Core Firebase functionality
- `firebase_auth: ^6.1.2` - Firebase Authentication
- `cloud_firestore: ^6.1.0` - Cloud Firestore database

## Setup Steps

### 1. Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project" or select an existing project
3. Follow the setup wizard to create your project
4. Enable Google Analytics (optional)

### 2. Register Your App

#### For Web:
1. In Firebase Console, click the web icon (</>) to add a web app
2. Register your app with a nickname (e.g., "Cashlyze Web")
3. Copy the Firebase configuration object

#### For Android:
1. Click the Android icon to add an Android app
2. Enter your package name (e.g., `com.example.cashlyze`)
3. Download the `google-services.json` file
4. Place it in `android/app/` directory

#### For iOS:
1. Click the iOS icon to add an iOS app
2. Enter your bundle ID (e.g., `com.example.cashlyze`)
3. Download the `GoogleService-Info.plist` file
4. Add it to your Xcode project

### 3. Configure Firebase Options

Update the `lib/firebase_options.dart` file with your Firebase project credentials:

```dart
static const FirebaseOptions web = FirebaseOptions(
  apiKey: 'YOUR_WEB_API_KEY',
  appId: 'YOUR_WEB_APP_ID',
  messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
  projectId: 'YOUR_PROJECT_ID',
  authDomain: 'YOUR_PROJECT_ID.firebaseapp.com',
  storageBucket: 'YOUR_PROJECT_ID.appspot.com',
);
```

Replace the placeholder values with your actual Firebase configuration values.

### 4. Enable Authentication

1. In Firebase Console, go to **Authentication** > **Sign-in method**
2. Enable **Email/Password** authentication
3. (Optional) Enable other authentication providers as needed

### 5. Set Up Firestore Database

1. In Firebase Console, go to **Firestore Database**
2. Click **Create database**
3. Choose **Start in test mode** for development (or production mode with custom rules)
4. Select a Cloud Firestore location
5. Click **Enable**

### 6. Configure Firestore Security Rules (Important!)

For development, you can use these rules (in Firebase Console > Firestore Database > Rules):

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow authenticated users to read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Add more collection rules as needed
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

**⚠️ Warning:** The above rules allow any authenticated user to read/write all data. Update these rules for production!

## Using FlutterFire CLI (Recommended)

Instead of manually configuring `firebase_options.dart`, you can use the FlutterFire CLI:

### Install FlutterFire CLI:
```bash
dart pub global activate flutterfire_cli
```

### Configure Firebase:
```bash
flutterfire configure
```

This will:
- Create/update `firebase_options.dart` automatically
- Register your app with Firebase
- Download configuration files

## Project Structure

```
lib/
├── firebase_options.dart          # Firebase configuration
├── core/
│   └── services/
│       ├── auth_service.dart      # Authentication service
│       └── firestore_service.dart # Firestore database service
└── features/
    └── auth/
        └── auth_screen.dart       # Authentication UI
```

## Usage Examples

### Authentication

```dart
// Get auth service
final authService = ref.read(authServiceProvider);

// Sign in
await authService.signInWithEmailAndPassword(
  email: 'user@example.com',
  password: 'password123',
);

// Sign up
await authService.createUserWithEmailAndPassword(
  email: 'user@example.com',
  password: 'password123',
);

// Sign out
await authService.signOut();

// Listen to auth state changes
ref.listen(authStateChangesProvider, (previous, next) {
  if (next.value != null) {
    // User is signed in
  } else {
    // User is signed out
  }
});
```

### Firestore

```dart
// Get firestore service
final firestoreService = ref.read(firestoreServiceProvider);

// Add a document
await firestoreService.addDocument('users', {
  'name': 'John Doe',
  'email': 'john@example.com',
  'createdAt': FieldValue.serverTimestamp(),
});

// Get a document
final doc = await firestoreService.getDocument('users/userId');

// Update a document
await firestoreService.updateDocument('users/userId', {
  'name': 'Jane Doe',
});

// Delete a document
await firestoreService.deleteDocument('users/userId');

// Stream a collection
firestoreService.streamCollection('users').listen((snapshot) {
  for (var doc in snapshot.docs) {
    print(doc.data());
  }
});
```

## Testing

To test Firebase integration:

1. Run your app: `flutter run`
2. Navigate to the auth screen
3. Try signing up with a test email and password
4. Check Firebase Console > Authentication to see the new user
5. Try signing in with the same credentials

## Troubleshooting

### Common Issues:

1. **"Firebase not initialized"**
   - Make sure `Firebase.initializeApp()` is called in `main.dart` before `runApp()`

2. **"Invalid API key"**
   - Double-check your `firebase_options.dart` configuration
   - Ensure you're using the correct configuration for your platform

3. **"Permission denied" in Firestore**
   - Check your Firestore security rules
   - Make sure the user is authenticated

4. **Web app not working**
   - Ensure you've enabled the web platform in Firebase Console
   - Check browser console for errors

## Next Steps

1. ✅ Firebase Core initialized
2. ✅ Authentication service created
3. ✅ Firestore service created
4. ✅ Auth UI screen created
5. 🔲 Configure Firebase project in Firebase Console
6. 🔲 Update `firebase_options.dart` with your credentials
7. 🔲 Set up Firestore security rules
8. 🔲 Integrate auth screen into your app routing
9. 🔲 Create user profile management
10. 🔲 Implement data models and repositories

## Resources

- [Firebase Documentation](https://firebase.google.com/docs)
- [FlutterFire Documentation](https://firebase.flutter.dev/)
- [Firebase Console](https://console.firebase.google.com/)
- [Firestore Security Rules](https://firebase.google.com/docs/firestore/security/get-started)

## Support

For issues or questions:
- Check the [FlutterFire GitHub](https://github.com/firebase/flutterfire)
- Visit [StackOverflow](https://stackoverflow.com/questions/tagged/flutter+firebase)
