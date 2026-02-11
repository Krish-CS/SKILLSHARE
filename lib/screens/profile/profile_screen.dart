import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/firestore_service.dart';
import '../../services/chat_service.dart';
import '../../models/skilled_user_profile.dart';
import '../../models/customer_profile.dart';
import '../../models/company_profile.dart';
import '../../models/review_model.dart';
import '../../models/service_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../utils/app_constants.dart';
import '../../utils/web_image_loader.dart';
import 'skilled_user_setup_screen.dart';
import 'customer_setup_screen.dart';
import 'company_setup_screen.dart';
import '../shop/add_product_screen.dart';
import '../chat/chat_detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  final ChatService _chatService = ChatService();
  late TabController _tabController;
  
  SkilledUserProfile? _profile;
  CustomerProfile? _customerProfile;
  CompanyProfile? _companyProfile;
  List<ReviewModel> _reviews = [];
  UserModel? _userData;
  String? _userRole;
  bool _isLoading = true;
  
  // Check if user is viewing their own profile
  bool get isOwnProfile => FirebaseAuth.instance.currentUser?.uid == widget.userId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load user basic info
      try {
        _userData = await _firestoreService.getUserById(widget.userId);
        _userRole = _userData?.role;
      } catch (e) {
        print('Could not load user data: $e');
      }

      if (_userRole == AppConstants.roleCustomer) {
        _customerProfile = await _firestoreService.getCustomerProfile(widget.userId);
      } else if (_userRole == AppConstants.roleCompany) {
        _companyProfile = await _firestoreService.getCompanyProfile(widget.userId);
      } else {
        _profile = await _firestoreService.getSkilledUserProfile(widget.userId);

        // Try to load reviews, but don't fail if reviews collection doesn't exist or has permission issues
        try {
          _reviews = await _firestoreService.getUserReviews(widget.userId);
        } catch (reviewError) {
          print('Could not load reviews: $reviewError');
          _reviews = []; // Set empty list if reviews fail
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading profile: $e');
      setState(() {
        _isLoading = false;
        _profile = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_userRole == AppConstants.roleCustomer) {
      if (_customerProfile == null) {
        if (isOwnProfile) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => CustomerSetupScreen(userId: widget.userId)),
            );
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return _buildProfileNotFound(
          message: 'This customer has not set up their profile yet',
        );
      }

      return _buildCustomerProfileView();
    }

    if (_userRole == AppConstants.roleCompany) {
      if (_companyProfile == null) {
        if (isOwnProfile) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => CompanySetupScreen(userId: widget.userId)),
            );
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return _buildProfileNotFound(
          message: 'This company has not set up their profile yet',
        );
      }

      return _buildCompanyProfileView();
    }

    if (_profile == null) {
      // If it's own profile, redirect to role-specific setup
      if (isOwnProfile) {
        final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
        final currentUser = authProvider.currentUser;
        
        if (currentUser != null) {
          // Redirect to role-specific profile setup
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Widget setupScreen;
            
            if (currentUser.role == AppConstants.roleSkilledUser) {
              setupScreen = SkilledUserSetupScreen(userId: widget.userId);
            } else if (currentUser.role == AppConstants.roleCustomer) {
              setupScreen = CustomerSetupScreen(userId: widget.userId);
            } else if (currentUser.role == AppConstants.roleCompany) {
              setupScreen = CompanySetupScreen(userId: widget.userId);
            } else {
              // Fallback to skilled setup
              setupScreen = SkilledUserSetupScreen(userId: widget.userId);
            }
            
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => setupScreen),
            );
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
      }
      
      // For other users or error case
      return _buildProfileNotFound(
        message: isOwnProfile
            ? 'Complete your profile to get started'
            : 'This user has not set up their profile yet',
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Profile Header
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            actions: [
              if (isOwnProfile)
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white),
                  onPressed: () async {
                    final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
                    final currentUser = authProvider.currentUser;
                    
                    Widget editScreen = SkilledUserSetupScreen(userId: widget.userId);
                    
                    if (currentUser?.role == AppConstants.roleCustomer) {
                      editScreen = CustomerSetupScreen(userId: widget.userId);
                    } else if (currentUser?.role == AppConstants.roleCompany) {
                      editScreen = CompanySetupScreen(userId: widget.userId);
                    }
                    
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => editScreen),
                    );
                    _loadProfile();
                  },
                )
              else ...[  
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.white),
                  onPressed: () {
                    Share.share(
                      'Check out ${_userData?.name ?? 'this profile'} on SkillShare!\n'
                      'Category: ${_profile!.category}\n'
                      'Rating: ${_profile!.rating.toStringAsFixed(1)} ⭐',
                      subject: 'SkillShare Profile',
                    );
                  },
                ),
                PopupMenuButton(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'report',
                      child: Row(
                        children: [
                          Icon(Icons.report, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Report Profile'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'block',
                      child: Row(
                        children: [
                          Icon(Icons.block, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Block User'),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'report') {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Report feature coming soon')),
                      );
                    } else if (value == 'block') {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Block feature coming soon')),
                      );
                    }
                  },
                ),
              ],
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Cover Image/Gradient
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  // Profile Info
                  Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: Column(
                      children: [
                        // Profile Image
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: WebImageLoader.loadAvatar(
                            imageUrl: _profile!.profilePicture,
                            radius: 55,
                            fallbackText: _userData?.name,
                            backgroundColor: Colors.grey[300],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Name
                        Text(
                          _userData?.name ?? 'User',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Category with verification badge
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _profile!.category ?? 'Skilled Professional',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            if (_profile!.isVerified) ...[  
                              const SizedBox(width: 6),
                              const Icon(Icons.verified, color: Colors.white, size: 20),
                            ],
                          ],
                        ),
                        if (_profile!.city != null || _profile!.address != null) ...[  
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.location_on, color: Colors.white70, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                _profile!.city ?? _profile!.address ?? '',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bio and Stats
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.star,
                          value: _profile!.rating.toStringAsFixed(1),
                          label: 'Rating',
                          color: Colors.amber,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.reviews,
                          value: _profile!.reviewCount.toString(),
                          label: 'Reviews',
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.work,
                          value: _profile!.projectCount.toString(),
                          label: 'Projects',
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Rating Bar
                  Row(
                    children: [
                      RatingBarIndicator(
                        rating: _profile!.rating,
                        itemBuilder: (context, index) => const Icon(
                          Icons.star,
                          color: Colors.amber,
                        ),
                        itemCount: 5,
                        itemSize: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_profile!.rating.toStringAsFixed(1)} (${_profile!.reviewCount} reviews)',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Bio
                  const Text(
                    'Bio',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _profile!.bio.isEmpty ? 'No bio available' : _profile!.bio,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 16),
                  // Skills
                  const Text(
                    'Skills',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _profile!.skills.map((skill) {
                      return Chip(
                        label: Text(skill),
                        backgroundColor: const Color(0xFF2196F3).withValues(alpha: 0.1),
                        labelStyle: const TextStyle(color: Color(0xFF2196F3)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  // Action Buttons - only show for other users' profiles
                  if (!isOwnProfile) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              // Create or get existing chat and navigate to chat screen
                              try {
                                final currentUser = FirebaseAuth.instance.currentUser;
                                if (currentUser == null) return;
                                
                                // Get current user data
                                final currentUserData = await _firestoreService.getUserById(currentUser.uid);
                                if (currentUserData == null || _userData == null) return;
                                
                                // Show loading
                                if (!mounted) return;
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (_) => const Center(child: CircularProgressIndicator()),
                                );
                                
                                // Get or create chat
                                final chatId = await _chatService.getOrCreateChat(
                                  currentUser.uid,
                                  widget.userId,
                                  {
                                    'name': currentUserData.name,
                                    'profilePhoto': currentUserData.profilePhoto,
                                  },
                                  {
                                    'name': _userData!.name,
                                    'profilePhoto': _userData!.profilePhoto,
                                  },
                                );
                                
                                // Close loading
                                if (!mounted) return;
                                Navigator.of(context).pop();
                                
                                // Navigate to chat detail screen
                                if (!mounted) return;
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ChatDetailScreen(
                                      chatId: chatId,
                                      otherUserId: widget.userId,
                                      otherUserName: _userData!.name,
                                      otherUserPhoto: _userData!.profilePhoto,
                                    ),
                                  ),
                                );
                              } catch (e) {
                                // Close loading if still showing
                                if (!mounted) return;
                                Navigator.of(context).pop();
                                
                                // Show error
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to start chat: $e')),
                                );
                              }
                            },
                            icon: const Icon(Icons.message),
                            label: const Text('Message'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2196F3),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // TODO: Send request
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Hire feature coming soon')),
                              );
                            },
                            icon: const Icon(Icons.handshake),
                            label: const Text('Hire'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4CAF50),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Contact Info Card
                    if (_userData?.phone != null || _userData?.email != null)
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.contact_phone, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Contact Information',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (_userData?.phone != null)
                                ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.phone, color: Color(0xFF2196F3)),
                                  title: Text(_userData!.phone!),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.copy, size: 20),
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: _userData!.phone!));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Phone copied to clipboard')),
                                      );
                                    },
                                  ),
                                ),
                              if (_userData?.email != null)
                                ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.email, color: Color(0xFF2196F3)),
                                  title: Text(_userData!.email),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.copy, size: 20),
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: _userData!.email));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Email copied to clipboard')),
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                  // Add Product button for own profile
                  if (isOwnProfile) ...[
                    ElevatedButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AddProductScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_shopping_cart),
                      label: const Text('Add Product to Shop'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE91E63),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Own Profile Stats Card
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.visibility, color: Color(0xFF2196F3)),
                                const SizedBox(width: 8),
                                const Text(
                                  'Profile Visibility: ',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  _profile!.visibility == AppConstants.visibilityPublic
                                      ? 'Public'
                                      : 'Private',
                                  style: TextStyle(
                                    color: _profile!.visibility == AppConstants.visibilityPublic
                                        ? Colors.green
                                        : Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.verified_user, color: Color(0xFF4CAF50)),
                                const SizedBox(width: 8),
                                const Text(
                                  'Verification: ',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  _profile!.isVerified ? 'Verified' : 'Pending',
                                  style: TextStyle(
                                    color: _profile!.isVerified ? Colors.green : Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
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

          // Tabs
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverAppBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF2196F3),
                unselectedLabelColor: Colors.grey,
                indicatorColor: const Color(0xFF2196F3),
                tabs: const [
                  Tab(text: 'Portfolio'),
                  Tab(text: 'Services'),
                  Tab(text: 'Reviews'),
                ],
              ),
            ),
          ),

          // Tab Content
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Portfolio Tab
                _buildPortfolioTab(),
                // Services Tab
                _buildServicesTab(),
                // Reviews Tab
                _buildReviewsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileNotFound({required String message}) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Profile not found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerProfileView() {
    final profile = _customerProfile!;
    final imageUrl = profile.profilePicture?.isNotEmpty == true
        ? profile.profilePicture
        : _userData?.profilePhoto;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Profile'),
        actions: [
          if (isOwnProfile)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CustomerSetupScreen(userId: widget.userId),
                  ),
                );
                _loadProfile();
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: WebImageLoader.loadAvatar(
                imageUrl: imageUrl,
                radius: 60,
                fallbackText: _userData?.name,
                backgroundColor: Colors.grey[300],
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                _userData?.name ?? 'Customer',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            if (profile.location != null && profile.location!.isNotEmpty)
              Center(
                child: Text(
                  profile.location!,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            const SizedBox(height: 24),
            const Text(
              'About',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(profile.bio.isEmpty ? 'No bio available' : profile.bio),
            const SizedBox(height: 16),
            const Text(
              'Interests',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (profile.interests.isEmpty)
              const Text('No interests added')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: profile.interests
                    .map((interest) => Chip(label: Text(interest)))
                    .toList(),
              ),
            const SizedBox(height: 16),
            const Text(
              'Looking For',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (profile.lookingFor.isEmpty)
              const Text('No services selected')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: profile.lookingFor
                    .map((category) => Chip(label: Text(category)))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyProfileView() {
    final profile = _companyProfile!;
    final imageUrl = profile.logoUrl?.isNotEmpty == true
        ? profile.logoUrl
        : _userData?.profilePhoto;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Company Profile'),
        actions: [
          if (isOwnProfile)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CompanySetupScreen(userId: widget.userId),
                  ),
                );
                _loadProfile();
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: WebImageLoader.loadAvatar(
                imageUrl: imageUrl,
                radius: 60,
                fallbackText: profile.companyName,
                backgroundColor: Colors.grey[300],
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                profile.companyName.isNotEmpty ? profile.companyName : 'Company',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            if (profile.industry.isNotEmpty)
              Center(
                child: Text(
                  profile.industry,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            const SizedBox(height: 24),
            const Text(
              'About',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(profile.description.isEmpty ? 'No description available' : profile.description),
            const SizedBox(height: 16),
            if (profile.website != null && profile.website!.isNotEmpty) ...[
              const Text(
                'Website',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(profile.website!),
              const SizedBox(height: 16),
            ],
            if (profile.headOfficeLocation != null && profile.headOfficeLocation!.isNotEmpty) ...[
              const Text(
                'Head Office',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(profile.headOfficeLocation!),
              const SizedBox(height: 16),
            ],
            if (profile.employeeCount != null && profile.employeeCount!.isNotEmpty) ...[
              const Text(
                'Company Size',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('${profile.employeeCount} employees'),
              const SizedBox(height: 16),
            ],
            if (profile.gstNumber != null && profile.gstNumber!.isNotEmpty) ...[
              const Text(
                'GST Number',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(profile.gstNumber!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPortfolioTab() {
    if (_profile!.portfolioImages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              isOwnProfile 
                  ? 'No portfolio images yet\nAdd some in edit profile'
                  : 'No portfolio items',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: _profile!.portfolioImages.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () {
            _showFullScreenImage(context, index);
          },
          child: Hero(
            tag: 'portfolio_$index',
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: WebImageLoader.loadImage(
                  imageUrl: _profile!.portfolioImages[index],
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showFullScreenImage(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullScreenImageViewer(
          images: _profile!.portfolioImages,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Widget _buildServicesTab() {
    return FutureBuilder<List<ServiceModel>>(
      future: _firestoreService.getUserServices(widget.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading services: ${snapshot.error}'));
        }
        final services = snapshot.data ?? [];
        if (services.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.miscellaneous_services, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('No services listed yet', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: services.length,
          itemBuilder: (context, index) {
            final service = services[index];
            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            service.title,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: service.isActive ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            service.isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              fontSize: 11,
                              color: service.isActive ? Colors.green : Colors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      service.description,
                      style: TextStyle(color: Colors.grey[700], fontSize: 14),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.currency_rupee, size: 16, color: Color(0xFF4CAF50)),
                          Text(
                            '${service.priceMin.toStringAsFixed(0)} - ${service.priceMax.toStringAsFixed(0)} ${service.priceUnit}',
                            style: const TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsTab() {
    if (_reviews.isEmpty) {
      return const Center(child: Text('No reviews yet'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _reviews.length,
      itemBuilder: (context, index) {
        final review = _reviews[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundImage: WebImageLoader.getImageProvider(review.reviewerPhoto),
                      child: review.reviewerPhoto == null || review.reviewerPhoto!.isEmpty
                          ? Text(review.reviewerName.isNotEmpty ? review.reviewerName[0].toUpperCase() : 'U')
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            review.reviewerName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          RatingBarIndicator(
                            rating: review.rating,
                            itemBuilder: (context, index) => const Icon(
                              Icons.star,
                              color: Colors.amber,
                            ),
                            itemCount: 5,
                            itemSize: 16,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(review.comment),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

// Fullscreen Image Viewer
class _FullScreenImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _FullScreenImageViewer({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_currentIndex + 1} / ${widget.images.length}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Download feature coming soon')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              Share.share(widget.images[_currentIndex]);
            },
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.images.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          return Center(
            child: index == _currentIndex
              ? Hero(
                  tag: 'portfolio_$index',
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: WebImageLoader.loadImage(
                      imageUrl: widget.images[index],
                      fit: BoxFit.contain,
                    ),
                  ),
                )
              : InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: WebImageLoader.loadImage(
                    imageUrl: widget.images[index],
                    fit: BoxFit.contain,
                  ),
                ),
          );
        },
      ),
      bottomNavigationBar: widget.images.length > 1
          ? Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.images.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentIndex == index
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
