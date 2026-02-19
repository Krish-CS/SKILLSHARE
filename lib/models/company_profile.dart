import 'package:cloud_firestore/cloud_firestore.dart';

/// Company Profile Model
/// Represents a company's profile with business information
/// Companies provide business details, not personal skills
class CompanyProfile {
  final String userId;
  final String companyName;
  final String description;
  final String industry; // e.g., "Technology", "Manufacturing", "Retail", "Healthcare"
  final String? website;
  final String? logoUrl;
  final String? employeeCount; // e.g., "1-10", "11-50", "51-200", "201-500", "500+"
  final String? headOfficeLocation;
  final String? city;
  final String? state;
  final double? latitude;
  final double? longitude;
  final List<String> branches; // Other office/branch locations
  final String? gstNumber; // Business registration number
  final Map<String, dynamic>? verificationData; // Business license, registration docs
  final bool isVerified; // Business verification status
  final String verificationStatus; // pending, approved, rejected
  final double rating; // Rating as an employer
  final int reviewCount; // Number of reviews from employees/candidates
  final DateTime? verifiedAt;
  /// Projects assigned by this company (request IDs or project metadata).
  final List<Map<String, dynamic>> assignedProjects;
  final DateTime createdAt;
  final DateTime updatedAt;

  CompanyProfile({
    required this.userId,
    required this.companyName,
    this.description = '',
    this.industry = '',
    this.website,
    this.logoUrl,
    this.employeeCount,
    this.headOfficeLocation,
    this.city,
    this.state,
    this.latitude,
    this.longitude,
    this.branches = const [],
    this.gstNumber,
    this.verificationData,
    this.isVerified = false,
    this.verificationStatus = 'pending',
    this.rating = 0.0,
    this.reviewCount = 0,
    this.verifiedAt,
    this.assignedProjects = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory CompanyProfile.fromMap(Map<String, dynamic> map, String userId) {
    return CompanyProfile(
      userId: userId,
      companyName: map['companyName'] ?? '',
      description: map['description'] ?? '',
      industry: map['industry'] ?? '',
      website: map['website'],
      logoUrl: map['logoUrl'],
      employeeCount: map['employeeCount'],
      headOfficeLocation: map['headOfficeLocation'],
      city: map['city'],
      state: map['state'],
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      branches: List<String>.from(map['branches'] ?? []),
      gstNumber: map['gstNumber'],
      verificationData: map['verificationData'],
      isVerified: map['isVerified'] ?? false,
      verificationStatus: map['verificationStatus'] ?? 'pending',
      rating: (map['rating'] ?? 0.0).toDouble(),
      reviewCount: map['reviewCount'] ?? 0,
      verifiedAt: (map['verifiedAt'] as Timestamp?)?.toDate(),
      assignedProjects: (map['assignedProjects'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e is Map ? e : {}))
          .toList(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyName': companyName,
      'description': description,
      'industry': industry,
      'website': website,
      'logoUrl': logoUrl,
      'employeeCount': employeeCount,
      'headOfficeLocation': headOfficeLocation,
      'city': city,
      'state': state,
      'latitude': latitude,
      'longitude': longitude,
      'branches': branches,
      'gstNumber': gstNumber,
      'verificationData': verificationData,
      'isVerified': isVerified,
      'verificationStatus': verificationStatus,
      'rating': rating,
      'reviewCount': reviewCount,
      'verifiedAt': verifiedAt != null ? Timestamp.fromDate(verifiedAt!) : null,
      'assignedProjects': assignedProjects,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  CompanyProfile copyWith({
    String? companyName,
    String? description,
    String? industry,
    String? website,
    String? logoUrl,
    String? employeeCount,
    String? headOfficeLocation,
    String? city,
    String? state,
    double? latitude,
    double? longitude,
    List<String>? branches,
    String? gstNumber,
    Map<String, dynamic>? verificationData,
    bool? isVerified,
    String? verificationStatus,
    double? rating,
    int? reviewCount,
    DateTime? verifiedAt,
    List<Map<String, dynamic>>? assignedProjects,
  }) {
    return CompanyProfile(
      userId: userId,
      companyName: companyName ?? this.companyName,
      description: description ?? this.description,
      industry: industry ?? this.industry,
      website: website ?? this.website,
      logoUrl: logoUrl ?? this.logoUrl,
      employeeCount: employeeCount ?? this.employeeCount,
      headOfficeLocation: headOfficeLocation ?? this.headOfficeLocation,
      city: city ?? this.city,
      state: state ?? this.state,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      branches: branches ?? this.branches,
      gstNumber: gstNumber ?? this.gstNumber,
      verificationData: verificationData ?? this.verificationData,
      isVerified: isVerified ?? this.isVerified,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      assignedProjects: assignedProjects ?? this.assignedProjects,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
