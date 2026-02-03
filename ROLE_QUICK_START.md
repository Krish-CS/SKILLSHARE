# 🎯 SKILLSHARE APP - ROLE-BASED SYSTEM QUICK START GUIDE

## 📋 Three User Types - Clear Separation

### 👤 CUSTOMER (Regular Users)
**What they do:**
- Browse and discover skilled persons
- View portfolios of skilled persons (photos of their work)
- Hire skilled persons for projects
- Buy products from skilled persons
- Post job requests
- Chat with skilled persons

**What they CAN'T do:**
- ❌ Upload portfolio items
- ❌ Open a shop or sell products
- ❌ Apply to jobs

**Navigation:** Home | Jobs | Shop | Chats | Profile

---

### 🏢 COMPANY (Organizations)
**What they do:**
- Browse and discover skilled persons
- View portfolios of skilled persons
- Hire skilled persons for projects
- Buy business supplies/products
- Post job listings
- Chat with skilled persons

**What they CAN'T do:**
- ❌ Upload portfolio items
- ❌ Open a shop or sell products
- ❌ Apply to jobs

**Navigation:** Home | Jobs | Shop | Chats | Profile

---

### ⭐ SKILLED PERSON (Service Providers)
**What they do:**
- Upload portfolio photos/videos (showcase their completed work)
- Manage their portfolio
- Open and manage online shop
- Sell products through their shop
- Apply to job listings
- Receive job offers
- Chat with potential clients

**What they CAN'T do:**
- ❌ Post jobs
- ❌ Hire other skilled persons

**Navigation:** Home | Portfolio | My Shop | Chats | Profile

---

## 🎨 Key Features by Role

### Portfolio System (Skilled Persons Only)
```
📸 Upload photos of completed work
🎥 Upload videos of projects
📝 Add descriptions and tags
💼 Showcase client projects
📊 Track views and likes
```

**Example Portfolio Items:**
- Baker: Photos of custom cakes, pastries
- Carpenter: Photos of furniture, installations
- Tailor: Photos of custom clothing, alterations
- Artist: Photos of paintings, handicrafts

### Shop System

**For Skilled Persons (My Shop):**
```
➕ Add products to sell
📦 Manage inventory and stock
📋 Process customer orders
📊 View sales analytics
💰 Track earnings
```

**For Customers/Companies (Shop):**
```
🔍 Browse all products
🛒 Purchase items
⭐ Review products
❤️ Save favorites
```

### Jobs/Hiring System

**For Customers/Companies:**
```
📢 Post job listings
💵 Set budget and requirements
👥 Review applicants
✅ Select skilled person
📈 Track project progress
```

**For Skilled Persons:**
```
🔍 Browse job listings
📝 Apply to jobs
💼 Submit proposals
📬 Receive direct hire requests
✓ Complete projects
```

---

## 🔐 Security & Access Control

### How It Works:
1. **Role stored in user profile** - `role: 'customer' | 'company' | 'skilled_person'`
2. **UI checks role** - Shows/hides features based on permissions
3. **Access gates** - Blocks unauthorized actions with error messages
4. **Different navigation** - Each role has unique bottom tabs

### Access Control Flow:
```dart
// Example: Only skilled persons can add products
if (!authProvider.isSkilledPerson) {
  // Show "Access Denied" screen
  return _buildAccessDenied();
}
```

---

## 📱 User Interface Differences

### Color Schemes:
- **Customers:** Purple/Pink gradient 💜
- **Companies:** Blue/Indigo gradient 💙
- **Skilled Persons:** Green/Teal gradient 💚

### Screen Titles:
| Screen | Customer | Company | Skilled Person |
|--------|----------|---------|----------------|
| Home | "Discover Skills" | "Find Talent" | "Dashboard" |
| Jobs | "Hire & Jobs" | "Post Jobs" | "Find Jobs" |
| Tab 2 | Jobs | Jobs | **Portfolio** |
| Tab 3 | Shop | Shop | **My Shop** |

---

## 🚀 User Flows

### Customer Flow:
1. Browse skilled persons on Home screen
2. View portfolio of a skilled person
3. Chat with them to discuss project
4. Either:
   - Post a job listing, OR
   - Hire directly through chat
5. Browse Shop to purchase products
6. Leave reviews after project completion

### Company Flow:
1. Browse skilled persons on Home screen
2. View portfolios to assess skills
3. Post job listings with requirements
4. Review applicants
5. Select skilled person for project
6. Manage project through chats
7. Purchase business supplies from Shop

### Skilled Person Flow:
1. Create profile and get verified
2. Upload portfolio items (photos of work)
3. Open shop and add products to sell
4. Browse job listings and apply
5. Receive inquiries from customers
6. Chat with potential clients
7. Complete projects and get reviews
8. Manage shop orders and inventory

---

## 📂 Important Files

### Core Role System:
- `lib/utils/user_roles.dart` - Role constants and permissions
- `lib/providers/auth_provider.dart` - Role checking methods
- `lib/screens/main_navigation.dart` - Role-based navigation

### Portfolio System:
- `lib/models/portfolio_model.dart` - Portfolio data models
- `lib/services/portfolio_service.dart` - Portfolio operations
- `lib/screens/portfolio/portfolio_screen.dart` - Portfolio UI
- `lib/screens/portfolio/my_shop_screen.dart` - Shop management UI

### Documentation:
- `ROLE_BASED_SYSTEM.md` - Complete system documentation
- `ROLE_IMPLEMENTATION_SUMMARY.md` - Implementation details
- `ROLE_QUICK_START.md` - This file

---

## 🧪 Testing

### Test Customer Account:
```
1. Sign up with role "customer"
2. Check navigation has: Home | Jobs | Shop | Chats | Profile
3. Try to access /portfolio → Should not exist in nav
4. Browse Home → Should see skilled persons
5. Try to add product → Should show "Access Denied"
6. Can post jobs ✅
7. Can buy products ✅
```

### Test Company Account:
```
1. Sign up with role "company"
2. Check navigation has: Home | Jobs | Shop | Chats | Profile
3. Browse skilled persons ✅
4. Post job listings ✅
5. Try to add product → Should show "Access Denied"
6. Can buy products ✅
```

### Test Skilled Person Account:
```
1. Sign up with role "skilled_person"
2. Check navigation has: Home | Portfolio | My Shop | Chats | Profile
3. Access Portfolio tab → Should work ✅
4. Upload portfolio items ✅
5. Access My Shop tab → Should work ✅
6. Add products to sell ✅
7. Try to post job → Should show "Access Denied"
8. Can apply to jobs ✅
```

---

## 🔥 Key Principles

### 1. **Strict Separation**
- No mixed roles - one user = one role
- Different screens for different roles
- Clear access control at every level

### 2. **Portfolio ≠ Social Media**
- Portfolio is for **showcasing completed professional work**
- Not a feed or timeline
- Photos/videos of actual projects done

### 3. **Shop Separation**
- "Shop" (tab 3 for customers/companies) = Browse and buy
- "My Shop" (tab 3 for skilled persons) = Manage and sell
- Completely different screens and purposes

### 4. **Jobs System**
- Companies/Customers = Employers (post jobs)
- Skilled Persons = Workers (apply to jobs)
- Clear distinction maintained

### 5. **Chat Context**
- Customer → Skilled Person: Hiring inquiries
- Company → Skilled Person: Job opportunities
- Context-aware messaging

---

## 🎓 For Developers

### Adding Role Check to New Screen:
```dart
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/user_roles.dart';

class MyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    
    // Check if user has permission
    if (!authProvider.isSkilledPerson) {
      return _buildAccessDenied();
    }
    
    // Continue with normal screen
    return Scaffold(...);
  }
}
```

### Checking Permissions:
```dart
final authProvider = Provider.of<AuthProvider>(context);

if (authProvider.canPostJobs) {
  // Show post job button
}

if (authProvider.canSellProducts) {
  // Show add product button
}

if (authProvider.isSkilledPerson) {
  // Show portfolio upload
}
```

---

## ✅ Implementation Checklist

- [x] Role constants and utilities created
- [x] Auth provider updated with role checks
- [x] Navigation system role-aware
- [x] Portfolio screens created
- [x] Shop management screen created
- [x] Home screen updated with role context
- [x] Jobs screen with role restrictions
- [x] Shop screen with role context
- [x] Add product screen protected
- [x] Create job screen protected
- [x] Portfolio service created
- [x] Data models defined
- [x] Documentation completed

### Still To Do:
- [ ] Implement Firestore security rules
- [ ] Complete portfolio CRUD operations
- [ ] Image upload integration
- [ ] Order management system
- [ ] Payment integration
- [ ] Job application system
- [ ] Enhanced chat features
- [ ] Review and rating system

---

## 📞 Quick Reference

### Role Permission Methods:
```dart
UserRoles.canPostJobs(role)           // Companies & Customers
UserRoles.canApplyToJobs(role)        // Skilled Persons
UserRoles.canSellProducts(role)       // Skilled Persons
UserRoles.canBuyProducts(role)        // All except skilled person focus
UserRoles.canUploadPortfolio(role)    // Skilled Persons
UserRoles.canHireSkilledPersons(role) // Companies & Customers
UserRoles.canBeHired(role)            // Skilled Persons
```

### Auth Provider Getters:
```dart
authProvider.isCustomer
authProvider.isCompany
authProvider.isSkilledPerson
authProvider.canPostJobs
authProvider.canApplyToJobs
authProvider.canSellProducts
authProvider.canUploadPortfolio
```

---

## 🎉 Summary

Your SkillShare app now has:
- ✅ Three distinct user roles with clear purposes
- ✅ Strict access control at UI and logic levels
- ✅ Portfolio system for skilled persons to showcase work
- ✅ Shop management for skilled persons to sell products
- ✅ Separate views for sellers vs buyers
- ✅ Jobs system with employer/worker separation
- ✅ Role-aware navigation and color schemes
- ✅ Comprehensive documentation

**The system is ready for further development with a solid role-based foundation!** 🚀
