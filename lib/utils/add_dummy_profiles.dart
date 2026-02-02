import 'package:cloud_firestore/cloud_firestore.dart';

/// Add dummy skilled user profiles with Aadhaar verification
/// Run this once to populate the database with sample data
class DummyDataSeeder {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addDummyProfiles() async {
    print('Starting to add dummy profiles...');

    // Dummy Aadhaar numbers (fictional)
    final dummyProfiles = [
      {
        'userId': 'dummy_user_1',
        'bio': 'Professional baker with 5 years of experience. Specializing in custom cakes and pastries.',
        'skills': ['Cake Baking', 'Pastry Making', 'Custom Decorations'],
        'category': 'Home Baking',
        'profilePicture': 'https://res.cloudinary.com/demo/image/upload/sample.jpg',
        'verificationStatus': 'verified',
        'visibility': 'public',
        'portfolioImages': [
          'https://res.cloudinary.com/demo/image/upload/sample1.jpg',
          'https://res.cloudinary.com/demo/image/upload/sample2.jpg',
        ],
        'verificationData': {
          'aadhaarNumber': '123456789012',
          'maskedAadhaar': 'XXXX XXXX 9012',
          'verifiedAt': DateTime.now().toIso8601String(),
        },
        'rating': 4.5,
        'reviewCount': 23,
        'projectCount': 45,
        'isVerified': true,
        'verifiedAt': Timestamp.now(),
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      },
      {
        'userId': 'dummy_user_2',
        'bio': 'Handicraft artist creating unique home decor items. Expert in macramé and pottery.',
        'skills': ['Macramé', 'Pottery', 'Wall Hangings'],
        'category': 'Handicrafts',
        'profilePicture': 'https://res.cloudinary.com/demo/image/upload/sample.jpg',
        'verificationStatus': 'verified',
        'visibility': 'public',
        'portfolioImages': [
          'https://res.cloudinary.com/demo/image/upload/sample3.jpg',
        ],
        'verificationData': {
          'aadhaarNumber': '234567890123',
          'maskedAadhaar': 'XXXX XXXX 0123',
          'verifiedAt': DateTime.now().toIso8601String(),
        },
        'rating': 4.8,
        'reviewCount': 45,
        'projectCount': 67,
        'isVerified': true,
        'verifiedAt': Timestamp.now(),
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      },
      {
        'userId': 'dummy_user_3',
        'bio': 'Content creator specializing in YouTube videos and social media marketing.',
        'skills': ['Video Editing', 'Social Media', 'Photography'],
        'category': 'Content Creation',
        'profilePicture': 'https://res.cloudinary.com/demo/image/upload/sample.jpg',
        'verificationStatus': 'verified',
        'visibility': 'public',
        'portfolioImages': [],
        'portfolioVideos': [],
        'verificationData': {
          'aadhaarNumber': '345678901234',
          'maskedAadhaar': 'XXXX XXXX 1234',
          'verifiedAt': DateTime.now().toIso8601String(),
        },
        'rating': 4.2,
        'reviewCount': 12,
        'projectCount': 28,
        'isVerified': true,
        'verifiedAt': Timestamp.now(),
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      },
      {
        'userId': 'dummy_user_4',
        'bio': 'Professional carpenter with expertise in custom furniture and home renovations.',
        'skills': ['Furniture Making', 'Wood Carving', 'Home Renovation'],
        'category': 'Carpentry',
        'profilePicture': 'https://res.cloudinary.com/demo/image/upload/sample.jpg',
        'verificationStatus': 'verified',
        'visibility': 'public',
        'portfolioImages': [
          'https://res.cloudinary.com/demo/image/upload/sample4.jpg',
          'https://res.cloudinary.com/demo/image/upload/sample5.jpg',
        ],
        'verificationData': {
          'aadhaarNumber': '456789012345',
          'maskedAadhaar': 'XXXX XXXX 2345',
          'verifiedAt': DateTime.now().toIso8601String(),
        },
        'rating': 4.9,
        'reviewCount': 67,
        'projectCount': 89,
        'isVerified': true,
        'verifiedAt': Timestamp.now(),
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      },
      {
        'userId': 'dummy_user_5',
        'bio': 'Expert tailor offering custom stitching and alterations. Specializing in traditional and modern wear.',
        'skills': ['Custom Stitching', 'Alterations', 'Design Consultation'],
        'category': 'Tailoring',
        'profilePicture': 'https://res.cloudinary.com/demo/image/upload/sample.jpg',
        'verificationStatus': 'verified',
        'visibility': 'public',
        'portfolioImages': [],
        'portfolioVideos': [],
        'verificationData': {
          'aadhaarNumber': '567890123456',
          'maskedAadhaar': 'XXXX XXXX 3456',
          'verifiedAt': DateTime.now().toIso8601String(),
        },
        'rating': 4.6,
        'reviewCount': 34,
        'projectCount': 56,
        'isVerified': true,
        'verifiedAt': Timestamp.now(),
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      },
    ];

    try {
      for (var profile in dummyProfiles) {
        await _firestore
            .collection('skilled_users')
            .doc(profile['userId'] as String)
            .set(profile);
        print('Added profile: ${profile['userId']}');
      }
      print('✅ Successfully added ${dummyProfiles.length} dummy profiles!');
    } catch (e) {
      print('❌ Error adding profiles: $e');
    }
  }

  /// Call this method from your app to seed the database
  static Future<void> seedDatabase() async {
    final seeder = DummyDataSeeder();
    await seeder.addDummyProfiles();
  }
}
