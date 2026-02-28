# Contributing to Cashlyze

First off, thank you for considering contributing to Cashlyze! It's people like you that make Cashlyze such a great tool.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
- [Development Setup](#development-setup)
- [Coding Standards](#coding-standards)
- [Commit Guidelines](#commit-guidelines)
- [Pull Request Process](#pull-request-process)
- [Issue Reporting](#issue-reporting)
- [Community](#community)

---

## Code of Conduct

This project and everyone participating in it is governed by our Code of Conduct. By participating, you are expected to uphold this code.

### Our Pledge

We pledge to make participation in our project a harassment-free experience for everyone, regardless of age, body size, disability, ethnicity, gender identity and expression, level of experience, nationality, personal appearance, race, religion, or sexual identity and orientation.

### Our Standards

**Positive behavior includes**:
- Using welcoming and inclusive language
- Being respectful of differing viewpoints
- Gracefully accepting constructive criticism
- Focusing on what is best for the community
- Showing empathy towards other community members

**Unacceptable behavior includes**:
- Trolling, insulting/derogatory comments, and personal attacks
- Public or private harassment
- Publishing others' private information without permission
- Other conduct which could reasonably be considered inappropriate

---

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check the existing issues to avoid duplicates. When creating a bug report, include as many details as possible:

**Bug Report Template**:
```markdown
**Describe the bug**
A clear and concise description of what the bug is.

**To Reproduce**
Steps to reproduce the behavior:
1. Go to '...'
2. Click on '....'
3. Scroll down to '....'
4. See error

**Expected behavior**
A clear description of what you expected to happen.

**Screenshots**
If applicable, add screenshots to help explain your problem.

**Environment:**
 - Device: [e.g. iPhone 12, Pixel 6]
 - OS: [e.g. iOS 15.0, Android 12]
 - App Version: [e.g. 1.0.0]

**Additional context**
Add any other context about the problem here.
```

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, include:

**Enhancement Template**:
```markdown
**Is your feature request related to a problem?**
A clear description of what the problem is.

**Describe the solution you'd like**
A clear description of what you want to happen.

**Describe alternatives you've considered**
Any alternative solutions or features you've considered.

**Additional context**
Add any other context or screenshots about the feature request.
```

### Your First Code Contribution

Unsure where to begin? Look for issues labeled:
- `good first issue` - Simple issues for beginners
- `help wanted` - Issues that need attention
- `documentation` - Documentation improvements

### Pull Requests

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Write/update tests
5. Ensure all tests pass
6. Submit a pull request

---

## Development Setup

### Prerequisites

- Flutter SDK 3.10.1+
- Dart SDK (comes with Flutter)
- Git
- IDE (VS Code, Android Studio, or IntelliJ)
- Firebase account (for full functionality)

### Setup Steps

1. **Fork and clone the repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/cashlyze.git
   cd cashlyze
   ```

2. **Add upstream remote**
   ```bash
   git remote add upstream https://github.com/ORIGINAL_OWNER/cashlyze.git
   ```

3. **Install dependencies**
   ```bash
   flutter pub get
   ```

4. **Set up Firebase** (optional for development)
   ```bash
   # Use placeholder Firebase config
   flutter run --dart-define=FIREBASE_PLACEHOLDER=true
   ```

5. **Generate code**
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

6. **Run the app**
   ```bash
   flutter run
   ```

### Development Workflow

1. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**
   - Write clean, readable code
   - Follow the coding standards
   - Add tests for new features
   - Update documentation

3. **Test your changes**
   ```bash
   # Run tests
   flutter test
   
   # Run with coverage
   flutter test --coverage
   
   # Format code
   flutter format .
   
   # Analyze code
   flutter analyze
   ```

4. **Commit your changes**
   ```bash
   git add .
   git commit -m "feat: add amazing feature"
   ```

5. **Push to your fork**
   ```bash
   git push origin feature/your-feature-name
   ```

6. **Create a Pull Request**
   - Go to GitHub and create a PR
   - Fill out the PR template
   - Link related issues

---

## Coding Standards

### Dart Style Guide

Follow the [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines:

#### Naming Conventions

```dart
// Classes and Types: PascalCase
class TransactionModel { }
enum TimeRange { }

// Variables and Functions: lowerCamelCase
String userName = 'John';
void calculateTotal() { }

// Constants: lowerCamelCase or SCREAMING_SNAKE_CASE
const double pi = 3.14159;
const String API_KEY = 'your-key';

// Private members: _leadingUnderscore
String _privateField;
void _privateMethod() { }

// Files: snake_case.dart
transaction_repository.dart
auth_service.dart
```

#### Code Formatting

```dart
// ✅ DO: Use trailing commas for better formatting
Widget build(BuildContext context) {
  return Container(
    padding: EdgeInsets.all(16),
    child: Text('Hello'),
  );
}

// ✅ DO: Use const constructors when possible
const Text('Hello World')

// ✅ DO: Prefer final over var
final String name = 'John';

// ✅ DO: Use meaningful variable names
final userTransactions = getTransactions();

// ❌ DON'T: Use abbreviations
final txs = getTransactions(); // Bad
```

#### Documentation

```dart
/// Calculates the EMI (Equated Monthly Installment) for a loan.
///
/// Uses the formula: EMI = [P x R x (1+R)^N]/[(1+R)^N-1]
///
/// Parameters:
/// - [principal]: The loan amount
/// - [annualRate]: Annual interest rate (percentage)
/// - [months]: Loan tenure in months
///
/// Returns the monthly EMI amount.
///
/// Example:
/// ```dart
/// final emi = calculateEMI(100000, 10.5, 24);
/// print('Monthly EMI: $emi');
/// ```
double calculateEMI(double principal, double annualRate, int months) {
  final monthlyRate = annualRate / 12 / 100;
  final numerator = principal * monthlyRate * pow(1 + monthlyRate, months);
  final denominator = pow(1 + monthlyRate, months) - 1;
  return numerator / denominator;
}
```

### Project-Specific Guidelines

#### 1. Feature Organization

```
features/
  ├── feature_name/
  │   ├── feature_screen.dart      # Main screen
  │   ├── widgets/                 # Feature-specific widgets
  │   │   ├── widget_1.dart
  │   │   └── widget_2.dart
  │   └── models/                  # Feature-specific models (if any)
```

#### 2. State Management

```dart
// ✅ DO: Use appropriate provider types
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(firebaseAuthProvider));
});

// ✅ DO: Handle all async states
transactions.when(
  data: (data) => ListView(...),
  loading: () => CircularProgressIndicator(),
  error: (error, stack) => ErrorView(error),
);

// ❌ DON'T: Use global state or singletons
class GlobalState {
  static final instance = GlobalState._();
  // Bad practice
}
```

#### 3. Error Handling

```dart
// ✅ DO: Handle errors gracefully
try {
  await authService.signIn(email, password);
} on FirebaseAuthException catch (e) {
  showError(_handleAuthException(e));
} catch (e) {
  showError('An unexpected error occurred');
}

// ✅ DO: Provide user-friendly error messages
String _handleAuthException(FirebaseAuthException e) {
  switch (e.code) {
    case 'user-not-found':
      return 'No user found with this email.';
    case 'wrong-password':
      return 'Incorrect password.';
    default:
      return 'An error occurred. Please try again.';
  }
}
```

#### 4. Testing

```dart
// ✅ DO: Write tests for new features
group('TransactionRepository', () {
  late TransactionRepository repository;
  late MockRealtimeDbService mockDb;

  setUp(() {
    mockDb = MockRealtimeDbService();
    repository = TransactionRepository(mockDb);
  });

  test('create should validate input', () {
    expect(
      () => repository.create(
        userId: 'user1',
        title: '',  // Empty title
        amount: 100,
        date: DateTime.now(),
      ),
      throwsArgumentError,
    );
  });
});
```

#### 5. Performance

```dart
// ✅ DO: Use const constructors
const SizedBox(height: 16)

// ✅ DO: Use ListView.builder for long lists
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) => ItemWidget(items[index]),
)

// ✅ DO: Optimize rebuilds with select
final balance = ref.watch(kpisProvider.select((kpis) => kpis.net));

// ❌ DON'T: Build expensive widgets in build method
Widget build(BuildContext context) {
  final expensiveData = calculateExpensiveData(); // Bad
  return Text(expensiveData);
}
```

---

## Commit Guidelines

We follow [Conventional Commits](https://www.conventionalcommits.org/) specification:

### Commit Message Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `perf`: Performance improvements
- `test`: Adding or updating tests
- `chore`: Maintenance tasks
- `ci`: CI/CD changes

### Examples

```bash
# Feature
git commit -m "feat(transactions): add transaction filtering"

# Bug fix
git commit -m "fix(auth): resolve email verification issue"

# Documentation
git commit -m "docs(readme): update installation instructions"

# Breaking change
git commit -m "feat(api)!: change transaction model structure

BREAKING CHANGE: TransactionModel now requires categoryId"
```

### Commit Message Guidelines

- Use present tense ("add feature" not "added feature")
- Use imperative mood ("move cursor to..." not "moves cursor to...")
- Limit first line to 72 characters
- Reference issues and PRs in the footer

---

## Pull Request Process

### Before Submitting

1. ✅ Ensure all tests pass
2. ✅ Update documentation
3. ✅ Add/update tests for new features
4. ✅ Run `flutter analyze` with no errors
5. ✅ Run `flutter format .`
6. ✅ Update CHANGELOG.md (if applicable)

### PR Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
Describe the tests you ran

## Checklist
- [ ] My code follows the style guidelines
- [ ] I have performed a self-review
- [ ] I have commented my code where necessary
- [ ] I have updated the documentation
- [ ] My changes generate no new warnings
- [ ] I have added tests that prove my fix/feature works
- [ ] New and existing tests pass locally

## Screenshots (if applicable)
Add screenshots here

## Related Issues
Closes #123
```

### Review Process

1. At least one maintainer must approve
2. All CI checks must pass
3. No merge conflicts
4. Code follows project standards

### After Merge

1. Delete your feature branch
2. Pull latest changes from upstream
3. Update your fork

---

## Issue Reporting

### Issue Labels

- `bug` - Something isn't working
- `enhancement` - New feature or request
- `documentation` - Documentation improvements
- `good first issue` - Good for newcomers
- `help wanted` - Extra attention needed
- `question` - Further information requested
- `wontfix` - This will not be worked on

### Issue Templates

Use the provided issue templates for:
- Bug reports
- Feature requests
- Documentation improvements

---

## Community

### Communication Channels

- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: General questions and discussions
- **Pull Requests**: Code contributions

### Getting Help

- Check existing documentation
- Search closed issues
- Ask in GitHub Discussions
- Join our community chat (if available)

### Recognition

Contributors will be:
- Listed in CONTRIBUTORS.md
- Mentioned in release notes
- Credited in the app's about section

---

## Development Tips

### Useful Commands

```bash
# Run app with hot reload
flutter run

# Run tests
flutter test

# Generate coverage
flutter test --coverage

# Format code
flutter format .

# Analyze code
flutter analyze

# Generate code (mocks, etc.)
flutter pub run build_runner build

# Clean build
flutter clean
flutter pub get

# Check outdated packages
flutter pub outdated
```

### Debugging

```dart
// Use debugPrint for logging
debugPrint('Transaction created: ${transaction.id}');

// Use assert for development checks
assert(amount > 0, 'Amount must be positive');

// Use Flutter DevTools
flutter run --observatory-port=9200
```

### Common Issues

**Issue**: Tests failing locally
```bash
# Solution: Clean and regenerate
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter test
```

**Issue**: Firebase errors in development
```bash
# Solution: Use placeholder config
flutter run --dart-define=FIREBASE_PLACEHOLDER=true
```

---

## License

By contributing, you agree that your contributions will be licensed under the same license as the project (MIT License).

---

## Questions?

Don't hesitate to ask! Open an issue or discussion, and we'll be happy to help.

---

**Thank you for contributing to Cashlyze! 🎉**

---

*Last Updated: December 3, 2025*
