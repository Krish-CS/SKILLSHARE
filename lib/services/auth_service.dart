import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../utils/app_constants.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static bool _isInitialized = false;

  AuthService() {
    _initializeAuth();
  }

  // Initialize auth settings once
  Future<void> _initializeAuth() async {
    if (!_isInitialized) {
      // Removed test mode setting - use production settings
      _isInitialized = true;
    }
  }

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Get current user stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign up with email and password
  Future<UserModel?> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String role,
    String? phone,
  }) async {
    try {
      // Create user in Firebase Auth with retry logic
      UserCredential? userCredential;
      int retries = 3;
      FirebaseAuthException? lastError;

      while (retries > 0 && userCredential == null) {
        try {
          userCredential = await _auth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          ).timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw FirebaseAuthException(
                code: 'network-error',
                message: 'Network timeout. Please check your internet connection.',
              );
            },
          );
        } on FirebaseAuthException catch (e) {
          lastError = e;
          retries--;
          if (retries > 0) {
            await Future.delayed(Duration(seconds: 2));
          }
        }
      }

      if (userCredential == null) {
        throw lastError ?? Exception('Failed to create user');
      }

      final user = userCredential.user;
      if (user == null) return null;

      print('User created in Firebase Auth: ${user.uid}');

      // Create user document in Firestore
      final userModel = UserModel(
        uid: user.uid,
        email: email,
        name: name,
        role: role,
        phone: phone,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      print('Attempting to write to Firestore collection: ${AppConstants.usersCollection}');
      try {
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(user.uid)
            .set(userModel.toMap());
        print('User document created successfully');
      } catch (firestoreError) {
        print('Firestore write error: $firestoreError');
        throw 'Failed to create user profile: $firestoreError';
      }

      // If skilled user, create empty profile
      if (role == AppConstants.roleSkilledUser) {
        print('Creating skilled user profile');
        try {
          await _firestore
              .collection(AppConstants.skilledUsersCollection)
              .doc(user.uid)
              .set({
            'bio': '',
            'skills': [],
            'verificationStatus': AppConstants.verificationPending,
            'visibility': AppConstants.visibilityPrivate,
            'portfolioImages': [],
            'portfolioVideos': [],
            'rating': 0.0,
            'reviewCount': 0,
            'projectCount': 0,
            'isVerified': false,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          print('Skilled user profile created successfully');
        } catch (firestoreError) {
          print('Skilled user profile error: $firestoreError');
          // Don't throw - user doc was created
        }
      }

      return userModel;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e, stackTrace) {
      print('Signup error: $e');
      print('Stack trace: $stackTrace');
      throw 'Signup failed: ${e.toString()}';
    }
  }

  // Sign in with email and password
  Future<UserModel?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        throw 'Authentication failed';
      }

      // Get user data from Firestore
      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        // User authenticated but no Firestore doc - create one
        print('Creating user document for ${user.uid}');
        final userModel = UserModel(
          uid: user.uid,
          email: email,
          name: email.split('@').first, // Use email prefix as name
          role: AppConstants.roleCustomer, // Default role
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(user.uid)
            .set(userModel.toMap());
            
        return userModel;
      }

      // Check if data exists
      final data = doc.data();
      if (data == null) {
        throw 'User data is empty';
      }

      print('User data: $data');
      return UserModel.fromMap(data, user.uid);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e, stackTrace) {
      // Print actual error for debugging
      print('Login error: $e');
      print('Stack trace: $stackTrace');
      throw 'Login failed: ${e.toString()}';
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Get user data
  Future<UserModel?> getUserData(String uid) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .get(const GetOptions(source: Source.serverAndCache));

      if (!doc.exists) return null;

      return UserModel.fromMap(doc.data()!, uid);
    } catch (e) {
      debugPrint('getUserData error: $e');
      // Try again from cache only on failure
      try {
        final doc = await _firestore
            .collection(AppConstants.usersCollection)
            .doc(uid)
            .get(const GetOptions(source: Source.cache));
        
        if (!doc.exists) return null;
        return UserModel.fromMap(doc.data()!, uid);
      } catch (cacheError) {
        debugPrint('Cache read error: $cacheError');
        return null;
      }
    }
  }

  // Update user profile
  Future<void> updateUserProfile(UserModel user) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .update(user.toMap());
    } catch (e) {
      debugPrint('updateUserProfile error: $e');
      // Silently fail on web if offline
      rethrow;
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Handle auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password is too weak';
      case 'email-already-in-use':
        return 'An account already exists for this email';
      case 'invalid-email':
        return 'The email address is invalid';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      default:
        return 'Authentication failed. Please try again';
    }
  }
}
