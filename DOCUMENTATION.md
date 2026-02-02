# SkillShare - Project Documentation

## 📋 Project Overview

SkillShare is a **LinkedIn + Local Market + Freelance App** built with Flutter and Firebase. It connects skilled professionals (bakers, handicrafters, carpenters, tailors, editors, creators) with customers and companies, featuring identity verification and trust-based profiles.

## 🎯 Key Features Implemented

### ✅ Core Functionality
- **User Authentication** (Email/Password with Firebase)
- **Multi-Role System** (Skilled Users, Customers, Companies, Admin)
- **Profile Management** with skills, portfolio, and services
- **Identity Verification** using dummy Aadhaar database
- **Profile Visibility Control** (private until verified)
- **Location-Based Discovery**
- **Jobs Board** for companies to post opportunities
- **Shop/Products** section
- **Reviews & Ratings** system
- **In-App Chat** functionality
- **Admin Panel** features

## 📂 Project Structure

```
lib/
├── main.dart                    # App entry point
├── firebase_options.dart        # Firebase configuration
│
├── models/                      # Data models
│   ├── user_model.dart
│   ├── skilled_user_profile.dart
│   ├── service_model.dart
│   ├── product_model.dart
│   ├── job_model.dart
│   ├── review_model.dart
│   ├── chat_model.dart
│   ├── service_request_model.dart
│   └── appeal_model.dart
│
├── services/                    # Business logic
│   ├── auth_service.dart        # Authentication
│   ├── firestore_service.dart   # Database operations
│   ├── storage_service.dart     # File uploads
│   ├── chat_service.dart        # Messaging
│   └── verification_service.dart # Aadhaar verification
│
├── providers/                   # State management
│   ├── auth_provider.dart
│   └── user_provider.dart
│
├── screens/                     # UI screens
│   ├── splash_screen.dart
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
│
├── widgets/                     # Reusable components
│   ├── category_card.dart
│   ├── expert_card.dart
│   ├── job_card.dart
│   └── product_card.dart
│
└── utils/                       # Utilities
    ├── app_theme.dart           # App styling
    ├── app_constants.dart       # Constants
    └── app_helpers.dart         # Helper functions
```

## 🎨 UI Design

The app follows the provided UI reference with:
- **Gradient color scheme** (Purple, Pink, Blue, Orange)
- **Bottom navigation** with 4 tabs (Home, Explore, Jobs, Shop)
- **Card-based layouts** for profiles and content
- **Material Design 3** principles
- **Poppins font** family

### Color Palette
- Primary Blue: `#2196F3`
- Primary Pink: `#E91E63`
- Primary Orange: `#FF9800`
- Primary Purple: `#9C27B0`
- Accent Green: `#4CAF50`

## 👥 User Roles

### 1. Skilled User
- Create profile with skills and portfolio
- Submit for identity verification
- Become publicly visible after verification
- Offer services and products
- Respond to job opportunities
- Receive reviews and ratings

### 2. Customer
- Browse verified skilled professionals
- Search by location and category
- Send service requests
- Chat with service providers
- Leave reviews after service

### 3. Company
- Post job opportunities
- Search for skilled professionals
- Review applicants
- Hire directly through platform

### 4. Admin
- Review verification requests
- Approve/reject skilled user profiles
- Handle appeals and complaints
- Manage platform content

## 🔐 Authentication Flow

1. **Sign Up** → User selects role and creates account
2. **Login** → Firebase authentication
3. **Profile Setup** → Users complete their profiles
4. **Verification** (Skilled Users only) → Submit Aadhaar for verification
5. **Active Profile** → Verified users become publicly visible

## ✅ Verification System

### Dummy Aadhaar Database
The app includes a test verification system with dummy Aadhaar numbers:
- `123456789012` - Anita Sharma
- `987654321098` - Rajesh Verma
- `111122223333` - Priya Singh

### Verification States
- **Pending**: Profile submitted, awaiting admin review
- **Approved**: Profile verified, publicly visible
- **Rejected**: Verification failed, can submit appeal

## 💾 Database Structure

### Collections

#### users
```json
{
  "uid": "string",
  "email": "string",
  "name": "string",
  "role": "skilled_user|customer|company|admin",
  "phone": "string?",
  "profilePhoto": "string?",
  "createdAt": "timestamp",
  "updatedAt": "timestamp",
  "isActive": "boolean"
}
```

#### skilled_users
```json
{
  "userId": "string",
  "bio": "string",
  "skills": "array<string>",
  "category": "string",
  "verificationStatus": "pending|approved|rejected",
  "visibility": "public|private",
  "portfolioImages": "array<string>",
  "rating": "number",
  "reviewCount": "number",
  "isVerified": "boolean",
  "latitude": "number?",
  "longitude": "number?",
  "city": "string?"
}
```

#### jobs
```json
{
  "companyId": "string",
  "title": "string",
  "description": "string",
  "requiredSkills": "array<string>",
  "location": "string",
  "budgetMin": "number?",
  "budgetMax": "number?",
  "status": "open|in_progress|completed",
  "applicants": "array<string>",
  "deadline": "timestamp"
}
```

#### reviews
```json
{
  "skilledUserId": "string",
  "reviewerId": "string",
  "rating": "number",
  "comment": "string",
  "images": "array<string>",
  "createdAt": "timestamp"
}
```

## 🔧 Setup Instructions

See [SETUP.md](SETUP.md) for detailed setup instructions including:
- Firebase project creation
- Android/iOS configuration
- Running the app
- Security rules setup

## 📦 Dependencies

### Core
- `firebase_core` - Firebase initialization
- `firebase_auth` - Authentication
- `cloud_firestore` - Database
- `firebase_storage` - File storage

### State Management
- `provider` - State management

### UI
- `google_fonts` - Typography
- `cached_network_image` - Image caching
- `flutter_rating_bar` - Star ratings
- `shimmer` - Loading effects

### Utils
- `image_picker` - Camera/gallery access
- `geolocator` - Location services
- `intl` - Date/time formatting
- `uuid` - Unique ID generation

## 🚀 Getting Started

1. **Install Flutter** (3.0.0 or higher)
2. **Clone the repository**
3. **Run `flutter pub get`**
4. **Setup Firebase** (see SETUP.md)
5. **Run `flutter run`**

## 🧪 Testing

### Test Accounts
Create accounts with different roles:
- Skilled User: Test profile setup and verification
- Customer: Test browsing and requesting services
- Company: Test job posting
- Admin: Manual role assignment in Firestore

### Test Scenarios
1. Complete registration flow
2. Setup skilled user profile
3. Submit verification with dummy Aadhaar
4. Browse verified professionals
5. Post and apply for jobs
6. Send messages
7. Leave reviews

## 🎯 Future Enhancements

### Phase 2 (Recommended)
- [ ] Real-time chat with push notifications
- [ ] Advanced search and filters
- [ ] Payment integration
- [ ] Order management system
- [ ] Analytics dashboard
- [ ] Push notifications
- [ ] Multi-language support

### Phase 3 (Advanced)
- [ ] Video calls for consultations
- [ ] AI-powered skill matching
- [ ] Subscription plans
- [ ] Background verification integration
- [ ] Invoice generation
- [ ] Tax documentation
- [ ] Referral program

## 🐛 Known Limitations

1. **Verification**: Uses dummy database (needs real Aadhaar API integration)
2. **Location**: Basic implementation (can add map view)
3. **Chat**: Structure ready but needs real-time updates
4. **Admin Panel**: Basic features (needs full dashboard)
5. **Payments**: Not implemented (Razorpay/Stripe integration needed)

## 📱 Platform Support

- ✅ Android (Minimum SDK 21)
- ✅ iOS (iOS 12.0+)
- ❌ Web (Can be added with responsive adjustments)

## 🔒 Security Considerations

### Development Mode
- Firebase rules are permissive for testing
- Test Aadhaar database is hardcoded

### Production Checklist
- [ ] Update Firebase security rules
- [ ] Integrate real Aadhaar verification API
- [ ] Add rate limiting
- [ ] Implement proper error tracking
- [ ] Enable Firebase App Check
- [ ] Add API key restrictions
- [ ] Implement proper data validation
- [ ] Add content moderation
- [ ] Enable 2FA for admin accounts
- [ ] Regular security audits

## 📄 License

This project is created for educational purposes. Ensure proper licensing before commercial use.

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Commit changes
4. Push to branch
5. Create Pull Request

## 📞 Support

For issues or questions:
- Check SETUP.md for configuration issues
- Review code comments for implementation details
- Test with provided dummy data first

## ✨ Acknowledgments

- Flutter team for excellent framework
- Firebase for backend services
- Material Design for UI guidelines
- Community packages for utilities

---

**Built with ❤️ using Flutter & Firebase**
