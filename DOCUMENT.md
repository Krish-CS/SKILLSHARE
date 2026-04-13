# SkillShare Project Document

SkillShare is a Flutter and Firebase marketplace app that connects skilled people, customers, companies, and delivery partners in one role-based platform. The app starts in `main.dart`, initializes Firebase, configures Firestore for web and mobile, loads providers with `MultiProvider`, and protects the app with `AppLockGate`. From there, the `SplashScreen` checks the Firebase auth state and routes the user either to login or into the main app.

## Brief Project Flow

- The user signs up or logs in with email/password or Google sign-in.
- During sign-up, the app creates the Firebase Auth account, writes the user document in Firestore, and opens the correct setup screen based on the selected role.
- After login, `AuthProvider` loads the user profile, starts presence tracking, and keeps the current role in memory.
- `MainNavigation` switches the whole app based on role, so each user sees only the screens and actions allowed for that role.
- The app uses live Firestore streams for chats, jobs, products, orders, requests, profiles, and notifications so the UI updates in real time.

## Main Features

- Role-based access for `customer`, `company`, `skilled_person`, `admin`, and `delivery_partner`.
- Skilled users can create profiles, portfolios, services, and products, then manage their shop and orders.
- Customers and companies can browse skilled users, view profiles, chat, buy products, and raise requests.
- Companies can post jobs, review applicants, and continue accepted job discussions in chat.
- Chat supports direct chat, work-request chat, and job-specific chat with unread badges and request badges.
- Delivery partners can view assigned deliveries and available deliveries.
- Admin tools cover dashboard, user management, product management, reports, verifications, and account actions.
- App lock supports PIN, pattern, and biometrics, and locks again when the app goes to the background.
- Notifications and in-app banners are streamed from Firestore for chat, work, job, and order updates.

## Technical Summary

The app is built with Flutter UI and Provider state management. `AuthProvider` manages authentication state, role checks, loading states, sign-in, sign-up, Google login, password reset, and profile syncing. `UserProvider` manages role-specific profile data and verified-user discovery. `FirestoreService` is the main data layer and handles CRUD, streams, chat creation, jobs, products, carts, orders, reviews, requests, appeals, reports, settings, blocking, verification, and admin operations. `ChatService` handles chat lookup and creation, privacy checks, and message flow. `PresenceService` writes online status and last-seen data to Firestore.

The project uses Firebase Authentication, Cloud Firestore, Google Sign-In, Cloudinary image handling, local authentication, shared preferences, and several utility packages for media, search, file export, and UI polish. Firestore collections in the app include users, skilled users, customer profiles, company profiles, jobs, chats, messages, products, carts, orders, requests, reviews, appeals, reports, blocked users, support tickets, and delivery assignments.

## Flutter Patterns Used

- `MaterialApp` for the app shell and theming.
- `MultiProvider` and `ChangeNotifierProvider` for global state.
- `StatefulWidget` with `initState`, `dispose`, and `setState` for screen lifecycle and UI updates.
- `StreamBuilder` for live Firestore content such as chats, jobs, products, and orders.
- `FutureBuilder` for one-time async data like notifications.
- `IndexedStack` for preserving tab state in the main navigation.
- `TabController` and `TabBarView` for role-specific tab layouts.
- `Navigator.push`, `Navigator.pushReplacement`, and custom `PageRouteBuilder` transitions for screen flow.
- `RefreshIndicator`, `SafeArea`, `Scaffold`, `CustomScrollView`, `Sliver` widgets, `showDialog`, and `showModalBottomSheet` for the main UI interactions.
- `AnimationController` and `AnimatedBuilder` for the animated gradients and polished transitions used across auth and admin screens.

## Why It Is Structured This Way

The app is structured around roles because the available features are different for each user type. That keeps the interface focused, reduces accidental access, and makes the same backend data model usable across browsing, hiring, shopping, chatting, delivery, and administration. The heavy use of Firestore streams keeps the app responsive without manual refresh, while Provider keeps auth and profile state available across the whole navigation tree.
