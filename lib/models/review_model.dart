import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String id;
  final String skilledUserId;
  final String reviewerId;
  final String reviewerName;
  final String? reviewerPhoto;
  final double rating;
  final String comment;
  final List<String> images;
  final DateTime createdAt;
  /// Role of the reviewer: 'company', 'customer', 'skilled_person', etc.
  final String? reviewerRole;
  /// Company display name — shown on highlighted endorsement badge.
  final String? reviewerCompanyName;

  ReviewModel({
    required this.id,
    required this.skilledUserId,
    required this.reviewerId,
    required this.reviewerName,
    this.reviewerPhoto,
    required this.rating,
    required this.comment,
    this.images = const [],
    required this.createdAt,
    this.reviewerRole,
    this.reviewerCompanyName,
  });

  bool get isCompanyReview => reviewerRole == 'company';

  factory ReviewModel.fromMap(Map<String, dynamic> map, String id) {
    return ReviewModel(
      id: id,
      skilledUserId: map['skilledUserId'] ?? '',
      reviewerId: map['reviewerId'] ?? '',
      reviewerName: map['reviewerName'] ?? '',
      reviewerPhoto: map['reviewerPhoto'],
      rating: (map['rating'] ?? 0.0).toDouble(),
      comment: map['comment'] ?? '',
      images: List<String>.from(map['images'] ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewerRole: map['reviewerRole'],
      reviewerCompanyName: map['reviewerCompanyName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'skilledUserId': skilledUserId,
      'reviewerId': reviewerId,
      'reviewerName': reviewerName,
      'reviewerPhoto': reviewerPhoto,
      'rating': rating,
      'comment': comment,
      'images': images,
      'createdAt': Timestamp.fromDate(createdAt),
      if (reviewerRole != null) 'reviewerRole': reviewerRole,
      if (reviewerCompanyName != null) 'reviewerCompanyName': reviewerCompanyName,
    };
  }
}
