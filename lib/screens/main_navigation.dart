import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/app_constants.dart';
import '../utils/user_roles.dart';
import '../services/firestore_service.dart';
import '../services/chat_service.dart';
import 'home/home_screen.dart';
import 'jobs/jobs_screen.dart';
import 'shop/shop_screen.dart';
import 'shop/cart_screen.dart';
import 'chat/chats_screen.dart';
import 'profile/profile_tab_screen.dart';
import 'portfolio/my_shop_screen.dart';
import 'admin/admin_screen.dart';
import 'delivery/delivery_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final FirestoreService _firestoreService = FirestoreService();
  final ChatService _chatService = ChatService();

  // ── In-app notification banners ─────────────────────────────────────────
  StreamSubscription<QuerySnapshot>? _notifSub;
  StreamSubscription<QuerySnapshot>? _orderNotifSub;
  StreamSubscription<Map<String, dynamic>>? _settingsSub;
  int _prevNotifCount = -1; // -1 means "not yet initialised"
  int _prevOrderNotifCount = -1;
  OverlayEntry? _bannerEntry;
  Timer? _bannerTimer;
  String? _watchingUserId;
  bool _pushNotificationsEnabled = true;
  bool _jobNotificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _applyInAppSystemUi();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initBannerStream());
  }

  void _applyInAppSystemUi() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Color(0xFFE0E0E0),
      ),
    );
  }

  void _restoreAuthSystemUi() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  void _initBannerStream() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final uid = auth.currentUser?.uid;
    // Capture role synchronously — used inside the async listener to avoid
    // accessing BuildContext across an async gap.
    final capturedRole = auth.userRole ?? UserRoles.customer;
    if (uid == null || uid == _watchingUserId) return;
    _watchingUserId = uid;
    _notifSub?.cancel();
    _orderNotifSub?.cancel();
    _settingsSub?.cancel();

    _settingsSub = _firestoreService.userSettingsStream(uid).listen((settings) {
      _pushNotificationsEnabled = settings['pushNotifications'] as bool? ?? true;
      _jobNotificationsEnabled = settings['jobNotifications'] as bool? ?? true;
    });

    _prevNotifCount = -1;
    _prevOrderNotifCount = -1;
    _notifSub = FirebaseFirestore.instance
        .collection(AppConstants.requestsCollection)
        .where('participants', arrayContains: uid)
        .snapshots()
        .listen((snap) {
      final count = snap.docs.length;
      if (_prevNotifCount == -1) {
        // Baseline – don\'t show banner on first load
        _prevNotifCount = count;
        return;
      }
      if (count > _prevNotifCount) {
        if (!_pushNotificationsEnabled || !_jobNotificationsEnabled) {
          _prevNotifCount = count;
          return;
        }
        // New notification arrived
        final newDocs = snap.docs.where((d) {
          final ts = d.data()['updatedAt'] as Timestamp?;
          return ts != null &&
              ts
                  .toDate()
                  .isAfter(DateTime.now().subtract(const Duration(minutes: 5)));
        }).toList();
        if (newDocs.isNotEmpty) {
          final data = newDocs.first.data();
          final chatIdx = _getChatTabIndex(capturedRole);
          _showTopBanner(
            'New work request',
            (data['title'] as String?) ??
                (data['description'] as String?) ??
                'You have a new update',
            navigateToIndex: chatIdx,
          );
        }
      }
      _prevNotifCount = count;
    });

    if (capturedRole == UserRoles.skilledPerson) {
      _orderNotifSub = FirebaseFirestore.instance
          .collection(AppConstants.ordersCollection)
          .where('sellerId', isEqualTo: uid)
          .snapshots()
          .listen((snap) {
        final count = snap.docs.length;
        if (_prevOrderNotifCount == -1) {
          _prevOrderNotifCount = count;
          return;
        }
        if (count > _prevOrderNotifCount) {
          if (!_pushNotificationsEnabled) {
            _prevOrderNotifCount = count;
            return;
          }
          final newDocs = snap.docs.where((d) {
            final ts = d.data()['createdAt'] as Timestamp?;
            return ts != null &&
                ts.toDate().isAfter(
                    DateTime.now().subtract(const Duration(minutes: 5)));
          }).toList();
          if (newDocs.isNotEmpty) {
            final data = newDocs.first.data();
            _showTopBanner(
              'New shop order',
              '${(data['productName'] as String?) ?? 'Product'} • Qty ${(data['quantity'] as num?)?.toInt() ?? 1}',
              navigateToIndex: 2, // My Shop tab for skilled users
            );
          }
        }
        _prevOrderNotifCount = count;
      });
    }
  }

  void _showTopBanner(String title, String subtitle, {int? navigateToIndex}) {
    _bannerTimer?.cancel();
    _bannerEntry?.remove();

    final overlay = Overlay.of(context);
    _bannerEntry = OverlayEntry(
      builder: (_) => _InAppBanner(
        title: title,
        subtitle: subtitle,
        onDismiss: () {
          _bannerEntry?.remove();
          _bannerEntry = null;
        },
        onTap: navigateToIndex != null
            ? () {
                _bannerEntry?.remove();
                _bannerEntry = null;
                if (mounted) setState(() => _currentIndex = navigateToIndex);
              }
            : null,
      ),
    );
    overlay.insert(_bannerEntry!);
    _bannerTimer = Timer(const Duration(seconds: 4), () {
      _bannerEntry?.remove();
      _bannerEntry = null;
    });
  }

  @override
  void dispose() {
    _restoreAuthSystemUi();
    _notifSub?.cancel();
    _orderNotifSub?.cancel();
    _settingsSub?.cancel();
    _bannerTimer?.cancel();
    _bannerEntry?.remove();
    _bannerEntry = null;
    super.dispose();
  }
  // ────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userRole = authProvider.userRole ?? UserRoles.customer;
    final currentUserId = authProvider.currentUser?.uid;

    // Start/reattach the banner stream when the logged-in user changes
    _initBannerStream();

    // Get role-specific screens and navigation items
    final screens = _getScreensForRole(userRole);
    final navItems = _getNavItemsForRole(userRole);

    // Bounds-check currentIndex when role changes (screen count may differ)
    if (_currentIndex >= screens.length) {
      _currentIndex = 0;
    }

    // Admin has a special simple layout (single screen)
    if (userRole == UserRoles.admin) {
      return const PopScope(
        canPop: false,
        child: AdminScreen(),
      );
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: screens,
        ),
        bottomNavigationBar:
            _buildCustomBottomNav(navItems, userRole, currentUserId),
      ),
    );
  }

  // ── Custom white bottom nav with per-tab gradient circles ──────────────
  Widget _buildCustomBottomNav(
    List<BottomNavigationBarItem> rawItems,
    String role,
    String? uid,
  ) {
    final chatIdx = _getChatTabIndex(role);
    const cartIdx = 2;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 80,
          child: Row(
            children: List.generate(rawItems.length, (i) {
              final selected = i == _currentIndex;
              final g0 = _getGradientColor(i, 0, role);
              final g1 = _getGradientColor(i, 2, role);
              final icData = _getNavIcon(role, i);
              final label = rawItems[i].label ?? '';

              // Base icon (white when selected, grey when not)
              Widget iconW = Icon(
                icData,
                color: selected ? Colors.white : Colors.grey[500],
                size: 22,
              );

              // Badge overlay for cart / chat / work requests
              if (uid != null) {
                if (role == UserRoles.customer && i == cartIdx) {
                  iconW = StreamBuilder<List<dynamic>>(
                    stream: _firestoreService.streamCartItems(uid),
                    builder: (_, snap) {
                      final cnt = snap.data?.fold<int>(0,
                              (a, x) => a + ((x as dynamic).quantity as int)) ??
                          0;
                      return _navBadge(icData, selected, cnt);
                    },
                  );
                } else if (i == chatIdx) {
                  // Stack both chat unread (red) and work request (amber) badges
                  iconW = StreamBuilder<List<dynamic>>(
                    stream: _chatService.getUserChats(uid),
                    builder: (_, chatSnap) {
                      int unread = 0;
                      for (final c in chatSnap.data ?? []) {
                        final u = (c as dynamic).unreadCount;
                        if (u is Map) unread += (u[uid] as int?) ?? 0;
                      }
                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection(AppConstants.requestsCollection)
                            .where('participants', arrayContains: uid)
                            .snapshots(),
                        builder: (_, reqSnap) {
                          int pendingWork = 0;
                          if (reqSnap.hasData) {
                            for (final doc in reqSnap.data!.docs) {
                              final d = doc.data() as Map<String, dynamic>;
                              final status = (d['status'] as String?) ?? '';
                              final type = (d['type'] as String?) ?? '';
                              final serviceId =
                                  (d['serviceId'] as String?) ?? '';
                              if ((type == 'chat_work_request' ||
                                      serviceId == 'direct_hire') &&
                                  status == 'pending') {
                                pendingWork++;
                              }
                            }
                          }
                          return _navDoubleBadge(
                            Icons.chat,
                            selected,
                            unread,
                            pendingWork,
                          );
                        },
                      );
                    },
                  );
                }
              }

              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _currentIndex = i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 8),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOut,
                        width: 44,
                        height: 44,
                        decoration: selected
                            ? BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [g0, g1],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: g0.withValues(alpha: 0.40),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              )
                            : null,
                        child: Center(child: iconW),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 10,
                          color: selected ? g0 : Colors.grey[500],
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  /// Badge-aware icon used in the custom nav bar.
  Widget _navBadge(IconData icon, bool selected, int count) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, color: selected ? Colors.white : Colors.grey[500], size: 22),
        if (count > 0)
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                  color: Colors.red, shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  /// Double-badge icon: red badge (top-right) for chat unread,
  /// amber badge (top-left) for pending work requests.
  Widget _navDoubleBadge(
      IconData icon, bool selected, int chatUnread, int workReqCount) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, color: selected ? Colors.white : Colors.grey[500], size: 22),
        // Chat unread — red, top-right
        if (chatUnread > 0)
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                  color: Colors.red, shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
              child: Text(
                chatUnread > 99 ? '99+' : '$chatUnread',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        // Work requests — amber, top-left
        if (workReqCount > 0)
          Positioned(
            left: -6,
            top: -6,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                  color: Color(0xFFFF8F00), shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
              child: Text(
                workReqCount > 99 ? '99+' : '$workReqCount',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  /// Maps role + tab index to the correct IconData.
  IconData _getNavIcon(String role, int index) {
    switch (role) {
      case UserRoles.customer:
        return const [
          Icons.home,
          Icons.shopping_bag,
          Icons.shopping_cart,
          Icons.chat,
          Icons.person
        ][index];
      case UserRoles.company:
        return const [
          Icons.home,
          Icons.work,
          Icons.shopping_bag,
          Icons.chat,
          Icons.business
        ][index];
      case UserRoles.skilledPerson:
        return const [
          Icons.home,
          Icons.work_outline,
          Icons.store,
          Icons.chat,
          Icons.person
        ][index];
      case UserRoles.deliveryPartner:
        return const [Icons.local_shipping, Icons.chat, Icons.person][index];
      default:
        return const [
          Icons.home,
          Icons.work,
          Icons.shopping_bag,
          Icons.chat,
          Icons.person
        ][index];
    }
  }

  /// Returns the index of the Chats tab for each user role.
  int _getChatTabIndex(String role) {
    switch (role) {
      case UserRoles.customer:
        return 3; // Home, Shop, Cart, *Chats*, Profile
      case UserRoles.company:
        return 3; // Home, Jobs, Shop, *Chats*, Profile
      case UserRoles.skilledPerson:
        return 3; // Home, Portfolio, MyShop, *Chats*, Profile
      case UserRoles.deliveryPartner:
        return 1; // Deliveries, *Chats*, Profile
      default:
        return 3;
    }
  }

  /// Returns screens based on user role
  List<Widget> _getScreensForRole(String role) {
    switch (role) {
      case UserRoles.customer:
        return const [
          HomeScreen(), // Browse skilled persons
          ShopScreen(), // Browse products
          CartScreen(), // Shopping cart
          ChatsScreen(),
          ProfileTabScreen(),
        ];

      case UserRoles.company:
        return const [
          HomeScreen(), // Browse skilled persons
          JobsScreen(), // View/post jobs
          ShopScreen(), // Browse products
          ChatsScreen(),
          ProfileTabScreen(),
        ];

      case UserRoles.skilledPerson:
        return const [
          HomeScreen(), // Dashboard/overview
          JobsScreen(), // Browse & apply for jobs
          MyShopScreen(), // Manage their shop/products
          ChatsScreen(),
          ProfileTabScreen(),
        ];

      case UserRoles.deliveryPartner:
        return const [
          DeliveryScreen(), // Assigned deliveries + available pickups
          ChatsScreen(),
          ProfileTabScreen(),
        ];

      default:
        return const [
          HomeScreen(),
          JobsScreen(),
          ShopScreen(),
          ChatsScreen(),
          ProfileTabScreen(),
        ];
    }
  }

  /// Returns navigation items based on user role
  List<BottomNavigationBarItem> _getNavItemsForRole(String role) {
    switch (role) {
      case UserRoles.customer:
        return const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.shopping_bag), label: 'Shop'),
          BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart), label: 'Cart'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chats'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ];

      case UserRoles.company:
        return const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.work), label: 'Jobs'),
          BottomNavigationBarItem(
              icon: Icon(Icons.shopping_bag), label: 'Shop'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chats'),
          BottomNavigationBarItem(icon: Icon(Icons.business), label: 'Profile'),
        ];

      case UserRoles.skilledPerson:
        return const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.work_outline), label: 'Find Jobs'),
          BottomNavigationBarItem(icon: Icon(Icons.store), label: 'My Shop'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chats'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ];

      case UserRoles.deliveryPartner:
        return const [
          BottomNavigationBarItem(
              icon: Icon(Icons.local_shipping), label: 'Deliveries'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chats'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ];

      default:
        return const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.work), label: 'Jobs'),
          BottomNavigationBarItem(
              icon: Icon(Icons.shopping_bag), label: 'Shop'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chats'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ];
    }
  }

  Color _getGradientColor(int currentIndex, int position, String role) {
    // Delivery partner
    if (role == UserRoles.deliveryPartner) {
      switch (currentIndex) {
        case 0: // Deliveries (orange AppBar)
          return position < 2
              ? const Color(0xFFFF6B35)
              : const Color(0xFFFF8E53);
        case 1: // Chats (violet AppBar)
          return position < 2
              ? const Color(0xFF7B1FA2)
              : const Color(0xFFAB47BC);
        case 2: // Profile (orange AppBar)
          return position < 2
              ? const Color(0xFFE65100)
              : const Color(0xFFFF9800);
        default:
          return const Color(0xFFFF6B35);
      }
    }

    if (role == UserRoles.skilledPerson) {
      // Skilled person: Home, Portfolio, My Shop, Chats, Profile
      switch (currentIndex) {
        case 0: // Home (purple→blue AppBar)
          return position < 2
              ? const Color(0xFF6A11CB)
              : const Color(0xFF2575FC);
        case 1: // Find Jobs (blue→cyan, matching company Jobs tab)
          return position < 2
              ? const Color(0xFF2196F3)
              : const Color(0xFF00BCD4);
        case 2: // My Shop (pink→orange AppBar)
          return position < 2
              ? const Color(0xFFE91E63)
              : const Color(0xFFFF9800);
        case 3: // Chats (violet AppBar)
          return position < 2
              ? const Color(0xFF7B1FA2)
              : const Color(0xFFAB47BC);
        case 4: // Profile (orange AppBar)
          return position < 2
              ? const Color(0xFFE65100)
              : const Color(0xFFFF9800);
        default:
          return const Color(0xFF6A11CB);
      }
    } else if (role == UserRoles.company) {
      // Company: Home, Jobs, Shop, Chats, Profile
      switch (currentIndex) {
        case 0: // Home (purple→blue AppBar)
          return position < 2
              ? const Color(0xFF6A11CB)
              : const Color(0xFF2575FC);
        case 1: // Jobs (blue→cyan AppBar)
          return position < 2
              ? const Color(0xFF2196F3)
              : const Color(0xFF00BCD4);
        case 2: // Shop (purple→pink AppBar)
          return position < 2
              ? const Color(0xFF9C27B0)
              : const Color(0xFFE91E63);
        case 3: // Chats (violet AppBar)
          return position < 2
              ? const Color(0xFF7B1FA2)
              : const Color(0xFFAB47BC);
        case 4: // Profile (orange AppBar)
          return position < 2
              ? const Color(0xFFE65100)
              : const Color(0xFFFF9800);
        default:
          return const Color(0xFF6A11CB);
      }
    } else {
      // Customer: Home, Shop, Cart, Chats, Profile
      switch (currentIndex) {
        case 0: // Home (purple→blue AppBar)
          return position < 2
              ? const Color(0xFF6A11CB)
              : const Color(0xFF2575FC);
        case 1: // Shop (purple→pink AppBar)
          return position < 2
              ? const Color(0xFF9C27B0)
              : const Color(0xFFE91E63);
        case 2: // Cart (pink→orange AppBar)
          return position < 2
              ? const Color(0xFFE91E63)
              : const Color(0xFFFF9800);
        case 3: // Chats (violet AppBar)
          return position < 2
              ? const Color(0xFF7B1FA2)
              : const Color(0xFFAB47BC);
        case 4: // Profile (orange AppBar)
          return position < 2
              ? const Color(0xFFE65100)
              : const Color(0xFFFF9800);
        default:
          return const Color(0xFF9C27B0);
      }
    }
  }
}

// ── In-app notification banner widget ───────────────────────────────────

class _InAppBanner extends StatefulWidget {
  const _InAppBanner({
    required this.title,
    required this.subtitle,
    required this.onDismiss,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onDismiss;

  /// If set, tapping the banner body calls this instead of onDismiss.
  final VoidCallback? onTap;

  @override
  State<_InAppBanner> createState() => _InAppBannerState();
}

class _InAppBannerState extends State<_InAppBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 12,
          right: 12,
          child: SlideTransition(
            position: _slideAnim,
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                onTap: widget.onTap ?? widget.onDismiss,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white24,
                        child: Icon(Icons.notifications,
                            color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              widget.subtitle,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (widget.onTap != null)
                              const Text(
                                'Tap to open chats →',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: widget.onDismiss,
                        child: const Icon(Icons.close,
                            color: Colors.white70, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
