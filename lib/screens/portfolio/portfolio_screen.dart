import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    
    // Role-based access check
    if (!authProvider.isSkilledPerson) {
      return _buildAccessDenied();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Portfolio'),
        backgroundColor: Colors.teal,
        bottom: TabBar(
          controller: _tabController,
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

  Widget _buildPortfolioTab(AuthProvider authProvider) {
    return CustomScrollView(
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
        // Portfolio grid will be loaded here from Firestore
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
              (context, index) => _buildPortfolioItemCard(index),
              childCount: 6, // TODO: Replace with actual portfolio items
            ),
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
      ],
    );
  }

  Widget _buildPortfolioItemCard(int index) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
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
                  'Project ${index + 1}',
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
                    Text('${index * 5}', style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 12),
                    const Icon(Icons.visibility, size: 14, color: Colors.blue),
                    const SizedBox(width: 4),
                    Text('${index * 25}', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsTab(AuthProvider authProvider) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStatCard(
          'Total Works',
          '12',
          Icons.photo_library,
          Colors.teal,
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          'Total Views',
          '1,234',
          Icons.visibility,
          Colors.blue,
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          'Total Likes',
          '567',
          Icons.favorite,
          Colors.red,
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          'Projects Completed',
          '8',
          Icons.check_circle,
          Colors.green,
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          'Average Rating',
          '4.8 ⭐',
          Icons.star,
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

  void _addPortfolioItem(BuildContext context) {
    // TODO: Navigate to add portfolio item screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Add portfolio item feature - Coming soon'),
        backgroundColor: Colors.teal,
      ),
    );
  }
}
