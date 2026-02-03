import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/skilled_user_profile.dart';
import '../models/service_model.dart';
import '../models/product_model.dart';
import '../models/job_model.dart';
import '../models/review_model.dart';
import '../models/service_request_model.dart';
import '../models/appeal_model.dart';
import '../models/user_model.dart';
import '../utils/app_constants.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ===== Users =====

  Future<UserModel?> getUserById(String userId) async {
    final doc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .get();

    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!, userId);
  }

  // Update user profile photo in users collection
  Future<void> updateUserProfilePhoto(String userId, String photoUrl) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .update({
        'profilePhoto': photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('User profile photo updated successfully');
    } catch (e) {
      debugPrint('Error updating user profile photo: $e');
      rethrow;
    }
  }

  // Update user role
  Future<void> updateUserRole(String userId, String role) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .update({
        'role': role,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('User role updated to: $role');
    } catch (e) {
      debugPrint('Error updating user role: $e');
      rethrow;
    }
  }

  // ===== Skilled User Profile =====

  Future<void> updateSkilledUserProfile(SkilledUserProfile profile) async {
    await _firestore
        .collection(AppConstants.skilledUsersCollection)
        .doc(profile.userId)
        .set(profile.toMap(), SetOptions(merge: true));
  }

  Future<SkilledUserProfile?> getSkilledUserProfile(String userId) async {
    final doc = await _firestore
        .collection(AppConstants.skilledUsersCollection)
        .doc(userId)
        .get();

    if (!doc.exists) return null;
    return SkilledUserProfile.fromMap(doc.data()!, userId);
  }

  Stream<SkilledUserProfile?> skilledUserProfileStream(String userId) {
    return _firestore
        .collection(AppConstants.skilledUsersCollection)
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return SkilledUserProfile.fromMap(doc.data()!, userId);
    });
  }

  Future<List<SkilledUserProfile>> getVerifiedSkilledUsers({
    String? category,
    List<String>? skills,
    int limit = 20,
  }) async {
    Query query = _firestore
        .collection(AppConstants.skilledUsersCollection)
        .where('isVerified', isEqualTo: true)
        .where('visibility', isEqualTo: AppConstants.visibilityPublic);

    if (category != null) {
      query = query.where('category', isEqualTo: category);
    }

    query = query.limit(limit);

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => SkilledUserProfile.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  // ===== Services =====

  Future<String> createService(ServiceModel service) async {
    final docRef = await _firestore
        .collection('services')
        .add(service.toMap());
    return docRef.id;
  }

  Future<List<ServiceModel>> getUserServices(String userId) async {
    final snapshot = await _firestore
        .collection('services')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => ServiceModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  // ===== Products =====

  Future<String> createProduct(ProductModel product) async {
    final docRef = await _firestore
        .collection(AppConstants.productsCollection)
        .add(product.toMap());
    return docRef.id;
  }

  Future<List<ProductModel>> getUserProducts(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.productsCollection)
          .where('userId', isEqualTo: userId)
          .get();

      // Filter and sort in memory to avoid index requirement
      final products = snapshot.docs
          .map((doc) => ProductModel.fromMap(doc.data(), doc.id))
          .where((product) => product.isAvailable)
          .toList();
      
      // Sort by createdAt descending
      products.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return products;
    } catch (e) {
      debugPrint('Error getting user products: $e');
      return [];
    }
  }

  Future<List<ProductModel>> getAllProducts({int limit = 50}) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.productsCollection)
          .limit(limit)
          .get();

      // Filter and sort in memory to avoid index requirement
      final products = snapshot.docs
          .map((doc) => ProductModel.fromMap(doc.data(), doc.id))
          .where((product) => product.isAvailable)
          .toList();
      
      // Sort by createdAt descending
      products.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return products;
    } catch (e) {
      debugPrint('Error getting products: $e');
      return []; // Return empty list on error
    }
  }

  Future<void> deleteProduct(String productId) async {
    await _firestore
        .collection(AppConstants.productsCollection)
        .doc(productId)
        .delete();
  }

  Future<void> updateProduct(ProductModel product) async {
    await _firestore
        .collection(AppConstants.productsCollection)
        .doc(product.id)
        .update(product.toMap());
  }

  // ===== Jobs =====

  Future<String> createJob(JobModel job) async {
    final docRef = await _firestore
        .collection(AppConstants.jobsCollection)
        .add(job.toMap());
    return docRef.id;
  }

  Future<List<JobModel>> getOpenJobs({String? skill, int limit = 20}) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.jobsCollection)
          .limit(limit * 2) // Get more to filter
          .get();

      // Filter in memory to avoid index requirement
      var jobs = snapshot.docs
          .map((doc) => JobModel.fromMap(doc.data(), doc.id))
          .where((job) => job.status == AppConstants.jobStatusOpen)
          .toList();
      
      // Filter by skill if provided
      if (skill != null) {
        jobs = jobs.where((job) => job.requiredSkills.contains(skill)).toList();
      }
      
      // Sort by createdAt descending
      jobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return jobs.take(limit).toList();
    } catch (e) {
      debugPrint('Error getting jobs: $e');
      return []; // Return empty list on error
    }
  }

  Future<void> applyForJob(String jobId, String userId) async {
    await _firestore.collection(AppConstants.jobsCollection).doc(jobId).update({
      'applicants': FieldValue.arrayUnion([userId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteJob(String jobId) async {
    await _firestore
        .collection(AppConstants.jobsCollection)
        .doc(jobId)
        .delete();
  }

  Future<void> updateJob(JobModel job) async {
    await _firestore
        .collection(AppConstants.jobsCollection)
        .doc(job.id)
        .update(job.toMap());
  }

  // ===== Reviews =====

  Future<void> createReview(ReviewModel review) async {
    final batch = _firestore.batch();

    // Add review
    final reviewRef = _firestore
        .collection(AppConstants.reviewsCollection)
        .doc();
    batch.set(reviewRef, review.toMap());

    // Update skilled user rating
    final profileRef = _firestore
        .collection(AppConstants.skilledUsersCollection)
        .doc(review.skilledUserId);

    final profileDoc = await profileRef.get();
    if (profileDoc.exists) {
      final data = profileDoc.data()!;
      final currentRating = (data['rating'] ?? 0.0).toDouble();
      final currentCount = (data['reviewCount'] ?? 0);

      final newCount = currentCount + 1;
      final newRating = ((currentRating * currentCount) + review.rating) / newCount;

      batch.update(profileRef, {
        'rating': newRating,
        'reviewCount': newCount,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Future<List<ReviewModel>> getUserReviews(String userId, {int limit = 10}) async {
    final snapshot = await _firestore
        .collection(AppConstants.reviewsCollection)
        .where('skilledUserId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => ReviewModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  // ===== Service Requests =====

  Future<String> createServiceRequest(ServiceRequestModel request) async {
    final docRef = await _firestore
        .collection(AppConstants.requestsCollection)
        .add(request.toMap());
    return docRef.id;
  }

  Future<List<ServiceRequestModel>> getUserRequests(String userId) async {
    final snapshot = await _firestore
        .collection(AppConstants.requestsCollection)
        .where('skilledUserId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => ServiceRequestModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<void> updateRequestStatus(String requestId, String status, {String? rejectionReason}) async {
    await _firestore
        .collection(AppConstants.requestsCollection)
        .doc(requestId)
        .update({
      'status': status,
      'rejectionReason': rejectionReason,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ===== Appeals =====

  Future<String> createAppeal(AppealModel appeal) async {
    final docRef = await _firestore
        .collection(AppConstants.appealsCollection)
        .add(appeal.toMap());
    return docRef.id;
  }

  Future<List<AppealModel>> getPendingAppeals() async {
    final snapshot = await _firestore
        .collection(AppConstants.appealsCollection)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: false)
        .get();

    return snapshot.docs
        .map((doc) => AppealModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<void> resolveAppeal(
    String appealId,
    String status,
    String adminResponse,
    String adminId,
  ) async {
    await _firestore
        .collection(AppConstants.appealsCollection)
        .doc(appealId)
        .update({
      'status': status,
      'adminResponse': adminResponse,
      'resolvedBy': adminId,
      'resolvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ===== Admin - Verification =====

  Future<List<SkilledUserProfile>> getPendingVerifications() async {
    final snapshot = await _firestore
        .collection(AppConstants.skilledUsersCollection)
        .where('verificationStatus', isEqualTo: AppConstants.verificationPending)
        .orderBy('createdAt', descending: false)
        .get();

    return snapshot.docs
        .map((doc) => SkilledUserProfile.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<void> approveVerification(String userId) async {
    await _firestore
        .collection(AppConstants.skilledUsersCollection)
        .doc(userId)
        .update({
      'verificationStatus': AppConstants.verificationApproved,
      'visibility': AppConstants.visibilityPublic,
      'isVerified': true,
      'verifiedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> rejectVerification(String userId, String reason) async {
    await _firestore
        .collection(AppConstants.skilledUsersCollection)
        .doc(userId)
        .update({
      'verificationStatus': AppConstants.verificationRejected,
      'rejectionReason': reason,
      'isVerified': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
