import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/portfolio_model.dart';

/// Portfolio Service
/// Handles all portfolio-related operations for skilled persons
class PortfolioService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Collection references
  final String _portfolioCollection = 'portfolio';
  final String _companyProfilesCollection = 'company_profiles';

  // ==================== PORTFOLIO OPERATIONS ====================
  
  /// Add a new portfolio item
  Future<String> addPortfolioItem(PortfolioItem item) async {
    try {
      final docRef = await _firestore.collection(_portfolioCollection).add(item.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add portfolio item: $e');
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
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => PortfolioItem.fromMap(doc.data(), doc.id))
          .toList();
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

      query = query.orderBy('createdAt', descending: true).limit(limit);

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => PortfolioItem.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to get public portfolio items: $e');
    }
  }

  /// Get a single portfolio item by ID
  Future<PortfolioItem?> getPortfolioItem(String itemId) async {
    try {
      final doc = await _firestore.collection(_portfolioCollection).doc(itemId).get();
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
      print('Failed to increment views: $e');
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
