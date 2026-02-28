import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/portfolio_model.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../providers/user_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/portfolio_service.dart';
import '../../utils/web_image_loader.dart';
import 'add_portfolio_item_screen.dart';

/// Portfolio Screen
///
/// - Skilled user opening their own portfolio: manage + edit + stats
/// - Customer/company opening a skilled profile portfolio: view + like
class PortfolioScreen extends StatefulWidget {
  final String? portfolioUserId;

  const PortfolioScreen({super.key, this.portfolioUserId});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final PortfolioService _portfolioService = PortfolioService();
  final FirestoreService _firestoreService = FirestoreService();

  StreamSubscription<List<PortfolioItem>>? _portfolioSub;
  StreamSubscription<int>? _profileViewsSub;

  List<PortfolioItem> _portfolioItems = [];
  String? _currentUserId;
  String? _portfolioOwnerId;
  bool _isLoading = true;
  String? _errorMessage;
  int _profileViews = 0;

  bool get _isViewingOwnPortfolio =>
      _currentUserId != null && _portfolioOwnerId == _currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _portfolioOwnerId = widget.portfolioUserId ?? _currentUserId;
    _subscribeToPortfolio();
    _subscribeToProfileViews();
  }

  @override
  void dispose() {
    _portfolioSub?.cancel();
    _profileViewsSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _subscribeToPortfolio() {
    final ownerId = _portfolioOwnerId;
    if (ownerId == null) {
      setState(() {
        _errorMessage = 'Please sign in to view portfolio.';
        _isLoading = false;
      });
      return;
    }

    _portfolioSub = _portfolioService.streamUserPortfolio(ownerId).listen(
      (items) {
        if (!mounted) return;
        setState(() {
          _portfolioItems = items;
          _isLoading = false;
          _errorMessage = null;
        });
      },
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Error loading portfolio: $e';
          _isLoading = false;
        });
      },
    );
  }

  void _subscribeToProfileViews() {
    final ownerId = _portfolioOwnerId;
    if (ownerId == null) return;
    _profileViewsSub = _firestoreService
        .skilledProfileViewCountStream(ownerId)
        .listen((count) {
      if (!mounted) return;
      setState(() {
        _profileViews = count;
      });
    });
  }

  int _gridCountForWidth(double width) {
    if (width >= 1400) return 6;
    if (width >= 1100) return 5;
    if (width >= 860) return 4;
    if (width >= 620) return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<app_auth.AuthProvider>(context);
    final canManagePortfolio =
        authProvider.isSkilledPerson && _isViewingOwnPortfolio;

    // From bottom-nav tab (no target user provided), keep it skilled-only.
    if (widget.portfolioUserId == null && !authProvider.isSkilledPerson) {
      return _buildAccessDenied();
    }

    final title = canManagePortfolio ? 'My Portfolio' : 'Portfolio';

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(color: Colors.white)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFC2185B), Color(0xFFFF6F61)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'My Work', icon: Icon(Icons.photo_library)),
            Tab(text: 'Statistics', icon: Icon(Icons.analytics)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPortfolioTab(canManagePortfolio),
          _buildStatisticsTab(),
        ],
      ),
      floatingActionButton: canManagePortfolio
          ? Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFC2185B), Color(0xFFFF6F61)],
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFC2185B).withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: FloatingActionButton.extended(
                onPressed: () => _addPortfolioItem(context),
                backgroundColor: Colors.transparent,
                elevation: 0,
                icon: const Icon(Icons.add_a_photo, color: Colors.white),
                label: const Text('Add Work',
                    style: TextStyle(color: Colors.white)),
              ),
            )
          : null,
    );
  }

  Widget _buildAccessDenied() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Portfolio'),
        backgroundColor: Colors.red,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.block, size: 80, color: Colors.red),
            SizedBox(height: 20),
            Text(
              'Access Denied',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Only skilled persons can manage their portfolio. Customers and companies can view portfolio from a skilled profile.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortfolioTab(bool canManagePortfolio) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFC2185B)),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _subscribeToPortfolio,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = _gridCountForWidth(screenWidth);

    return RefreshIndicator(
      onRefresh: () async {},
      color: const Color(0xFFC2185B),
      child: CustomScrollView(
        slivers: [
          const SliverPadding(padding: EdgeInsets.only(top: 12)),
          if (_portfolioItems.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.photo_library_outlined,
                        size: 80, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No portfolio items yet',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      canManagePortfolio
                          ? 'Tap the + button to add your first work'
                          : 'This skilled person has not added work yet',
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  mainAxisExtent: 230,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildPortfolioItemCard(
                    _portfolioItems[index],
                    canManagePortfolio: canManagePortfolio,
                  ),
                  childCount: _portfolioItems.length,
                ),
              ),
            ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
        ],
      ),
    );
  }

  Widget _buildPortfolioItemCard(
    PortfolioItem item, {
    required bool canManagePortfolio,
  }) {
    final canLike = !canManagePortfolio &&
        _currentUserId != null &&
        _currentUserId != item.userId;

    return GestureDetector(
      onTap: () =>
          _viewPortfolioItem(item, canManagePortfolio: canManagePortfolio),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 140,
              width: double.infinity,
              child: item.images.isNotEmpty
                  ? WebImageLoader.loadImage(
                      imageUrl: item.images.first,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: Colors.grey.shade300,
                      child: Center(
                        child: Icon(
                          Icons.image,
                          size: 40,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        if (canLike)
                          StreamBuilder<bool>(
                            stream:
                                _portfolioService.streamIsPortfolioLikedByUser(
                              item.id,
                              _currentUserId!,
                            ),
                            builder: (context, snapshot) {
                              final isLiked = snapshot.data ?? false;
                              return InkWell(
                                onTap: () =>
                                    _toggleLike(item, shouldLike: !isLiked),
                                child: Row(
                                  children: [
                                    Icon(
                                      isLiked
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      size: 16,
                                      color: Colors.red,
                                    ),
                                    const SizedBox(width: 4),
                                    Text('${item.likes}',
                                        style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                              );
                            },
                          )
                        else
                          Row(
                            children: [
                              const Icon(Icons.favorite,
                                  size: 16, color: Colors.red),
                              const SizedBox(width: 4),
                              Text('${item.likes}',
                                  style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        const Spacer(),
                        const Icon(Icons.visibility,
                            size: 16, color: Colors.blue),
                        const SizedBox(width: 4),
                        Text('${item.views}',
                            style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsTab() {
    final totalWorks = _portfolioItems.length;
    final totalLikes =
        _portfolioItems.fold<int>(0, (sum, item) => sum + item.likes);
    final itemViews =
        _portfolioItems.fold<int>(0, (sum, item) => sum + item.views);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStatCard(
          'Total Works',
          '$totalWorks',
          Icons.photo_library,
          const Color(0xFFC2185B),
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          'Total Views',
          '$_profileViews',
          Icons.visibility,
          Colors.blue,
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          'Work Item Opens',
          '$itemViews',
          Icons.remove_red_eye_outlined,
          const Color(0xFF5C6BC0),
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          'Total Likes',
          '$totalLikes',
          Icons.favorite,
          Colors.red,
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          'Average Likes per Work',
          totalWorks > 0 ? (totalLikes / totalWorks).toStringAsFixed(1) : '0',
          Icons.trending_up,
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        trailing: Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  Future<void> _toggleLike(
    PortfolioItem item, {
    required bool shouldLike,
  }) async {
    final userId = _currentUserId;
    if (userId == null) return;

    try {
      await _portfolioService.setPortfolioLike(
        itemId: item.id,
        userId: userId,
        shouldLike: shouldLike,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update like: $e')),
      );
    }
  }

  void _addPortfolioItem(BuildContext context) async {
    final authProvider =
        Provider.of<app_auth.AuthProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final nav = Navigator.of(context);

    if (userProvider.currentProfile == null &&
        authProvider.currentUser != null) {
      await userProvider.loadProfile(authProvider.currentUser!.uid);
    }

    if (userProvider.currentProfile?.isVerified != true) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.security, color: Colors.orange),
              SizedBox(width: 8),
              Text('Verification Required'),
            ],
          ),
          content: const Text(
            'You must verify your Aadhaar to add portfolio items. This helps maintain platform integrity and prevents fake profiles.\n\n'
            'Please complete your identity verification from your profile setup.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/skilled-setup');
              },
              child: const Text('Verify Now'),
            ),
          ],
        ),
      );
      return;
    }

    await nav.push(
      MaterialPageRoute(
        builder: (context) => const AddPortfolioItemScreen(),
      ),
    );
  }

  void _viewPortfolioItem(
    PortfolioItem item, {
    required bool canManagePortfolio,
  }) {
    final viewerId = _currentUserId;
    if (viewerId != null) {
      _portfolioService.trackUniquePortfolioView(
        itemId: item.id,
        viewerId: viewerId,
        ownerId: item.userId,
      );
    }

    if (canManagePortfolio) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddPortfolioItemScreen(portfolioItem: item),
        ),
      );
      return;
    }

    _openPortfolioPreview(item);
  }

  void _openPortfolioPreview(PortfolioItem item) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.images.isNotEmpty)
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: WebImageLoader.loadImage(
                      imageUrl: item.images.first,
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                Container(
                  height: 220,
                  alignment: Alignment.center,
                  color: Colors.grey.shade200,
                  child:
                      Icon(Icons.image, size: 56, color: Colors.grey.shade500),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.description.isEmpty
                          ? 'No description added.'
                          : item.description,
                      style:
                          const TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.favorite, color: Colors.red, size: 18),
                        const SizedBox(width: 6),
                        Text('${item.likes}'),
                        const SizedBox(width: 20),
                        const Icon(Icons.visibility,
                            color: Colors.blue, size: 18),
                        const SizedBox(width: 6),
                        Text('${item.views}'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
