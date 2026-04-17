# Project Main Coding Document

This document contains only the main functional coding blocks and important logical parts from the project.

## Main Coding

### 1) App bootstrap and Firebase setup
~~~dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter Error: ${details.exception}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught async error: $error');
    return true;
  };

  bool firebaseInitialized = false;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    firebaseInitialized = true;

    if (kIsWeb) {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: false,
      );
    } else {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    }
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  runApp(MyApp(firebaseInitialized: firebaseInitialized));
}
~~~

### 2) Auth state listener and role-based capabilities
~~~dart
class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _currentUser;
  StreamSubscription<User?>? _authSub;
  int _authRevision = 0;

  String? get userRole => UserRoles.normalizeRole(_currentUser?.role);
  bool get isCustomer => userRole == UserRoles.customer;
  bool get isCompany => userRole == UserRoles.company;
  bool get isSkilledPerson => userRole == UserRoles.skilledPerson;
  bool get isAdmin => userRole == UserRoles.admin;

  bool get canPostJobs =>
      _currentUser != null && UserRoles.canPostJobs(userRole ?? '');
  bool get canApplyToJobs =>
      _currentUser != null && UserRoles.canApplyToJobs(userRole ?? '');

  AuthProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    _authSub = _authService.authStateChanges.listen((User? user) {
      final revision = ++_authRevision;
      if (user != null) {
        _loadUserData(user.uid, revision);
      } else {
        _currentUser = null;
        notifyListeners();
      }
    });
  }
}
~~~

### 3) Resilient sign-in logic with Firestore retry fallback
~~~dart
Future<UserModel?> signInWithEmail({
  required String email,
  required String password,
}) async {
  final userCredential = await _auth.signInWithEmailAndPassword(
    email: email,
    password: password,
  );

  final user = userCredential.user;
  if (user == null) {
    throw 'Authentication failed';
  }

  final doc = await _getUserDocWithRetry(user.uid);

  if (doc != null && !doc.exists) {
    final userModel = UserModel(
      uid: user.uid,
      email: email,
      name: email.split('@').first,
      role: AppConstants.roleCustomer,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(user.uid)
        .set(userModel.toMap());

    return userModel;
  }

  if (doc == null) {
    return UserModel(
      uid: user.uid,
      email: user.email ?? email,
      name: user.displayName ?? email.split('@').first,
      role: AppConstants.roleCustomer,
      profilePhoto: user.photoURL,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  final data = doc.data();
  if (data == null) {
    throw 'User data is empty';
  }

  return UserModel.fromMap(data, user.uid);
}

Future<DocumentSnapshot<Map<String, dynamic>>?> _getUserDocWithRetry(
  String uid,
) async {
  const maxAttempts = 4;

  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .get(const GetOptions(source: Source.serverAndCache));
    } on FirebaseException catch (e) {
      final retryable = e.code == 'permission-denied' ||
          e.code == 'unavailable' ||
          e.code == 'aborted' ||
          e.code == 'deadline-exceeded';
      if (!retryable || attempt == maxAttempts) {
        break;
      }
      await Future.delayed(Duration(milliseconds: 250 * attempt));
    }
  }

  return null;
}
~~~

### 4) Splash routing based on persisted auth
~~~dart
Future<void> _checkAuthStatus() async {
  await Future.delayed(const Duration(seconds: 2));

  if (!mounted) return;

  final firebaseUser = FirebaseAuth.instance.currentUser;

  if (firebaseUser != null) {
    try {
      await firebaseUser.reload();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainNavigation()),
        );
      }
    } catch (_) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  } else {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }
}
~~~

### 5) Role-based screen mapping in main navigation
~~~dart
int _getChatTabIndex(String role) {
  switch (role) {
    case UserRoles.customer:
      return 3;
    case UserRoles.company:
      return 3;
    case UserRoles.skilledPerson:
      return 3;
    case UserRoles.deliveryPartner:
      return 1;
    default:
      return 3;
  }
}

List<Widget> _getScreensForRole(String role) {
  switch (role) {
    case UserRoles.customer:
      return const [HomeScreen(), ShopScreen(), CartScreen(), ChatsScreen(), ProfileTabScreen()];
    case UserRoles.company:
      return const [HomeScreen(), JobsScreen(), ShopScreen(), ChatsScreen(), ProfileTabScreen()];
    case UserRoles.skilledPerson:
      return const [HomeScreen(), JobsScreen(), MyShopScreen(), ChatsScreen(), ProfileTabScreen()];
    case UserRoles.deliveryPartner:
      return const [DeliveryScreen(), ChatsScreen(), ProfileTabScreen()];
    default:
      return const [HomeScreen(), JobsScreen(), ShopScreen(), ChatsScreen(), ProfileTabScreen()];
  }
}
~~~

## Important Logical Parts and Their Code

### 1) Direct chat creation with privacy and block checks
~~~dart
Future<String> getOrCreateChat(
  String user1Id,
  String user2Id,
  Map<String, dynamic> user1Details,
  Map<String, dynamic> user2Details,
) async {
  if (user1Id == user2Id) {
    throw Exception('You cannot start a chat with yourself.');
  }

  final isBlocked = await _isUserBlockedEitherWay(user1Id, user2Id);
  if (isBlocked) {
    throw Exception('Chat is unavailable due to user privacy settings.');
  }

  final sortedParticipants = [user1Id, user2Id]..sort();
  final deterministicChatId =
      '${sortedParticipants[0]}__${sortedParticipants[1]}';

  // 1) Try deterministic chat id
  // 2) Try existing 2-user chat lookup
  // 3) Create fallback chat doc if needed
  return _createChatWithFallbackId(
    preferredChatId: deterministicChatId,
    participants: sortedParticipants,
    participantDetails: {
      user1Id: _normalizeParticipantDetails(user1Details),
      user2Id: _normalizeParticipantDetails(user2Details),
    },
    chatCategory: _deriveDirectChatCategory(user1Details, user2Details),
  );
}
~~~

### 2) Direct purchase flow with stock and delivery workflow rules
~~~dart
Future<OrderModel> purchaseProductDirect({
  required String userId,
  required ProductModel product,
  int quantity = 1,
  String paymentMethod = 'gpay_simulation',
  String? paymentReference,
  String? deliveryAddress,
  String? deliveryLocation,
}) async {
  if (quantity <= 0) throw Exception('Quantity must be at least 1.');
  if (userId == product.userId) throw Exception('You cannot buy your own product.');

  final shopSettings = await getShopSettings(product.userId);
  final userSettings = await getUserSettings(product.userId);

  final profileWorkflowEnabled =
      (userSettings['enableShopDeliveryWorkflow'] as bool?) ?? false;
  final allowDeliveryIfAvailable =
      (shopSettings['enableDeliveryIfAvailable'] as bool?) ?? true;
  final maxQty = (shopSettings['maxDeliveryQuantity'] as int?) ?? 10;

  final deliveryByPartner =
      profileWorkflowEnabled && allowDeliveryIfAvailable && quantity <= maxQty;

  await _firestore.runTransaction((transaction) async {
    final productRef = _firestore
        .collection(AppConstants.productsCollection)
        .doc(product.id);
    final snap = await transaction.get(productRef);

    if (!snap.exists || snap.data() == null) {
      throw Exception('Product no longer exists.');
    }

    final latest = ProductModel.fromMap(snap.data()!, snap.id);
    if (!latest.isAvailable || latest.stock < quantity) {
      throw Exception('Insufficient stock.');
    }

    transaction.update(productRef, {'stock': latest.stock - quantity});
    // order creation and payment metadata write happen in same flow
  });

  // returns created order after transaction + metadata writes
}
~~~

### 3) Cart checkout as batched multi-order transaction-like flow
~~~dart
Future<List<OrderModel>> checkoutCart(
  String userId, {
  String paymentMethod = 'gpay_simulation',
}) async {
  final cartItems = await getCartItems(userId);
  if (cartItems.isEmpty) throw Exception('Your cart is empty.');

  final batch = _firestore.batch();
  final createdOrders = <OrderModel>[];

  for (final item in cartItems) {
    final productRef = _firestore
        .collection(AppConstants.productsCollection)
        .doc(item.productId);
    final productSnap = await productRef.get();
    if (!productSnap.exists) throw Exception('Product missing.');

    final latest = ProductModel.fromMap(productSnap.data()!, item.productId);
    if (!latest.isAvailable || latest.stock < item.quantity) {
      throw Exception('Insufficient stock for ${latest.name}.');
    }

    final orderRef = _firestore.collection(AppConstants.ordersCollection).doc();
    batch.update(productRef, {'stock': latest.stock - item.quantity});
    batch.delete(_firestore
        .collection(AppConstants.cartsCollection)
        .doc(userId)
        .collection('items')
        .doc(item.productId));

    // build order model and batch.set(orderRef, order.toMap())
  }

  await batch.commit();
  return createdOrders;
}
~~~

### 4) Job application with role and ownership safeguards
~~~dart
Future<void> applyForJob(String jobId, String userId) async {
  final jobRef = _firestore.collection(AppConstants.jobsCollection).doc(jobId);
  final userRef = _firestore.collection(AppConstants.usersCollection).doc(userId);

  await _firestore.runTransaction((transaction) async {
    final jobSnap = await transaction.get(jobRef);
    if (!jobSnap.exists) throw Exception('Job not found.');

    final userSnap = await transaction.get(userRef);
    if (!userSnap.exists) throw Exception('User not found.');

    final jobData = jobSnap.data()!;
    final userData = userSnap.data()!;
    final role = (userData['role'] as String?)?.trim().toLowerCase() ?? '';

    if (role != AppConstants.roleSkilledUser) {
      throw Exception('Only skilled users can apply for jobs.');
    }
    if ((jobData['status'] as String?) != AppConstants.jobStatusOpen) {
      throw Exception('This job is no longer open.');
    }
    if ((jobData['companyId'] as String?) == userId) {
      throw Exception('You cannot apply to your own job.');
    }

    transaction.update(jobRef, {
      'applicants': FieldValue.arrayUnion([userId]),
      'applicationStatus.$userId': 'pending',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  });
}
~~~

### 5) Job acceptance creates selected status, chat, and notification
~~~dart
Future<String> acceptJobApplicant({
  required String jobId,
  required String applicantId,
  required String companyId,
}) async {
  final jobRef = _firestore.collection(AppConstants.jobsCollection).doc(jobId);

  await _firestore.runTransaction((transaction) async {
    final jobSnap = await transaction.get(jobRef);
    if (!jobSnap.exists) throw Exception('Job not found.');

    final data = jobSnap.data()!;
    final ownerId =
        (data['companyId'] as String?) ?? (data['postedBy'] as String?) ?? '';
    if (ownerId != companyId) {
      throw Exception('Only job owner can accept applicants.');
    }

    transaction.update(jobRef, {
      'selectedApplicant': applicantId,
      'status': AppConstants.jobStatusInProgress,
      'applicationStatus.$applicantId': 'accepted',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  });

  final chatId = await ensureJobApplicationChat(
    jobId: jobId,
    companyId: companyId,
    skilledUserId: applicantId,
    skipStatusCheck: true,
  );

  await _firestore.collection('notifications').add({
    'toUserId': applicantId,
    'fromUserId': companyId,
    'type': 'jobAccepted',
    'jobId': jobId,
    'chatId': chatId,
    'createdAt': FieldValue.serverTimestamp(),
    'seen': false,
  });

  return chatId;
}
~~~

### 6) Chat work-request lifecycle (create, respond, convert to work-chat)
~~~dart
Future<String> createChatWorkRequest({
  required String chatId,
  required String customerId,
  required String skilledUserId,
  required String title,
  required String description,
}) async {
  if (customerId == skilledUserId) throw Exception('Invalid participants.');

  final customer = await getUserById(customerId);
  final customerRole = (customer?.role ?? '').toLowerCase().trim();
  if (customerRole != AppConstants.roleCustomer &&
      customerRole != AppConstants.roleCompany) {
    throw Exception('Only customers or companies can create work requests in chat.');
  }

  final docRef = _firestore.collection(AppConstants.requestsCollection).doc();
  await docRef.set({
    'type': 'chat_work_request',
    'chatId': chatId,
    'customerId': customerId,
    'skilledUserId': skilledUserId,
    'title': title.trim(),
    'description': description.trim(),
    'status': AppConstants.requestStatusPending,
    'participants': [customerId, skilledUserId],
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  });

  return docRef.id;
}

Future<void> respondToChatWorkRequest({
  required String requestId,
  required String skilledUserId,
  required bool approve,
}) async {
  final requestRef = _firestore.collection(AppConstants.requestsCollection).doc(requestId);

  await _firestore.runTransaction((transaction) async {
    final requestSnap = await transaction.get(requestRef);
    if (!requestSnap.exists) throw Exception('Work request not found.');

    final nextStatus = approve
        ? AppConstants.requestStatusAccepted
        : AppConstants.requestStatusRejected;

    transaction.update(requestRef, {
      'status': nextStatus,
      'respondedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  });
}
~~~

### 7) App lock: secure hash and biometric unlock
~~~dart
class AppLockService {
  static const _hashVersionPrefix = 'v2';
  static const _hashRounds = 2048;

  Future<void> setPinLock(String pin) async {
    final prefs = await _safePrefs();
    if (prefs == null) return;
    await prefs.setBool('app_lock_enabled', true);
    await prefs.setString('app_lock_type', 'pin');
    await prefs.setString('app_lock_secret_hash', _buildSecretHash(pin.trim()));
  }

  Future<bool> authenticateBiometric() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Authenticate to unlock SkillShare',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }

  bool verifySecret({required String input, required String? secretHash}) {
    if (secretHash == null || secretHash.isEmpty) return false;

    final normalizedInput = input.trim();
    if (secretHash.startsWith('$_hashVersionPrefix:')) {
      final parts = secretHash.split(':');
      if (parts.length != 3) return false;

      final salt = parts[1];
      final storedHash = parts[2];
      return _hashWithSalt(normalizedInput, salt) == storedHash;
    }

    return _legacyHash(normalizedInput) == secretHash;
  }
}
~~~

## Notes

- This document intentionally keeps only functional coding blocks.
- UI styling and non-core rendering code are omitted.
- Code is simplified in places for readability while preserving project logic.
