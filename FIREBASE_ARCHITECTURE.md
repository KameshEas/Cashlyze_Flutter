# Firebase Architecture - Cashlyze

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         Flutter App                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌────────────────────────────────────────────────────────┐    │
│  │                    UI Layer                             │    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │    │
│  │  │ Auth Screen  │  │ Home Screen  │  │ Profile Page │ │    │
│  │  └──────────────┘  └──────────────┘  └──────────────┘ │    │
│  └────────────────────────────────────────────────────────┘    │
│                           │                                      │
│                           ▼                                      │
│  ┌────────────────────────────────────────────────────────┐    │
│  │              Riverpod Providers                         │    │
│  │  ┌──────────────────────────────────────────────────┐  │    │
│  │  │ authStateChangesProvider                         │  │    │
│  │  │ currentUserProvider                              │  │    │
│  │  │ currentUserDataProvider                          │  │    │
│  │  │ currentUserModelProvider                         │  │    │
│  │  └──────────────────────────────────────────────────┘  │    │
│  └────────────────────────────────────────────────────────┘    │
│                           │                                      │
│                           ▼                                      │
│  ┌────────────────────────────────────────────────────────┐    │
│  │              Repository Layer                           │    │
│  │  ┌──────────────────────────────────────────────────┐  │    │
│  │  │ UserRepository                                   │  │    │
│  │  │  - createUser()                                  │  │    │
│  │  │  - getUser()                                     │  │    │
│  │  │  - updateUser()                                  │  │    │
│  │  │  - deleteUser()                                  │  │    │
│  │  │  - streamUser()                                  │  │    │
│  │  └──────────────────────────────────────────────────┘  │    │
│  └────────────────────────────────────────────────────────┘    │
│                           │                                      │
│                           ▼                                      │
│  ┌────────────────────────────────────────────────────────┐    │
│  │                Service Layer                            │    │
│  │  ┌──────────────────┐      ┌──────────────────────┐    │    │
│  │  │  AuthService     │      │  FirestoreService    │    │    │
│  │  │  - signIn()      │      │  - addDocument()     │    │    │
│  │  │  - signUp()      │      │  - getDocument()     │    │    │
│  │  │  - signOut()     │      │  - updateDocument()  │    │    │
│  │  │  - resetPwd()    │      │  - deleteDocument()  │    │    │
│  │  └──────────────────┘      │  - streamDocument()  │    │    │
│  │                             │  - queryCollection() │    │    │
│  │                             └──────────────────────┘    │    │
│  └────────────────────────────────────────────────────────┘    │
│                           │                                      │
│                           ▼                                      │
│  ┌────────────────────────────────────────────────────────┐    │
│  │                 Firebase SDK                            │    │
│  │  ┌──────────────────┐      ┌──────────────────────┐    │    │
│  │  │  firebase_auth   │      │  cloud_firestore     │    │    │
│  │  └──────────────────┘      └──────────────────────┘    │    │
│  │                 firebase_core                           │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Firebase Backend                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────────┐      ┌──────────────────────┐            │
│  │  Authentication  │      │  Cloud Firestore     │            │
│  │  - User Mgmt     │      │  - users/            │            │
│  │  - Email/Pwd     │      │  - transactions/     │            │
│  │  - Sessions      │      │  - categories/       │            │
│  └──────────────────┘      └──────────────────────┘            │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow

### Authentication Flow
```
1. User enters credentials in AuthScreen
   ↓
2. AuthScreen calls AuthService.signIn()
   ↓
3. AuthService calls FirebaseAuth.signInWithEmailAndPassword()
   ↓
4. Firebase returns UserCredential
   ↓
5. authStateChangesProvider emits new user state
   ↓
6. UI updates based on new auth state
   ↓
7. UserRepository.getOrCreateUser() creates/fetches user document
   ↓
8. currentUserDataProvider provides user data to UI
```

### Data Read Flow
```
1. UI watches a Riverpod provider
   ↓
2. Provider calls Repository method
   ↓
3. Repository calls FirestoreService method
   ↓
4. FirestoreService calls Firestore SDK
   ↓
5. Data flows back through the layers
   ↓
6. Provider notifies listeners
   ↓
7. UI rebuilds with new data
```

### Data Write Flow
```
1. User action triggers write operation
   ↓
2. UI calls Repository method
   ↓
3. Repository validates and transforms data
   ↓
4. Repository calls FirestoreService method
   ↓
5. FirestoreService executes Firestore operation
   ↓
6. Success/Error propagates back
   ↓
7. UI shows feedback to user
```

## File Structure

```
lib/
├── main.dart                           # App entry + Firebase init
├── firebase_options.dart               # Platform-specific config
│
├── core/
│   ├── models/
│   │   └── user_model.dart            # User data model
│   │
│   ├── repositories/
│   │   └── user_repository.dart       # User data operations
│   │
│   └── services/
│       ├── auth_service.dart          # Authentication logic
│       └── firestore_service.dart     # Database operations
│
└── features/
    └── auth/
        └── auth_screen.dart           # Authentication UI
```

## Key Components

### 1. Firebase Core
- Initializes Firebase app
- Manages platform-specific configuration
- Required for all Firebase services

### 2. Firebase Auth
- Handles user authentication
- Manages user sessions
- Provides auth state streams

### 3. Cloud Firestore
- NoSQL document database
- Real-time synchronization
- Offline support
- Powerful querying

### 4. Riverpod Providers
- State management
- Dependency injection
- Reactive data flow
- Type-safe

### 5. Repository Pattern
- Abstracts data sources
- Business logic layer
- Data transformation
- Error handling

## Security Model

```
┌─────────────────────────────────────────┐
│         Client (Flutter App)            │
├─────────────────────────────────────────┤
│ - User authentication                   │
│ - Client-side validation                │
│ - UI/UX logic                           │
└─────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│      Firebase Authentication            │
├─────────────────────────────────────────┤
│ - Verifies user identity                │
│ - Issues auth tokens                    │
│ - Manages sessions                      │
└─────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│      Firestore Security Rules           │
├─────────────────────────────────────────┤
│ - Validates auth tokens                 │
│ - Enforces access control               │
│ - Validates data structure              │
│ - Prevents unauthorized access          │
└─────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│         Cloud Firestore                 │
├─────────────────────────────────────────┤
│ - Stores data                           │
│ - Executes queries                      │
│ - Syncs data                            │
└─────────────────────────────────────────┘
```

## Best Practices Implemented

1. **Separation of Concerns**
   - UI, Business Logic, and Data layers are separate
   - Each layer has a single responsibility

2. **Type Safety**
   - Models for all data structures
   - Type-safe providers
   - Compile-time error checking

3. **Error Handling**
   - Try-catch blocks in services
   - User-friendly error messages
   - Proper error propagation

4. **State Management**
   - Riverpod for reactive state
   - Providers for dependency injection
   - Stream-based real-time updates

5. **Code Reusability**
   - Generic Firestore service
   - Reusable repository pattern
   - Shared providers

6. **Security**
   - Authentication required
   - User-specific data access
   - Server-side validation (rules)

7. **Performance**
   - Efficient queries
   - Proper indexing
   - Offline support
   - Optimistic updates

## Next Steps

1. Configure Firebase project
2. Update firebase_options.dart
3. Enable Authentication
4. Create Firestore database
5. Set up security rules
6. Integrate auth screen
7. Test authentication flow
8. Implement data models
9. Create feature repositories
10. Build UI screens
