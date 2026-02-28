# SkillShare — Issues & Fixes Log

A running record of bugs encountered during development and how they were resolved.

---

## 1. Customer Profile Photo Not Displaying

**Date:** 2026-02-28  
**Severity:** High  
**Affected Role:** Customer  

### Symptom
- Customer (e.g., "erica") saw only the initial letter avatar ("E") instead of her uploaded profile photo on the home screen, profile tab, and profile screen.
- The **same photo appeared correctly** on a skilled person's chat list (because chat stores a snapshot of the photo URL in `participantDetails`).

### Root Cause
`UserModel.toMap()` always included `'profilePhoto': profilePhoto` in its output — even when the value was `null`. This meant:

1. On login, `AuthProvider._loadUserData()` calls `getUserData()`.
2. If the Firestore read returned `null` (transient network/cache failure), a **new** `UserModel` was created with `profilePhoto: null`.
3. `updateUserProfile()` then ran `.update(user.toMap())`, which wrote `'profilePhoto': null` to Firestore — **wiping the previously saved photo URL**.

The same issue existed in `CustomerProfile.toMap()` for the `profilePicture` field.

### Files Changed
| File | Change |
|------|--------|
| `lib/models/user_model.dart` | `toMap()` now uses `if (profilePhoto != null) 'profilePhoto': profilePhoto` — null values are never written to Firestore |
| `lib/models/customer_profile.dart` | Same conditional include for `profilePicture` in `toMap()` |
| `lib/providers/auth_provider.dart` | `_loadUserData()` now calls `mergeUserProfile()` (merge: true) instead of `updateUserProfile()` (update) when recreating a missing doc |
| `lib/services/auth_service.dart` | Added `mergeUserProfile()` method using `SetOptions(merge: true)` for safe writes |
| `lib/screens/home/home_screen.dart` | Added photo recovery: if both `users` and `customer_profiles` have no photo, recovers the URL from chat `participantDetails` and syncs it back |
| `lib/screens/profile/customer_setup_screen.dart` | Never writes empty string for `profilePicture`; preserves existing value when no new photo is picked |

### Lesson
Never include nullable fields unconditionally in `toMap()`. Use conditional entries (`if (field != null)`) so that Firestore's existing values are preserved when the local model doesn't have the data.

---

## 2. SnackBar Replaced with Animated AppDialog

**Date:** 2026-02-28  
**Severity:** UI/UX Improvement  

### Symptom
Default Material `SnackBar` notifications felt inconsistent and were sometimes hidden behind bottom navigation or dismissed too quickly.

### Fix
Created `lib/utils/app_dialog.dart` — a reusable animated popup with:
- **Success** (green, check icon), **Error** (red, error icon), and **Info** (blue, info icon) variants.
- Slide-up + fade animation.
- Auto-dismiss after a configurable delay with optional `onDismiss` callback.
- Non-blocking overlay (doesn't interfere with navigation).

Replaced all `ScaffoldMessenger.of(context).showSnackBar(...)` calls across **17 files**.

### Files Changed
All screens that previously used `SnackBar` — including profile screens, auth screens, chat screens, shop screens, job screens, and service screens.

### Lesson
Centralising feedback UI into a single utility makes it easy to maintain consistent look-and-feel across the app.

---

## 3. `use_build_context_synchronously` Lint Warnings

**Date:** 2026-02-28  
**Severity:** Low (lint)  

### Symptom
`dart analyze` flagged `use_build_context_synchronously` in several files where `context` was used after an `await` without checking `mounted`.

### Fix
Added `if (!mounted) return;` guards before every post-`await` usage of `context` (7 locations across multiple files).

### Lesson
Always check `mounted` before using `BuildContext` after any asynchronous gap in `State` classes.

---

<!--
Template for new entries:

## N. Title

**Date:** YYYY-MM-DD  
**Severity:** Low / Medium / High / Critical  

### Symptom
What the user saw or what broke.

### Root Cause
Why it happened.

### Files Changed
| File | Change |
|------|--------|

### Lesson
What to remember for the future.

-->
