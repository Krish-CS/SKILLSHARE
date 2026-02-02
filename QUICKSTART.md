# SkillShare - Quick Start Guide

## 🚀 Quick Setup (5 minutes)

### Step 1: Install Dependencies
```bash
flutter pub get
```

### Step 2: Setup Firebase (Choose one option)

#### Option A: Automatic Setup (Recommended)
```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase
flutterfire configure
```

#### Option B: Manual Setup
1. Create Firebase project at https://console.firebase.google.com/
2. Download `google-services.json` → place in `android/app/`
3. Update `lib/firebase_options.dart` with your config

### Step 3: Enable Firebase Services
In Firebase Console, enable:
- ✅ Authentication (Email/Password)
- ✅ Cloud Firestore
- ✅ Cloud Storage

### Step 4: Run the App
```bash
flutter run
```

## 📱 Test the App

### Create Test Accounts

**Skilled User:**
```
Email: baker@test.com
Password: test123
Role: Skilled Professional
```

**Customer:**
```
Email: customer@test.com
Password: test123
Role: Customer
```

**Company:**
```
Email: company@test.com
Password: test123
Role: Company
```

### Test Verification
Use these dummy Aadhaar numbers:
- `123456789012`
- `987654321098`
- `111122223333`

## 🎯 Feature Testing Checklist

### Authentication
- [ ] Sign up with different roles
- [ ] Login with credentials
- [ ] Sign out

### Skilled User Flow
- [ ] Complete profile setup
- [ ] Add skills and bio
- [ ] Submit verification
- [ ] Add portfolio images
- [ ] Create services

### Customer Flow
- [ ] Browse verified experts
- [ ] View expert profiles
- [ ] Send service requests
- [ ] Leave reviews

### Company Flow
- [ ] Post job opportunities
- [ ] Browse skilled professionals
- [ ] Review applicants

## 🐛 Troubleshooting

### Build Failed?
```bash
flutter clean
flutter pub get
flutter run
```

### Firebase Error?
- Check `google-services.json` is in `android/app/`
- Verify Firebase services are enabled
- Run `flutterfire configure` again

### Gradle Error?
```bash
cd android
./gradlew clean
cd ..
flutter run
```

## 📂 Important Files

```
lib/
├── main.dart                    # Start here
├── firebase_options.dart        # Firebase config
├── screens/
│   ├── auth/login_screen.dart  # Login UI
│   ├── home/home_screen.dart   # Main screen
│   └── profile/                # Profile screens
├── services/
│   └── verification_service.dart # Test Aadhaar
└── utils/
    └── app_constants.dart       # App settings
```

## 🎨 Customization

### Change Colors
Edit `lib/utils/app_theme.dart`:
```dart
static const Color primaryBlue = Color(0xFF2196F3);
static const Color primaryPink = Color(0xFFE91E63);
```

### Add Categories
Edit `lib/screens/profile/skilled_user_setup_screen.dart`:
```dart
final List<String> _categories = [
  'Home Baking',
  'Your New Category', // Add here
];
```

### Modify Verification
Edit `lib/services/verification_service.dart`:
```dart
static final Map<String, Map<String, dynamic>> _dummyAadhaarDatabase = {
  'YOUR_TEST_NUMBER': {
    'name': 'Test User',
    'isValid': true,
  },
};
```

## 📚 Next Steps

1. ✅ Complete Firebase setup
2. ✅ Run the app
3. ✅ Create test accounts
4. ✅ Test all user flows
5. 📖 Read [DOCUMENTATION.md](DOCUMENTATION.md) for details
6. 🔧 Customize for your needs
7. 🚀 Deploy to Play Store / App Store

## 💡 Pro Tips

### Development
- Use Android Emulator for faster testing
- Enable Hot Reload (press `r` in terminal)
- Check Firebase Console for data
- Use Chrome DevTools for debugging

### Testing
- Test on multiple screen sizes
- Try different user roles
- Test with/without internet
- Check error messages

### Production
- Update Firebase security rules
- Add error tracking (Crashlytics)
- Test on real devices
- Get real Aadhaar API integration

## 🔗 Useful Links

- [Flutter Docs](https://flutter.dev/docs)
- [Firebase Console](https://console.firebase.google.com/)
- [FlutterFire Docs](https://firebase.flutter.dev/)
- [Project Documentation](DOCUMENTATION.md)
- [Setup Guide](SETUP.md)

## ❓ Common Questions

**Q: Can I use this in production?**
A: Yes, but update security rules and integrate real verification API.

**Q: How do I add an admin user?**
A: Create account, then manually change role to "admin" in Firestore.

**Q: Can I customize the UI?**
A: Yes! Edit screens and theme files. Colors are in `app_theme.dart`.

**Q: Is iOS supported?**
A: Yes, but you need a Mac for iOS development and testing.

**Q: How do I deploy?**
A: Follow Flutter's deployment guides for Play Store and App Store.

## 🎓 Learning Resources

- **Flutter Basics**: https://flutter.dev/learn
- **Firebase Setup**: https://firebase.google.com/docs/flutter/setup
- **State Management**: https://flutter.dev/docs/development/data-and-backend/state-mgmt
- **UI Design**: https://material.io/design

---

**Need Help?** Check DOCUMENTATION.md or SETUP.md for detailed information.

**Ready to Start?** Run `flutter pub get` and then `flutter run`! 🚀
