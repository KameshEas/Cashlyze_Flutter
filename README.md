# 💰 Cashlyze - Personal Finance Manager

<div align="center">

![Cashlyze Logo](assets/logo_icon.png)

**A modern, cross-platform personal finance management application built with Flutter**

[![Flutter](https://img.shields.io/badge/Flutter-3.10.1+-02569B?logo=flutter)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Enabled-FFCA28?logo=firebase)](https://firebase.google.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Tests](https://img.shields.io/badge/Tests-90+-success)](test/)

[Features](#-features) • [Getting Started](#-getting-started) • [Architecture](#-architecture) • [Contributing](#-contributing) • [License](#-license)

</div>

---

## 📱 Overview

Cashlyze is a comprehensive personal finance management application that helps you track expenses, manage budgets, monitor EMIs, and gain insights into your spending habits. Built with Flutter and Firebase, it offers a seamless experience across Android, iOS, Web, Windows, macOS, and Linux platforms.

### ✨ Key Highlights

- 🎨 **Modern UI/UX** - Material Design 3 with dark/light theme support
- 🔐 **Secure Authentication** - Firebase Auth with biometric support
- 📊 **Smart Insights** - AI-powered categorization and spending analysis
- 🌍 **Multi-language** - English and Hindi localization
- ☁️ **Cloud Sync** - Real-time data synchronization via Firebase
- 📱 **Cross-platform** - Works on all major platforms

---

## 🚀 Features

### 💳 Transaction Management
- ✅ Add, edit, and delete transactions
- ✅ Automatic categorization using AI
- ✅ Support for income and expenses
- ✅ Transaction search and filtering
- ✅ Recurring transaction support
- ✅ Import/export capabilities

### 📊 Budget Planning
- ✅ Create and manage budgets by category
- ✅ Real-time budget tracking
- ✅ Budget alerts and notifications
- ✅ Visual budget progress indicators
- ✅ Monthly/yearly budget views

### 💰 EMI Tracker
- ✅ Track multiple EMI/loan payments
- ✅ EMI calculator with interest rates
- ✅ Payment reminders
- ✅ Remaining balance tracking
- ✅ Zero-cost EMI support

### 📈 Financial Insights
- ✅ Spending trends and patterns
- ✅ Category-wise breakdown
- ✅ Income vs. expense analysis
- ✅ Savings rate calculation
- ✅ Anomaly detection
- ✅ Personalized recommendations

### 🔒 Security & Privacy
- ✅ Firebase Authentication
- ✅ Biometric authentication (fingerprint/face)
- ✅ Email verification
- ✅ Secure data storage
- ✅ Google Drive backup

### 🌐 Additional Features
- ✅ Multi-language support (EN/HI)
- ✅ Dark/Light theme
- ✅ Offline support
- ✅ Data export (CSV/JSON)
- ✅ Analytics and crash reporting

---

## 🛠️ Getting Started

### Prerequisites

Before you begin, ensure you have the following installed:

- **Flutter SDK** 3.10.1 or higher ([Install Flutter](https://docs.flutter.dev/get-started/install))
- **Dart SDK** (comes with Flutter)
- **Firebase Account** ([Create Firebase Project](https://console.firebase.google.com))
- **IDE**: Android Studio, VS Code, or IntelliJ IDEA
- **Git** for version control

### Platform-Specific Requirements

#### Android
- Android Studio with Android SDK
- Java Development Kit (JDK) 17+
- Android device or emulator (API 21+)

#### iOS
- macOS with Xcode 14+
- CocoaPods
- iOS device or simulator (iOS 12+)

#### Web
- Chrome browser for testing

#### Desktop (Windows/macOS/Linux)
- Platform-specific build tools

### 📥 Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/cashlyze.git
   cd cashlyze
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   
   Follow the [Firebase Setup Guide](docs/FIREBASE_SETUP.md) to:
   - Create a Firebase project
   - Add your app to Firebase (Android/iOS/Web)
   - Download configuration files
   - Enable Firebase services (Auth, Realtime Database, Analytics, Crashlytics)

4. **Set up Firebase configuration**
   ```bash
   # Install FlutterFire CLI
   dart pub global activate flutterfire_cli
   
   # Configure Firebase for your project
   flutterfire configure
   ```

5. **Run the app**
   ```bash
   # Run on connected device
   flutter run
   
   # Run on specific platform
   flutter run -d chrome        # Web
   flutter run -d windows       # Windows
   flutter run -d macos         # macOS
   flutter run -d linux         # Linux
   ```

### 🔧 Development Setup

1. **Enable development mode**
   ```bash
   # Run with Firebase placeholder (no real Firebase needed)
   flutter run --dart-define=FIREBASE_PLACEHOLDER=true
   ```

2. **Generate code (for mocks, etc.)**
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

3. **Run tests**
   ```bash
   # Run all tests
   flutter test
   
   # Run with coverage
   flutter test --coverage
   
   # Generate coverage report
   tool/test_coverage.bat  # Windows
   ./tool/test_coverage.sh # macOS/Linux
   ```

4. **Code formatting**
   ```bash
   # Format all files
   flutter format .
   
   # Analyze code
   flutter analyze
   ```

---

## 🏗️ Architecture

Cashlyze follows **Clean Architecture** principles with clear separation of concerns:

```
lib/
├── core/                 # Shared/core functionality
│   ├── models/          # Data models
│   ├── repositories/    # Data access layer
│   ├── services/        # Business logic services
│   ├── providers/       # State management (Riverpod)
│   ├── theme/           # App theming
│   ├── utils/           # Utility functions
│   └── widgets/         # Reusable widgets
├── features/            # Feature modules
│   ├── auth/           # Authentication
│   ├── home/           # Dashboard
│   ├── transactions/   # Transaction management
│   ├── budgets/        # Budget planning
│   ├── insights/       # Analytics
│   ├── settings/       # App settings
│   └── emi/            # EMI tracking
├── routes/             # Navigation/routing
└── l10n/               # Localization
```

For detailed architecture documentation, see [ARCHITECTURE.md](docs/ARCHITECTURE.md).

### Tech Stack

- **Framework**: Flutter 3.10.1+
- **Language**: Dart
- **State Management**: Riverpod 3.0+
- **Navigation**: go_router 17.0+
- **Backend**: Firebase (Auth, Realtime Database, Analytics, Crashlytics)
- **Local Storage**: SharedPreferences
- **Charts**: fl_chart
- **Fonts**: Google Fonts
- **Icons**: Material Icons + Cupertino Icons

---

## 📖 Documentation

- [Architecture Guide](docs/ARCHITECTURE.md) - Detailed architecture documentation
- [Firebase Setup](docs/FIREBASE_SETUP.md) - Firebase configuration guide
- [Testing Guide](test/README.md) - How to write and run tests
- [Contributing Guide](CONTRIBUTING.md) - Contribution guidelines
- [API Documentation](docs/API.md) - API reference (auto-generated)

---

## 🧪 Testing

Cashlyze has comprehensive test coverage (35%+ and growing):

```bash
# Run all tests
flutter test

# Run specific test suite
flutter test test/features/
flutter test test/core/services/

# Run integration tests
flutter test integration_test/

# Generate coverage report
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

See [Test Coverage Report](TEST_COVERAGE_REPORT.md) for detailed coverage information.

---

## 🚢 Deployment

### Android

```bash
# Build APK
flutter build apk --release

# Build App Bundle (for Play Store)
flutter build appbundle --release

# Build with obfuscation
flutter build apk --obfuscate --split-debug-info=build/debug-info
```

### iOS

```bash
# Build for iOS
flutter build ios --release

# Create IPA
flutter build ipa
```

### Web

```bash
# Build for web
flutter build web --release

# Build with custom base href
flutter build web --base-href /cashlyze/
```

### Desktop

```bash
# Windows
flutter build windows --release

# macOS
flutter build macos --release

# Linux
flutter build linux --release
```

---

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details on:

- Code of Conduct
- Development workflow
- Coding standards
- Pull request process
- Issue reporting

### Quick Start for Contributors

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Write/update tests
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

---

## 📝 Changelog

See [CHANGELOG.md](CHANGELOG.md) for a list of changes in each version.

---

## 🐛 Known Issues

- Widget tests require provider setup adjustments (in progress)
- Some integration tests need device configuration
- See [Issues](https://github.com/yourusername/cashlyze/issues) for full list

---

## 🗺️ Roadmap

### Version 1.1 (Q1 2026)
- [ ] Investment tracking
- [ ] Bill reminders
- [ ] Receipt scanning (OCR)
- [ ] Multiple currency support
- [ ] Family sharing

### Version 1.2 (Q2 2026)
- [ ] AI-powered financial advisor
- [ ] Goal tracking
- [ ] Tax calculation
- [ ] Bank account integration
- [ ] Cryptocurrency tracking

### Version 2.0 (Q3 2026)
- [ ] Web dashboard
- [ ] API for third-party integrations
- [ ] Advanced analytics
- [ ] Custom reports
- [ ] Multi-user support

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 👥 Authors

- **Your Name** - *Initial work* - [@yourusername](https://github.com/yourusername)

See also the list of [contributors](https://github.com/yourusername/cashlyze/contributors) who participated in this project.

---

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Firebase for backend services
- Material Design for UI guidelines
- All open-source contributors

---

## 📞 Support

- **Documentation**: [docs/](docs/)
- **Issues**: [GitHub Issues](https://github.com/yourusername/cashlyze/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/cashlyze/discussions)
- **Email**: support@cashlyze.com

---

## 📊 Project Stats

![GitHub stars](https://img.shields.io/github/stars/yourusername/cashlyze?style=social)
![GitHub forks](https://img.shields.io/github/forks/yourusername/cashlyze?style=social)
![GitHub watchers](https://img.shields.io/github/watchers/yourusername/cashlyze?style=social)

---

<div align="center">

**Made with ❤️ using Flutter**

[⬆ Back to Top](#-cashlyze---personal-finance-manager)

</div>
