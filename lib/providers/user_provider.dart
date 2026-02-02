import 'package:flutter/material.dart';
import '../models/skilled_user_profile.dart';
import '../models/review_model.dart';
import '../services/firestore_service.dart';

class UserProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  SkilledUserProfile? _currentProfile;
  List<SkilledUserProfile> _verifiedUsers = [];
  List<ReviewModel> _reviews = [];
  bool _isLoading = false;
  String? _error;

  SkilledUserProfile? get currentProfile => _currentProfile;
  List<SkilledUserProfile> get verifiedUsers => _verifiedUsers;
  List<ReviewModel> get reviews => _reviews;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Load skilled user profile
  Future<void> loadProfile(String userId) async {
    try {
      _isLoading = true;
      notifyListeners();

      _currentProfile = await _firestoreService.getSkilledUserProfile(userId);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update skilled user profile
  Future<bool> updateProfile(SkilledUserProfile profile) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _firestoreService.updateSkilledUserProfile(profile);
      _currentProfile = profile;

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Load verified skilled users
  Future<void> loadVerifiedUsers({String? category, List<String>? skills}) async {
    try {
      _isLoading = true;
      notifyListeners();

      _verifiedUsers = await _firestoreService.getVerifiedSkilledUsers(
        category: category,
        skills: skills,
      );

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading verified users: $e');
      _error = e.toString();
      _verifiedUsers = []; // Set empty list on error
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load user reviews
  Future<void> loadReviews(String userId) async {
    try {
      _reviews = await _firestoreService.getUserReviews(userId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Add review
  Future<bool> addReview(ReviewModel review) async {
    try {
      await _firestoreService.createReview(review);
      await loadReviews(review.skilledUserId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
