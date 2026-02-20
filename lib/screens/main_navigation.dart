import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/app_constants.dart';
import '../utils/user_roles.dart';
import '../services/firestore_service.dart';
import 'home/home_screen.dart';
import 'jobs/jobs_screen.dart';
import 'shop/shop_screen.dart';
import 'shop/cart_screen.dart';
import 'chat/chats_screen.dart';
import 'profile/profile_tab_screen.dart';
import 'portfolio/portfolio_screen.dart';
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

  // ── In-app notification banners ─────────────────────────────────────────
  StreamSubscription<QuerySnapshot>? _notifSub;
  int _prevNotifCount = -1; // -1 means "not yet initialised"
  OverlayEntry? _bannerEntry;
  Timer? _bannerTimer;
  String? _watchingUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initBannerStream());
  }

  void _initBannerStream() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final uid = auth.currentUser?.uid;
    if (uid == null || uid == _watchingUserId) return;
    _watchingUserId = uid;
    _notifSub?.cancel();
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
        // New notification arrived
        final newDocs = snap.docs
            .where((d) {
              final ts = d.data()['updatedAt'] as Timestamp?;
              return ts != null &&
                  ts.toDate().isAfter(
                      DateTime.now().subtract(const Duration(minutes: 5)));
            })
            .toList();
        if (newDocs.isNotEmpty) {
          final data = newDocs.first.data();
          _showTopBanner(
            'New notification',
            (data['title'] as String?) ??
                (data['description'] as String?) ??
                'You have a new update',
          );
        }
      }
      _prevNotifCount = count;
    });
  }

  void _showTopBanner(String title, String subtitle) {
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
    _notifSub?.cancel();
    _bannerTimer?.cancel();
    _bannerEntry?.remove();
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
      return const AdminScreen();
    }

    // Delivery partner has minimal nav (3 tabs)
    final isDelivery = userRole == UserRoles.deliveryPartner;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _getGradientColor(_currentIndex, 0, userRole),
              _getGradientColor(_currentIndex, 1, userRole),
              _getGradientColor(_currentIndex, 2, userRole),
              if (!isDelivery)
                _getGradientColor(_currentIndex, 3, userRole),
            ],
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white70,
          elevation: 0,
          items: _buildNavItemsWithBadges(navItems, userRole, currentUserId),
        ),
      ),
    );
  }

  /// Wraps the cart nav item with a badge showing item count for customers
  List<BottomNavigationBarItem> _buildNavItemsWithBadges(
    List<BottomNavigationBarItem> items,
    String role,
    String? userId,
  ) {
    if (role != UserRoles.customer || userId == null) return items;

    // Find cart index (index 2 for customer: Home, Shop, Cart, Chats, Profile)
    return List.generate(items.length, (i) {
      if (i == 2) {
        // Cart tab for customer
        return BottomNavigationBarItem(
          icon: StreamBuilder<List<dynamic>>(
            stream: _firestoreService.streamCartItems(userId),
            builder: (context, snapshot) {
              final count = snapshot.data?.fold<int>(
                      0, (acc, item) => acc + (item.quantity as int)) ??
                  0;
              if (count <= 0) {
                return const Icon(Icons.shopping_cart);
              }
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.shopping_cart),
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints:
                          const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        count > 9 ? '9+' : '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          label: 'Cart',
        );
      }
      return items[i];
    });
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
          PortfolioScreen(), // Manage portfolio (showcase work)
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
              icon: Icon(Icons.photo_library), label: 'Portfolio'),
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
    // Delivery partner uses orange gradient
    if (role == UserRoles.deliveryPartner) {
      return position < 2
          ? const Color(0xFFFF6B35)
          : const Color(0xFFFF8E53);
    }

    // Different color schemes based on role
    if (role == UserRoles.skilledPerson) {
      // Green/teal gradient for skilled persons
      switch (currentIndex) {
        case 0: // Home
          return position < 2
              ? const Color(0xFF4CAF50)
              : const Color(0xFF009688);
        case 1: // Portfolio
          return position < 2
              ? const Color(0xFF009688)
              : const Color(0xFF00BCD4);
        case 2: // My Shop
          return position < 2
              ? const Color(0xFFFF9800)
              : const Color(0xFFFF5722);
        case 3: // Chats
          return position < 2
              ? const Color(0xFF9C27B0)
              : const Color(0xFFE91E63);
        case 4: // Profile
          return position < 2
              ? const Color(0xFF4CAF50)
              : const Color(0xFF009688);
        default:
          return const Color(0xFF4CAF50);
      }
    } else if (role == UserRoles.company) {
      // Blue/indigo gradient for companies
      switch (currentIndex) {
        case 0: // Home
          return position < 2
              ? const Color(0xFF3F51B5)
              : const Color(0xFF2196F3);
        case 1: // Jobs
          return position < 2
              ? const Color(0xFF2196F3)
              : const Color(0xFF00BCD4);
        case 2: // Shop
          return position < 2
              ? const Color(0xFFE91E63)
              : const Color(0xFFFF9800);
        case 3: // Chats
          return position < 2
              ? const Color(0xFF9C27B0)
              : const Color(0xFFE91E63);
        case 4: // Profile
          return position < 2
              ? const Color(0xFF3F51B5)
              : const Color(0xFF2196F3);
        default:
          return const Color(0xFF3F51B5);
      }
    } else {
      // Purple/pink gradient for customers (Home, Shop, Cart, Chats, Profile)
      switch (currentIndex) {
        case 0: // Home
          return position < 2
              ? const Color(0xFF9C27B0)
              : const Color(0xFFE91E63);
        case 1: // Shop
          return position < 2
              ? const Color(0xFF2196F3)
              : const Color(0xFF00BCD4);
        case 2: // Cart
          return position < 2
              ? const Color(0xFFE91E63)
              : const Color(0xFFFF9800);
        case 3: // Chats
          return position < 2
              ? const Color(0xFF9C27B0)
              : const Color(0xFFE91E63);
        case 4: // Profile
          return position < 2
              ? const Color(0xFF9C27B0)
              : const Color(0xFFE91E63);
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
  });

  final String title;
  final String subtitle;
  final VoidCallback onDismiss;

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
            onTap: widget.onDismiss,
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