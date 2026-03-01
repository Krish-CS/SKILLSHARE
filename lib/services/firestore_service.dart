import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/skilled_user_profile.dart';
import '../models/customer_profile.dart';
import '../models/company_profile.dart';
import '../models/service_model.dart';
import '../models/product_model.dart';
import '../models/cart_item_model.dart';
import '../models/order_model.dart';
import '../models/job_model.dart';
import '../models/review_model.dart';
import '../models/service_request_model.dart';
import '../models/appeal_model.dart';
import '../models/user_model.dart';
import '../utils/app_constants.dart';
import '../utils/user_roles.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _aadhaarRegistryCollection =
      AppConstants.aadhaarRegistryCollection;
  static const String _aadhaarChangeRequestType = 'aadhaar_change_request';
  static const String _chatWorkRequestType = 'chat_work_request';
  static const String _legacyDirectHireServiceId = 'direct_hire';

  String _normalizeAadhaar(String aadhaar) =>
      aadhaar.replaceAll(' ', '').trim();

  String _maskAadhaar(String aadhaar) {
    final clean = _normalizeAadhaar(aadhaar);
    if (clean.length < 4) return clean;
    return 'XXXX XXXX ${clean.substring(clean.length - 4)}';
  }

  bool _isSkilledUserDataAadhaarVerified(Map<String, dynamic> data) {
    final verificationData = data['verificationData'];
    final verificationMap = verificationData is Map
        ? Map<String, dynamic>.from(verificationData)
        : <String, dynamic>{};

    final aadhaarNumber =
        ((verificationMap['aadhaarNumber'] as String?)?.trim() ??
                (verificationMap['aadharNumber'] as String?)?.trim() ??
                (verificationMap['adharNumber'] as String?)?.trim() ??
                (data['aadhaarNumber'] as String?)?.trim() ??
                (data['aadharNumber'] as String?)?.trim() ??
                (data['adharNumber'] as String?)?.trim() ??
                '')
            .replaceAll(' ', '');
    final aadhaarLocked = verificationMap['aadhaarLocked'] == true ||
        verificationMap['aadharLocked'] == true ||
        aadhaarNumber.length == 12;
    final status =
        ((data['verificationStatus'] as String?) ?? '').toLowerCase().trim();
    final statusApproved = status == AppConstants.verificationApproved ||
        status == 'verified' ||
        status == 'approved';
    final visibility =
        ((data['visibility'] as String?) ?? '').toLowerCase().trim();

    return (data['isVerified'] == true || statusApproved) &&
        (visibility == AppConstants.visibilityPublic) &&
        statusApproved &&
        aadhaarLocked &&
        aadhaarNumber.length == 12;
  }

  bool _isSkilledProfileAadhaarVerified(SkilledUserProfile profile) {
    final verificationData = profile.verificationData ?? <String, dynamic>{};
    final aadhaarNumber =
        ((verificationData['aadhaarNumber'] as String?)?.trim() ??
                (verificationData['aadharNumber'] as String?)?.trim() ??
                (verificationData['adharNumber'] as String?)?.trim() ??
                '')
            .replaceAll(' ', '');
    final aadhaarLocked = verificationData['aadhaarLocked'] == true ||
        verificationData['aadharLocked'] == true ||
        aadhaarNumber.length == 12;
    final status = profile.verificationStatus.toLowerCase().trim();
    final statusApproved = status == AppConstants.verificationApproved ||
        status == 'verified' ||
        status == 'approved';

    return profile.isVerified &&
        profile.visibility.toLowerCase().trim() ==
            AppConstants.visibilityPublic &&
        statusApproved &&
        aadhaarLocked &&
        aadhaarNumber.length == 12;
  }

  bool _isCompanyProfileVerified(CompanyProfile? profile) {
    if (profile == null) return false;
    final status = profile.verificationStatus.toLowerCase().trim();
    final statusApproved =
        status == AppConstants.verificationApproved || status == 'verified';
    return profile.isVerified || statusApproved;
  }

  Future<bool> canCompanyHireSkilledPersons(String companyUserId) async {
    final profile = await getCompanyProfile(companyUserId);
    return _isCompanyProfileVerified(profile);
  }

  Stream<bool> companyHireEligibilityStream(String companyUserId) {
    return companyProfileStream(companyUserId).map(_isCompanyProfileVerified);
  }

  // ===== Users =====

  Future<UserModel?> getUserById(String userId) async {
    final doc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .get();

    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!, userId);
  }

  bool _isWorkRequestLike(ServiceRequestModel request) {
    final normalizedType = request.type.toLowerCase().trim();
    final normalizedServiceId = request.serviceId.toLowerCase().trim();
    return normalizedType == _chatWorkRequestType ||
        normalizedServiceId == _legacyDirectHireServiceId;
  }

  Map<String, dynamic> _participantDetailsFromUser(UserModel? user) {
    final safeName = (user?.name ?? '').trim();
    final safePhoto = (user?.profilePhoto ?? '').trim();
    final safeRole = (user?.role ?? '').trim();
    return {
      'name': safeName.isEmpty ? 'User' : safeName,
      'photo': safePhoto,
      if (safeRole.isNotEmpty) 'role': safeRole,
    };
  }

  Future<String> _ensureDirectChatBetweenUsers({
    required UserModel? userA,
    required UserModel? userB,
    required String userAId,
    required String userBId,
  }) async {
    final participants = [userAId, userBId]..sort();
    final chatId = '${participants[0]}__${participants[1]}';
    final chatRef =
        _firestore.collection(AppConstants.chatsCollection).doc(chatId);
    final chatData = {
      'participants': participants,
      'participantDetails': {
        userAId: _participantDetailsFromUser(userA),
        userBId: _participantDetailsFromUser(userB),
      },
      'lastMessage': '',
      'lastMessageType': 'text',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadCount': {
        for (final id in participants) id: 0,
      },
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await chatRef.set(chatData, SetOptions(merge: true));
      return chatId;
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      final fallbackRef = await _firestore
          .collection(AppConstants.chatsCollection)
          .add(chatData);
      return fallbackRef.id;
    }
  }

  Future<String> _ensureWorkProjectChat({
    required String requestId,
    required String customerId,
    required String skilledUserId,
    String? originChatId,
    String? requestTitle,
  }) async {
    final customer = await getUserById(customerId);
    final skilled = await getUserById(skilledUserId);
    final participants = [customerId, skilledUserId]..sort();
    final workChatId = 'work_$requestId';
    final workChatRef =
        _firestore.collection(AppConstants.chatsCollection).doc(workChatId);

    await workChatRef.set({
      'participants': participants,
      'participantDetails': {
        customerId: _participantDetailsFromUser(customer),
        skilledUserId: _participantDetailsFromUser(skilled),
      },
      'lastMessage': '',
      'lastMessageType': 'text',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadCount': {
        for (final id in participants) id: 0,
      },
      'isWorkChat': true,
      'workRequestId': requestId,
      if (originChatId != null && originChatId.trim().isNotEmpty)
        'originChatId': originChatId.trim(),
      if (requestTitle != null && requestTitle.trim().isNotEmpty)
        'workTitle': requestTitle.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return workChatId;
  }

  Future<List<UserModel>> getCompanyUsers({
    String? excludeUserId,
    int limit = 20,
  }) async {
    final snapshot = await _firestore
        .collection(AppConstants.usersCollection)
        .where('role', isEqualTo: AppConstants.roleCompany)
        .get();

    final companies = snapshot.docs
        .map((doc) => UserModel.fromMap(doc.data(), doc.id))
        .where((user) => user.isActive)
        .where((user) => excludeUserId == null || user.uid != excludeUserId)
        .toList();

    companies.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (companies.length > limit) {
      return companies.sublist(0, limit);
    }
    return companies;
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

  Future<Map<String, dynamic>> getUserSettings(String userId) async {
    final doc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .get();
    if (!doc.exists) return <String, dynamic>{};
    final data = doc.data();
    final settings = data?['settings'];
    if (settings is Map) {
      return Map<String, dynamic>.from(settings);
    }
    return <String, dynamic>{};
  }

  Stream<Map<String, dynamic>> userSettingsStream(String userId) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return <String, dynamic>{};
      final settings = doc.data()?['settings'];
      if (settings is Map) {
        return Map<String, dynamic>.from(settings);
      }
      return <String, dynamic>{};
    });
  }

  Future<void> updateUserSettings(
    String userId,
    Map<String, dynamic> settings,
  ) async {
    await _firestore.collection(AppConstants.usersCollection).doc(userId).set({
      'settings': settings,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateUserSettingField(
    String userId, {
    required String key,
    required dynamic value,
  }) async {
    await _firestore.collection(AppConstants.usersCollection).doc(userId).set({
      'settings': {key: value},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ===== Notification Seen Tracking =====

  /// Stamps the user document with the current server timestamp so the badge
  /// count resets once all current notifications are considered "seen".
  Future<void> markNotificationsSeen(String userId) async {
    await _firestore.collection(AppConstants.usersCollection).doc(userId).set(
        {'lastNotificationSeenAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true));
  }

  /// Returns a stream that emits the `lastNotificationSeenAt` timestamp for
  /// [userId] every time the user document changes.
  Stream<DateTime?> lastNotificationSeenStream(String userId) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      final ts = doc.data()?['lastNotificationSeenAt'];
      if (ts == null) return null;
      return (ts as Timestamp).toDate();
    });
  }

  // ===== Banner Data =====

  /// Saves [bannerData] for a user into both the users collection and the
  /// role-specific profile collection (customers or skilled_users).
  Future<void> saveBannerData({
    required String userId,
    required String role,
    required Map<String, dynamic> bannerData,
  }) async {
    final batch = _firestore.batch();

    String collection;
    if (role == AppConstants.roleCustomer) {
      collection = AppConstants.customerProfilesCollection;
    } else if (role == AppConstants.roleCompany) {
      collection = AppConstants.companyProfilesCollection;
    } else {
      collection = AppConstants.skilledUsersCollection;
    }

    batch.set(
        _firestore.collection(collection).doc(userId),
        {'bannerData': bannerData, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true));

    await batch.commit();
  }

  Future<String> submitSupportTicket({
    required String userId,
    required String subject,
    required String message,
    String priority = 'normal',
  }) async {
    final normalizedSubject = subject.trim();
    final normalizedMessage = message.trim();
    if (normalizedSubject.isEmpty || normalizedMessage.isEmpty) {
      throw Exception('Subject and message are required.');
    }

    final docRef =
        _firestore.collection(AppConstants.supportTicketsCollection).doc();
    await docRef.set({
      'userId': userId,
      'subject': normalizedSubject,
      'message': normalizedMessage,
      'priority': priority,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Future<String> submitProfileReport({
    required String reporterId,
    required String reportedUserId,
    required String reason,
    String? details,
  }) async {
    if (reporterId == reportedUserId) {
      throw Exception('You cannot report yourself.');
    }

    final normalizedReason = reason.trim();
    if (normalizedReason.isEmpty) {
      throw Exception('Please provide a report reason.');
    }

    final docRef = _firestore.collection(AppConstants.reportsCollection).doc();
    await docRef.set({
      'reporterId': reporterId,
      'reportedUserId': reportedUserId,
      'reason': normalizedReason,
      'details': details?.trim(),
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Future<void> blockUser({
    required String blockerId,
    required String blockedUserId,
    String? reason,
  }) async {
    if (blockerId == blockedUserId) {
      throw Exception('You cannot block yourself.');
    }

    final docId = '${blockerId}_$blockedUserId';
    await _firestore
        .collection(AppConstants.blockedUsersCollection)
        .doc(docId)
        .set({
      'blockerId': blockerId,
      'blockedUserId': blockedUserId,
      'reason': reason?.trim(),
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> unblockUser({
    required String blockerId,
    required String blockedUserId,
  }) async {
    final docId = '${blockerId}_$blockedUserId';
    await _firestore
        .collection(AppConstants.blockedUsersCollection)
        .doc(docId)
        .set({
      'blockerId': blockerId,
      'blockedUserId': blockedUserId,
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Set<String>> getBlockedUserIds(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.blockedUsersCollection)
          .where('blockerId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => (doc.data()['blockedUserId'] as String?) ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
    } on FirebaseException catch (e) {
      // Existing projects may still have strict blocked_users rules.
      if (e.code == 'permission-denied' || e.code == 'failed-precondition') {
        debugPrint('getBlockedUserIds permission fallback: ${e.message}');
        return <String>{};
      }
      rethrow;
    }
  }

  Future<Set<String>> getUsersWhoBlocked(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.blockedUsersCollection)
          .where('blockedUserId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => (doc.data()['blockerId'] as String?) ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
    } on FirebaseException catch (e) {
      // Existing projects may still have strict blocked_users rules.
      if (e.code == 'permission-denied' || e.code == 'failed-precondition') {
        debugPrint('getUsersWhoBlocked permission fallback: ${e.message}');
        return <String>{};
      }
      rethrow;
    }
  }

  Future<bool> isUserBlockedEitherWay({
    required String currentUserId,
    required String otherUserId,
  }) async {
    try {
      final checks = await Future.wait([
        _firestore
            .collection(AppConstants.blockedUsersCollection)
            .where('blockerId', isEqualTo: currentUserId)
            .where('blockedUserId', isEqualTo: otherUserId)
            .limit(5)
            .get(),
        _firestore
            .collection(AppConstants.blockedUsersCollection)
            .where('blockerId', isEqualTo: otherUserId)
            .where('blockedUserId', isEqualTo: currentUserId)
            .limit(5)
            .get(),
      ]);

      return checks.any(
        (snapshot) =>
            snapshot.docs.any((doc) => doc.data()['isActive'] == true),
      );
    } on FirebaseException catch (e) {
      // Keep core profile/chat flows working even when rules are not yet updated.
      if (e.code == 'permission-denied' || e.code == 'failed-precondition') {
        debugPrint('isUserBlockedEitherWay permission fallback: ${e.message}');
        return false;
      }
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
    final collection =
        _firestore.collection(AppConstants.skilledUsersCollection);

    final doc = await collection.doc(userId).get();
    if (doc.exists) {
      final canonicalData = Map<String, dynamic>.from(doc.data()!);
      canonicalData['userId'] = userId;
      return SkilledUserProfile.fromMap(canonicalData, userId);
    }

    // Backward compatibility for legacy docs saved with auto IDs and userId field.
    final legacySnapshot =
        await collection.where('userId', isEqualTo: userId).limit(1).get();
    if (legacySnapshot.docs.isEmpty) return null;

    final legacyData =
        Map<String, dynamic>.from(legacySnapshot.docs.first.data());
    legacyData['userId'] = userId;

    // Opportunistic migration to canonical /skilled_users/{uid}.
    try {
      await collection.doc(userId).set({
        ...legacyData,
        'userId': userId,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Legacy skilled profile migration skipped for $userId: $e');
    }

    return SkilledUserProfile.fromMap(legacyData, userId);
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

  /// Counts a skilled profile view only once per viewer.
  Future<void> trackUniqueSkilledProfileView({
    required String skilledUserId,
    required String viewerUserId,
  }) async {
    if (skilledUserId.trim().isEmpty || viewerUserId.trim().isEmpty) return;
    if (skilledUserId == viewerUserId) return;

    final profileRef = _firestore
        .collection(AppConstants.skilledUsersCollection)
        .doc(skilledUserId);
    final viewerRef =
        profileRef.collection('profile_viewers').doc(viewerUserId);

    try {
      await _firestore.runTransaction((transaction) async {
        final viewerSnap = await transaction.get(viewerRef);
        if (viewerSnap.exists) return;

        transaction.set(viewerRef, {
          'viewerId': viewerUserId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.update(profileRef, {
          'profileViews': FieldValue.increment(1),
        });
      });
    } catch (e) {
      debugPrint('Failed to track unique profile view: $e');
    }
  }

  /// Realtime stream of profile view count for a skilled user.
  Stream<int> skilledProfileViewCountStream(String skilledUserId) {
    return _firestore
        .collection(AppConstants.skilledUsersCollection)
        .doc(skilledUserId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return 0;
      final value = doc.data()?['profileViews'];
      if (value is int) return value;
      if (value is num) return value.toInt();
      return 0;
    });
  }

  Future<bool> isAadhaarAlreadyUsed(String aadhaarNumber,
      {String? excludeUserId}) async {
    final cleanAadhaar = _normalizeAadhaar(aadhaarNumber);
    if (cleanAadhaar.length != 12 || int.tryParse(cleanAadhaar) == null) {
      throw Exception('Invalid Aadhaar number format');
    }

    final doc = await _firestore
        .collection(_aadhaarRegistryCollection)
        .doc(cleanAadhaar)
        .get();

    if (!doc.exists) return false;
    final ownerUserId = doc.data()?['userId'] as String?;
    return ownerUserId != null && ownerUserId != excludeUserId;
  }

  Future<bool> isSkilledUserAadhaarVerified(String userId) async {
    final profile = await getSkilledUserProfile(userId);
    if (profile == null) return false;
    return _isSkilledProfileAadhaarVerified(profile);
  }

  Future<SkilledUserProfile?> verifyAndLockAadhaar({
    required String userId,
    required String aadhaarNumber,
  }) async {
    final cleanAadhaar = _normalizeAadhaar(aadhaarNumber);
    if (cleanAadhaar.length != 12 || int.tryParse(cleanAadhaar) == null) {
      throw Exception(
          'Invalid Aadhaar number. Aadhaar must contain exactly 12 digits.');
    }

    final profileRef =
        _firestore.collection(AppConstants.skilledUsersCollection).doc(userId);
    final aadhaarRef =
        _firestore.collection(_aadhaarRegistryCollection).doc(cleanAadhaar);

    await _firestore.runTransaction((transaction) async {
      final profileSnap = await transaction.get(profileRef);
      final profileData = profileSnap.data() ?? <String, dynamic>{};
      final rawVerificationData = profileData['verificationData'];
      final verificationData = rawVerificationData is Map
          ? Map<String, dynamic>.from(rawVerificationData)
          : <String, dynamic>{};

      final existingAadhaar =
          (verificationData['aadhaarNumber'] as String?)?.trim();
      final aadhaarLocked = verificationData['aadhaarLocked'] == true;

      if (aadhaarLocked &&
          existingAadhaar != null &&
          existingAadhaar.isNotEmpty &&
          existingAadhaar != cleanAadhaar) {
        throw Exception(
          'Aadhaar is locked for this profile. Submit a request to admin with valid proofs to change it.',
        );
      }

      final aadhaarSnap = await transaction.get(aadhaarRef);
      if (aadhaarSnap.exists) {
        final ownerUserId = aadhaarSnap.data()?['userId'] as String?;
        if (ownerUserId != null && ownerUserId != userId) {
          throw Exception(
              'This Aadhaar number is already linked to another account.');
        }
      }

      final maskedAadhaar = _maskAadhaar(cleanAadhaar);

      transaction.set(
        aadhaarRef,
        {
          'userId': userId,
          'maskedAadhaar': maskedAadhaar,
          'updatedAt': FieldValue.serverTimestamp(),
          if (!aadhaarSnap.exists) 'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // Cleanup old registry entry if user is linking a new Aadhaar for the first time.
      if (existingAadhaar != null &&
          existingAadhaar.isNotEmpty &&
          existingAadhaar != cleanAadhaar &&
          !aadhaarLocked) {
        final oldAadhaarRef = _firestore
            .collection(_aadhaarRegistryCollection)
            .doc(existingAadhaar);
        transaction.delete(oldAadhaarRef);
      }

      transaction.set(
        profileRef,
        {
          'verificationStatus': AppConstants.verificationApproved,
          'visibility': AppConstants.visibilityPublic,
          'isVerified': true,
          'verifiedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'verificationData': {
            ...verificationData,
            'aadhaarNumber': cleanAadhaar,
            'maskedAadhaar': maskedAadhaar,
            'aadhaarLocked': true,
            'aadhaarLockedAt': verificationData['aadhaarLockedAt'] ??
                FieldValue.serverTimestamp(),
            'aadhaarChangeRequested': false,
            'aadhaarChangeRequestId': null,
            'verifiedAt': FieldValue.serverTimestamp(),
          },
        },
        SetOptions(merge: true),
      );
    });

    return getSkilledUserProfile(userId);
  }

  Future<bool> hasPendingAadhaarChangeRequest(String userId) async {
    final snapshot = await _firestore
        .collection(AppConstants.appealsCollection)
        .where('userId', isEqualTo: userId)
        .limit(25)
        .get();

    return snapshot.docs.any((doc) {
      final data = doc.data();
      return data['type'] == _aadhaarChangeRequestType &&
          data['status'] == 'pending';
    });
  }

  Future<String> requestAadhaarChange({
    required String userId,
    required String reason,
    List<String> proofLinks = const [],
  }) async {
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      throw Exception(
          'Please provide a valid reason and proof details for Aadhaar change.');
    }

    final profile = await getSkilledUserProfile(userId);
    if (profile == null || !_isSkilledProfileAadhaarVerified(profile)) {
      throw Exception('Aadhaar must be verified before requesting a change.');
    }

    final alreadyPending = await hasPendingAadhaarChangeRequest(userId);
    if (alreadyPending) {
      throw Exception('You already have a pending Aadhaar change request.');
    }

    final cleanProofLinks =
        proofLinks.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    final requestId = await createAppeal(
      AppealModel(
        id: '',
        userId: userId,
        type: _aadhaarChangeRequestType,
        title: 'Aadhaar Change Request',
        description: trimmedReason,
        attachments: cleanProofLinks,
        status: 'pending',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    await _firestore
        .collection(AppConstants.skilledUsersCollection)
        .doc(userId)
        .set({
      'updatedAt': FieldValue.serverTimestamp(),
      'verificationData': {
        ...(profile.verificationData ?? <String, dynamic>{}),
        'aadhaarChangeRequested': true,
        'aadhaarChangeRequestedAt': FieldValue.serverTimestamp(),
        'aadhaarChangeRequestId': requestId,
      },
    }, SetOptions(merge: true));

    return requestId;
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

    final fetchLimit = (limit * 3).clamp(20, 120).toInt();
    query = query.limit(fetchLimit);

    final snapshot = await query.get();
    final dedupedProfiles = <String, SkilledUserProfile>{};

    for (final doc in snapshot.docs) {
      final profile = SkilledUserProfile.fromMap(
        doc.data() as Map<String, dynamic>,
        doc.id,
      );
      if (!_isSkilledProfileAadhaarVerified(profile)) continue;
      if (profile.userId.trim().isEmpty) continue;
      if (doc.id != profile.userId) {
        // Legacy compatibility: move auto-id profile docs to /skilled_users/{uid}.
        try {
          final legacyData = Map<String, dynamic>.from(
            doc.data() as Map<String, dynamic>,
          );
          legacyData['userId'] = profile.userId;
          await _firestore
              .collection(AppConstants.skilledUsersCollection)
              .doc(profile.userId)
              .set(legacyData, SetOptions(merge: true));
        } catch (e) {
          debugPrint(
            'Verified profile migration skipped (${profile.userId}): $e',
          );
        }
      }

      final existing = dedupedProfiles[profile.userId];
      if (existing == null || profile.updatedAt.isAfter(existing.updatedAt)) {
        dedupedProfiles[profile.userId] = profile;
      }
    }

    var profiles = dedupedProfiles.values.toList();

    if (skills != null && skills.isNotEmpty) {
      final normalizedSkills = skills
          .map((skill) => skill.toLowerCase().trim())
          .where((skill) => skill.isNotEmpty)
          .toSet();
      if (normalizedSkills.isNotEmpty) {
        profiles = profiles.where((profile) {
          final profileSkills =
              profile.skills.map((skill) => skill.toLowerCase().trim());
          return profileSkills.any(normalizedSkills.contains);
        }).toList();
      }
    }

    if (profiles.length > limit) {
      return profiles.sublist(0, limit);
    }
    return profiles;
  }

  // ===== Customer Profile =====

  Future<void> updateCustomerProfile(CustomerProfile profile) async {
    await _firestore
        .collection(AppConstants.customerProfilesCollection)
        .doc(profile.userId)
        .set(profile.toMap(), SetOptions(merge: true));
  }

  Future<CustomerProfile?> getCustomerProfile(String userId) async {
    final doc = await _firestore
        .collection(AppConstants.customerProfilesCollection)
        .doc(userId)
        .get();

    if (!doc.exists) return null;
    return CustomerProfile.fromMap(doc.data()!, userId);
  }

  Stream<CustomerProfile?> customerProfileStream(String userId) {
    return _firestore
        .collection(AppConstants.customerProfilesCollection)
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return CustomerProfile.fromMap(doc.data()!, userId);
    });
  }

  // ===== Company Profile =====

  Future<void> updateCompanyProfile(CompanyProfile profile) async {
    await _firestore
        .collection(AppConstants.companyProfilesCollection)
        .doc(profile.userId)
        .set(profile.toMap(), SetOptions(merge: true));
  }

  Future<CompanyProfile?> getCompanyProfile(String userId) async {
    final doc = await _firestore
        .collection(AppConstants.companyProfilesCollection)
        .doc(userId)
        .get();

    if (!doc.exists) return null;
    return CompanyProfile.fromMap(doc.data()!, userId);
  }

  Stream<CompanyProfile?> companyProfileStream(String userId) {
    return _firestore
        .collection(AppConstants.companyProfilesCollection)
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return CompanyProfile.fromMap(doc.data()!, userId);
    });
  }

  // ===== Services =====

  List<ServiceModel> _sortServicesByNewest(List<ServiceModel> services) {
    services.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return services;
  }

  double _safeDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  List<ServiceModel> _buildServicesFromProfileData(
    Map<String, dynamic> profileData,
    String userId,
  ) {
    final now = DateTime.now();
    final bio = (profileData['bio'] as String?)?.trim() ?? '';
    final fallbackDescription =
        bio.isNotEmpty ? bio : 'Service details are available on request.';
    final fallbackCategory =
        ((profileData['category'] as String?)?.trim().isNotEmpty == true)
            ? (profileData['category'] as String).trim()
            : 'General';

    final rawServices = profileData['services'] ??
        profileData['serviceList'] ??
        profileData['servicesOffered'];
    final services = <ServiceModel>[];

    if (rawServices is List) {
      for (var i = 0; i < rawServices.length; i++) {
        final rawItem = rawServices[i];
        if (rawItem is Map) {
          final item = Map<String, dynamic>.from(rawItem);
          final title = ((item['title'] ??
                      item['name'] ??
                      item['service'] ??
                      item['label'])
                  ?.toString()
                  .trim() ??
              '');
          if (title.isEmpty) continue;

          services.add(
            ServiceModel(
              id: 'profile_service_${userId}_$i',
              userId: userId,
              title: title,
              description: ((item['description'] ?? item['details'])
                              ?.toString()
                              .trim() ??
                          '')
                      .isNotEmpty
                  ? (item['description'] ?? item['details']).toString().trim()
                  : fallbackDescription,
              priceMin: _safeDouble(item['priceMin'] ?? item['minPrice']),
              priceMax: _safeDouble(item['priceMax'] ?? item['maxPrice']),
              priceUnit: ((item['priceUnit'] ?? item['unit'])?.toString() ??
                      'on request')
                  .trim(),
              images: item['images'] is List
                  ? List<String>.from(
                      (item['images'] as List)
                          .map((e) => e.toString().trim())
                          .where((e) => e.isNotEmpty),
                    )
                  : const [],
              category:
                  ((item['category'] as String?)?.trim().isNotEmpty == true)
                      ? (item['category'] as String).trim()
                      : fallbackCategory,
              isActive: item['isActive'] != false,
              createdAt: (item['createdAt'] as Timestamp?)?.toDate() ?? now,
              updatedAt: (item['updatedAt'] as Timestamp?)?.toDate() ?? now,
            ),
          );
          continue;
        }

        final title = rawItem.toString().trim();
        if (title.isEmpty) continue;
        services.add(
          ServiceModel(
            id: 'profile_service_${userId}_$i',
            userId: userId,
            title: title,
            description: fallbackDescription,
            priceMin: 0,
            priceMax: 0,
            priceUnit: 'on request',
            category: fallbackCategory,
            isActive: true,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    }

    return _sortServicesByNewest(services);
  }

  Future<List<ServiceModel>> _getFallbackServicesFromProfile(
      String userId) async {
    try {
      final profileByDocId = await _firestore
          .collection(AppConstants.skilledUsersCollection)
          .doc(userId)
          .get();
      if (profileByDocId.exists) {
        final data = Map<String, dynamic>.from(profileByDocId.data()!);
        final derived = _buildServicesFromProfileData(data, userId);
        if (derived.isNotEmpty) return derived;
      }

      final legacyProfile = await _firestore
          .collection(AppConstants.skilledUsersCollection)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();
      if (legacyProfile.docs.isNotEmpty) {
        final data = Map<String, dynamic>.from(legacyProfile.docs.first.data());
        final derived = _buildServicesFromProfileData(data, userId);
        if (derived.isNotEmpty) return derived;
      }
    } catch (e) {
      debugPrint('Service profile fallback lookup failed: $e');
    }

    final profile = await getSkilledUserProfile(userId);
    if (profile == null || profile.skills.isEmpty) return [];

    final fallbackDescription = profile.bio.trim().isNotEmpty
        ? profile.bio.trim()
        : 'Service details are available on request.';
    final fallbackCategory = (profile.category?.trim().isNotEmpty == true)
        ? profile.category!
        : 'General';
    final fallbackServices = <ServiceModel>[];
    var index = 0;

    for (final rawSkill in profile.skills) {
      final skill = rawSkill.trim();
      if (skill.isEmpty) continue;
      fallbackServices.add(
        ServiceModel(
          id: 'profile_skill_${userId}_$index',
          userId: userId,
          title: skill,
          description: fallbackDescription,
          priceMin: 0,
          priceMax: 0,
          priceUnit: 'on request',
          category: fallbackCategory,
          isActive: true,
          createdAt: profile.createdAt,
          updatedAt: profile.updatedAt,
        ),
      );
      index += 1;
      if (index >= 6) break;
    }

    return _sortServicesByNewest(fallbackServices);
  }

  Future<String> createService(ServiceModel service) async {
    final docRef = await _firestore.collection('services').add(service.toMap());
    return docRef.id;
  }

  Future<List<ServiceModel>> getUserServices(String userId) async {
    final servicesCollection = _firestore.collection('services');
    try {
      final snapshot = await servicesCollection
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => ServiceModel.fromMap(doc.data(), doc.id))
          .toList();
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition') {
        try {
          // Fallback query for projects that don't have this composite index yet.
          final snapshot =
              await servicesCollection.where('userId', isEqualTo: userId).get();
          final services = snapshot.docs
              .map((doc) => ServiceModel.fromMap(doc.data(), doc.id))
              .toList();
          return _sortServicesByNewest(services);
        } on FirebaseException catch (_) {
          // Continue to profile fallback below.
        }
      }

      if (e.code == 'permission-denied' || e.code == 'failed-precondition') {
        debugPrint('getUserServices fallback for user $userId: ${e.message}');
        return _getFallbackServicesFromProfile(userId);
      }
      rethrow;
    }
  }

  Future<void> updateService(ServiceModel service) async {
    await _firestore
        .collection('services')
        .doc(service.id)
        .update(service.toMap());
  }

  Future<void> deleteService(String serviceId) async {
    await _firestore.collection('services').doc(serviceId).delete();
  }

  // ===== Custom Skills (global suggestions) =====

  Future<void> addCustomSkill(String skill) async {
    final normalized = skill.trim();
    if (normalized.isEmpty) return;
    // Use skill as doc ID (lowercase) to avoid duplicates
    await _firestore
        .collection('custom_skills')
        .doc(normalized.toLowerCase())
        .set({
      'name': normalized,
      'addedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<List<String>> getCustomSkills() async {
    final snapshot =
        await _firestore.collection('custom_skills').orderBy('name').get();
    return snapshot.docs
        .map((doc) => doc.data()['name'] as String? ?? doc.id)
        .toList();
  }

  // ===== Products =====

  Future<String> createProduct(ProductModel product) async {
    final canSell = await isSkilledUserAadhaarVerified(product.userId);
    if (!canSell) {
      throw Exception(
          'Aadhaar verification is required before publishing products.');
    }

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

      // Show ALL products for the owner (including unavailable ones)
      final products = snapshot.docs
          .map((doc) => ProductModel.fromMap(doc.data(), doc.id))
          .toList();

      // Sort by createdAt descending
      products.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return products;
    } catch (e) {
      debugPrint('Error getting user products: $e');
      return [];
    }
  }

  Stream<List<ProductModel>> streamUserProducts(String userId) {
    return _firestore
        .collection(AppConstants.productsCollection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final products = snapshot.docs
          .map((doc) => ProductModel.fromMap(doc.data(), doc.id))
          .toList();
      products.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return products;
    });
  }

  Future<List<ProductModel>> getAllProducts({int limit = 50}) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.productsCollection)
          .limit(limit)
          .get();

      // Filter in memory to avoid index requirement
      final products = snapshot.docs
          .map((doc) => ProductModel.fromMap(doc.data(), doc.id))
          .where((product) => product.isAvailable)
          .toList();

      if (products.isEmpty) return [];

      // Enforce strict visibility: only products from Aadhaar-verified skilled users are public
      final sellerIds = products
          .map((product) => product.userId)
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      final verifiedSellerIds = <String>{};
      for (var i = 0; i < sellerIds.length; i += 10) {
        final end = (i + 10 > sellerIds.length) ? sellerIds.length : i + 10;
        final batchIds = sellerIds.sublist(i, end);

        final docsByUserId = <String, Map<String, dynamic>>{};

        final byDocIdSnapshot = await _firestore
            .collection(AppConstants.skilledUsersCollection)
            .where(FieldPath.documentId, whereIn: batchIds)
            .get();

        for (final doc in byDocIdSnapshot.docs) {
          final data = Map<String, dynamic>.from(doc.data());
          final mappedUserId = (data['userId'] as String?)?.trim();
          final resolvedUserId =
              (mappedUserId != null && mappedUserId.isNotEmpty)
                  ? mappedUserId
                  : doc.id;
          docsByUserId[resolvedUserId] = data;
        }

        // Legacy compatibility: some profiles were saved with auto doc IDs.
        final byUserIdFieldSnapshot = await _firestore
            .collection(AppConstants.skilledUsersCollection)
            .where('userId', whereIn: batchIds)
            .get();

        for (final doc in byUserIdFieldSnapshot.docs) {
          final data = Map<String, dynamic>.from(doc.data());
          final mappedUserId = (data['userId'] as String?)?.trim();
          if (mappedUserId == null || mappedUserId.isEmpty) continue;
          docsByUserId[mappedUserId] = data;
        }

        for (final entry in docsByUserId.entries) {
          if (_isSkilledUserDataAadhaarVerified(entry.value)) {
            verifiedSellerIds.add(entry.key);
          }
        }
      }

      final visibleProducts = products
          .where((product) => verifiedSellerIds.contains(product.userId))
          .toList();

      // Sort by createdAt descending
      visibleProducts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return visibleProducts;
    } catch (e) {
      debugPrint('Error getting products: $e');
      return []; // Return empty list on error
    }
  }

  /// Emits a fresh product list whenever the products collection changes.
  Stream<List<ProductModel>> streamAllProducts({int limit = 50}) {
    return _firestore
        .collection(AppConstants.productsCollection)
        .limit(limit)
        .snapshots()
        .asyncMap((_) => getAllProducts(limit: limit));
  }

  /// Real-time stream of the base [UserModel] for a given uid.
  Stream<UserModel?> streamUserModel(String userId) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .snapshots()
        .map((snap) =>
            snap.exists ? UserModel.fromMap(snap.data()!, snap.id) : null);
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

  // ===== Cart & Orders =====

  Future<void> addToCart({
    required String userId,
    required ProductModel product,
    int quantity = 1,
  }) async {
    if (quantity <= 0) {
      throw Exception('Quantity must be at least 1.');
    }
    if (userId == product.userId) {
      throw Exception('You cannot add your own product to cart.');
    }

    final productRef =
        _firestore.collection(AppConstants.productsCollection).doc(product.id);
    final cartItemRef = _firestore
        .collection(AppConstants.cartsCollection)
        .doc(userId)
        .collection('items')
        .doc(product.id);

    await _firestore.runTransaction((transaction) async {
      final productSnap = await transaction.get(productRef);
      if (!productSnap.exists) {
        throw Exception('Product no longer exists.');
      }

      final productData = productSnap.data()!;
      final latestProduct = ProductModel.fromMap(productData, productSnap.id);

      if (!latestProduct.isAvailable || latestProduct.stock <= 0) {
        throw Exception('This product is currently out of stock.');
      }

      final cartSnap = await transaction.get(cartItemRef);
      final existingQuantity =
          cartSnap.exists ? (cartSnap.data()?['quantity'] as int? ?? 0) : 0;
      final newQuantity = existingQuantity + quantity;

      if (newQuantity > latestProduct.stock) {
        throw Exception(
            'Only ${latestProduct.stock} item(s) are available in stock.');
      }

      transaction.set(
        cartItemRef,
        {
          'userId': userId,
          'productId': latestProduct.id,
          'sellerId': latestProduct.userId,
          'productName': latestProduct.name,
          'productImage': latestProduct.images.isNotEmpty
              ? latestProduct.images.first
              : null,
          'price': latestProduct.price,
          'quantity': newQuantity,
          'availableStock': latestProduct.stock,
          'isAvailable': latestProduct.isAvailable,
          'updatedAt': FieldValue.serverTimestamp(),
          if (!cartSnap.exists) 'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  Stream<List<CartItemModel>> streamCartItems(String userId) {
    return _firestore
        .collection(AppConstants.cartsCollection)
        .doc(userId)
        .collection('items')
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs
          .map((doc) => CartItemModel.fromMap(doc.data(), doc.id))
          .toList();
      items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return items;
    });
  }

  Future<List<CartItemModel>> getCartItems(String userId) async {
    final snapshot = await _firestore
        .collection(AppConstants.cartsCollection)
        .doc(userId)
        .collection('items')
        .get();
    final items = snapshot.docs
        .map((doc) => CartItemModel.fromMap(doc.data(), doc.id))
        .toList();
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  }

  Future<void> updateCartItemQuantity({
    required String userId,
    required String productId,
    required int quantity,
  }) async {
    if (quantity <= 0) {
      await removeCartItem(userId: userId, productId: productId);
      return;
    }

    final productSnap = await _firestore
        .collection(AppConstants.productsCollection)
        .doc(productId)
        .get();
    if (!productSnap.exists) {
      throw Exception('Product no longer exists.');
    }
    final product = ProductModel.fromMap(productSnap.data()!, productSnap.id);
    if (quantity > product.stock) {
      throw Exception('Only ${product.stock} item(s) are available.');
    }

    await _firestore
        .collection(AppConstants.cartsCollection)
        .doc(userId)
        .collection('items')
        .doc(productId)
        .set({
      'quantity': quantity,
      'availableStock': product.stock,
      'isAvailable': product.isAvailable,
      'price': product.price,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> removeCartItem({
    required String userId,
    required String productId,
  }) async {
    await _firestore
        .collection(AppConstants.cartsCollection)
        .doc(userId)
        .collection('items')
        .doc(productId)
        .delete();
  }

  Future<int> getCartItemCount(String userId) async {
    final items = await getCartItems(userId);
    return items.fold<int>(0, (totalItems, item) => totalItems + item.quantity);
  }

  Future<List<OrderModel>> checkoutCart(
    String userId, {
    String paymentMethod = 'gpay_simulation',
    String? paymentReference,
  }) async {
    final cartItems = await getCartItems(userId);
    if (cartItems.isEmpty) {
      throw Exception('Your cart is empty.');
    }

    if (cartItems.length > 100) {
      throw Exception(
          'Cart has too many items to process at once. Please checkout fewer items.');
    }

    final buyer = await getUserById(userId);
    final batch = _firestore.batch();
    final createdOrders = <OrderModel>[];
    final now = DateTime.now();
    final sellerShopSettingsById = <String, Map<String, dynamic>>{};
    final sellerUserSettingsById = <String, Map<String, dynamic>>{};
    final normalizedPaymentMethod =
        paymentMethod.trim().isEmpty ? 'gpay_simulation' : paymentMethod.trim();
    final normalizedReference = paymentReference?.trim();

    int parseMaxDeliveryQuantity(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
      return 0;
    }

    bool parseAllowDelivery(dynamic value) {
      if (value is bool) return value;
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        return normalized == 'true' || normalized == '1' || normalized == 'yes';
      }
      if (value is num) return value != 0;
      return true;
    }

    for (final item in cartItems) {
      final productRef = _firestore
          .collection(AppConstants.productsCollection)
          .doc(item.productId);
      final productSnap = await productRef.get();
      if (!productSnap.exists) {
        throw Exception('One of the products in cart no longer exists.');
      }

      final latestProduct =
          ProductModel.fromMap(productSnap.data()!, item.productId);
      if (!latestProduct.isAvailable || latestProduct.stock < item.quantity) {
        throw Exception(
            'Insufficient stock for "${latestProduct.name}". Please update cart.');
      }

      if (!sellerShopSettingsById.containsKey(latestProduct.userId)) {
        sellerShopSettingsById[latestProduct.userId] =
            await getShopSettings(latestProduct.userId);
      }
      if (!sellerUserSettingsById.containsKey(latestProduct.userId)) {
        sellerUserSettingsById[latestProduct.userId] =
            await getUserSettings(latestProduct.userId);
      }
      final shopSettings = sellerShopSettingsById[latestProduct.userId]!;
      final userSettings = sellerUserSettingsById[latestProduct.userId]!;
      final profileWorkflowEnabled =
          (userSettings['enableShopDeliveryWorkflow'] as bool?) ?? false;
      final allowDeliveryIfAvailable =
          parseAllowDelivery(shopSettings['enableDeliveryIfAvailable']);
      final configuredMaxDeliveryQty =
          parseMaxDeliveryQuantity(shopSettings['maxDeliveryQuantity']);
      final appliedMaxDeliveryQty =
          configuredMaxDeliveryQty > 0 ? configuredMaxDeliveryQty : 10;
      final deliveryByPartner = profileWorkflowEnabled &&
          allowDeliveryIfAvailable &&
          item.quantity <= appliedMaxDeliveryQty;

      final orderRef =
          _firestore.collection(AppConstants.ordersCollection).doc();
      final totalPrice = latestProduct.price * item.quantity;
      final order = OrderModel(
        id: orderRef.id,
        buyerId: userId,
        sellerId: latestProduct.userId,
        productId: latestProduct.id,
        productName: latestProduct.name,
        productImage:
            latestProduct.images.isNotEmpty ? latestProduct.images.first : null,
        quantity: item.quantity,
        unitPrice: latestProduct.price,
        totalPrice: totalPrice,
        status: 'pending',
        buyerName: buyer?.name,
        buyerEmail: buyer?.email,
        paymentMethod: normalizedPaymentMethod,
        paymentStatus: 'paid',
        paymentReference:
            (normalizedReference != null && normalizedReference.isNotEmpty)
                ? normalizedReference
                : null,
        paidAt: now,
        sellerTransferStatus: 'credited_simulated',
        sellerTransferAt: now,
        statusTimeline: {'pending': now},
        deliveryByPartner: deliveryByPartner,
        deliveryQuantityLimit: appliedMaxDeliveryQty,
        createdAt: now,
        updatedAt: now,
      );
      createdOrders.add(order);
      batch.set(orderRef, order.toMap());

      final cartItemRef = _firestore
          .collection(AppConstants.cartsCollection)
          .doc(userId)
          .collection('items')
          .doc(item.productId);
      batch.delete(cartItemRef);
    }

    await batch.commit();
    return createdOrders;
  }

  Stream<List<OrderModel>> streamSellerOrders(String sellerId) {
    return _firestore
        .collection(AppConstants.ordersCollection)
        .where('sellerId', isEqualTo: sellerId)
        .snapshots()
        .map((snapshot) {
      final orders = snapshot.docs
          .map((doc) => OrderModel.fromMap(doc.data(), doc.id))
          .toList();
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    });
  }

  Stream<List<OrderModel>> streamBuyerOrders(String buyerId) {
    return _firestore
        .collection(AppConstants.ordersCollection)
        .where('buyerId', isEqualTo: buyerId)
        .snapshots()
        .map((snapshot) {
      final orders = snapshot.docs
          .map((doc) => OrderModel.fromMap(doc.data(), doc.id))
          .toList();
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    });
  }

  Future<void> updateOrderStatus({
    required String orderId,
    required String sellerId,
    required String status,
  }) async {
    const allowedStatuses = {'confirmed', 'shipped', 'delivered', 'cancelled'};
    if (!allowedStatuses.contains(status)) {
      throw Exception('Invalid order status.');
    }

    final orderRef =
        _firestore.collection(AppConstants.ordersCollection).doc(orderId);
    final orderSnap = await orderRef.get();
    if (!orderSnap.exists) {
      throw Exception('Order not found.');
    }

    final orderSellerId = orderSnap.data()?['sellerId'] as String?;
    if (orderSellerId != sellerId) {
      throw Exception('You are not authorized to update this order.');
    }

    final data = orderSnap.data() ?? <String, dynamic>{};
    final currentStatus = (data['status'] as String?)?.trim() ?? 'pending';
    final deliveryByPartner = data['deliveryByPartner'] == true;

    bool isAllowedTransition() {
      if (currentStatus == 'pending') {
        return status == 'confirmed' || status == 'cancelled';
      }
      if (currentStatus == 'confirmed') {
        if (deliveryByPartner) {
          return status == 'cancelled';
        }
        return status == 'shipped' || status == 'cancelled';
      }
      if (currentStatus == 'shipped') {
        return status == 'delivered' || status == 'cancelled';
      }
      return false;
    }

    if (!isAllowedTransition()) {
      throw Exception(
          'Invalid transition: $currentStatus -> $status for this order.');
    }

    if (deliveryByPartner && (status == 'shipped' || status == 'delivered')) {
      throw Exception(
          'Seller cannot mark shipped/delivered for delivery-partner orders.');
    }

    await orderRef.update({
      'status': status,
      'statusTimeline.$status': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ===== Delivery Partner =====

  /// Stream all orders assigned to a delivery partner.
  Stream<List<OrderModel>> streamDeliveryPartnerOrders(
      String deliveryPartnerId) {
    return _firestore
        .collection(AppConstants.ordersCollection)
        .where('deliveryPartnerId', isEqualTo: deliveryPartnerId)
        .snapshots()
        .map((snapshot) {
      final orders = snapshot.docs
          .map((doc) => OrderModel.fromMap(doc.data(), doc.id))
          .toList();
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    });
  }

  /// Stream orders that are confirmed for partner delivery and unassigned.
  Stream<List<OrderModel>> streamAvailableDeliveries() {
    return _firestore
        .collection(AppConstants.ordersCollection)
        .where('status', isEqualTo: 'confirmed')
        .snapshots()
        .map((snapshot) {
      final orders = snapshot.docs
          .map((doc) => OrderModel.fromMap(doc.data(), doc.id))
          .where((o) =>
              o.deliveryByPartner &&
              (o.deliveryPartnerId == null || o.deliveryPartnerId!.isEmpty))
          .toList();
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    });
  }

  /// Assign a delivery partner to an order and set estimated delivery.
  Future<void> assignDeliveryPartner({
    required String orderId,
    required String deliveryPartnerId,
    required String deliveryPartnerName,
    DateTime? estimatedDelivery,
  }) async {
    final ref =
        _firestore.collection(AppConstants.ordersCollection).doc(orderId);
    final snap = await ref.get();
    if (!snap.exists) {
      throw Exception('Order not found.');
    }
    final data = snap.data() ?? <String, dynamic>{};
    final status = (data['status'] as String?)?.trim() ?? '';
    final deliveryByPartner = data['deliveryByPartner'] == true;
    final assignedPartnerId =
        (data['deliveryPartnerId'] as String?)?.trim() ?? '';

    if (!deliveryByPartner) {
      throw Exception(
          'This order is not configured for delivery partner flow.');
    }
    if (status != 'confirmed') {
      throw Exception('Only confirmed orders can be accepted for delivery.');
    }
    if (assignedPartnerId.isNotEmpty) {
      throw Exception('This order is already assigned to a delivery partner.');
    }

    final updateData = <String, dynamic>{
      'deliveryPartnerId': deliveryPartnerId,
      'deliveryPartnerName': deliveryPartnerName,
      'status': 'out_for_delivery',
      'statusTimeline.shipped': FieldValue.serverTimestamp(),
      'statusTimeline.out_for_delivery': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (estimatedDelivery != null) {
      updateData['estimatedDelivery'] = Timestamp.fromDate(estimatedDelivery);
    }
    await ref.update(updateData);
  }

  /// Update order delivery status (only assigned delivery partner can do this).
  Future<void> updateDeliveryStatus({
    required String orderId,
    required String deliveryPartnerId,
    required String status,
  }) async {
    const allowed = {
      'out_for_delivery',
      'delivered',
      'failed_delivery',
    };
    if (!allowed.contains(status)) {
      throw Exception('Invalid delivery status: $status');
    }
    final ref =
        _firestore.collection(AppConstants.ordersCollection).doc(orderId);
    final snap = await ref.get();
    if (!snap.exists) throw Exception('Order not found.');
    final data = snap.data()!;
    final assignedId = data['deliveryPartnerId'] as String?;
    final deliveryByPartner = data['deliveryByPartner'] == true;
    if (!deliveryByPartner) {
      throw Exception('This order is not using delivery-partner flow.');
    }
    if (assignedId != deliveryPartnerId) {
      throw Exception(
          'You are not the assigned delivery partner for this order.');
    }
    await ref.update({
      'status': status,
      'statusTimeline.$status': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Update estimated delivery timeline for the assigned delivery partner.
  Future<void> updateDeliveryEstimate({
    required String orderId,
    required String deliveryPartnerId,
    required DateTime estimatedDelivery,
  }) async {
    final ref =
        _firestore.collection(AppConstants.ordersCollection).doc(orderId);
    final snap = await ref.get();
    if (!snap.exists) {
      throw Exception('Order not found.');
    }
    final data = snap.data() ?? <String, dynamic>{};
    final deliveryByPartner = data['deliveryByPartner'] == true;
    final assignedId = (data['deliveryPartnerId'] as String?)?.trim() ?? '';
    if (!deliveryByPartner) {
      throw Exception('This order is not using delivery-partner flow.');
    }
    if (assignedId != deliveryPartnerId) {
      throw Exception(
          'You are not the assigned delivery partner for this order.');
    }

    await ref.update({
      'estimatedDelivery': Timestamp.fromDate(estimatedDelivery),
      'updatedAt': FieldValue.serverTimestamp(),
    });
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
    final jobRef =
        _firestore.collection(AppConstants.jobsCollection).doc(jobId);
    final userRef =
        _firestore.collection(AppConstants.usersCollection).doc(userId);

    await _firestore.runTransaction((transaction) async {
      final jobSnap = await transaction.get(jobRef);
      if (!jobSnap.exists) {
        throw Exception('Job not found.');
      }

      final userSnap = await transaction.get(userRef);
      if (!userSnap.exists) {
        throw Exception('User not found.');
      }

      final jobData = jobSnap.data()!;
      final userData = userSnap.data()!;
      final role = (userData['role'] as String?)?.trim().toLowerCase() ?? '';

      if (role != AppConstants.roleSkilledUser) {
        throw Exception('Only skilled users can apply for jobs.');
      }
      if ((jobData['status'] as String?) != AppConstants.jobStatusOpen) {
        throw Exception('This job is no longer open.');
      }
      if ((jobData['companyId'] as String?) == userId ||
          (jobData['postedBy'] as String?) == userId) {
        throw Exception('You cannot apply to your own job.');
      }

      final existingStatus =
          (jobData['applicationStatus'] as Map<String, dynamic>? ?? {})[userId]
              ?.toString();
      if (existingStatus == 'accepted') {
        throw Exception('You are already accepted for this job.');
      }

      final Map<String, dynamic> updates = {
        'applicants': FieldValue.arrayUnion([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
        'applicationStatus.$userId': 'pending',
      };

      transaction.update(jobRef, updates);

      // Notify the company about the new application
      final companyId = (jobData['companyId'] as String?)?.trim() ?? '';
      if (companyId.isNotEmpty && companyId != userId) {
        final notifRef = _firestore.collection('notifications').doc();
        transaction.set(notifRef, {
          'toUserId': companyId,
          'fromUserId': userId,
          'type': 'jobApplication',
          'title': 'New job application',
          'body':
              '${(userData['name'] as String?)?.trim() ?? 'Someone'} applied for "${(jobData['title'] as String?)?.trim() ?? 'your job'}"',
          'jobId': jobId,
          'jobTitle': (jobData['title'] as String?)?.trim() ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'seen': false,
        });
      }
    });
  }

  /// Real-time stream of open jobs, re-emits whenever the jobs collection changes.
  Stream<List<JobModel>> streamOpenJobs({int limit = 20}) {
    return _firestore
        .collection(AppConstants.jobsCollection)
        .limit(limit * 2)
        .snapshots()
        .map((snapshot) {
      var jobs = snapshot.docs
          .map((doc) => JobModel.fromMap(doc.data(), doc.id))
          .where((job) => job.status == AppConstants.jobStatusOpen)
          .toList();
      jobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return jobs.take(limit).toList();
    });
  }

  /// Real-time stream of jobs posted by a specific company/user (all statuses).
  Stream<List<JobModel>> streamCompanyJobs(String companyId,
      {int limit = 100}) {
    return _firestore
        .collection(AppConstants.jobsCollection)
        .where('companyId', isEqualTo: companyId)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      final jobs = snapshot.docs
          .map((doc) => JobModel.fromMap(doc.data(), doc.id))
          .toList();
      jobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return jobs;
    });
  }

  /// Fetch a single job by its document id (one-time read).
  Future<JobModel?> getJobById(String jobId) async {
    final doc = await _firestore
        .collection(AppConstants.jobsCollection)
        .doc(jobId)
        .get();
    if (!doc.exists || doc.data() == null) return null;
    return JobModel.fromMap(doc.data()!, doc.id);
  }

  /// Realtime stream for a single job document.
  Stream<JobModel?> streamJob(String jobId) {
    return _firestore
        .collection(AppConstants.jobsCollection)
        .doc(jobId)
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return JobModel.fromMap(doc.data()!, doc.id);
    });
  }

  /// Accept one applicant for a job.
  /// Sets selectedApplicant and moves job to in_progress.
  Future<void> acceptJobApplicant({
    required String jobId,
    required String applicantId,
    required String companyId,
  }) async {
    final jobRef =
        _firestore.collection(AppConstants.jobsCollection).doc(jobId);
    await _firestore.runTransaction((transaction) async {
      final jobSnap = await transaction.get(jobRef);
      if (!jobSnap.exists) throw Exception('Job not found.');

      final data = jobSnap.data()!;
      final ownerId =
          (data['companyId'] as String?) ?? (data['postedBy'] as String?) ?? '';
      if (ownerId != companyId) {
        throw Exception('Only job owner can accept applicants.');
      }

      final applicants = List<String>.from(data['applicants'] ?? const []);
      if (!applicants.contains(applicantId)) {
        throw Exception('Applicant not found in this job.');
      }

      transaction.update(jobRef, {
        'selectedApplicant': applicantId,
        'status': AppConstants.jobStatusInProgress,
        'updatedAt': FieldValue.serverTimestamp(),
        'applicationStatus.$applicantId': 'accepted',
      });
    });
  }

  /// Reject an applicant for a job.
  /// Keeps applicant history but marks status as rejected.
  Future<void> rejectJobApplicant({
    required String jobId,
    required String applicantId,
    required String companyId,
  }) async {
    final jobRef =
        _firestore.collection(AppConstants.jobsCollection).doc(jobId);
    await _firestore.runTransaction((transaction) async {
      final jobSnap = await transaction.get(jobRef);
      if (!jobSnap.exists) throw Exception('Job not found.');

      final data = jobSnap.data()!;
      final ownerId =
          (data['companyId'] as String?) ?? (data['postedBy'] as String?) ?? '';
      if (ownerId != companyId) {
        throw Exception('Only job owner can reject applicants.');
      }

      final applicants = List<String>.from(data['applicants'] ?? const []);
      if (!applicants.contains(applicantId)) {
        throw Exception('Applicant not found in this job.');
      }

      transaction.update(jobRef, {
        'updatedAt': FieldValue.serverTimestamp(),
        'applicationStatus.$applicantId': 'rejected',
      });
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

  Future<void> createReview(ReviewModel review,
      {String? reviewerRole, String? reviewerCompanyName}) async {
    if (review.reviewerId == review.skilledUserId) {
      throw Exception('You cannot review your own profile.');
    }

    final existingReview = await _firestore
        .collection(AppConstants.reviewsCollection)
        .where('skilledUserId', isEqualTo: review.skilledUserId)
        .where('reviewerId', isEqualTo: review.reviewerId)
        .limit(1)
        .get();
    if (existingReview.docs.isNotEmpty) {
      throw Exception('You have already reviewed this skilled person.');
    }

    // Build the review with role info (prefer fields already on the model)
    final effectiveRole = review.reviewerRole ?? reviewerRole;
    final effectiveCompanyName =
        review.reviewerCompanyName ?? reviewerCompanyName;
    final reviewWithRole = ReviewModel(
      id: review.id,
      skilledUserId: review.skilledUserId,
      reviewerId: review.reviewerId,
      reviewerName: review.reviewerName,
      reviewerPhoto: review.reviewerPhoto,
      rating: review.rating,
      comment: review.comment,
      images: review.images,
      createdAt: review.createdAt,
      reviewerRole: effectiveRole,
      reviewerCompanyName: effectiveCompanyName,
    );

    final batch = _firestore.batch();

    // Add review
    final reviewRef =
        _firestore.collection(AppConstants.reviewsCollection).doc();
    batch.set(reviewRef, reviewWithRole.toMap());

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
      final newRating =
          ((currentRating * currentCount) + review.rating) / newCount;

      batch.update(profileRef, {
        'rating': newRating,
        'reviewCount': newCount,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Future<List<ReviewModel>> getUserReviews(String userId,
      {int limit = 10}) async {
    final snapshot = await _firestore
        .collection(AppConstants.reviewsCollection)
        .where('skilledUserId', isEqualTo: userId)
        .get();

    final reviews = snapshot.docs
        .map((doc) => ReviewModel.fromMap(doc.data(), doc.id))
        .toList();

    // Sort: company reviews first, then by date descending
    reviews.sort((a, b) {
      if (a.isCompanyReview && !b.isCompanyReview) return -1;
      if (!a.isCompanyReview && b.isCompanyReview) return 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return reviews.take(limit).toList();
  }

  // ===== Company Endorsements =====

  String _endorsementDocId(String companyId, String skilledUserId) =>
      '${companyId}__$skilledUserId';

  /// Toggle a company's endorsement of a skilled user.
  /// Returns `true` if the endorsement was added, `false` if removed.
  Future<bool> toggleCompanyEndorsement({
    required String companyId,
    required String skilledUserId,
  }) async {
    final docId = _endorsementDocId(companyId, skilledUserId);
    final endorsementRef = _firestore
        .collection(AppConstants.companyEndorsementsCollection)
        .doc(docId);
    final profileRef = _firestore
        .collection(AppConstants.skilledUsersCollection)
        .doc(skilledUserId);

    final existing = await endorsementRef.get();
    final batch = _firestore.batch();

    if (existing.exists) {
      // Remove endorsement
      batch.delete(endorsementRef);
      batch.update(profileRef, {
        'companyEndorsementCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      return false;
    } else {
      // Add endorsement
      batch.set(endorsementRef, {
        'companyId': companyId,
        'skilledUserId': skilledUserId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.update(profileRef, {
        'companyEndorsementCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      return true;
    }
  }

  /// Check if a company has endorsed a skilled user.
  Future<bool> hasCompanyEndorsed({
    required String companyId,
    required String skilledUserId,
  }) async {
    final docId = _endorsementDocId(companyId, skilledUserId);
    final doc = await _firestore
        .collection(AppConstants.companyEndorsementsCollection)
        .doc(docId)
        .get();
    return doc.exists;
  }

  /// Stream the live endorsement state (endorsed or not) for a company-user pair.
  Stream<bool> streamCompanyEndorsementState({
    required String companyId,
    required String skilledUserId,
  }) {
    final docId = _endorsementDocId(companyId, skilledUserId);
    return _firestore
        .collection(AppConstants.companyEndorsementsCollection)
        .doc(docId)
        .snapshots()
        .map((snap) => snap.exists);
  }

  /// Stream the live company endorsement count of a skilled user.
  Stream<int> streamCompanyEndorsementCount(String skilledUserId) {
    return _firestore
        .collection(AppConstants.skilledUsersCollection)
        .doc(skilledUserId)
        .snapshots()
        .map((snap) =>
            snap.exists ? ((snap.data()?['companyEndorsementCount'] ?? 0) as int) : 0);
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

  Future<void> updateRequestStatus(String requestId, String status,
      {String? rejectionReason}) async {
    await _firestore
        .collection(AppConstants.requestsCollection)
        .doc(requestId)
        .update({
      'status': status,
      'rejectionReason': rejectionReason,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Send a silent reminder notification (stored in Firestore notifications collection)
  /// instead of posting a visible chat message.
  Future<void> sendReminderNotification({
    required String requestId,
    required String fromUserId,
    required String toUserId,
    required String requestTitle,
  }) async {
    await _firestore.collection('notifications').add({
      'type': 'work_request_reminder',
      'requestId': requestId,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'title': 'Reminder',
      'body': 'Work request "$requestTitle" is still awaiting your response.',
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> createHireRequest({
    required String requesterId,
    required String skilledUserId,
    required String title,
    required String description,
    DateTime? scheduledDate,
    String? hireType, // full_time, part_time, project_based
  }) async {
    if (requesterId == skilledUserId) {
      throw Exception('You cannot hire yourself.');
    }

    final requester = await getUserById(requesterId);
    final requesterRole = (requester?.role ?? '').toLowerCase().trim();
    if (requesterRole != AppConstants.roleCompany) {
      throw Exception('Only company accounts can send direct hire requests.');
    }

    final isCompanyVerified = await canCompanyHireSkilledPersons(requesterId);
    if (!isCompanyVerified) {
      throw Exception(
          'Company verification is required before sending hire requests.');
    }

    final normalizedTitle = title.trim();
    final normalizedDescription = description.trim();
    if (normalizedTitle.isEmpty || normalizedDescription.isEmpty) {
      throw Exception('Title and description are required.');
    }

    final existingPending = await _firestore
        .collection(AppConstants.requestsCollection)
        .where('customerId', isEqualTo: requesterId)
        .where('skilledUserId', isEqualTo: skilledUserId)
        .where('status', isEqualTo: AppConstants.requestStatusPending)
        .limit(1)
        .get();
    if (existingPending.docs.isNotEmpty) {
      throw Exception('You already have a pending hire request for this user.');
    }

    final skilledUser = await getUserById(skilledUserId);
    final chatId = await _ensureDirectChatBetweenUsers(
      userA: requester,
      userB: skilledUser,
      userAId: requesterId,
      userBId: skilledUserId,
    );

    final now = DateTime.now();
    final request = ServiceRequestModel(
      id: '',
      type: _chatWorkRequestType,
      chatId: chatId,
      customerId: requesterId,
      skilledUserId: skilledUserId,
      requesterId: requesterId,
      requesterName: requester?.name,
      requesterPhoto: requester?.profilePhoto,
      skilledUserName: skilledUser?.name,
      skilledUserPhoto: skilledUser?.profilePhoto,
      participants: [requesterId, skilledUserId],
      serviceId: 'direct_hire',
      title: normalizedTitle,
      description: normalizedDescription,
      status: AppConstants.requestStatusPending,
      scheduledDate: scheduledDate,
      hireType: hireType,
      requesterRole: (requester?.role ?? '').toLowerCase().trim(),
      createdAt: now,
      updatedAt: now,
    );
    return createServiceRequest(request);
  }

  Future<String> createChatWorkRequest({
    required String chatId,
    required String customerId,
    required String skilledUserId,
    required String title,
    required String description,
  }) async {
    if (customerId == skilledUserId) {
      throw Exception('Invalid participants.');
    }

    final normalizedTitle = title.trim();
    final normalizedDescription = description.trim();
    if (normalizedTitle.isEmpty || normalizedDescription.isEmpty) {
      throw Exception('Title and description are required.');
    }

    final customer = await getUserById(customerId);
    final customerRole = (customer?.role ?? '').toLowerCase().trim();
    if (customerRole != AppConstants.roleCustomer &&
        customerRole != AppConstants.roleCompany) {
      throw Exception(
          'Only customers or companies can create work requests in chat.');
    }

    final skilledProfile = await getSkilledUserProfile(skilledUserId);
    if (skilledProfile == null ||
        !_isSkilledProfileAadhaarVerified(skilledProfile)) {
      throw Exception(
        'This skilled profile is not available for work requests yet.',
      );
    }
    final skilledUser = await getUserById(skilledUserId);

    // No duplicate check — customers can submit multiple work requests per chat.
    final docRef = _firestore.collection(AppConstants.requestsCollection).doc();
    await docRef.set({
      'type': _chatWorkRequestType,
      'chatId': chatId,
      'customerId': customerId,
      'requesterId': customerId,
      'requesterName': customer?.name ?? '',
      'requesterPhoto': customer?.profilePhoto ?? '',
      'skilledUserId': skilledUserId,
      'skilledUserName': skilledUser?.name ?? '',
      'skilledUserPhoto': skilledUser?.profilePhoto ?? '',
      'participants': [customerId, skilledUserId],
      'serviceId': 'chat_work',
      'title': normalizedTitle,
      'description': normalizedDescription,
      'status': AppConstants.requestStatusPending,
      'requesterRole': customerRole, // 'company' or 'customer'
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  Stream<List<ServiceRequestModel>> streamChatWorkRequests(String chatId) {
    return _firestore
        .collection(AppConstants.requestsCollection)
        .where('chatId', isEqualTo: chatId) // single-field — no composite index
        .snapshots()
        .map((snapshot) {
      final requests = snapshot.docs
          .map((doc) => ServiceRequestModel.fromMap(doc.data(), doc.id))
          .where(_isWorkRequestLike) // type filter in memory
          .toList();
      requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return requests;
    });
  }

  Stream<List<ServiceRequestModel>> streamUserWorkRequests(String userId) {
    return _firestore
        .collection(AppConstants.requestsCollection)
        .where('participants',
            arrayContains: userId) // single-field — no composite index
        .snapshots()
        .map((snapshot) {
      final requests = snapshot.docs
          .map((doc) => ServiceRequestModel.fromMap(doc.data(), doc.id))
          .where(_isWorkRequestLike) // type filter in memory
          .toList();
      requests.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return requests;
    });
  }

  Stream<List<ServiceRequestModel>> streamSkilledRequests(String skilledUserId) {
    return _firestore
        .collection(AppConstants.requestsCollection)
        .where('skilledUserId', isEqualTo: skilledUserId)
        .snapshots()
        .map((snapshot) {
      final requests = snapshot.docs
          .map((doc) => ServiceRequestModel.fromMap(doc.data(), doc.id))
          .where(_isWorkRequestLike)
          .toList();
      requests.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return requests;
    });
  }

  Future<List<ServiceRequestModel>> getLatestUserWorkRequests(
    String userId, {
    int limit = 20,
  }) async {
    final snapshot = await _firestore
        .collection(AppConstants.requestsCollection)
        .where('participants',
            arrayContains: userId) // single-field — no composite index
        .get();

    final requests = snapshot.docs
        .map((doc) => ServiceRequestModel.fromMap(doc.data(), doc.id))
        .where(_isWorkRequestLike) // type filter in memory
        .toList();
    requests.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (requests.length > limit) {
      return requests.sublist(0, limit);
    }
    return requests;
  }

  Future<List<OrderModel>> getLatestOrdersForUser(
    String userId, {
    int limit = 20,
  }) async {
    // Run each query independently so a permission error on one field
    // (e.g. deliveryPartnerId for a non-delivery user) doesn't block others.
    Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> safeDocs(
        Query<Map<String, dynamic>> q) async {
      try {
        return (await q.get()).docs;
      } catch (_) {
        return const [];
      }
    }

    final results = await Future.wait([
      safeDocs(_firestore
          .collection(AppConstants.ordersCollection)
          .where('buyerId', isEqualTo: userId)),
      safeDocs(_firestore
          .collection(AppConstants.ordersCollection)
          .where('sellerId', isEqualTo: userId)),
      safeDocs(_firestore
          .collection(AppConstants.ordersCollection)
          .where('deliveryPartnerId', isEqualTo: userId)),
    ]);

    final ordersById = <String, OrderModel>{};
    for (final docs in results) {
      for (final doc in docs) {
        ordersById[doc.id] = OrderModel.fromMap(doc.data(), doc.id);
      }
    }

    final orders = ordersById.values.toList();
    orders.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (orders.length > limit) {
      return orders.sublist(0, limit);
    }
    return orders;
  }

  Future<void> respondToChatWorkRequest({
    required String requestId,
    required String skilledUserId,
    required bool approve,
    String? responseMessage,
  }) async {
    final requestRef =
        _firestore.collection(AppConstants.requestsCollection).doc(requestId);
    final skilledProfileRef = _firestore
        .collection(AppConstants.skilledUsersCollection)
        .doc(skilledUserId);

    String? customerId;
    String? requestTitle;
    String? requestDescription;
    String? originChatId;

    await _firestore.runTransaction((transaction) async {
      final requestSnap = await transaction.get(requestRef);
      if (!requestSnap.exists) {
        throw Exception('Work request not found.');
      }

      final data = requestSnap.data() ?? <String, dynamic>{};
      final requestType =
          ((data['type'] as String?) ?? '').toLowerCase().trim();
      final serviceId =
          ((data['serviceId'] as String?) ?? '').toLowerCase().trim();
      if (requestType != _chatWorkRequestType &&
          serviceId != _legacyDirectHireServiceId) {
        throw Exception('Invalid work request type.');
      }

      final requestSkilledUserId =
          ((data['skilledUserId'] as String?) ?? '').trim();
      if (requestSkilledUserId != skilledUserId) {
        throw Exception('Only the skilled person can respond to this request.');
      }

      final status = ((data['status'] as String?) ?? '').toLowerCase().trim();
      if (status != AppConstants.requestStatusPending) {
        throw Exception('This work request has already been processed.');
      }

      customerId =
          ((data['customerId'] ?? data['requesterId']) as String?)?.trim();
      requestTitle = (data['title'] as String?)?.trim() ?? 'Unnamed Project';
      requestDescription = (data['description'] as String?)?.trim() ?? '';
      originChatId = (data['chatId'] as String?)?.trim();

      final nextStatus = approve
          ? AppConstants.requestStatusAccepted
          : AppConstants.requestStatusRejected;

      transaction.update(requestRef, {
        'status': nextStatus,
        'responseMessage': responseMessage?.trim(),
        'respondedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (approve) {
        transaction.set(
          skilledProfileRef,
          {
            'projectCount': FieldValue.increment(1),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    });

    // After transaction: add to customer/company assignedProjects
    if (approve && customerId != null && customerId!.isNotEmpty) {
      final workChatId = await _ensureWorkProjectChat(
        requestId: requestId,
        customerId: customerId!,
        skilledUserId: skilledUserId,
        originChatId: originChatId,
        requestTitle: requestTitle,
      );
      await requestRef.set({
        'workChatId': workChatId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final projectEntry = {
        'requestId': requestId,
        'title': requestTitle,
        'description': requestDescription,
        'skilledUserId': skilledUserId,
        'workChatId': workChatId,
        'status': 'accepted',
        'assignedAt': DateTime.now().toIso8601String(),
      };
      await _addProjectToUserProfile(customerId!, projectEntry);
    }
  }

  Future<String> ensureWorkChatForRequest({
    required String requestId,
  }) async {
    final requestRef =
        _firestore.collection(AppConstants.requestsCollection).doc(requestId);
    final snap = await requestRef.get();
    if (!snap.exists) {
      throw Exception('Work request not found.');
    }
    final data = snap.data() ?? <String, dynamic>{};
    final type = ((data['type'] as String?) ?? '').toLowerCase().trim();
    final serviceId =
        ((data['serviceId'] as String?) ?? '').toLowerCase().trim();
    if (type != _chatWorkRequestType &&
        serviceId != _legacyDirectHireServiceId) {
      throw Exception('Invalid work request type.');
    }
    final status = ((data['status'] as String?) ?? '').toLowerCase().trim();
    if (status != AppConstants.requestStatusAccepted &&
        status != AppConstants.requestStatusCompleted) {
      throw Exception('Work chat is available only for accepted projects.');
    }

    final existing = (data['workChatId'] as String?)?.trim() ?? '';
    if (existing.isNotEmpty) return existing;

    final customerId =
        ((data['customerId'] ?? data['requesterId']) as String?)?.trim() ?? '';
    final skilledUserId = (data['skilledUserId'] as String?)?.trim() ?? '';
    if (customerId.isEmpty || skilledUserId.isEmpty) {
      throw Exception('Invalid work request participants.');
    }

    final workChatId = await _ensureWorkProjectChat(
      requestId: requestId,
      customerId: customerId,
      skilledUserId: skilledUserId,
      originChatId: (data['chatId'] as String?)?.trim(),
      requestTitle: (data['title'] as String?)?.trim(),
    );
    await requestRef.set({
      'workChatId': workChatId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return workChatId;
  }

  /// Adds a project entry to the customer_profiles or company_profiles assignedProjects array.
  Future<void> _addProjectToUserProfile(
      String userId, Map<String, dynamic> projectEntry) async {
    try {
      final user = await getUserById(userId);
      final role = UserRoles.normalizeRole(user?.role ?? '');

      if (role == UserRoles.customer) {
        await _firestore
            .collection(AppConstants.customerProfilesCollection)
            .doc(userId)
            .set({
          'assignedProjects': FieldValue.arrayUnion([projectEntry]),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else if (role == UserRoles.company) {
        await _firestore
            .collection(AppConstants.companyProfilesCollection)
            .doc(userId)
            .set({
          'assignedProjects': FieldValue.arrayUnion([projectEntry]),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Failed to add project to user profile: $e');
    }
  }

  Future<Map<String, dynamic>> getShopSettings(String userId) async {
    final doc = await _firestore
        .collection(AppConstants.skilledUsersCollection)
        .doc(userId)
        .get();
    const defaults = <String, dynamic>{
      'enableDeliveryIfAvailable': true,
      'maxDeliveryQuantity': 10,
    };
    if (!doc.exists) return defaults;
    final data = doc.data();
    final settings = data?['shopSettings'];
    if (settings is Map) {
      return {
        ...defaults,
        ...Map<String, dynamic>.from(settings),
      };
    }
    return defaults;
  }

  /// Real-time stream of shop settings from the skilled user's document.
  /// Emits the merged settings map (with defaults) whenever it changes.
  Stream<Map<String, dynamic>> streamShopSettings(String userId) {
    const defaults = <String, dynamic>{
      'enableDeliveryIfAvailable': true,
      'maxDeliveryQuantity': 10,
    };
    return _firestore
        .collection(AppConstants.skilledUsersCollection)
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return defaults;
      final settings = doc.data()?['shopSettings'];
      if (settings is Map) {
        return {
          ...defaults,
          ...Map<String, dynamic>.from(settings),
        };
      }
      return defaults;
    });
  }

  Future<void> updateShopSettings(
    String userId,
    Map<String, dynamic> settings,
  ) async {
    await _firestore
        .collection(AppConstants.skilledUsersCollection)
        .doc(userId)
        .set({
      'shopSettings': settings,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
        .where('verificationStatus',
            isEqualTo: AppConstants.verificationPending)
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
      'visibility': AppConstants.visibilityPrivate,
      'isVerified': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ===== Reports (extra admin methods – submitProfileReport is defined earlier) ======

  Future<void> submitChatReport({
    required String reporterId,
    required String reportedUserId,
    required String chatId,
    required String reason,
    String? details,
  }) async {
    await _firestore.collection(AppConstants.reportsCollection).add({
      'type': 'chat',
      'reporterId': reporterId,
      'reportedUserId': reportedUserId,
      'chatId': chatId,
      'reason': reason,
      'details': details ?? '',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<Map<String, dynamic>>> getAllReports({int limit = 100}) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.reportsCollection)
          .limit(limit)
          .get();
      final reports =
          snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      reports.sort((a, b) {
        final aTime = a['createdAt'];
        final bTime = b['createdAt'];
        if (aTime is Timestamp && bTime is Timestamp) {
          return bTime.compareTo(aTime);
        }
        return 0;
      });
      return reports;
    } catch (e) {
      debugPrint('getAllReports error: $e');
      return [];
    }
  }

  Future<void> updateReportStatus(
    String reportId,
    String status, {
    String? adminNotes,
    String? adminId,
  }) async {
    await _firestore
        .collection(AppConstants.reportsCollection)
        .doc(reportId)
        .update({
      'status': status,
      if (adminNotes != null) 'adminNotes': adminNotes,
      if (adminId != null) 'resolvedBy': adminId,
      'resolvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ===== Admin - User Management =====

  Future<List<UserModel>> getAllUsers({int limit = 100}) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .limit(limit)
          .get();
      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('getAllUsers error: $e');
      return [];
    }
  }

  Future<void> suspendUser(String userId, {required bool suspend}) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .update({
      'isSuspended': suspend,
      'suspendedAt': suspend ? FieldValue.serverTimestamp() : null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> adminDeleteUserAccount(String userId) async {
    final batch = _firestore.batch();

    // Delete user doc
    batch.delete(
        _firestore.collection(AppConstants.usersCollection).doc(userId));

    // Delete profile doc (skilled/customer/company)
    batch.delete(
        _firestore.collection(AppConstants.skilledUsersCollection).doc(userId));
    batch.delete(_firestore
        .collection(AppConstants.customerProfilesCollection)
        .doc(userId));
    batch.delete(_firestore
        .collection(AppConstants.companyProfilesCollection)
        .doc(userId));

    await batch.commit();
  }

  /// Cancel a pending chat work request (customer only).
  Future<void> cancelChatWorkRequest({
    required String requestId,
    required String customerId,
  }) async {
    final ref =
        _firestore.collection(AppConstants.requestsCollection).doc(requestId);
    final snap = await ref.get();
    if (!snap.exists) throw Exception('Request not found.');
    final data = snap.data()!;
    if ((data['customerId'] ?? data['requesterId']) != customerId) {
      throw Exception('Not authorized to cancel this request.');
    }
    if (data['status'] != AppConstants.requestStatusPending) {
      throw Exception('Only pending requests can be cancelled.');
    }
    await ref.update({
      'status': 'cancelled',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ===== Animated Avatar Config =====

  /// Save custom animated avatar configuration for any user role.
  /// Stores in the `users` collection so it's universally accessible.
  Future<void> saveAvatarConfig(String userId, dynamic avatarConfig) async {
    final configMap = avatarConfig is Map<String, dynamic>
        ? avatarConfig
        : (avatarConfig as dynamic).toMap() as Map<String, dynamic>;
    await _firestore.collection(AppConstants.usersCollection).doc(userId).set(
      {
        'avatarConfig': configMap,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Remove the custom animated avatar (revert to photo / emoji / letter).
  Future<void> removeAvatarConfig(String userId) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .update(
      {
        'avatarConfig': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }
}
