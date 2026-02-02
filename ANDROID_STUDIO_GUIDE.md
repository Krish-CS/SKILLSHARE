# 🚀 Running SkillShare in Android Studio

## ✅ Yes, You Can Run in Android Studio!

Android Studio is perfect for running this Flutter project. Here's how:

---

## 📱 Step 1: Open Project in Android Studio

1. **Launch Android Studio**
2. Click **"Open"** or **"Open an Existing Project"**
3. Navigate to: `D:\SKILLSHARE`
4. Click **"OK"**

Android Studio will automatically:
- Detect it's a Flutter project
- Index the files
- Download dependencies

---

## 🔧 Step 2: Install Flutter Plugin (If Not Already)

1. Go to **File → Settings** (or **Ctrl + Alt + S**)
2. Navigate to **Plugins**
3. Search for **"Flutter"**
4. Click **Install**
5. Restart Android Studio

---

## 📱 Step 3: Set Up Device

### Option A: Android Emulator (Recommended for Testing)

1. Click **Device Manager** (phone icon) in toolbar
2. Click **Create Device**
3. Choose a device (e.g., Pixel 5)
4. Select a system image (API 30+ recommended)
5. Click **Finish**
6. Click **▶️ Play** to start emulator

### Option B: Physical Android Device

1. Enable **Developer Options** on your phone:
   - Go to Settings → About Phone
   - Tap "Build Number" 7 times
2. Enable **USB Debugging**:
   - Settings → Developer Options → USB Debugging
3. Connect phone via USB
4. Allow USB debugging on phone

---

## 🔥 Step 4: Configure Firebase (IMPORTANT!)

Before running, you MUST configure Firebase:

### In Terminal (within Android Studio):

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase
flutterfire configure
```

**Follow the prompts:**
1. Login to Firebase
2. Select or create project: "skillshare-app"
3. Select platforms: Android (and iOS if needed)
4. This creates `lib/firebase_options.dart`

### Enable Firebase Services:

Go to [Firebase Console](https://console.firebase.google.com):

1. **Authentication**
   - Click "Get Started"
   - Enable "Email/Password"
   - Save

2. **Firestore Database**
   - Click "Create database"
   - Start in "Test mode"
   - Choose location (e.g., us-central1)
   - Enable

3. **Cloud Storage**
   - Click "Get Started"  
   - Start in "Test mode"
   - Done

---

## ▶️ Step 5: Run the App

### Method 1: Using Toolbar
1. Select your device from dropdown (top toolbar)
2. Click **▶️ Run** button (or press **Shift + F10**)

### Method 2: Using Terminal
```bash
flutter run
```

### Method 3: Right-click Method
1. Right-click on `lib/main.dart`
2. Select **"Run 'main.dart'"**

---

## 🛠️ Fix Current Errors

There are a few minor warnings. Run these commands in Android Studio Terminal:

```bash
# Clean the project
flutter clean

# Get dependencies
flutter pub get

# Run the app
flutter run
```

---

## 🐛 Common Issues & Solutions

### Issue 1: "SDK not found"
**Solution:**
1. File → Settings → Languages & Frameworks → Flutter
2. Set Flutter SDK path (e.g., `C:\src\flutter`)

### Issue 2: "Gradle build failed"
**Solution:**
```bash
cd android
gradlew clean
cd ..
flutter clean
flutter run
```

### Issue 3: "Firebase not initialized"
**Solution:**
```bash
flutterfire configure
flutter clean
flutter pub get
```

### Issue 4: Emulator not starting
**Solution:**
1. Tools → Device Manager
2. Delete emulator
3. Create new emulator
4. Use API 30 or higher

---

## 📊 Android Studio Features for Flutter

### Hot Reload (Super Fast!)
- **Save file** or press **Ctrl + S**
- Changes appear instantly!
- No need to restart app

### Hot Restart
- **Ctrl + Shift + \\** 
- Restarts app quickly
- Useful for major changes

### Debug Mode
- Set breakpoints (click left margin)
- Press **Shift + F9** to debug
- Step through code

### Flutter Inspector
- **View → Tool Windows → Flutter Inspector**
- Inspect widget tree
- Debug layout issues
- View widget properties

### Dart Analysis
- See errors/warnings in real-time
- Bottom toolbar shows issues
- Click to navigate to problem

---

## 🎯 Recommended Workflow

1. **Open project** in Android Studio
2. **Start emulator** (or connect device)
3. **Run `flutter pub get`** (if needed)
4. **Configure Firebase** (one-time setup)
5. **Press Run button** ▶️
6. **Make changes** to code
7. **Save** to hot reload
8. **Test features** in app

---

## 📱 Testing the App

Once running, test these features:

### 1. **Sign Up**
- Email: test@example.com
- Password: Test@123
- Choose role: Skilled User

### 2. **Complete Profile**
- Add bio and skills
- Upload sample images
- Submit for verification

### 3. **Browse**
- Check Home screen
- Explore categories
- View other profiles

### 4. **Jobs**
- View job listings
- Apply for jobs (skilled users)
- Post jobs (companies)

### 5. **Chat**
- Message other users
- Send images
- Check notifications

---

## 🔧 Android Studio Shortcuts

| Action | Shortcut |
|--------|----------|
| Run | Shift + F10 |
| Debug | Shift + F9 |
| Stop | Ctrl + F2 |
| Hot Reload | Ctrl + S |
| Hot Restart | Ctrl + Shift + \\ |
| Find | Ctrl + F |
| Replace | Ctrl + R |
| Go to File | Ctrl + Shift + N |
| Recent Files | Ctrl + E |
| Format Code | Ctrl + Alt + L |

---

## 💡 Pro Tips

### 1. Enable Auto-Save
- File → Settings → Appearance & Behavior → System Settings
- Check "Save files automatically"

### 2. Show Flutter Outline
- View → Tool Windows → Flutter Outline
- See widget structure visually

### 3. Use Flutter Commands
- Right-click any widget
- "Show Context Actions"
- Quick wrap/extract widgets

### 4. View Logs
- View → Tool Windows → Run
- See console output and errors

### 5. Performance
- Run → Flutter Performance
- Monitor frame rates
- Check for jank

---

## 🎉 You're Ready!

Android Studio is the BEST IDE for Flutter development. You get:

✅ Auto-complete  
✅ Error detection  
✅ Hot reload  
✅ Debugging tools  
✅ Flutter Inspector  
✅ Performance monitoring  
✅ Emulator integration  

Just remember to **configure Firebase** before first run!

---

## 📞 Need More Help?

1. Check `QUICKSTART.md` for setup details
2. Read `SETUP_GUIDE.md` for Firebase config
3. View `FEATURES.md` for app features
4. Run `flutter doctor` to check environment

**Happy Coding in Android Studio! 🚀**
