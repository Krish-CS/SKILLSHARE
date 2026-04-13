import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/skilled_user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/app_constants.dart';
import '../../utils/web_image_loader.dart';
import '../../widgets/universal_avatar.dart';
import '../../widgets/filter_bottom_sheet.dart';
import '../../utils/app_helpers.dart';
import '../profile/profile_screen.dart';

class ExploreScreen extends StatefulWidget {
  final String? initialCategory;

  const ExploreScreen({super.key, this.initialCategory});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _searchQuery = '';
  String? _selectedCategory;
  double _minRating = 0;
  String _sortBy = 'rating';
  bool _isGridView = true;

  final List<String> _categories = ['All', ...AppConstants.categories];
  final List<String> _sortOptions = ['rating', 'reviews', 'projects', 'newest'];
  final Map<String, String> _sortLabels = {
    'rating': 'Top Rated',
    'reviews': 'Most Reviewed',
    'projects': 'Most Projects',
    'newest': 'Newest',
  };

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<UserProvider>(context, listen: false).loadVerifiedUsers();
    });
  }

  Future<void> _openFilterSheet() async {
    final result = await FilterBottomSheet.show(
      context,
      mode: 'experts',
      initialCategory: _selectedCategory,
      initialSortBy: _sortBy,
      initialMinRating: _minRating,
      initialViewMode: _isGridView ? 'grid' : 'list',
    );
    if (result == null) return;
    setState(() {
      _selectedCategory = result.category;
      _sortBy = result.sortBy ?? 'rating';
      _minRating = result.minRating ?? 0;
      _isGridView = result.viewMode == 'grid';
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() => _searchQuery = value.toLowerCase());
    });
  }

  List<SkilledUserProfile> _filter(
    List<SkilledUserProfile> users, {
    String? currentUserId,
  }) {
    var result = users.where((p) {
      // Exclude the currently logged-in user: skilled persons can only explore OTHERS
      if (currentUserId != null && p.userId == currentUserId) return false;

      final q = _searchQuery.toLowerCase();
      final matchSearch = q.isEmpty ||
          (p.category?.toLowerCase().contains(q) ?? false) ||
          p.skills.any((s) => s.toLowerCase().contains(q)) ||
          p.bio.toLowerCase().contains(q);
      final matchCategory = _selectedCategory == null ||
          _selectedCategory == 'All' ||
          p.category == _selectedCategory;
      final matchRating = p.rating >= _minRating;
      return matchSearch && matchCategory && matchRating;
    }).toList();

    switch (_sortBy) {
      case 'reviews':
        result.sort((a, b) => b.reviewCount.compareTo(a.reviewCount));
        break;
      case 'projects':
        result.sort((a, b) => b.projectCount.compareTo(a.projectCount));
        break;
      case 'newest':
        result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'rating':
      default:
        result.sort((a, b) => b.rating.compareTo(a.rating));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUserId = authProvider.currentUser?.uid;
    final filtered =
        _filter(userProvider.verifiedUsers, currentUserId: currentUserId);
    final isCompact = MediaQuery.of(context).size.width < 380;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Explore Experts',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(
              _isGridView ? Icons.view_list : Icons.grid_view,
              color: Colors.white,
            ),
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search + Filter Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8)
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: isCompact
                          ? 'Search skills...'
                          : 'Search skills, categories...',
                      prefixIcon:
                          const Icon(Icons.search, color: Color(0xFF6A11CB)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : IconButton(
                              onPressed: _openFilterSheet,
                              tooltip: 'Filters',
                              icon: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF6A11CB),
                                      Color(0xFF2575FC),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.tune_rounded,
                                    color: Colors.white, size: 16),
                              ),
                            ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Category Chips
                SizedBox(
                  height: 36,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (_, i) {
                      final cat = _categories[i];
                      final selected =
                          (cat == 'All' && _selectedCategory == null) ||
                              _selectedCategory == cat;
                      return GestureDetector(
                        onTap: () => setState(() =>
                            _selectedCategory = cat == 'All' ? null : cat),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: selected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              color: selected
                                  ? const Color(0xFF6A11CB)
                                  : Colors.white,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),

          // Sort + Rating Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 380;

                Widget sortControl = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sort, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _sortBy,
                      underline: const SizedBox(),
                      isDense: true,
                      items: _sortOptions
                          .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(_sortLabels[s]!,
                                    style: const TextStyle(fontSize: 13)),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _sortBy = v!),
                    ),
                  ],
                );

                Widget ratingControl = Row(
                  children: [
                    const Icon(Icons.star, size: 16, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text('${_minRating.toStringAsFixed(1)}+',
                        style: const TextStyle(fontSize: 13)),
                    Expanded(
                      child: Slider(
                        value: _minRating,
                        min: 0,
                        max: 5,
                        divisions: 10,
                        activeColor: const Color(0xFF6A11CB),
                        onChanged: (v) => setState(() => _minRating = v),
                      ),
                    ),
                  ],
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      sortControl,
                      const SizedBox(height: 6),
                      ratingControl,
                    ],
                  );
                }

                return Row(
                  children: [
                    sortControl,
                    const Spacer(),
                    SizedBox(width: 170, child: ratingControl),
                  ],
                );
              },
            ),
          ),

          // Results Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Text(
                  '${filtered.length} expert${filtered.length != 1 ? 's' : ''} found',
                  style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          // Results List / Grid
          Expanded(
            child: userProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? _buildEmpty()
                    : _isGridView
                        ? _buildGrid(filtered)
                        : _buildList(filtered),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 72, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No experts found',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text('Try adjusting your filters',
              style: TextStyle(color: Colors.grey[500])),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () => setState(() {
              _searchController.clear();
              _searchQuery = '';
              _selectedCategory = null;
              _minRating = 0;
            }),
            child: const Text('Clear All Filters'),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<SkilledUserProfile> users) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final maxTileWidth = width >= 1400
            ? 220.0
            : width >= 1000
                ? 210.0
                : width >= 700
                    ? 190.0
                    : 170.0;

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: maxTileWidth,
            childAspectRatio: 0.80,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: users.length,
          itemBuilder: (_, i) => _buildGridCard(users[i]),
        );
      },
    );
  }

  Widget _buildList(List<SkilledUserProfile> users) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      itemBuilder: (_, i) => _buildListCard(users[i]),
    );
  }

  Widget _buildGridCard(SkilledUserProfile profile) {
    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ProfileScreen(userId: profile.userId))),
      child: Card(
        elevation: 2,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: WebImageLoader.loadImage(
                imageUrl: profile.profilePicture,
                fit: BoxFit.cover,
                errorWidget: Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.person, size: 42, color: Colors.grey),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                            AppHelpers.capitalize(profile.name ?? 'Unnamed'),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (profile.isVerified)
                        const Icon(Icons.verified,
                            size: 14, color: Color(0xFF2196F3)),
                    ],
                  ),
                  if (profile.category != null)
                    Text(profile.category!,
                        style:
                            TextStyle(fontSize: 10.5, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 12, color: Colors.amber),
                      const SizedBox(width: 2),
                      Text(profile.rating.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 11.5)),
                      const SizedBox(width: 4),
                      Text('(${profile.reviewCount})',
                          style: TextStyle(
                              fontSize: 10.5, color: Colors.grey[500])),
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

  Widget _buildListCard(SkilledUserProfile profile) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ProfileScreen(userId: profile.userId))),
        leading: UniversalAvatar(
          avatarConfig: profile.avatarConfig,
          photoUrl: profile.profilePicture,
          fallbackName: profile.name ?? '?',
          radius: 28,
          animate: false,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(AppHelpers.capitalize(profile.name ?? 'Unnamed'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            if (profile.isVerified)
              const Icon(Icons.verified, size: 16, color: Color(0xFF2196F3)),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (profile.category != null && profile.category!.isNotEmpty)
              Text(profile.category!,
                  style: const TextStyle(color: Color(0xFF6A11CB))),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.star, size: 14, color: Colors.amber),
                const SizedBox(width: 2),
                Text(
                    '${profile.rating.toStringAsFixed(1)} (${profile.reviewCount} reviews)'),
                const SizedBox(width: 8),
                Icon(Icons.work, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 2),
                Text('${profile.projectCount} projects',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
            if (profile.skills.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  profile.skills.take(3).join(' • '),
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
