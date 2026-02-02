# Cloudinary Setup Guide for SkillShare

## 🎯 Why Cloudinary?
- **Free Tier**: 25GB storage + 25GB bandwidth/month
- **Automatic optimization**: Images compressed automatically
- **CDN delivery**: Super fast loading worldwide
- **No credit card**: Completely free for development

## 📋 Setup Steps

### 1. Create Cloudinary Account
1. Go to: https://cloudinary.com/users/register/free
2. Sign up with your email
3. Verify your email

### 2. Get Your Credentials
1. Login to Cloudinary Dashboard
2. Copy your **Cloud Name** from the top
3. Note it down - you'll need it

### 3. Create Upload Preset
1. Click **Settings** (gear icon) → **Upload**
2. Scroll to **Upload presets**
3. Click **Add upload preset**
4. Configure:
   - **Preset name**: `skillshare_uploads`
   - **Signing mode**: Unsigned (for development)
   - **Folder**: Leave empty (we set it in code)
   - **Overwrite**: No
5. Click **Save**

### 4. Update Your Code
Open `lib/utils/cloudinary_config.dart` and replace:

```dart
static const String cloudName = 'your_cloud_name'; // Replace with YOUR cloud name
static const String uploadPreset = 'skillshare_uploads'; // Must match preset name
```

Example:
```dart
static const String cloudName = 'dxyz12345'; // Your actual cloud name
static const String uploadPreset = 'skillshare_uploads';
```

### 5. Run the App
```bash
flutter pub get
flutter run
```

## 🔄 How It Works

**Upload Flow:**
```
User picks image 
  ↓
App compresses (85% quality)
  ↓
POST to Cloudinary API
  ↓
Cloudinary returns secure_url
  ↓
Save URL to Firestore
```

**Benefits:**
- ✅ Images automatically optimized
- ✅ Fast CDN delivery
- ✅ No Firebase Storage costs
- ✅ 25GB free storage
- ✅ Works with Spark plan

## 📁 Folder Structure in Cloudinary

Your images will be organized as:
```
skillshare/
├── profiles/          (Profile photos)
├── portfolios/        (Portfolio images)
│   ├── user_id_1/
│   └── user_id_2/
├── products/          (Product images)
│   ├── user_id_1/
│   └── user_id_2/
├── verification/      (ID documents)
└── chat/              (Chat media)
```

## 🆓 Free Tier Limits
- Storage: 25GB
- Bandwidth: 25GB/month
- Transformations: 25 credits
- Image size: Up to 100MB
- Perfect for development + small apps!

## 🚀 For Production
When you need more:
1. Upgrade to **Pay-as-you-go** (starts at $0/month)
2. Only pay for what you use
3. Much cheaper than Firebase Storage

## 🔐 Security Notes
- Upload preset is **unsigned** (for development)
- For production, use **signed uploads**
- Add authentication checks before upload
- Validate file types and sizes

## ❓ Troubleshooting

**"Invalid cloud name"**
- Double-check your cloud name from dashboard
- No spaces or special characters

**"Upload preset not found"**
- Ensure preset name is exactly `skillshare_uploads`
- Check signing mode is **Unsigned**

**"Upload failed"**
- Check internet connection
- Verify image file is valid
- Check file size (max 10MB with compression)
