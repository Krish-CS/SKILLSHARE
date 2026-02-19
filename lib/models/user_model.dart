import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/user_roles.dart';

class UserModel {
  final String uid;
  final String email;
  final String name;
  final String role; // skilled_user, customer, company, admin
  final String? phone;
  final String? profilePhoto;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.phone,
    this.profilePhoto,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    final rawRole = (map['role'] as String?) ?? '';
    final normalizedRole = UserRoles.normalizeRole(rawRole) ?? rawRole;

    return UserModel(
      uid: uid,
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      role: normalizedRole,
      phone: map['phone'],
      profilePhoto: map['profilePhoto'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'role': role,
      'phone': phone,
      'profilePhoto': profilePhoto,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
    };
  }

  UserModel copyWith({
    String? name,
    String? phone,
    String? profilePhoto,
    bool? isActive,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      name: name ?? this.name,
      role: role,
      phone: phone ?? this.phone,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      isActive: isActive ?? this.isActive,
    );
  }
}
