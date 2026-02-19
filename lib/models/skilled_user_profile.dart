import 'package:cloud_firestore/cloud_firestore.dart';

class SkilledUserProfile {
  final String userId;
  final String? name;
  final String bio;
  final List<String> skills;
  final String? category; // Home Baking, Handicrafts, Content Creation, etc.
  final String? profilePicture; // Profile photo URL
  final String verificationStatus; // pending, approved, rejected
  final String visibility; // public, private
  final List<String> portfolioImages;
  final List<String> portfolioVideos;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? city;
  final String? state;
  final Map<String, dynamic>? verificationData; // Aadhaar info
  final double rating;
  final int reviewCount;
  final int projectCount;
  final bool isVerified;
  final DateTime? verifiedAt;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  SkilledUserProfile({
    required this.userId,
    this.name,
    required this.bio,
    required this.skills,
    this.category,
    this.profilePicture,
    this.verificationStatus = 'pending',
    this.visibility = 'private',
    this.portfolioImages = const [],
    this.portfolioVideos = const [],
    this.latitude,
    this.longitude,
    this.address,
    this.city,
    this.state,
    this.verificationData,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.projectCount = 0,
    this.isVerified = false,
    this.verifiedAt,
    this.rejectionReason,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SkilledUserProfile.fromMap(Map<String, dynamic> map, String userId) {
    final mappedUserId = (map['userId'] as String?)?.trim() ??
        (map['uid'] as String?)?.trim() ??
        (map['userUid'] as String?)?.trim() ??
        (map['ownerId'] as String?)?.trim() ??
        (map['createdBy'] as String?)?.trim() ??
        '';
    final effectiveUserId = mappedUserId.isNotEmpty ? mappedUserId : userId;

    List<String> asStringList(dynamic value) {
      if (value is List) {
        return value
            .map((item) => item?.toString().trim() ?? '')
            .where((item) => item.isNotEmpty)
            .toList();
      }
      return const <String>[];
    }

    return SkilledUserProfile(
      userId: effectiveUserId,
      name: map['name'],
      bio: map['bio'] ?? '',
      skills: asStringList(map['skills']),
      category: map['category'],
      profilePicture: map['profilePicture'],
      verificationStatus: map['verificationStatus'] ?? 'pending',
      visibility: map['visibility'] ?? 'private',
      portfolioImages: asStringList(map['portfolioImages']),
      portfolioVideos: asStringList(map['portfolioVideos']),
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      address: map['address'],
      city: map['city'],
      state: map['state'],
      verificationData: map['verificationData'],
      rating: (map['rating'] ?? 0.0).toDouble(),
      reviewCount: map['reviewCount'] ?? 0,
      projectCount: map['projectCount'] ?? 0,
      isVerified: map['isVerified'] ?? false,
      verifiedAt: (map['verifiedAt'] as Timestamp?)?.toDate(),
      rejectionReason: map['rejectionReason'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      if (name != null) 'name': name,
      'bio': bio,
      'skills': skills,
      'category': category,
      'profilePicture': profilePicture,
      'verificationStatus': verificationStatus,
      'visibility': visibility,
      'portfolioImages': portfolioImages,
      'portfolioVideos': portfolioVideos,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'city': city,
      'state': state,
      'verificationData': verificationData,
      'rating': rating,
      'reviewCount': reviewCount,
      'projectCount': projectCount,
      'isVerified': isVerified,
      'verifiedAt': verifiedAt != null ? Timestamp.fromDate(verifiedAt!) : null,
      'rejectionReason': rejectionReason,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  SkilledUserProfile copyWith({
    String? name,
    String? bio,
    List<String>? skills,
    String? category,
    String? profilePicture,
    String? verificationStatus,
    String? visibility,
    List<String>? portfolioImages,
    List<String>? portfolioVideos,
    double? latitude,
    double? longitude,
    String? address,
    String? city,
    String? state,
    Map<String, dynamic>? verificationData,
    double? rating,
    int? reviewCount,
    int? projectCount,
    bool? isVerified,
    DateTime? verifiedAt,
    String? rejectionReason,
  }) {
    return SkilledUserProfile(
      userId: userId,
      name: name ?? this.name,
      bio: bio ?? this.bio,
      skills: skills ?? this.skills,
      category: category ?? this.category,
      profilePicture: profilePicture ?? this.profilePicture,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      visibility: visibility ?? this.visibility,
      portfolioImages: portfolioImages ?? this.portfolioImages,
      portfolioVideos: portfolioVideos ?? this.portfolioVideos,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      verificationData: verificationData ?? this.verificationData,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      projectCount: projectCount ?? this.projectCount,
      isVerified: isVerified ?? this.isVerified,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
