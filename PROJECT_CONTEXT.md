# SkillShare Project Context (for AI continuity)

> **Last updated:** 2026-02-28
> **Flutter:** 3.27.1 | **Target:** Web (Chrome)
> **Backend:** Firebase/Firestore, Cloudinary for images
> **Latest commit:** `562f336` on `origin/main`

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

1. **Search Filter Bottom Sheet** — New `lib/widgets/filter_bottom_sheet.dart`
   - Reusable filter UI with sort, category, rating, price range filters
   - Integrated into: `home_screen.dart`, `shop_screen.dart`, `explore_screen.dart`
   - `FilterBottomSheet.show(context, mode: 'experts'|'products', ...)`

2. **Shop Screen Spacing** — `lib/screens/shop/shop_screen.dart`
   - Added breathing room between search bar, sort chips, category chips, featured section
   - `expandedHeight: 145`, bottom padding on search, 12px spacers between sections

3. **Dynamic Gradient Backgrounds** — Profile screens
   - `lib/screens/profile/profile_tab_screen.dart` — AnimatedBuilder with 6 rotating gradient palettes, 6s cycle
   - `lib/screens/profile/profile_screen.dart` — Same treatment, 8s cycle
   - Uses `TickerProviderStateMixin`, cos/sin for gradient direction rotation

4. **Banner Fonts & Animations Expansion**
   - `lib/screens/profile/banner_editor_screen.dart` and `lib/widgets/banner_display.dart`
   - Fonts: 6→12 (added lobster, raleway, mono, caveat, satisfy, righteous)
   - Animations: 6→10 (added bounce, glow, typewriter, rotate)
   - Gradients: 5→10

5. **Avatar Picker** — WhatsApp-style emoji avatars
   - New `lib/widgets/avatar_picker.dart` — 32 avatars in 4 categories
   - `avatarKey` field added to `lib/models/customer_profile.dart`
   - Integrated into `lib/screens/profile/customer_setup_screen.dart`

### Phase 6 — Shop Spacing Fix (commit `562f336`)
Further refined spacing in shop_screen.dart per user feedback.

---

## IN-PROGRESS WORK (INCOMPLETE — MUST BE FINISHED)

### Work Request & Notification System Enhancement

**What the user requested:**
1. Work request notifications should show badge counts — red for chat unread, amber/orange for pending work requests — on **both** the bottom navigation chat icon AND individual chat items in the chat list
2. Skilled person needs a proper **accept/reject UI** for incoming work requests (when they open from notification)
3. Notification bell taps should **navigate to the relevant page** (chat detail for work requests/messages, order tracking for orders)
4. Work request count badge should be visible in bottom nav AND chat list separately

**What has been done so far:**

#### A. `lib/utils/notification_helpers.dart` — MODIFIED ✅
- `NotificationItem` class expanded with navigation fields:
  - `NotificationType type` enum (workRequest, order, chatMessage)
  - `String? chatId`, `otherUserId`, `otherUserName`, `otherUserPhoto`
  - `String? requestId` (for work requests)
  - `OrderModel? orderData` (for orders)
- `loadNotificationsForUser()` updated to populate all navigation fields

#### B. `lib/screens/main_navigation.dart` — MODIFIED ✅
- Bottom nav chat icon now shows DUAL badges:
  - Red (top-right): unread chat messages
  - Amber (top-left): pending work requests
- New `_navDoubleBadge()` method added
- Uses nested `StreamBuilder<QuerySnapshot>` for work requests collection

#### C. `lib/screens/chat/chats_screen.dart` — PARTIALLY MODIFIED ⚠️
- Added imports: `cloud_firestore`, `app_constants`
- Added `_pendingWorkCounts` map and `_workRequestStream`
- Wrapped chat list with outer `StreamBuilder<QuerySnapshot>` for work requests
- Each chat item now shows:
  - Red badge (top-right): unread messages (existing)
  - Amber badge (top-left): pending work requests for that chat (NEW)
- **Status:** The code changes ARE in the file but have NOT been verified with `dart analyze` yet

#### D. `lib/screens/notifications/notifications_screen.dart` — NOT YET MODIFIED ❌
- Need to make notification cards **tappable** with navigation:
  - Work request → navigate to `ChatDetailScreen` with the relevant chat
  - Order → navigate to `OrderTrackingScreen`
  - Chat message → navigate to `ChatDetailScreen`
- The `NotificationItem` already has all the navigation data, just need to add `onTap` handlers to `_NotificationCard`

#### E. Skilled Person Accept/Reject UI — ALREADY EXISTS ✅
- `lib/widgets/chat/chat_work_request_section.dart` already has full accept/reject/cancel/remind/payment UI
- The `_WorkRequestCard` widget shows Approve/Decline buttons for skilled persons when status is pending
- **No new UI needed** — the navigation from notifications to the chat (where the work request section is) will solve this

**What still needs to be done:**
1. ✅ Verify `chats_screen.dart` compiles (run `dart analyze`)
2. ❌ Update `notifications_screen.dart` to make cards tappable with proper navigation
3. ❌ Run `dart analyze lib` to verify zero errors
4. ❌ Git commit and push all changes

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
  - SkilledPerson: Home(0), Portfolio(1), MyShop(2), Chats(3), Profile(4)
  - Company: Home(0), Jobs(1), Shop(2), Chats(3), Profile(4)
  - DeliveryPartner: Deliveries(0), Chats(1), Profile(2)

### Screens
- `lib/screens/chat/chats_screen.dart` — Chat list
- `lib/screens/chat/chat_detail_screen.dart` — Individual chat (constructor: chatId, otherUserId, otherUserName, otherUserPhoto)
- `lib/screens/notifications/notifications_screen.dart` — Notification list (constructor: userId)
- `lib/screens/shop/order_tracking_screen.dart` — Order tracking (constructor: order: OrderModel)

### Widgets
- `lib/widgets/notification_bell.dart` — Bell icon with badge in app bars
- `lib/widgets/chat/chat_work_request_section.dart` — Full work request UI inside chat (accept/reject/cancel/remind/pay)
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

---

## HOW TO CONTINUE IN NEW CHAT

Tell the new chat:
> "Read `D:\SKILLSHARE\PROJECT_CONTEXT.md` to understand the full project context and what work is in progress. Continue from where the previous session left off — specifically finish the notification click navigation and verify everything compiles."
