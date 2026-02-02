# SkillShare - Detailed Setup Guide

## 📋 Table of Contents
1. [Prerequisites](#prerequisites)
2. [Project Setup](#project-setup)
3. [Firebase Configuration](#firebase-configuration)
4. [Running the Application](#running-the-application)
5. [Project Structure](#project-structure)
6. [Features Overview](#features-overview)
7. [Troubleshooting](#troubleshooting)

## ✅ Prerequisites

Before you begin, ensure you have the following installed:

### Required Software
- **Flutter SDK** (3.0.0 or higher)
  ```bash
  flutter --version
  ```
- **Android Studio** (for Android development)
- **Xcode** (for iOS development - macOS only)
- **VS Code** or **Android Studio** with Flutter plugins
- **Git**

### Verify Installation
```bash
flutter doctor
```

## 🚀 Project Setup

### Step 1: Clone and Install Dependencies

```bash
cd SKILLSHARE
flutter pub get
```

### Step 2: Install Additional Tools

```bash
# Install FlutterFire CLI for Firebase configuration
dart pub global activate flutterfire_cli
```

## 🔥 Firebase Configuration

### Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project"
3. Enter project name: `skillshare-app`
4. Enable Google Analytics (optional)
5. Click "Create project"

### Step 2: Register Your Apps

#### For Android:
1. In Firebase Console, click Android icon
2. Package name: `com.skillshare.app`
3. App nickname: `SkillShare Android`
4. Download `google-services.json`
5. Place file in: `android/app/google-services.json`

#### For iOS:
1. In Firebase Console, click iOS icon
2. Bundle ID: `com.skillshare.app`
3. App nickname: `SkillShare iOS`
4. Download `GoogleService-Info.plist`
5. Place file in: `ios/Runner/GoogleService-Info.plist`

### Step 3: Configure Firebase (Automated)

Run FlutterFire configuration:
```bash
flutterfire configure
```

This will:
- Create/update `lib/firebase_options.dart`
- Configure Firebase for all platforms
- Set up Firebase Analytics

### Step 4: Enable Firebase Services

#### Authentication
1. Go to Firebase Console → Authentication
2. Click "Get Started"
3. Enable "Email/Password" sign-in method
4. Save

#### Cloud Firestore
1. Go to Firebase Console → Firestore Database
2. Click "Create database"
3. Start in **Test mode** (for development)
4. Choose a location (e.g., `us-central1`)
5. Click "Enable"

#### Firestore Security Rules (Update after testing):
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
    }
    
    // Skilled users collection
    match /skilled_users/{userId} {
      allow read: if resource.data.visibility == 'public' && resource.data.isVerified == true;
      allow write: if request.auth.uid == userId;
      allow update: if request.auth != null && 
        (request.auth.uid == userId || get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin');
    }
    
    // Jobs collection
    match /jobs/{jobId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'company';
      allow update: if request.auth != null;
    }
    
    // Reviews collection
    match /reviews/{reviewId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
    }
    
    // Chats collection
    match /chats/{chatId} {
      allow read, write: if request.auth != null && 
        request.auth.uid in resource.data.participants;
      
      match /messages/{messageId} {
        allow read, write: if request.auth != null && 
          request.auth.uid in get(/databases/$(database)/documents/chats/$(chatId)).data.participants;
      }
    }
    
    // Products collection
    match /products/{productId} {
      allow read: if resource.data.isAvailable == true;
      allow write: if request.auth.uid == resource.data.userId;
    }
    
    // Service requests collection
    match /requests/{requestId} {
      allow read: if request.auth.uid == resource.data.skilledUserId || 
                     request.auth.uid == resource.data.customerId;
      allow create: if request.auth != null;
      allow update: if request.auth.uid == resource.data.skilledUserId;
    }
    
    // Appeals collection
    match /appeals/{appealId} {
      allow read: if request.auth.uid == resource.data.userId || 
                     get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
      allow create: if request.auth != null;
      allow update: if get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
  }
}
```

#### Cloud Storage
1. Go to Firebase Console → Storage
2. Click "Get Started"
3. Start in **Test mode** (for development)
4. Click "Done"

#### Storage Security Rules (Update after testing):
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /profile_photos/{userId}/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth.uid == userId;
    }
    
    match /portfolio/{userId}/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth.uid == userId;
    }
    
    match /product_photos/{userId}/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth.uid == userId;
    }
    
    match /chat_media/{chatId}/{allPaths=**} {
      allow read, write: if request.auth != null;
    }
    
    match /verification_documents/{userId}/{allPaths=**} {
      allow read, write: if request.auth.uid == userId;
    }
  }
}
```

## 🏃 Running the Application

### Development Mode

#### Run on Android Emulator:
```bash
flutter run
```

#### Run on iOS Simulator (macOS only):
```bash
flutter run -d ios
```

#### Run on Physical Device:
1. Enable Developer Mode on your device
2. Connect via USB
3. Run:
```bash
flutter devices
flutter run -d <device-id>
```

### Build Release

#### Android APK:
```bash
flutter build apk --release
```

#### Android App Bundle (for Play Store):
```bash
flutter build appbundle --release
```

#### iOS (macOS only):
```bash
flutter build ios --release
```

## 📁 Project Structure

```
lib/
├── main.dart                    # App entry point
├── firebase_options.dart        # Firebase configuration
├── models/                      # Data models
│   ├── user_model.dart
│   ├── skilled_user_profile.dart
│   ├── job_model.dart
│   ├── service_model.dart
│   ├── product_model.dart
│   ├── review_model.dart
│   ├── chat_model.dart
│   ├── service_request_model.dart
│   └── appeal_model.dart
├── services/                    # Business logic
│   ├── auth_service.dart
│   ├── firestore_service.dart
│   ├── storage_service.dart
│   ├── chat_service.dart
│   └── verification_service.dart
├── providers/                   # State management
│   ├── auth_provider.dart
│   └── user_provider.dart
├── screens/                     # UI screens
│   ├── splash_screen.dart
│   ├── main_screen.dart
│   ├── main_navigation.dart
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── signup_screen.dart
│   ├── home/
│   │   ├── home_screen.dart
│   │   └── explore_screen.dart
│   ├── profile/
│   │   ├── profile_screen.dart
│   │   └── skilled_user_setup_screen.dart
│   ├── jobs/
│   │   └── jobs_screen.dart
│   └── shop/
│       └── shop_screen.dart
├── widgets/                     # Reusable components
│   ├── expert_card.dart
│   ├── job_card.dart
│   ├── product_card.dart
│   └── category_card.dart
└── utils/                       # Utilities
    ├── app_theme.dart
    ├── app_constants.dart
    └── app_helpers.dart
```

## 🎯 Features Overview

### User Roles
1. **Skilled User** - Service providers showcasing their work
2. **Customer** - People seeking services
3. **Company** - Businesses posting jobs
4. **Admin** - Platform managers

### Core Features

#### 1. Authentication
- Email/password sign up and login
- Password reset
- Role-based registration

#### 2. Skilled User Profile
- Bio and skills showcase
- Portfolio (images & videos)
- Location-based services
- Aadhaar verification (dummy)
- Public/private visibility control

#### 3. Home Screen
- Browse verified skilled users
- Category-based filtering
- Location-based discovery
- Featured experts

#### 4. Jobs Section
- Companies post job opportunities
- Skilled users can apply
- Job filtering and search
- Application tracking

#### 5. Shop/Products
- Skilled users can sell products
- Product listings with images
- Ratings and reviews
- Inventory management

#### 6. Chat System
- Direct messaging between users
- Image/video sharing
- Real-time chat updates
- Unread message tracking

#### 7. Reviews & Ratings
- Customers can review services
- 5-star rating system
- Review images
- Average rating calculation

#### 8. Verification System
- Dummy Aadhaar verification
- Admin approval workflow
- Profile visibility control
- Appeal mechanism

#### 9. Service Requests
- Customers send service requests
- Skilled users accept/reject
- Request status tracking
- Communication via chat

## 🛠 Troubleshooting

### Common Issues

#### 1. Firebase Not Initialized
**Error**: `[core/no-app] No Firebase App '[DEFAULT]' has been created`

**Solution**:
```bash
flutterfire configure
flutter clean
flutter pub get
```

#### 2. Google Services Plugin Error (Android)
**Error**: `Could not find com.google.gms:google-services`

**Solution**:
- Ensure `google-services.json` is in `android/app/`
- Check `android/build.gradle` has Google services classpath
- Run: `flutter clean && flutter pub get`

#### 3. CocoaPods Error (iOS)
**Error**: `CocoaPods not installed`

**Solution** (macOS):
```bash
sudo gem install cocoapods
cd ios
pod install
```

#### 4. Gradle Build Failed (Android)
**Solution**:
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter run
```

#### 5. Location Permission Denied
**Solution**:
- Check `AndroidManifest.xml` has location permissions
- Check `Info.plist` (iOS) has location usage descriptions
- Grant permissions in device settings

### Debug Mode

Enable verbose logging:
```bash
flutter run --verbose
```

Check Flutter doctor:
```bash
flutter doctor -v
```

## 📱 Testing

### Create Test Accounts

#### Admin Account:
```
Email: admin@skillshare.com
Password: Admin@123
Role: admin
```

#### Skilled User:
```
Email: baker@skillshare.com
Password: Baker@123
Role: skilled_user
```

#### Customer:
```
Email: customer@skillshare.com
Password: Customer@123
Role: customer
```

#### Company:
```
Email: company@skillshare.com
Password: Company@123
Role: company
```

### Verification OTP (Dummy)
For testing, the OTP is hardcoded as: `123456`

### Aadhaar Numbers (Dummy)
- Valid: Any 12-digit number NOT ending in `0000`
- Invalid: Any number ending in `0000`
- Example valid: `1234 5678 9012`

## 🔐 Security Notes

⚠️ **Important**: The current setup uses Firebase Test Mode for development. Before deploying to production:

1. Update Firestore Security Rules (see above)
2. Update Storage Security Rules (see above)
3. Enable App Check for additional security
4. Set up proper authentication flows
5. Implement rate limiting
6. Add data validation on backend

## 📚 Additional Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Firebase Documentation](https://firebase.google.com/docs)
- [FlutterFire Documentation](https://firebase.flutter.dev/)
- [Provider Package](https://pub.dev/packages/provider)

## 🆘 Support

For issues or questions:
1. Check the Troubleshooting section above
2. Review Flutter and Firebase documentation
3. Check existing GitHub issues
4. Create a new issue with detailed information

## 📝 License

This project is licensed under the MIT License.
