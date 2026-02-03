import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/skilled_user_profile.dart';
import '../../utils/app_constants.dart';
import '../../utils/user_roles.dart';
import '../../utils/add_dummy_profiles.dart';
import '../../widgets/expert_card.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;
  String _sortBy = 'rating'; // rating, reviews, projects
  bool _isGridView = false;
  bool _showFilters = false;

  final List<String> _categories = [
    'All',
    'Home Baking',
    'Handicrafts',
    'Content Creation',
    'Beauty & Wellness',
    'Carpentry',
    'Tailoring',
    'Photography',
    'Videography',
    'Editing',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    // Use addPostFrameCallback to ensure widget tree is built before loading data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  Future<void> _loadData() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.loadVerifiedUsers();
    } catch (e) {
      print('Error loading data: $e');
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  List<SkilledUserProfile> _getFilteredAndSortedUsers(List<SkilledUserProfile> users) {
    var filtered = users.where((profile) {
      // Search filter
      final matchesSearch = _searchQuery.isEmpty ||
          (profile.category?.toLowerCase().contains(_searchQuery) ?? false) ||
          profile.skills.any((skill) => skill.toLowerCase().contains(_searchQuery)) ||
          (profile.bio.toLowerCase().contains(_searchQuery));

      // Category filter
      final matchesCategory = _selectedCategory == null ||
          _selectedCategory == 'All' ||
          profile.category == _selectedCategory;

      return matchesSearch && matchesCategory;
    }).toList();

    // Sort
    filtered.sort((a, b) {
      switch (_sortBy) {
        case 'reviews':
          return b.reviewCount.compareTo(a.reviewCount);
        case 'projects':
          return b.projectCount.compareTo(a.projectCount);
        case 'rating':
        default:
          return b.rating.compareTo(a.rating);
      }
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final currentUser = authProvider.currentUser;
    final userRole = authProvider.userRole ?? UserRoles.customer;
    
    // Role-based title and subtitle
    String screenTitle = 'SkillShare';
    String screenSubtitle = '';
    
    if (userRole == UserRoles.skilledPerson) {
      screenTitle = 'Dashboard';
      screenSubtitle = 'View your performance & opportunities';
    } else if (userRole == UserRoles.company) {
      screenTitle = 'Find Talent';
      screenSubtitle = 'Hire skilled professionals for your projects';
    } else {
      screenTitle = 'Discover Skills';
      screenSubtitle = 'Find experts for your needs';
    }

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: CustomScrollView(
            slivers: [
              // App Bar with gradient background
              SliverAppBar(
                expandedHeight: 200,
                floating: false,
                pinned: true,
                flexibleSpace: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF9C27B0), Color(0xFFE91E63)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: FlexibleSpaceBar(
                    title: Text(
                      screenTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    background: Padding(
                      padding: const EdgeInsets.only(top: 60, left: 16, right: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Search Bar
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search skills, categories...',
                                border: InputBorder.none,
                                icon: const Icon(Icons.search, color: Colors.grey),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, color: Colors.grey),
                                        onPressed: () {
                                          _searchController.clear();
                                        },
                                      )
                                    : null,
                              ),
                              onSubmitted: (value) {
                                setState(() {
                                  _searchQuery = value.toLowerCase();
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                    onPressed: () {
                      // TODO: Navigate to notifications
                    },
                  ),
                  IconButton(
                    icon: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.white,
                      child: currentUser?.profilePhoto != null
                          ? ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: currentUser!.profilePhoto!,
                                width: 32,
                                height: 32,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) => Text(
                                  currentUser.name[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Color(0xFF9C27B0),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            )
                          : Text(
                              currentUser?.name[0].toUpperCase() ?? 'U',
                              style: const TextStyle(
                                color: Color(0xFF9C27B0),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    onPressed: () {
                      if (currentUser != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfileScreen(userId: currentUser.uid),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),

              // Categories with Filter
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Categories',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _showFilters = !_showFilters;
                              });
                            },
                            icon: Icon(
                              _showFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
                              size: 20,
                            ),
                            label: const Text('Filters'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 40,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _categories.length,
                          itemBuilder: (context, index) {
                            final category = _categories[index];
                            final isSelected = _selectedCategory == category ||
                                (_selectedCategory == null && category == 'All');
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(category),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedCategory = category == 'All' ? null : category;
                                  });
                                },
                                selectedColor: const Color(0xFF2196F3).withValues(alpha: 0.2),
                                checkmarkColor: const Color(0xFF2196F3),
                                labelStyle: TextStyle(
                                  color: isSelected ? const Color(0xFF2196F3) : Colors.grey[700],
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      // Filter Options
                      if (_showFilters) ...[  
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Sort By',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    ChoiceChip(
                                      label: const Text('Rating'),
                                      selected: _sortBy == 'rating',
                                      onSelected: (selected) {
                                        setState(() {
                                          _sortBy = 'rating';
                                        });
                                      },
                                    ),
                                    ChoiceChip(
                                      label: const Text('Reviews'),
                                      selected: _sortBy == 'reviews',
                                      onSelected: (selected) {
                                        setState(() {
                                          _sortBy = 'reviews';
                                        });
                                      },
                                    ),
                                    ChoiceChip(
                                      label: const Text('Projects'),
                                      selected: _sortBy == 'projects',
                                      onSelected: (selected) {
                                        setState(() {
                                          _sortBy = 'projects';
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    const Text(
                                      'View Mode',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      icon: Icon(
                                        Icons.view_list,
                                        color: !_isGridView ? const Color(0xFF2196F3) : Colors.grey,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _isGridView = false;
                                        });
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.grid_view,
                                        color: _isGridView ? const Color(0xFF2196F3) : Colors.grey,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _isGridView = true;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Top Rated Experts Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedCategory != null && _selectedCategory != 'All'
                            ? '$_selectedCategory Experts'
                            : 'Skilled Professionals',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_searchQuery.isNotEmpty || _selectedCategory != null)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _selectedCategory = null;
                            });
                          },
                          child: const Text('Clear'),
                        ),
                    ],
                  ),
                ),
              ),

              // Experts Grid/List
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: userProvider.isLoading
                    ? SliverToBoxAdapter(
                        child: Column(
                          children: List.generate(
                            3,
                            (index) => _buildShimmerCard(),
                          ),
                        ),
                      )
                    : Builder(
                        builder: (context) {
                          final filteredUsers = _getFilteredAndSortedUsers(
                            userProvider.verifiedUsers,
                          );

                          if (filteredUsers.isEmpty) {
                            return SliverToBoxAdapter(
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(48),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.search_off,
                                        size: 80,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        _searchQuery.isNotEmpty
                                            ? 'No results found for "$_searchQuery"'
                                            : 'No experts available',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[600],
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Try adjusting your search or filters',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }

                          if (_isGridView) {
                            return SliverGrid(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.75,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final profile = filteredUsers[index];
                                  return _buildGridCard(profile);
                                },
                                childCount: filteredUsers.length,
                              ),
                            );
                          } else {
                            return SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final profile = filteredUsers[index];
                                  return ExpertCard(profile: profile);
                                },
                                childCount: filteredUsers.length,
                              ),
                            );
                          }
                        },
                      ),
              ),
              
              // Bottom spacing
              const SliverToBoxAdapter(
                child: SizedBox(height: 80),
              ),
            ],
          ),
        ),
      ),
      // Admin Debug Button - Remove in production
      floatingActionButton: (currentUser?.role == AppConstants.roleAdmin)
          ? FloatingActionButton.extended(
              onPressed: () async {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                );
                await DummyDataSeeder.seedDatabase();
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Dummy profiles added successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _loadData(); // Reload data
                }
              },
              icon: const Icon(Icons.add_circle),
              label: const Text('Add Dummy Data'),
              backgroundColor: Colors.orange,
            )
          : null,
    );
  }

  Widget _buildGridCard(SkilledUserProfile profile) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileScreen(userId: profile.userId),
          ),
        );
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Profile Image
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      gradient: LinearGradient(
                        colors: [Colors.blue[400]!, Colors.purple[400]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: CircleAvatar(
                        radius: 45,
                        backgroundColor: Colors.white,
                        child: CircleAvatar(
                          radius: 42,
                          backgroundImage: (profile.profilePicture != null && profile.profilePicture!.isNotEmpty)
                              ? CachedNetworkImageProvider(profile.profilePicture!)
                              : null,
                          child: (profile.profilePicture == null || profile.profilePicture!.isEmpty)
                              ? const Icon(Icons.person, size: 40, color: Colors.grey)
                              : null,
                        ),
                      ),
                    ),
                  ),
                  if (profile.isVerified)
                    const Positioned(
                      top: 8,
                      right: 8,
                      child: Icon(
                        Icons.verified,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                ],
              ),
            ),
            // Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.category ?? 'Professional',
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
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          profile.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '(${profile.reviewCount})',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.work_outline, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${profile.projectCount} projects',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
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

  Widget _buildShimmerCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 150,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 100,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
