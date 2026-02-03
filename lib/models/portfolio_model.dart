import 'package:cloud_firestore/cloud_firestore.dart';

/// Portfolio Item Model
/// Represents a single work sample/showcase item uploaded by a skilled person
/// This can be a photo of completed work, a project showcase, etc.
class PortfolioItem {
  final String id;
  final String userId; // The skilled person who uploaded it
  final String title;
  final String description;
  final List<String> images; // URLs of work photos
  final List<String> videos; // URLs of work videos (optional)
  final String category; // Type of work (e.g., "Baking", "Handicraft", "Content Creation")
  final List<String> tags; // Skills/tags associated with this work
  final int likes;
  final int views;
  final bool isPublic;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Project details (optional)
  final String? clientName; // If it was a client project
  final DateTime? completionDate;
  final double? projectCost;
  final int? durationInDays;

  PortfolioItem({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.images,
    this.videos = const [],
    required this.category,
    this.tags = const [],
    this.likes = 0,
    this.views = 0,
    this.isPublic = true,
    required this.createdAt,
    required this.updatedAt,
    this.clientName,
    this.completionDate,
    this.projectCost,
    this.durationInDays,
  });

  factory PortfolioItem.fromMap(Map<String, dynamic> map, String id) {
    return PortfolioItem(
      id: id,
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      images: List<String>.from(map['images'] ?? []),
      videos: List<String>.from(map['videos'] ?? []),
      category: map['category'] ?? '',
      tags: List<String>.from(map['tags'] ?? []),
      likes: map['likes'] ?? 0,
      views: map['views'] ?? 0,
      isPublic: map['isPublic'] ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      clientName: map['clientName'],
      completionDate: (map['completionDate'] as Timestamp?)?.toDate(),
      projectCost: map['projectCost']?.toDouble(),
      durationInDays: map['durationInDays'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'images': images,
      'videos': videos,
      'category': category,
      'tags': tags,
      'likes': likes,
      'views': views,
      'isPublic': isPublic,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'clientName': clientName,
      'completionDate': completionDate != null ? Timestamp.fromDate(completionDate!) : null,
      'projectCost': projectCost,
      'durationInDays': durationInDays,
    };
  }

  PortfolioItem copyWith({
    String? title,
    String? description,
    List<String>? images,
    List<String>? videos,
    String? category,
    List<String>? tags,
    int? likes,
    int? views,
    bool? isPublic,
    String? clientName,
    DateTime? completionDate,
    double? projectCost,
    int? durationInDays,
  }) {
    return PortfolioItem(
      id: id,
      userId: userId,
      title: title ?? this.title,
      description: description ?? this.description,
      images: images ?? this.images,
      videos: videos ?? this.videos,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      likes: likes ?? this.likes,
      views: views ?? this.views,
      isPublic: isPublic ?? this.isPublic,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      clientName: clientName ?? this.clientName,
      completionDate: completionDate ?? this.completionDate,
      projectCost: projectCost ?? this.projectCost,
      durationInDays: durationInDays ?? this.durationInDays,
    );
  }
}

/// Company Profile Model
/// Stores additional information specific to company accounts
class CompanyProfile {
  final String userId;
  final String companyName;
  final String? industry;
  final String? website;
  final String? description;
  final String? companySize; // e.g., "1-10", "11-50", "51-200", etc.
  final String? registrationNumber;
  final String? taxId;
  final String? address;
  final String? city;
  final String? state;
  final String? country;
  final String? logoUrl;
  final List<String> certificateUrls; // Business certificates, licenses
  final bool isVerified;
  final String verificationStatus; // pending, approved, rejected
  final DateTime? verifiedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  CompanyProfile({
    required this.userId,
    required this.companyName,
    this.industry,
    this.website,
    this.description,
    this.companySize,
    this.registrationNumber,
    this.taxId,
    this.address,
    this.city,
    this.state,
    this.country,
    this.logoUrl,
    this.certificateUrls = const [],
    this.isVerified = false,
    this.verificationStatus = 'pending',
    this.verifiedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CompanyProfile.fromMap(Map<String, dynamic> map, String userId) {
    return CompanyProfile(
      userId: userId,
      companyName: map['companyName'] ?? '',
      industry: map['industry'],
      website: map['website'],
      description: map['description'],
      companySize: map['companySize'],
      registrationNumber: map['registrationNumber'],
      taxId: map['taxId'],
      address: map['address'],
      city: map['city'],
      state: map['state'],
      country: map['country'],
      logoUrl: map['logoUrl'],
      certificateUrls: List<String>.from(map['certificateUrls'] ?? []),
      isVerified: map['isVerified'] ?? false,
      verificationStatus: map['verificationStatus'] ?? 'pending',
      verifiedAt: (map['verifiedAt'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyName': companyName,
      'industry': industry,
      'website': website,
      'description': description,
      'companySize': companySize,
      'registrationNumber': registrationNumber,
      'taxId': taxId,
      'address': address,
      'city': city,
      'state': state,
      'country': country,
      'logoUrl': logoUrl,
      'certificateUrls': certificateUrls,
      'isVerified': isVerified,
      'verificationStatus': verificationStatus,
      'verifiedAt': verifiedAt != null ? Timestamp.fromDate(verifiedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
