# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

To report a security vulnerability, please email security@cashlyze.com. We will respond within 48 hours.

## Security Measures

### 1. Data Storage
- **Sensitive Data**: Stored using `flutter_secure_storage`.
  - iOS: Keychain
  - Android: EncryptedSharedPreferences
- **Local Data**: Encrypted using AES-256-GCM via `EncryptionService`.
- **Database**: Firestore rules ensure strict data isolation per user.

### 2. Authentication
- Firebase Authentication is used for identity management.
- Biometric authentication is supported for local app access.

### 3. Network Security
- All network traffic uses HTTPS/TLS.
- API keys are stored in environment variables (not in source code).

### 4. Environment Variables
- We use `flutter_dotenv` to manage environment variables.
- Create a `.env` file in the root directory based on `.env.example`.
- **NEVER** commit `.env` to version control.

## Setup Instructions for Developers

1. **Environment Variables**
   Copy `.env.example` to `.env` and fill in your keys:
   ```bash
   cp .env.example .env
   ```

2. **Firebase Setup**
   Ensure `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) are present but **NOT** committed if they contain sensitive secrets (though usually they are safe to commit for Firebase, API keys should be restricted in Google Cloud Console).

3. **API Keys**
   - Restrict API keys in Google Cloud Console to specific platforms (Android/iOS) and APIs.

## Best Practices

- Always use `EncryptionService` for storing sensitive user input.
- Validate all inputs.
- Keep dependencies updated.
