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

class DeliveryPartnerAdminService {
  Future<CreatedDeliveryPartnerAccount> createDeliveryPartner({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    final normalizedName = name.trim();
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPassword = password.trim();
    final normalizedPhone =
        phone != null && phone.trim().isNotEmpty ? phone.trim() : null;

    if (normalizedName.isEmpty) {
      throw Exception('Delivery partner name is required.');
    }
    if (normalizedEmail.isEmpty) {
      throw Exception('Delivery partner email is required.');
    }
    if (normalizedPassword.length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }

    final tempAppName =
        'delivery-partner-admin-${DateTime.now().microsecondsSinceEpoch}';
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
        throw Exception('Could not create the delivery partner account.');
      }

      final userModel = UserModel(
        uid: createdUser.uid,
        email: normalizedEmail,
        name: normalizedName,
        role: UserRoles.deliveryPartner,
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
        throw Exception('Failed to save delivery partner profile: $e');
      }

      return CreatedDeliveryPartnerAccount(
        uid: createdUser.uid,
        name: normalizedName,
        email: normalizedEmail,
        password: normalizedPassword,
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
        return e.message ?? 'Could not create the delivery partner account.';
    }
  }
}
