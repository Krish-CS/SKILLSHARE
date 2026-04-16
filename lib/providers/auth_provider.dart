import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/presence_service.dart';
import '../utils/user_roles.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _currentUser;
  StreamSubscription<User?>? _authSub;
  int _authRevision = 0;
  bool _isLoading = false; // used by signup / resetPassword
  bool _isEmailLoading = false; // used by email sign-in only
  bool _isGoogleLoading = false; // used by Google sign-in only
  String? _error;

  UserModel? get currentUser => _currentUser;

  /// True when ANY auth operation is in progress (backward-compat).
  bool get isLoading => _isLoading || _isEmailLoading || _isGoogleLoading;

  /// True only while the email/password login button is loading.
  bool get isEmailLoading => _isEmailLoading;

  /// True only while the Google sign-in button is loading.
  bool get isGoogleLoading => _isGoogleLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;

  // Role-based getters for easy access
  String? get userRole => UserRoles.normalizeRole(_currentUser?.role);
  bool get isCustomer => userRole == UserRoles.customer;
  bool get isCompany => userRole == UserRoles.company;
  bool get isSkilledPerson => userRole == UserRoles.skilledPerson;
  bool get isAdmin => userRole == UserRoles.admin;

  // Check if user can perform specific actions
  bool get canPostJobs =>
      _currentUser != null && UserRoles.canPostJobs(userRole ?? '');
  bool get canApplyToJobs =>
      _currentUser != null && UserRoles.canApplyToJobs(userRole ?? '');
  bool get canSellProducts =>
      _currentUser != null && UserRoles.canSellProducts(userRole ?? '');
  bool get canBuyProducts =>
      _currentUser != null && UserRoles.canBuyProducts(userRole ?? '');
  bool get canUploadPortfolio =>
      _currentUser != null && UserRoles.canUploadPortfolio(userRole ?? '');
  bool get canHireSkilledPersons =>
      _currentUser != null && UserRoles.canHireSkilledPersons(userRole ?? '');
  bool get canBeHired =>
      _currentUser != null && UserRoles.canBeHired(userRole ?? '');

  AuthProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Listen to auth state changes
      _authSub = _authService.authStateChanges.listen((User? user) {
        final revision = ++_authRevision;
        if (user != null) {
          _loadUserData(user.uid, revision);
        } else {
          _currentUser = null;
          notifyListeners();
        }
      });
    } catch (e) {
      debugPrint('Auth provider initialization error: $e');
      _error = e.toString();
      notifyListeners();
    }
  }

  bool _isCurrentAuthLoad(String uid, int revision) {
    return revision == _authRevision && _authService.currentUser?.uid == uid;
  }

  Future<void> _loadUserData(String uid, int revision) async {
    try {
      final loadedUser = await _authService.getUserData(uid);
      if (!_isCurrentAuthLoad(uid, revision)) return;

      _currentUser = loadedUser;
      if (_currentUser == null) {
        // getUserData returned null — could be "doc doesn't exist" OR
        // a transient network/cache failure.  Do NOT overwrite role if
        // the doc already exists — that would corrupt a skilled_person
        // or company into a customer.
        final firebaseUser = _authService.currentUser;
        if (firebaseUser != null) {
          // Only create a fallback model for in-memory use.
          // Do NOT write role to Firestore — the doc may already have
          // the correct role; a merge with role:'customer' would overwrite it.
          _currentUser = UserModel(
            uid: uid,
            email: firebaseUser.email ?? '',
            name: firebaseUser.displayName ??
                firebaseUser.email?.split('@').first ??
                'User',
            role: 'customer', // in-memory default only
            profilePhoto: firebaseUser.photoURL,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          // Only merge non-role fields so we never corrupt the stored role.
          // Use a minimal map that excludes 'role'.
          try {
            await _authService.mergeUserProfileWithoutRole(_currentUser!);
          } catch (e) {
            debugPrint('Fallback profile merge (without role) failed: $e');
          }
        }
      }
      if (!_isCurrentAuthLoad(uid, revision)) return;
      _error = null;
      // Start online-presence tracking
      PresenceService.instance.startTracking(uid);
      notifyListeners();
    } catch (e) {
      if (!_isCurrentAuthLoad(uid, revision)) return;
      debugPrint('Error loading user data: $e');
      _error = e.toString();
      // Don't set _currentUser to null - keep session alive
      notifyListeners();
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
    String? phone,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _currentUser = await _authService.signUpWithEmail(
        email: email,
        password: password,
        name: name,
        role: role,
        phone: phone,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _isEmailLoading = true;
      _error = null;
      notifyListeners();

      _currentUser = await _authService.signInWithEmail(
        email: email,
        password: password,
      );

      _isEmailLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isEmailLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    ++_authRevision;
    _currentUser = null;
    _error = null;
    notifyListeners();
    PresenceService.instance.stopTracking();
    await _authService.signOut();
  }

  Future<bool> signInWithGoogle({String defaultRole = 'customer'}) async {
    try {
      _isGoogleLoading = true;
      _error = null;
      notifyListeners();

      _currentUser =
          await _authService.signInWithGoogle(defaultRole: defaultRole);

      _isGoogleLoading = false;
      notifyListeners();
      return _currentUser != null;
    } catch (e) {
      _error = e.toString();
      _isGoogleLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword(String email) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _authService.resetPassword(email);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> updateProfile(UserModel user) async {
    try {
      await _authService.updateUserProfile(user);
      _currentUser = user;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Refresh user data from Firestore
  Future<void> refreshUserData() async {
    if (_currentUser != null) {
      await _loadUserData(_currentUser!.uid, ++_authRevision);
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    PresenceService.instance.stopTracking();
    super.dispose();
  }
}
