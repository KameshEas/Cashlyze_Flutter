# Test Coverage Scripts for Cashlyze

This directory contains scripts to run tests and generate coverage reports.

## Prerequisites

- Flutter SDK 3.10.1+
- lcov (for HTML coverage reports)
  - Windows: Install via Chocolatey: `choco install lcov`
  - macOS: `brew install lcov`
  - Linux: `sudo apt-get install lcov`

## Running Tests

### Unit Tests
```bash
# Run all unit tests
flutter test

# Run specific test file
flutter test test/core/services/auth_service_test.dart

# Run tests with verbose output
flutter test --verbose
```

### Widget Tests
```bash
# Run all widget tests
flutter test test/features/

# Run specific widget test
flutter test test/features/home/home_screen_test.dart
```

### Integration Tests
```bash
# Run all integration tests
flutter test integration_test/

# Run specific integration test
flutter test integration_test/auth_flow_test.dart

# Run integration tests on a device
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_test.dart
```

## Test Coverage

### Generate Coverage Report
```bash
# Generate coverage data
flutter test --coverage

# Generate HTML report (requires lcov)
genhtml coverage/lcov.info -o coverage/html

# Open coverage report in browser
# Windows
start coverage/html/index.html

# macOS
open coverage/html/index.html

# Linux
xdg-open coverage/html/index.html
```

### Using the Coverage Script
```bash
# Windows
.\tool\test_coverage.bat

# macOS/Linux
chmod +x tool/test_coverage.sh
./tool/test_coverage.sh
```

## Test Organization

```
test/
├── core/
│   ├── services/          # Service layer tests
│   │   ├── auth_service_test.dart
│   │   └── categorization_service_test.dart
│   └── repositories/      # Repository tests
│       └── transaction_repository_test.dart
├── features/              # Feature widget tests
│   ├── home/
│   │   └── home_screen_test.dart
│   ├── auth/
│   │   └── auth_screen_test.dart
│   └── transactions/
│       └── transactions_screen_test.dart
└── integration_test/      # Integration tests
    ├── app_test.dart
    ├── auth_flow_test.dart
    └── transaction_flow_test.dart
```

## Coverage Goals

- **Target**: 70%+ overall coverage
- **Critical paths**: 90%+ coverage
  - Authentication flows
  - Transaction management
  - Data persistence

## Continuous Integration

Tests are automatically run on:
- Every push to main/develop branches
- Every pull request
- Before releases

See `.github/workflows/test.yml` for CI configuration.

## Writing Tests

### Test Naming Convention
- Test files: `*_test.dart`
- Test groups: Describe the class/feature being tested
- Test cases: Use descriptive names starting with lowercase

### Example Test Structure
```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FeatureName', () {
    late ServiceClass service;

    setUp(() {
      service = ServiceClass();
    });

    tearDown(() {
      // Cleanup
    });

    group('methodName', () {
      test('should do something when condition', () {
        // Arrange
        final input = 'test';

        // Act
        final result = service.methodName(input);

        // Assert
        expect(result, expectedValue);
      });
    });
  });
}
```

## Mocking

We use `mockito` for mocking dependencies:

```dart
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([FirebaseAuth, User])
void main() {
  late MockFirebaseAuth mockAuth;

  setUp(() {
    mockAuth = MockFirebaseAuth();
  });

  test('example', () {
    when(mockAuth.currentUser).thenReturn(mockUser);
    // ... test code
  });
}
```

## Generating Mocks

```bash
# Generate mock files
flutter pub run build_runner build

# Watch for changes and regenerate
flutter pub run build_runner watch
```

## Troubleshooting

### Coverage not generating
- Ensure you're running `flutter test --coverage`
- Check that test files are in the `test/` directory
- Verify lcov is installed for HTML reports

### Integration tests failing
- Ensure a device/emulator is running
- Check Firebase configuration
- Verify network connectivity for remote tests

### Mock generation errors
- Run `flutter pub run build_runner clean`
- Then `flutter pub run build_runner build --delete-conflicting-outputs`

## Resources

- [Flutter Testing Documentation](https://docs.flutter.dev/testing)
- [Mockito Documentation](https://pub.dev/packages/mockito)
- [Integration Testing](https://docs.flutter.dev/testing/integration-tests)
