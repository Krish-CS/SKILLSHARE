import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/user_model.dart';
import '../utils/app_constants.dart';
import '../utils/user_roles.dart';

class CreatedDeliveryPartnerAccount {
  final String uid;
  final String name;
  final String email;
  final String password;
  final String? phone;

  const CreatedDeliveryPartnerAccount({
    required this.uid,
    required this.name,
    required this.email,
    required this.password,
    this.phone,
  });
}

class CreatedManagedUserAccount {
  final String uid;
  final String name;
  final String email;
  final String password;
  final String role;
  final String? phone;

  const CreatedManagedUserAccount({
    required this.uid,
    required this.name,
    required this.email,
    required this.password,
    required this.role,
    this.phone,
  });
}

class DeliveryPartnerAdminService {
  Future<CreatedManagedUserAccount> createManagedUser({
    required String name,
    required String email,
    required String password,
    required String role,
    String? phone,
  }) async {
    final normalizedName = name.trim();
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPassword = password.trim();
    final normalizedPhone =
        phone != null && phone.trim().isNotEmpty ? phone.trim() : null;
    final normalizedRole = UserRoles.normalizeRole(role);

    if (normalizedName.isEmpty) {
      throw Exception('User name is required.');
    }
    if (normalizedEmail.isEmpty) {
      throw Exception('User email is required.');
    }
    if (normalizedPassword.length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }
    if (normalizedRole == null || !UserRoles.isValidRole(normalizedRole)) {
      throw Exception('Invalid role "$role".');
    }

    final tempAppName =
        'managed-user-admin-${DateTime.now().microsecondsSinceEpoch}';
    FirebaseApp? tempApp;
    FirebaseAuth? tempAuth;
    User? createdUser;

    try {
      tempApp = await Firebase.initializeApp(
        name: tempAppName,
        options: Firebase.app().options,
      );
      tempAuth = FirebaseAuth.instanceFor(app: tempApp);
      final tempFirestore = FirebaseFirestore.instanceFor(app: tempApp);

      final credential = await tempAuth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: normalizedPassword,
      );

      createdUser = credential.user;
      if (createdUser == null) {
        throw Exception('Could not create the user account.');
      }

      final userModel = UserModel(
        uid: createdUser.uid,
        email: normalizedEmail,
        name: normalizedName,
        role: normalizedRole,
        phone: normalizedPhone,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      try {
        await tempFirestore
            .collection(AppConstants.usersCollection)
            .doc(createdUser.uid)
            .set(userModel.toMap());
      } catch (e) {
        await createdUser.delete();
        throw Exception('Failed to save user profile: $e');
      }

      return CreatedManagedUserAccount(
        uid: createdUser.uid,
        name: normalizedName,
        email: normalizedEmail,
        password: normalizedPassword,
        role: normalizedRole,
        phone: normalizedPhone,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapAuthError(e));
    } finally {
      try {
        await tempAuth?.signOut();
      } catch (_) {}
      try {
        await tempApp?.delete();
      } catch (_) {}
    }
  }

  Future<CreatedDeliveryPartnerAccount> createDeliveryPartner({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    final created = await createManagedUser(
      name: name,
      email: email,
      password: password,
      role: UserRoles.deliveryPartner,
      phone: phone,
    );

    return CreatedDeliveryPartnerAccount(
      uid: created.uid,
      name: created.name,
      email: created.email,
      password: created.password,
      phone: created.phone,
    );
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already in use.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled in Firebase Auth.';
      case 'network-request-failed':
        return 'Network error while creating the account.';
      default:
        return e.message ?? 'Could not create the account.';
    }
  }
}
