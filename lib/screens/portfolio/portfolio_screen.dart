import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../providers/user_provider.dart';
import '../../models/portfolio_model.dart';
import '../../services/portfolio_service.dart';
import '../../utils/web_image_loader.dart';
import 'add_portfolio_item_screen.dart';

/// Portfolio Screen - For Skilled Persons Only
/// This is where skilled persons showcase their work through photos/videos
/// Customers and companies can view portfolios but cannot manage them
class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final PortfolioService _portfolioService = PortfolioService();
  List<PortfolioItem> _portfolioItems = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPortfolio();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPortfolio() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final items = await _portfolioService.getUserPortfolio(userId);
        setState(() {
          _portfolioItems = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading portfolio: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<app_auth.AuthProvider>(context);
    
    // Role-based access check
    if (!authProvider.isSkilledPerson) {
      return _buildAccessDenied();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Portfolio', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal,
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
          _buildPortfolioTab(authProvider),
          _buildStatisticsTab(authProvider),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addPortfolioItem(context),
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Add Work'),
      ),
    );
  }

  Widget _buildAccessDenied() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Portfolio'),
        backgroundColor: Colors.red,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.block, size: 80, color: Colors.red),
            const SizedBox(height: 20),
            const Text(
              'Access Denied',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Only skilled persons can manage their portfolio. Please switch to a skilled person account.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortfolioTab(app_auth.AuthProvider authProvider) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.teal),
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
              onPressed: _loadPortfolio,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPortfolio,
      color: Colors.teal,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: Card(
                color: Colors.teal.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.teal),
                          const SizedBox(width: 8),
                          Text(
                            'Portfolio Tips',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '• Upload high-quality photos of your completed work\n'
                        '• Add detailed descriptions to showcase your skills\n'
                        '• Tag your work with relevant skills to get discovered\n'
                        '• Regular updates improve your visibility',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Portfolio grid
          if (_portfolioItems.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.photo_library_outlined, size: 80, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No portfolio items yet',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the + button to add your first work',
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.75,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildPortfolioItemCard(_portfolioItems[index]),
                  childCount: _portfolioItems.length,
                ),
              ),
            ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
        ],
      ),
    );
  }

  Widget _buildPortfolioItemCard(PortfolioItem item) {
    return GestureDetector(
      onTap: () => _viewPortfolioItem(item),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
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
                          size: 60,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.favorite, size: 14, color: Colors.red),
                      const SizedBox(width: 4),
                      Text('${item.likes}', style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 12),
                      const Icon(Icons.visibility, size: 14, color: Colors.blue),
                      const SizedBox(width: 4),
                      Text('${item.views}', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsTab(app_auth.AuthProvider authProvider) {
    final totalWorks = _portfolioItems.length;
    final totalViews = _portfolioItems.fold<int>(0, (sum, item) => sum + item.views);
    final totalLikes = _portfolioItems.fold<int>(0, (sum, item) => sum + item.likes);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStatCard(
          'Total Works',
          '$totalWorks',
          Icons.photo_library,
          Colors.teal,
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          'Total Views',
          '$totalViews',
          Icons.visibility,
          Colors.blue,
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
          totalWorks > 0 ? '${(totalLikes / totalWorks).toStringAsFixed(1)}' : '0',
          Icons.trending_up,
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
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

  void _addPortfolioItem(BuildContext context) async {
    // SECURITY: Check if user is verified before allowing portfolio item creation
    final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    // Load profile if not already loaded
    if (userProvider.currentProfile == null && authProvider.currentUser != null) {
      await userProvider.loadProfile(authProvider.currentUser!.uid);
    }
    
    // Check verification status
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
                // Navigate to verification screen
                Navigator.pushNamed(context, '/skilled-setup');
              },
              child: const Text('Verify Now'),
            ),
          ],
        ),
      );
      return;
    }
    
    // Verified - proceed to add portfolio item
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddPortfolioItemScreen(),
      ),
    );

    if (result == true) {
      _loadPortfolio(); // Refresh the list
    }
  }

  void _viewPortfolioItem(PortfolioItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddPortfolioItemScreen(portfolioItem: item),
      ),
    ).then((_) => _loadPortfolio());
  }
}
