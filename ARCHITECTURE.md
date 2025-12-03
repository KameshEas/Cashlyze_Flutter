# Architecture Documentation

## Table of Contents

- [Overview](#overview)
- [Architecture Principles](#architecture-principles)
- [Project Structure](#project-structure)
- [Layer Descriptions](#layer-descriptions)
- [Data Flow](#data-flow)
- [State Management](#state-management)
- [Navigation](#navigation)
- [Design Patterns](#design-patterns)
- [Best Practices](#best-practices)

---

## Overview

Cashlyze follows **Clean Architecture** principles combined with **Feature-First** organization. This architecture ensures:

- ✅ **Separation of Concerns** - Clear boundaries between layers
- ✅ **Testability** - Easy to write unit and integration tests
- ✅ **Maintainability** - Code is organized and easy to navigate
- ✅ **Scalability** - Easy to add new features
- ✅ **Reusability** - Shared code in core module

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                      Presentation Layer                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   Screens   │  │   Widgets   │  │  Providers  │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────┴────────────────────────────────────┐
│                     Business Logic Layer                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │  Services   │  │  Use Cases  │  │ Validators  │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────┴────────────────────────────────────┐
│                       Data Layer                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │Repositories │  │   Models    │  │Data Sources │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

---

## Architecture Principles

### 1. Dependency Rule
Dependencies point **inward**. Inner layers don't know about outer layers.

### 2. Single Responsibility Principle (SRP)
Each class/module has one reason to change.

### 3. Dependency Inversion Principle (DIP)
High-level modules don't depend on low-level modules.

### 4. Interface Segregation Principle (ISP)
Clients shouldn't depend on interfaces they don't use.

### 5. Open/Closed Principle (OCP)
Open for extension, closed for modification.

---

## Project Structure

```
lib/
├── main.dart                      # App entry point
├── firebase_options.dart          # Firebase configuration
│
├── core/                          # Shared/Core functionality
│   ├── models/                    # Data models
│   ├── repositories/              # Data access layer
│   ├── services/                  # Business logic services
│   ├── providers/                 # Riverpod state providers
│   ├── theme/                     # App theming
│   ├── utils/                     # Utility functions
│   └── widgets/                   # Reusable widgets
│
├── features/                      # Feature modules
│   ├── auth/                      # Authentication
│   ├── home/                      # Dashboard
│   ├── transactions/              # Transaction management
│   ├── budgets/                   # Budget planning
│   ├── insights/                  # Analytics
│   ├── settings/                  # App settings
│   ├── emi/                       # EMI tracking
│   ├── categories/                # Category management
│   ├── onboarding/                # First-time user experience
│   └── splash/                    # Splash screen
│
├── routes/                        # Navigation configuration
│   └── app_router.dart
│
└── l10n/                          # Localization
    ├── app_localizations.dart
    ├── app_localizations_en.dart
    └── app_localizations_hi.dart
```

---

## Layer Descriptions

### 1. Presentation Layer (`features/` + `core/widgets/`)

**Responsibility**: UI and user interaction

**Components**:
- **Screens**: Full-page views
- **Widgets**: Reusable UI components
- **Providers**: State management using Riverpod

**Example**:
```dart
class HomeScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(recentTransactionsProvider);
    final kpis = ref.watch(kpisProvider);
    
    return Scaffold(
      appBar: AppBar(title: Text('Dashboard')),
      body: transactions.when(
        data: (data) => TransactionList(data),
        loading: () => SkeletonLoader(),
        error: (e, st) => ErrorView(e),
      ),
    );
  }
}
```

### 2. Business Logic Layer (`core/services/`)

**Responsibility**: Business rules and application logic

**Components**:
- **Services**: Encapsulate business logic
- **Validators**: Input validation logic

**Example**:
```dart
class CategorizationService {
  String? suggestCategory(String title) {
    final keywords = {
      'grocery': 'Food',
      'uber': 'Transport',
      'netflix': 'Entertainment',
    };
    
    for (final entry in keywords.entries) {
      if (title.toLowerCase().contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }
}
```

### 3. Data Layer (`core/repositories/` + `core/models/`)

**Responsibility**: Data access and persistence

**Components**:
- **Repositories**: Abstract data sources
- **Models**: Data structures
- **Data Sources**: Firebase, SharedPreferences

---

## Data Flow

### Read Flow (Data → UI)

```
Firebase/Local Storage → Repository → Provider → Widget → UI
```

### Write Flow (UI → Data)

```
User Action → Widget → Service → Repository → Firebase/Local Storage
```

---

## State Management

### Riverpod Architecture

We use **Riverpod** for state management:

#### 1. Provider (Immutable)
```dart
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(firebaseAuthProvider));
});
```

#### 2. StreamProvider (Real-time Data)
```dart
final userTransactionsProvider = StreamProvider<List<TransactionModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.watch(transactionRepositoryProvider).streamForUser(user.uid);
});
```

#### 3. StateProvider (Simple State)
```dart
final selectedTimeRangeProvider = StateProvider<TimeRange>((ref) {
  return TimeRange.last30d;
});
```

---

## Navigation

### go_router Configuration

We use **go_router** for declarative routing with authentication guards and nested navigation.

---

## Design Patterns

### 1. Repository Pattern
Abstracts data sources

### 2. Service Pattern
Encapsulates business logic

### 3. Provider Pattern
State management and dependency injection

### 4. Observer Pattern
Reactive programming with Streams

### 5. Factory Pattern
Creating objects from data

---

## Best Practices

### 1. Code Organization
✅ Group by feature, not by type

### 2. State Management
✅ Use appropriate provider types

### 3. Error Handling
✅ Handle errors gracefully with `.when()`

### 4. Testing
✅ Write testable code with dependency injection

### 5. Documentation
✅ Document public APIs with dartdoc

### 6. Performance
✅ Use const constructors
✅ Use ListView.builder for long lists
✅ Optimize provider rebuilds

---

**Last Updated**: December 3, 2025
