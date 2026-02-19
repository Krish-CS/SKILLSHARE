import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/portfolio_model.dart';
import '../utils/app_constants.dart';

/// Portfolio Service
/// Handles all portfolio-related operations for skilled persons
class PortfolioService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection references
  final String _portfolioCollection = 'portfolio';
  final String _companyProfilesCollection = 'company_profiles';
  final String _skilledUsersCollection = AppConstants.skilledUsersCollection;

  List<String> _asStringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const <String>[];
  }

  DateTime _asDate(dynamic value, {DateTime? fallback}) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return fallback ?? DateTime.now();
  }

  List<PortfolioItem> _mapAndSortPortfolioItems(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final items = snapshot.docs
        .map((doc) => PortfolioItem.fromMap(doc.data(), doc.id))
        .toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<Map<String, dynamic>?> _getLegacySkilledProfileData(
      String userId) async {
    final skilledCollection = _firestore.collection(_skilledUsersCollection);

    final canonicalDoc = await skilledCollection.doc(userId).get();
    if (canonicalDoc.exists && canonicalDoc.data() != null) {
      return Map<String, dynamic>.from(canonicalDoc.data()!);
    }

    final legacySnapshot = await skilledCollection
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();
    if (legacySnapshot.docs.isNotEmpty) {
      return Map<String, dynamic>.from(legacySnapshot.docs.first.data());
    }

    return null;
  }

  List<PortfolioItem> _buildLegacyPortfolioItems(
    String userId,
    Map<String, dynamic> profileData,
  ) {
    final images = _asStringList(profileData['portfolioImages']);
    final videos = _asStringList(profileData['portfolioVideos']);
    if (images.isEmpty && videos.isEmpty) return const <PortfolioItem>[];

    final category = (profileData['category'] as String?)?.trim();
    final normalizedCategory =
        category == null || category.isEmpty ? 'Other' : category;
    final bio = (profileData['bio'] as String?)?.trim();
    final normalizedBio = (bio == null || bio.isEmpty)
        ? 'Portfolio work uploaded from profile setup'
        : bio;
    final skills = _asStringList(profileData['skills']);
    final createdAt = _asDate(profileData['createdAt']);
    final updatedAt = _asDate(profileData['updatedAt'], fallback: createdAt);

    final items = <PortfolioItem>[];
    if (images.isNotEmpty) {
      for (var index = 0; index < images.length; index++) {
        items.add(
          PortfolioItem(
            id: 'legacy_local_image_${index + 1}',
            userId: userId,
            title: 'Work Sample ${index + 1}',
            description: normalizedBio,
            images: [images[index]],
            videos: index == 0 ? videos : const <String>[],
            category: normalizedCategory,
            tags: skills,
            likes: 0,
            views: 0,
            isPublic: true,
            createdAt: createdAt.add(Duration(seconds: index)),
            updatedAt: updatedAt,
          ),
        );
      }
    } else {
      items.add(
        PortfolioItem(
          id: 'legacy_local_video_1',
          userId: userId,
          title: 'Work Sample Video',
          description: normalizedBio,
          images: const <String>[],
          videos: videos,
          category: normalizedCategory,
          tags: skills,
          likes: 0,
          views: 0,
          isPublic: true,
          createdAt: createdAt,
          updatedAt: updatedAt,
        ),
      );
    }

    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<List<PortfolioItem>> _loadLegacyPortfolioItems(String userId) async {
    final profileData = await _getLegacySkilledProfileData(userId);
    if (profileData == null) return const <PortfolioItem>[];
    return _buildLegacyPortfolioItems(userId, profileData);
  }

  Future<void> _migrateLegacyPortfolioItems(
    String userId,
    List<PortfolioItem> legacyItems,
  ) async {
    if (legacyItems.isEmpty) return;

    final batch = _firestore.batch();
    for (var index = 0; index < legacyItems.length; index++) {
      final item = legacyItems[index];
      final docRef = _firestore
          .collection(_portfolioCollection)
          .doc('legacy_${userId}_${index + 1}');
      batch.set(
        docRef,
        {
          ...item.toMap(),
          'userId': userId,
          'legacyMigrated': true,
          'legacySource': 'skilled_profile',
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  // ==================== PORTFOLIO OPERATIONS ====================

  /// Add a new portfolio item
  Future<String> addPortfolioItem(PortfolioItem item) async {
    try {
      final docRef =
          await _firestore.collection(_portfolioCollection).add(item.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add portfolio item: $e');
    }
  }

  /// Create a new portfolio item (alias for addPortfolioItem)
  Future<void> createPortfolioItem(PortfolioItem item) async {
    try {
      final Map<String, dynamic> itemMap = item.toMap();
      if (item.id.isEmpty) {
        // Create new document
        await _firestore.collection(_portfolioCollection).add(itemMap);
      } else {
        // Update existing document
        await _firestore
            .collection(_portfolioCollection)
            .doc(item.id)
            .set(itemMap);
      }
    } catch (e) {
      throw Exception('Failed to create portfolio item: $e');
    }
  }

  /// Update an existing portfolio item
  Future<void> updatePortfolioItem(PortfolioItem item) async {
    try {
      await _firestore
          .collection(_portfolioCollection)
          .doc(item.id)
          .update(item.toMap());
    } catch (e) {
      throw Exception('Failed to update portfolio item: $e');
    }
  }

  /// Delete a portfolio item
  Future<void> deletePortfolioItem(String itemId) async {
    try {
      await _firestore.collection(_portfolioCollection).doc(itemId).delete();
    } catch (e) {
      throw Exception('Failed to delete portfolio item: $e');
    }
  }

  /// Get all portfolio items for a specific user
  Future<List<PortfolioItem>> getUserPortfolio(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_portfolioCollection)
          .where('userId', isEqualTo: userId)
          .get();

      final items = _mapAndSortPortfolioItems(snapshot);
      if (items.isNotEmpty) return items;

      // Backward compatibility for existing users whose portfolio was saved only
      // inside /skilled_users/{uid}.portfolioImages.
      final legacyItems = await _loadLegacyPortfolioItems(userId);
      if (legacyItems.isEmpty) return const <PortfolioItem>[];

      try {
        await _migrateLegacyPortfolioItems(userId, legacyItems);
        final migratedSnapshot = await _firestore
            .collection(_portfolioCollection)
            .where('userId', isEqualTo: userId)
            .get();
        final migratedItems = _mapAndSortPortfolioItems(migratedSnapshot);
        if (migratedItems.isNotEmpty) {
          return migratedItems;
        }
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied' || e.code == 'failed-precondition') {
          return legacyItems;
        }
        rethrow;
      }

      return legacyItems;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied' || e.code == 'failed-precondition') {
        final legacyItems = await _loadLegacyPortfolioItems(userId);
        if (legacyItems.isNotEmpty) {
          return legacyItems;
        }
      }
      throw Exception('Failed to get user portfolio: ${e.message ?? e.code}');
    } catch (e) {
      throw Exception('Failed to get user portfolio: $e');
    }
  }

  /// Get all public portfolio items (for browsing by customers/companies)
  Future<List<PortfolioItem>> getPublicPortfolioItems({
    String? category,
    List<String>? tags,
    int limit = 50,
  }) async {
    try {
      Query query = _firestore
          .collection(_portfolioCollection)
          .where('isPublic', isEqualTo: true);

      if (category != null && category.isNotEmpty) {
        query = query.where('category', isEqualTo: category);
      }

      if (tags != null && tags.isNotEmpty) {
        query = query.where('tags', arrayContainsAny: tags);
      }

      // Remove orderBy to avoid composite index requirement
      final snapshot = await query.get();

      // Convert to list and sort on client side
      final items = snapshot.docs
          .map((doc) =>
              PortfolioItem.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      // Sort by createdAt descending (newest first)
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Apply limit on client side
      return items.take(limit).toList();
    } catch (e) {
      throw Exception('Failed to get public portfolio items: $e');
    }
  }

  /// Get a single portfolio item by ID
  Future<PortfolioItem?> getPortfolioItem(String itemId) async {
    try {
      final doc =
          await _firestore.collection(_portfolioCollection).doc(itemId).get();
      if (doc.exists) {
        return PortfolioItem.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get portfolio item: $e');
    }
  }

  /// Increment view count for a portfolio item
  Future<void> incrementPortfolioViews(String itemId) async {
    try {
      await _firestore.collection(_portfolioCollection).doc(itemId).update({
        'views': FieldValue.increment(1),
      });
    } catch (e) {
      // Silently fail for view count
      debugPrint('Failed to increment views: $e');
    }
  }

  /// Toggle like on a portfolio item
  Future<void> togglePortfolioLike(String itemId, bool increment) async {
    try {
      await _firestore.collection(_portfolioCollection).doc(itemId).update({
        'likes': FieldValue.increment(increment ? 1 : -1),
      });
    } catch (e) {
      throw Exception('Failed to toggle like: $e');
    }
  }

  /// Search portfolio items by query
  Stream<List<PortfolioItem>> searchPortfolioItems(String searchQuery) {
    return _firestore
        .collection(_portfolioCollection)
        .where('isPublic', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs
          .map((doc) => PortfolioItem.fromMap(doc.data(), doc.id))
          .toList();

      // Filter by search query
      if (searchQuery.isEmpty) return items;

      final query = searchQuery.toLowerCase();
      return items.where((item) {
        return item.title.toLowerCase().contains(query) ||
            item.description.toLowerCase().contains(query) ||
            item.category.toLowerCase().contains(query) ||
            item.tags.any((tag) => tag.toLowerCase().contains(query));
      }).toList();
    });
  }

  // ==================== COMPANY PROFILE OPERATIONS ====================

  /// Create or update company profile
  Future<void> saveCompanyProfile(CompanyProfile profile) async {
    try {
      await _firestore
          .collection(_companyProfilesCollection)
          .doc(profile.userId)
          .set(profile.toMap(), SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to save company profile: $e');
    }
  }

  /// Get company profile
  Future<CompanyProfile?> getCompanyProfile(String userId) async {
    try {
      final doc = await _firestore
          .collection(_companyProfilesCollection)
          .doc(userId)
          .get();

      if (doc.exists) {
        return CompanyProfile.fromMap(doc.data()!, userId);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get company profile: $e');
    }
  }

  /// Stream company profile
  Stream<CompanyProfile?> streamCompanyProfile(String userId) {
    return _firestore
        .collection(_companyProfilesCollection)
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return CompanyProfile.fromMap(doc.data()!, userId);
      }
      return null;
    });
  }

  // ==================== STATISTICS ====================

  /// Get portfolio statistics for a skilled person
  Future<Map<String, dynamic>> getPortfolioStats(String userId) async {
    try {
      final portfolio = await getUserPortfolio(userId);

      int totalViews = 0;
      int totalLikes = 0;

      for (var item in portfolio) {
        totalViews += item.views;
        totalLikes += item.likes;
      }

      return {
        'totalItems': portfolio.length,
        'totalViews': totalViews,
        'totalLikes': totalLikes,
        'averageViews': portfolio.isEmpty ? 0 : totalViews / portfolio.length,
        'averageLikes': portfolio.isEmpty ? 0 : totalLikes / portfolio.length,
      };
    } catch (e) {
      throw Exception('Failed to get portfolio stats: $e');
    }
  }
}
