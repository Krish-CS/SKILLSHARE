# ROLE-BASED SYSTEM IMPLEMENTATION

## Overview
This document explains the **strict role-based access control** implemented in the SkillShare application. The system ensures complete separation between three distinct user types, with each having specific permissions and views.

---

## User Roles

### 1. **CUSTOMER** (`UserRoles.customer`)
**Purpose:** Individual users who want to hire skilled persons or purchase products.

**Permissions:**
- ✅ Browse skilled persons and their portfolios
- ✅ View portfolio photos/videos of skilled persons
- ✅ Hire skilled persons for projects
- ✅ Purchase products from skilled persons' shops
- ✅ Post job requests
- ✅ Chat with skilled persons
- ✅ Write reviews and ratings
- ❌ **CANNOT** upload portfolio items
- ❌ **CANNOT** sell products
- ❌ **CANNOT** apply to jobs

**Navigation:**
- Home (Browse skilled persons)
- Jobs (View/post jobs)
- Shop (Browse and buy products)
- Chats
- Profile

---

### 2. **COMPANY** (`UserRoles.company`)
**Purpose:** Organizations that need to hire skilled persons for projects.

**Permissions:**
- ✅ Browse skilled persons and their portfolios
- ✅ View portfolio photos/videos of skilled persons
- ✅ Hire skilled persons for projects
- ✅ Purchase products (business supplies)
- ✅ Post job listings
- ✅ Chat with skilled persons
- ✅ Write reviews and ratings
- ✅ Bulk hiring capabilities
- ❌ **CANNOT** upload portfolio items
- ❌ **CANNOT** sell products
- ❌ **CANNOT** apply to jobs

**Navigation:**
- Home (Find talent)
- Jobs (Post/manage jobs)
- Shop (Browse business supplies)
- Chats
- Profile (Business profile)

**Additional Features:**
- Company profile with verification
- Business registration details
- Company logo and certificates

---

### 3. **SKILLED PERSON** (`UserRoles.skilledPerson`)
**Purpose:** Service providers who showcase their work and offer services/products.

**Permissions:**
- ✅ Upload portfolio photos/videos (showcase completed work)
- ✅ Manage portfolio items
- ✅ Open and manage online shop
- ✅ Sell products through their shop
- ✅ Apply to job listings
- ✅ Receive job offers from customers/companies
- ✅ Chat with potential clients
- ✅ Receive reviews and ratings
- ✅ Set availability status
- ❌ **CANNOT** post jobs
- ❌ **CANNOT** hire other skilled persons
- ❌ **CAN** browse products but primary focus is selling

**Navigation:**
- Home (Dashboard with performance metrics)
- Portfolio (Upload and manage work photos/videos)
- My Shop (Manage products and orders)
- Chats
- Profile

**Key Features:**
- **Portfolio System:** Upload photos/videos of completed work
- **Shop Management:** Add products, manage inventory, process orders
- **Profile Verification:** Aadhaar verification for credibility
- **Skills & Categories:** Tag work with relevant skills
- **Showcase Work:** Display projects with details (client, cost, duration)

---

## Core Principle: Strict Separation

### What This Means:
1. **NO MIXED ROLES:** A user can only be ONE type at a time
2. **ENFORCED ACCESS:** Role checks at every critical operation
3. **SEPARATE VIEWS:** Each role sees different content and options
4. **PERMISSION GATES:** Actions blocked if user lacks permission

---

## Key Features by Role

### Portfolio System (Skilled Persons ONLY)
```dart
// Portfolio items contain:
- Work photos/videos
- Project descriptions
- Skills/tags
- Client information (optional)
- Project cost and duration
- Likes and views count
```

**Access:** Only skilled persons can:
- Add portfolio items
- Edit portfolio items
- Delete portfolio items
- Make items public/private

**Customers/Companies can:**
- View public portfolio items
- Like and save favorites
- Contact skilled person about their work

---

### Shop System

#### For Skilled Persons:
- **"My Shop" Tab** in navigation
- Add/edit/delete products
- Manage inventory and stock
- Process orders
- View sales analytics
- Set product availability

#### For Customers/Companies:
- **"Shop" Tab** in navigation
- Browse all products from all skilled persons
- Filter by category, price, rating
- Purchase products
- Review products
- Save favorites

**Critical Rule:** Only skilled persons can **SELL**. Customers/companies can only **BUY**.

---

### Jobs/Hiring System

#### For Customers/Companies:
- Post job listings
- Set budget and requirements
- Review applicants
- Select skilled person for job
- Track project progress

#### For Skilled Persons:
- Browse job listings
- Apply to jobs
- Submit proposals
- Receive direct hire requests
- Complete projects

**Critical Rule:** 
- Customers/Companies **POST** jobs
- Skilled Persons **APPLY** to jobs

---

### Chat System (All Roles)
**Everyone can chat, but context matters:**

#### Customer → Skilled Person:
- Inquire about services
- Discuss project requirements
- Negotiate pricing

#### Company → Skilled Person:
- Discuss job opportunities
- Request proposals
- Coordinate projects

#### Skilled Person → Customer/Company:
- Respond to inquiries
- Send proposals
- Provide updates

**Chat features:**
- Direct messaging
- Image/file sharing
- Project discussions
- Order support

---

## Implementation Details

### Role Checking in Code

#### 1. **AuthProvider** (lib/providers/auth_provider.dart)
```dart
// Quick role checks
bool get isCustomer => currentUser?.role == UserRoles.customer;
bool get isCompany => currentUser?.role == UserRoles.company;
bool get isSkilledPerson => currentUser?.role == UserRoles.skilledPerson;

// Permission checks
bool get canPostJobs => UserRoles.canPostJobs(currentUser!.role);
bool get canApplyToJobs => UserRoles.canApplyToJobs(currentUser!.role);
bool get canSellProducts => UserRoles.canSellProducts(currentUser!.role);
```

#### 2. **Role-Based Navigation** (lib/screens/main_navigation.dart)
Different bottom navigation based on role:
```dart
// Customer/Company: Home | Jobs | Shop | Chats | Profile
// Skilled Person: Home | Portfolio | My Shop | Chats | Profile
```

#### 3. **Access Control Example**
```dart
// In Portfolio Screen
if (!authProvider.isSkilledPerson) {
  return _buildAccessDenied(); // Show error message
}

// In Add Product Screen
if (!authProvider.isSkilledPerson) {
  return _buildAccessDenied(); // Prevent product creation
}

// In Create Job Screen
if (!authProvider.canPostJobs) {
  return _buildAccessDenied(); // Prevent job posting
}
```

---

## Data Models

### User Model (lib/models/user_model.dart)
```dart
class UserModel {
  final String uid;
  final String email;
  final String name;
  final String role; // 'customer', 'company', 'skilled_person'
  // ... other fields
}
```

### Portfolio Item Model (lib/models/portfolio_model.dart)
```dart
class PortfolioItem {
  final String userId; // Skilled person's ID
  final String title;
  final String description;
  final List<String> images; // Work photos
  final List<String> videos; // Work videos
  final String category;
  final List<String> tags; // Skills
  // ... other fields
}
```

### Company Profile Model (lib/models/portfolio_model.dart)
```dart
class CompanyProfile {
  final String userId;
  final String companyName;
  final String industry;
  final String registrationNumber;
  // ... verification details
}
```

---

## Security Rules (Firestore)

### Recommended Firestore Rules:
```javascript
// Products - Only skilled persons can create
match /products/{productId} {
  allow read: if true; // Everyone can view
  allow create: if request.auth != null && 
                get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'skilled_person';
  allow update, delete: if request.auth != null && 
                        resource.data.userId == request.auth.uid;
}

// Jobs - Only companies/customers can create
match /jobs/{jobId} {
  allow read: if true; // Everyone can view
  allow create: if request.auth != null && 
                (get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'company' ||
                 get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'customer');
  allow update, delete: if request.auth != null && 
                        resource.data.companyId == request.auth.uid;
}

// Portfolio - Only skilled persons can create
match /portfolio/{itemId} {
  allow read: if resource.data.isPublic == true || 
                request.auth.uid == resource.data.userId;
  allow create: if request.auth != null && 
                get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'skilled_person';
  allow update, delete: if request.auth != null && 
                        resource.data.userId == request.auth.uid;
}
```

---

## UI/UX Differentiation

### Color Schemes by Role:
- **Customers:** Purple/Pink gradient (0xFF9C27B0 → 0xFFE91E63)
- **Companies:** Blue/Indigo gradient (0xFF3F51B5 → 0xFF2196F3)
- **Skilled Persons:** Green/Teal gradient (0xFF4CAF50 → 0xFF009688)

### Screen Titles by Role:
| Screen | Customer | Company | Skilled Person |
|--------|----------|---------|----------------|
| Home | "Discover Skills" | "Find Talent" | "Dashboard" |
| Jobs | "Hire & Jobs" | "Post Jobs" | "Find Jobs" |
| Shop | "Shop - Browse Products" | "Shop - Business Supplies" | N/A (Uses "My Shop") |

---

## Testing Checklist

### Customer Account:
- [ ] Can browse skilled persons
- [ ] Can view portfolios (read-only)
- [ ] Can post jobs
- [ ] Can purchase products
- [ ] **CANNOT** access Portfolio tab
- [ ] **CANNOT** access My Shop tab
- [ ] **CANNOT** add products

### Company Account:
- [ ] Can browse skilled persons
- [ ] Can view portfolios (read-only)
- [ ] Can post jobs
- [ ] Can purchase products
- [ ] **CANNOT** access Portfolio tab
- [ ] **CANNOT** access My Shop tab
- [ ] **CANNOT** add products

### Skilled Person Account:
- [ ] Can upload portfolio items
- [ ] Can manage My Shop
- [ ] Can add products to sell
- [ ] Can apply to jobs
- [ ] **CANNOT** post jobs
- [ ] Shop tab shows browse view (not manage view)

---

## Summary

This role-based system ensures:
1. ✅ **Clear separation** between user types
2. ✅ **Skilled persons** showcase work via portfolios
3. ✅ **Skilled persons** can open shops to sell products
4. ✅ **Customers/Companies** can hire and purchase
5. ✅ **Strict enforcement** at UI and data levels
6. ✅ **Appropriate views** for each role
7. ✅ **Secure data access** via role checks

The system is designed to be **intuitive, secure, and scalable** while maintaining strict boundaries between user types.
