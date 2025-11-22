# 🚀 Firebase Quick Start Guide

Get Firebase up and running in your Cashlyze app in just a few minutes!

## ⚡ Super Quick Setup (5 minutes)

### Step 1: Create Firebase Project (2 min)
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **"Add project"**
3. Enter project name: **"Cashlyze"**
4. Click **Continue** → **Continue** → **Create project**

### Step 2: Register Web App (1 min)
1. Click the **web icon** `</>`
2. Enter app nickname: **"Cashlyze Web"**
3. Click **"Register app"**
4. **Copy the configuration** (you'll need this next!)

### Step 3: Update Configuration (1 min)
1. Open `lib/firebase_options.dart`
2. Find the `web` section
3. Replace these values with your copied config:
   ```dart
   static const FirebaseOptions web = FirebaseOptions(
     apiKey: 'YOUR_API_KEY_HERE',           // ← Paste your apiKey
     appId: 'YOUR_APP_ID_HERE',             // ← Paste your appId
     messagingSenderId: 'YOUR_SENDER_ID',   // ← Paste your messagingSenderId
     projectId: 'YOUR_PROJECT_ID',          // ← Paste your projectId
     authDomain: 'YOUR_PROJECT_ID.firebaseapp.com',
     storageBucket: 'YOUR_PROJECT_ID.appspot.com',
   );
   ```

### Step 4: Enable Services (1 min)

**Enable Authentication:**
1. In Firebase Console, click **"Authentication"**
2. Click **"Get started"**
3. Click **"Email/Password"**
4. Toggle **"Enable"**
5. Click **"Save"**

**Enable Firestore:**
1. Click **"Firestore Database"**
2. Click **"Create database"**
3. Select **"Start in test mode"**
4. Click **"Next"** → **"Enable"**

### Step 5: Run Your App! (30 sec)
```bash
flutter run -d chrome
```

**That's it!** 🎉 Firebase is now integrated!

---

## 🧪 Test It Out

### Test Authentication
1. Run your app
2. Navigate to the auth screen (you may need to add it to your routes)
3. Try signing up with a test email:
   - Email: `test@example.com`
   - Password: `password123`
4. Check Firebase Console → Authentication to see your new user!

### Test Firestore
Add this code somewhere in your app to test Firestore:

```dart
// Import at the top
import 'package:cloud_firestore/cloud_firestore.dart';

// Add this in a button press or initState
final db = FirebaseFirestore.instance;
await db.collection('test').add({
  'message': 'Hello Firebase!',
  'timestamp': FieldValue.serverTimestamp(),
});
```

Check Firebase Console → Firestore Database to see your data!

---

## 🎯 Next Steps

Now that Firebase is working, here's what to do next:

### 1. Add Auth Screen to Routes
In `lib/routes/app_router.dart`, add:

```dart
GoRoute(
  path: '/auth',
  name: 'auth',
  builder: (context, state) => const AuthScreen(),
),
```

### 2. Add Authentication Guard
Protect your routes by checking if user is logged in:

```dart
redirect: (context, state) {
  // Get current user from provider
  final user = ref.read(currentUserProvider);
  final isAuthRoute = state.matchedLocation == '/auth';
  
  // Redirect to auth if not logged in
  if (user == null && !isAuthRoute) {
    return '/auth';
  }
  
  // Redirect to home if already logged in
  if (user != null && isAuthRoute) {
    return '/';
  }
  
  return null;
},
```

### 3. Use Firebase in Your App

**Check if user is logged in:**
```dart
final user = ref.watch(currentUserProvider);
if (user != null) {
  print('User is logged in: ${user.email}');
}
```

**Listen to auth state changes:**
```dart
ref.listen(authStateChangesProvider, (previous, next) {
  next.when(
    data: (user) {
      if (user != null) {
        // User logged in
      } else {
        // User logged out
      }
    },
    loading: () {},
    error: (error, stack) {},
  );
});
```

**Save data to Firestore:**
```dart
final firestoreService = ref.read(firestoreServiceProvider);
await firestoreService.addDocument('transactions', {
  'amount': 100.0,
  'description': 'Coffee',
  'userId': user.uid,
  'date': FieldValue.serverTimestamp(),
});
```

---

## 📚 Learn More

- **Detailed Setup:** See [FIREBASE_SETUP.md](./FIREBASE_SETUP.md)
- **Architecture:** See [FIREBASE_ARCHITECTURE.md](./FIREBASE_ARCHITECTURE.md)
- **Code Examples:** See [firebase_quick_reference.dart](./lib/core/firebase_quick_reference.dart)
- **Checklist:** See [FIREBASE_CHECKLIST.md](./FIREBASE_CHECKLIST.md)

---

## 🆘 Common Issues

### "Firebase not initialized"
**Solution:** Make sure you updated `firebase_options.dart` with your actual config values.

### "Permission denied" in Firestore
**Solution:** Check that you enabled Firestore in test mode, or update your security rules.

### Auth screen not showing
**Solution:** Add the auth route to your `app_router.dart` file.

### "Invalid API key"
**Solution:** Double-check that you copied the correct values from Firebase Console.

---

## ✅ What You Have Now

- ✅ Firebase Core initialized
- ✅ Authentication ready to use
- ✅ Firestore database ready
- ✅ Auth service with sign in/up/out
- ✅ Firestore service with CRUD operations
- ✅ User model and repository
- ✅ Beautiful auth screen
- ✅ Riverpod providers for state management

---

## 🎨 Customize

### Change Auth Screen Theme
Edit `lib/features/auth/auth_screen.dart` to match your brand colors.

### Add More Auth Methods
Enable Google, Facebook, or Apple sign-in in Firebase Console → Authentication.

### Create Your Data Models
Follow the pattern in `lib/core/models/user_model.dart` to create models for your app's data.

---

## 💡 Pro Tips

1. **Use Test Mode** for Firestore during development
2. **Update Security Rules** before going to production
3. **Enable Email Verification** for better security
4. **Use Transactions** for operations that need to be atomic
5. **Index Your Queries** for better performance (Firestore will prompt you)

---

**Happy Coding!** 🚀

If you need help, check the other documentation files or the code examples in `firebase_quick_reference.dart`.
