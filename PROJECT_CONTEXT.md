# SkillShare Project Context (for AI continuity)

> **Last updated:** 2026-02-28
> **Flutter:** 3.27.1 | **Target:** Web (Chrome)
> **Backend:** Firebase/Firestore, Cloudinary for images
> **Latest commit:** `4e16120` on `origin/main`

---

## COMPLETED WORK

### Phase 1 — SnackBar → AppDialog Migration (17 files)
All SnackBar calls replaced with `AppPopup.show()` / `AppDialog` animated popups across the entire app.

### Phase 2 — Customer Profile Photo Fix
Root cause: `UserModel.toMap()` was writing null to Firestore for photo fields. Fixed.

### Phase 3 — ISSUES_AND_FIXES.md
Created documentation of all bugs found and fixed.

### Phase 4 — Git Push
Commit `da82c65` pushed to `origin/main`.

### Phase 5 — Five New UI Features (commit `52b87b6`)

1. **Search Filter Bottom Sheet** — `lib/widgets/filter_bottom_sheet.dart`
   - Reusable filter UI with sort, category, rating, price range filters
   - Integrated into: `home_screen.dart`, `shop_screen.dart`, `explore_screen.dart`

2. **Shop Screen Spacing** — `lib/screens/shop/shop_screen.dart`
   - Breathing room between search bar, sort chips, category chips, featured section

3. **Dynamic Gradient Backgrounds** — Profile screens
   - `lib/screens/profile/profile_tab_screen.dart` — 6 rotating gradient palettes, 6s cycle
   - `lib/screens/profile/profile_screen.dart` — Same treatment, 8s cycle

4. **Banner Fonts & Animations Expansion**
   - Fonts: 6→12 | Animations: 6→10 | Gradients: 5→10
   - Files: `banner_editor_screen.dart`, `banner_display.dart`

5. **Avatar Picker** — WhatsApp-style emoji avatars
   - `lib/widgets/avatar_picker.dart` — 32 avatars in 4 categories
   - `avatarKey` field added to `lib/models/customer_profile.dart`

### Phase 6 — Shop Spacing Fix (commit `562f336`)
Further refined spacing in `shop_screen.dart` per user feedback.

### Phase 7 — Work Request Badges, Notification Navigation & Banner UX (commit `209f5cd`)

1. **Chat list — amber work-request badges (reliable)**
   - `lib/screens/chat/chats_screen.dart`
   - `StreamBuilder` approach replaced with `StreamSubscription` in `initState` calling `setState` — badges always reflect live Firestore state
   - Per chat row: amber circle badge top-left of avatar (count), amber 4px left-border + light amber row tint, "● N pending work request(s)" text under last message

2. **Notification cards — tappable with navigation**
   - `lib/screens/notifications/notifications_screen.dart`
   - Work request & chat message notifications → `ChatDetailScreen` (which contains the Approve/Decline UI)
   - Order notifications → `OrderTrackingScreen`
   - Tappable cards: colored border, "Tap to view" pill, chevron `›`

3. **In-app banner — tap to open Chats tab**
   - `lib/screens/main_navigation.dart`
   - Banner navigates to Chats tab on tap; shows "Tap to open chats →" hint
   - Fixed `use_build_context_synchronously` lint warning — role captured synchronously before stream listener fires

### Phase 8 — Skilled Person Job Discovery, Portfolio in Profile & Company Verification (commit `4e16120`)

1. **Skilled Person bottom nav: Portfolio → Find Jobs**
   - `lib/screens/main_navigation.dart`
   - SkilledPerson nav index 1 changed from `PortfolioScreen()` → `JobsScreen()` (already role-aware)
   - Icon: `Icons.photo_library` → `Icons.work_outline`; label: `'Portfolio'` → `'Find Jobs'`
   - Gradient colour for that tab changed from deep-rose to blue→cyan

2. **Portfolio accessible from Profile tab**
   - `lib/screens/profile/profile_tab_screen.dart`
   - Added "My Portfolio" menu tile (pink `Icons.photo_library_rounded`) in the menu section, only for `UserRoles.skilledPerson`
   - Navigates to `PortfolioScreen`

3. **Company business verification badge in profile**
   - `lib/screens/profile/profile_tab_screen.dart`
   - Tracks `_companyProfile` via `companyProfileStream` in `_subscribeToRoleProfile`
   - Shows: green "Business Verified" / blue "Verification Pending" (hourglass) / orange tappable "Tap to Verify Business" → navigates to `CompanySetupScreen`

4. **Business Verification section in Company Setup**
   - `lib/screens/profile/company_setup_screen.dart`
   - New state vars: `_businessRegController`, `_isVerifying`, `_verificationStatus`
   - New "Business Verification" section card before Legal Details
   - Fields: Business Registration Number; Submit button → saves `verificationData: {businessRegNumber, gstNumber, submittedAt}` and sets `verificationStatus: 'submitted'`
   - Displays status-appropriate UI: green approved banner / blue pending banner / red rejected banner / input form
   - On save, preserves existing `isVerified` & `verificationStatus` (no longer hardcodes `false`/`'pending'`)

5. **Company verification gate on job posting**
   - `lib/screens/jobs/jobs_screen.dart`
   - Subscribes to `companyProfileStream` for company users
   - `_navigateToPostJob()` helper: if `!isCompanyVerified` → shows dialog prompting to complete verification; otherwise navigates to `CreateJobScreen`
   - Both "+ add" AppBar icon and empty-state "Post a Job" button routed through the gate

6. **Company in-chat hire requests — already supported**
   - `lib/screens/chat/chat_detail_screen.dart`
   - `canAskForWork = (isCustomer || isCompany)` — companies already see the work/hire request button in chat
   - `createChatWorkRequest()` already allows `company` role as sender

---

## IN-PROGRESS WORK

None — all features are complete. `dart analyze lib` returns **No issues found.**

---

## KEY FILES & ARCHITECTURE

### Models
- `lib/models/service_request_model.dart` — WorkRequest: id, chatId, customerId, skilledUserId, status (pending/accepted/rejected/completed/cancelled), title, description
- `lib/models/customer_profile.dart` — includes `avatarKey` field
- `lib/models/chat_model.dart` — participants, unreadCount map, lastMessage
- `lib/models/order_model.dart` — buyerId, sellerId, status, statusTimeline

### Navigation
- `lib/screens/main_navigation.dart` — IndexedStack with role-based tabs
  - Customer: Home(0), Shop(1), Cart(2), Chats(3), Profile(4)
  - SkilledPerson: Home(0), **Find Jobs**(1), MyShop(2), Chats(3), Profile(4)
  - Company: Home(0), Jobs(1), Shop(2), Chats(3), Profile(4)
  - DeliveryPartner: Deliveries(0), Chats(1), Profile(2)
  - Chat tab dual-badge: red top-right (unread messages), amber top-left (pending work requests)
  - Skilled person portfolio is now accessible from Profile tab menu ("My Portfolio" tile)

### Screens
- `lib/screens/chat/chats_screen.dart` — Chat list with per-row amber work-request badge
- `lib/screens/chat/chat_detail_screen.dart` — Individual chat (constructor: chatId, otherUserId, otherUserName, otherUserPhoto)
- `lib/screens/notifications/notifications_screen.dart` — Tappable notification list (constructor: userId)
- `lib/screens/shop/order_tracking_screen.dart` — Order tracking (constructor: order: OrderModel)

### Widgets
- `lib/widgets/notification_bell.dart` — Bell icon with badge in app bars
- `lib/widgets/chat/chat_work_request_section.dart` — Full work request UI (Approve/Decline/Cancel/Remind/Pay) shown inside ChatDetailScreen
- `lib/widgets/filter_bottom_sheet.dart` — Reusable filter sheet
- `lib/widgets/avatar_picker.dart` — Emoji avatar picker
- `lib/widgets/app_popup.dart` — `AppPopup.show()` for toast-style messages

### Services
- `lib/services/firestore_service.dart` — Key methods:
  - `createChatWorkRequest()`, `respondToChatWorkRequest()`, `cancelChatWorkRequest()`
  - `streamChatWorkRequests(chatId)`, `streamUserWorkRequests(userId)`
  - `getLatestUserWorkRequests()`, `getLatestOrdersForUser()`
  - `markNotificationsSeen(userId)`
- `lib/services/chat_service.dart` — `getUserChats()`, message CRUD
- `lib/utils/app_constants.dart` — Collection names, status constants
- `lib/utils/user_roles.dart` — `UserRoles.customer`, `.skilledPerson`, `.company`, `.deliveryPartner`, `.admin`

### Key Constants
- `AppConstants.requestsCollection` — Firestore collection for work requests
- `AppConstants.chatsCollection` — Firestore collection for chats
- `AppConstants.requestStatusPending/Accepted/Rejected` — Status strings
- Chat work request type string: `'chat_work_request'`

### Notification Flow (end-to-end)
1. Customer sends a work request from `ChatDetailScreen`
2. Firestore document created in `requests` collection (type: `chat_work_request`, status: `pending`)
3. Skilled person sees:
   - **Bottom nav** chat icon: amber badge (top-left) with pending count
   - **Chat list row**: amber left-border, amber text "N pending work request(s)"
   - **In-app banner** slides down from top; tapping it opens the Chats tab
   - **Notification bell**: opens `NotificationsScreen` — card is tappable → opens `ChatDetailScreen`
4. Inside `ChatDetailScreen`, `ChatWorkRequestSection` renders **Approve / Decline** buttons
5. On approval: `respondToChatWorkRequest()` updates status → customer sees accepted state with **Pay** button

---

## HOW TO CONTINUE IN NEW CHAT

> "Read `D:\SKILLSHARE\PROJECT_CONTEXT.md` to understand the full project context. All work is complete and pushed to `origin/main`. Ask what the user wants to build or fix next."
