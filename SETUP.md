# SkillShare - Setup Instructions

## Firebase Setup

### 1. Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project"
3. Name your project "SkillShare"
4. Follow the setup wizard

### 2. Add Android App

1. In Firebase Console, click "Add app" → Android
2. Package name: `com.skillshare.app`
3. Download `google-services.json`
4. Place it in `android/app/` directory

### 3. Add iOS App (Optional)

1. In Firebase Console, click "Add app" → iOS
2. Bundle ID: `com.skillshare.app`
3. Download `GoogleService-Info.plist`
4. Place it in `ios/Runner/` directory

### 4. Enable Firebase Services

#### Authentication
1. Go to Authentication → Sign-in method
2. Enable Email/Password authentication

#### Cloud Firestore
1. Go to Firestore Database → Create database
2. Start in **test mode** (for development)
3. Select a location closest to your users

#### Cloud Storage
1. Go to Storage → Get started
2. Start in **test mode** (for development)

### 5. Configure FlutterFire

Run the following command to automatically configure Firebase:

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase for your Flutter project
flutterfire configure
```

This will automatically update `lib/firebase_options.dart` with your project's configuration.

## Android Configuration

### Update AndroidManifest.xml

Add the following permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
```

### Update build.gradle

1. In `android/build.gradle`, ensure you have:
```gradle
dependencies {
    classpath 'com.google.gms:google-services:4.3.15'
}
```

2. In `android/app/build.gradle`, add at the bottom:
```gradle
apply plugin: 'com.google.gms.google-services'
```

And ensure `minSdkVersion` is at least 21:
```gradle
defaultConfig {
    minSdkVersion 21
}
```

## iOS Configuration (Optional)

### Update Info.plist

Add the following keys to `ios/Runner/Info.plist`:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs access to photo library to upload images</string>
<key>NSCameraUsageDescription</key>
<string>This app needs access to camera to take photos</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location access to find nearby skilled professionals</string>
```

## Install Dependencies

```bash
flutter pub get
```

## Run the App

### For Android:
```bash
flutter run
```

### For iOS (Mac only):
```bash
cd ios
pod install
cd ..
flutter run
```

## Firestore Security Rules

For development, use these rules (in Firebase Console → Firestore → Rules):

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
    }
    
    match /skilled_users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId || 
                     get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    match /jobs/{jobId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
    
    match /reviews/{reviewId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
    }
    
    match /chats/{chatId} {
      allow read, write: if request.auth != null && 
                           request.auth.uid in resource.data.participants;
    }
    
    match /chats/{chatId}/messages/{messageId} {
      allow read: if request.auth != null && 
                    request.auth.uid in get(/databases/$(database)/documents/chats/$(chatId)).data.participants;
      allow create: if request.auth != null;
    }
  }
}
```

## Storage Security Rules

For Firebase Storage (in Firebase Console → Storage → Rules):

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /profile_photos/{userId}/{fileName} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
    }
    
    match /portfolio/{userId}/{fileName} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
    }
    
    match /product_photos/{userId}/{fileName} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
    }
    
    match /chat_media/{chatId}/{fileName} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## Test Accounts

For development, you can create test accounts with these roles:

1. **Skilled User**: Create an account and select "Skilled Professional"
2. **Customer**: Create an account and select "Customer"
3. **Company**: Create an account and select "Company"
4. **Admin**: Manually change role in Firestore to "admin"

## Dummy Aadhaar Numbers for Testing

Use these Aadhaar numbers in the verification screen:
- `123456789012`
- `987654321098`
- `111122223333`

## Troubleshooting

### Firebase not initialized
- Make sure you've run `flutterfire configure`
- Verify `google-services.json` is in the correct location

### Build errors
- Run `flutter clean`
- Delete `pubspec.lock`
- Run `flutter pub get`
- Try again

### Location not working
- Ensure location permissions are granted
- Check that location services are enabled on device

## Next Steps

1. Complete the Firebase setup
2. Run the app on an emulator or physical device
3. Create test accounts for different user roles
4. Test the verification flow
5. Customize the UI and branding as needed

## Development Notes

- The app uses test mode for Firebase during development
- Make sure to update security rules before production
- Test on both Android and iOS devices
- Consider adding error tracking (e.g., Firebase Crashlytics)
