import 'package:cloud_firestore/cloud_firestore.dart';

/// Customer Profile Model
/// Represents a customer's profile with their interests and preferences
/// Customers specify WHAT THEY NEED, not what skills they have
class CustomerProfile {
  final String userId;
  final String bio;
  final List<String> interests; // What they're interested in (e.g., "DIY projects", "Home improvement")
  final List<String> lookingFor; // Service categories they need (e.g., "Carpenter", "Baker", "Electrician")
  final String? profilePicture;
  final String? location;
  final String? city;
  final String? state;
  final double? latitude;
  final double? longitude;
  final List<String> preferredCategories; // Skill categories they frequently search for
  final Map<String, dynamic>? preferences; // Additional preferences (budget range, distance, etc.)
  final DateTime createdAt;
  final DateTime updatedAt;

  CustomerProfile({
    required this.userId,
    this.bio = '',
    this.interests = const [],
    this.lookingFor = const [],
    this.profilePicture,
    this.location,
    this.city,
    this.state,
    this.latitude,
    this.longitude,
    this.preferredCategories = const [],
    this.preferences,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CustomerProfile.fromMap(Map<String, dynamic> map, String userId) {
    return CustomerProfile(
      userId: userId,
      bio: map['bio'] ?? '',
      interests: List<String>.from(map['interests'] ?? []),
      lookingFor: List<String>.from(map['lookingFor'] ?? []),
      profilePicture: map['profilePicture'],
      location: map['location'],
      city: map['city'],
      state: map['state'],
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      preferredCategories: List<String>.from(map['preferredCategories'] ?? []),
      preferences: map['preferences'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bio': bio,
      'interests': interests,
      'lookingFor': lookingFor,
      'profilePicture': profilePicture,
      'location': location,
      'city': city,
      'state': state,
      'latitude': latitude,
      'longitude': longitude,
      'preferredCategories': preferredCategories,
      'preferences': preferences,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  CustomerProfile copyWith({
    String? bio,
    List<String>? interests,
    List<String>? lookingFor,
    String? profilePicture,
    String? location,
    String? city,
    String? state,
    double? latitude,
    double? longitude,
    List<String>? preferredCategories,
    Map<String, dynamic>? preferences,
  }) {
    return CustomerProfile(
      userId: userId,
      bio: bio ?? this.bio,
      interests: interests ?? this.interests,
      lookingFor: lookingFor ?? this.lookingFor,
      profilePicture: profilePicture ?? this.profilePicture,
      location: location ?? this.location,
      city: city ?? this.city,
      state: state ?? this.state,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      preferredCategories: preferredCategories ?? this.preferredCategories,
      preferences: preferences ?? this.preferences,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
