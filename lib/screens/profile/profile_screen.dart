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
import '../../utils/user_roles.dart';
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

class _ProfileScreenState extends State<ProfileScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final ChatService _chatService = ChatService();

  SkilledUserProfile? _profile;
  CustomerProfile? _customerProfile;
  CompanyProfile? _companyProfile;
  List<ReviewModel> _reviews = [];
  UserModel? _userData;
  String? _userRole;
  bool _isLoading = true;

  // Check if user is viewing their own profile
  bool get isOwnProfile =>
      FirebaseAuth.instance.currentUser?.uid == widget.userId;

  String? get _currentViewerRole {
    final auth = Provider.of<app_auth.AuthProvider>(context, listen: false);
    return UserRoles.normalizeRole(auth.userRole ?? '');
  }

  bool get _canCurrentUserReview {
    final role = _currentViewerRole;
    return role == UserRoles.customer || role == UserRoles.company;
  }

  bool get _isCurrentUserCompany => _currentViewerRole == UserRoles.company;

  bool get _isCurrentUserCustomer => _currentViewerRole == UserRoles.customer;

  void _showReportDialog() {
    final reasonController = TextEditingController();
    final reasons = [
      'Spam or misleading',
      'Inappropriate content',
      'Fake profile',
      'Harassment',
      'Other',
    ];
    String? selectedReason;
    bool isSending = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.flag, color: Colors.red),
              SizedBox(width: 8),
              Text('Report User'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Why are you reporting this user?'),
                const SizedBox(height: 12),
                ...reasons.map((r) => RadioListTile<String>(
                      title: Text(r),
                      value: r,
                      groupValue: selectedReason,
                      onChanged: (v) => setDialogState(() => selectedReason = v),
                      dense: true,
                    )),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Additional details (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: (isSending || selectedReason == null)
                  ? null
                  : () async {
                      final currentUid =
                          FirebaseAuth.instance.currentUser?.uid;
                      if (currentUid == null) return;
                      setDialogState(() => isSending = true);
                      try {
                        await _firestoreService.submitProfileReport(
                          reporterId: currentUid,
                          reportedUserId: widget.userId,
                          reason: selectedReason!,
                          details: reasonController.text.trim().isEmpty
                              ? null
                              : reasonController.text.trim(),
                        );
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        // ignore: use_build_context_synchronously
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('User reported. Thank you.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        setDialogState(() => isSending = false);
                        // ignore: use_build_context_synchronously
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red),
              child: isSending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Report',
                      style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showBlockDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.block, color: Colors.red),
            SizedBox(width: 8),
            Text('Block User'),
          ],
        ),
        content: const Text(
          'This user will no longer be able to send you messages or view your profile. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final currentUid = FirebaseAuth.instance.currentUser?.uid;
              if (currentUid == null) return;
              Navigator.pop(ctx);
              try {
                await _firestoreService.blockUser(
                  blockerId: currentUid,
                  blockedUserId: widget.userId,
                );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('User blocked successfully.'),
                    backgroundColor: Colors.green,
                  ),
                );
                Navigator.pop(context); // Go back from profile
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Block',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _showHireRequestDialog() async {
    if (!_isCurrentUserCompany) return;

    final titleController = TextEditingController();
    final descController = TextEditingController();
    final currentUser = FirebaseAuth.instance.currentUser;
    final messenger = ScaffoldMessenger.of(context);
    String selectedHireType = 'full_time';

    const hireTypes = [
      {'value': 'full_time', 'label': 'Full-time Employee', 'icon': Icons.work},
      {
        'value': 'part_time',
        'label': 'Part-time / Freelance',
        'icon': Icons.access_time
      },
      {
        'value': 'project_based',
        'label': 'Project-based',
        'icon': Icons.task_alt
      },
    ];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text('Send Hire Request'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        hintText: 'Project / position title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      minLines: 3,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Describe the work requirement',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Hire Type',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(hireTypes.length, (i) {
                      final ht = hireTypes[i];
                      final isSelected =
                          selectedHireType == ht['value'] as String;
                      return GestureDetector(
                        onTap: () => setDialogState(
                            () => selectedHireType = ht['value'] as String),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF3F51B5)
                                    .withValues(alpha: 0.08)
                                : Colors.grey[50],
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF3F51B5)
                                  : Colors.grey[300]!,
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                ht['icon'] as IconData,
                                size: 18,
                                color: isSelected
                                    ? const Color(0xFF3F51B5)
                                    : Colors.grey[600],
                              ),
                              const SizedBox(width: 10),
                              Text(
                                ht['label'] as String,
                                style: TextStyle(
                                  color: isSelected
                                      ? const Color(0xFF3F51B5)
                                      : Colors.black87,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  fontSize: 14,
                                ),
                              ),
                              if (isSelected)
                                const Spacer(),
                              if (isSelected)
                                const Icon(Icons.check_circle,
                                    color: Color(0xFF3F51B5), size: 18),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3F51B5),
                      foregroundColor: Colors.white),
                  child: const Text('Send Request'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || currentUser == null) {
      titleController.dispose();
      descController.dispose();
      return;
    }

    try {
      await _firestoreService.createHireRequest(
        requesterId: currentUser.uid,
        skilledUserId: widget.userId,
        title: titleController.text.trim(),
        description: descController.text.trim(),
        hireType: selectedHireType,
      );
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Hire request sent'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to send hire request: $e')),
      );
    } finally {
      titleController.dispose();
      descController.dispose();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
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
        debugPrint('Could not load user data: $e');
      }

      if (_userRole == AppConstants.roleCustomer) {
        _customerProfile =
            await _firestoreService.getCustomerProfile(widget.userId);
      } else if (_userRole == AppConstants.roleCompany) {
        _companyProfile =
            await _firestoreService.getCompanyProfile(widget.userId);
      } else {
        _profile = await _firestoreService.getSkilledUserProfile(widget.userId);

        // Try to load reviews, but don't fail if reviews collection doesn't exist or has permission issues
        try {
          _reviews = await _firestoreService.getUserReviews(widget.userId);
        } catch (reviewError) {
          debugPrint('Could not load reviews: $reviewError');
          _reviews = []; // Set empty list if reviews fail
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading profile: $e');
      setState(() {
        _isLoading = false;
        _profile = null;
      });
    }
  }

  Future<void> _showAddReviewDialog() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || _userData == null) return;

    // Unfocus before opening dialog to avoid Flutter web pointer assertion.
    FocusManager.instance.primaryFocus?.unfocus();

    double rating = 5.0;
    final commentController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Write a Review'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Rate this skilled person'),
                  const SizedBox(height: 8),
                  RatingBar.builder(
                    initialRating: rating,
                    minRating: 1,
                    allowHalfRating: true,
                    itemSize: 30,
                    itemBuilder: (context, _) =>
                        const Icon(Icons.star, color: Colors.amber),
                    onRatingUpdate: (value) => setStateDialog(() {
                      rating = value;
                    }),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: commentController,
                    autofocus: false,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 3,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Comment',
                      hintText: 'Share your experience',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );

    if (submitted != true) {
      commentController.dispose();
      return;
    }

    final normalizedComment = commentController.text.trim();
    commentController.dispose();

    try {
      final reviewerData = await _firestoreService.getUserById(currentUser.uid);
      final reviewerName = reviewerData?.name.trim().isNotEmpty == true
          ? reviewerData!.name
          : 'User';
      final reviewerPhoto = reviewerData?.profilePhoto;

      await _firestoreService.createReview(
        ReviewModel(
          id: '',
          skilledUserId: widget.userId,
          reviewerId: currentUser.uid,
          reviewerName: reviewerName,
          reviewerPhoto: reviewerPhoto,
          rating: rating,
          comment: normalizedComment,
          createdAt: DateTime.now(),
        ),
      );

      await _loadProfile();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Review submitted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to submit review: $e')),
      );
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
              MaterialPageRoute(
                  builder: (_) => CustomerSetupScreen(userId: widget.userId)),
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
              MaterialPageRoute(
                  builder: (_) => CompanySetupScreen(userId: widget.userId)),
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
        final authProvider =
            Provider.of<app_auth.AuthProvider>(context, listen: false);
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

    return _buildSkilledPersonProfile();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LinkedIn / Instagram style skilled-person profile
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSkilledPersonProfile() {
    const coverHeight = 210.0;
    const avatarRadius = 52.0;

    // gradient stops derived from category for a unique feel
    final List<Color> coverColors = _getCoverGradient(_profile!.category);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: CustomScrollView(
        slivers: [
          // ── Pinned app-bar overlay (transparent → fills as you scroll) ──
          SliverAppBar(
            pinned: true,
            expandedHeight: coverHeight,
            backgroundColor: coverColors.first,
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              if (isOwnProfile)
                _appBarIcon(Icons.edit_rounded, () async {
                  final authProvider = Provider.of<app_auth.AuthProvider>(
                      context,
                      listen: false);
                  final currentUser = authProvider.currentUser;
                  Widget editScreen =
                      SkilledUserSetupScreen(userId: widget.userId);
                  if (currentUser?.role == AppConstants.roleCustomer) {
                    editScreen = CustomerSetupScreen(userId: widget.userId);
                  } else if (currentUser?.role == AppConstants.roleCompany) {
                    editScreen = CompanySetupScreen(userId: widget.userId);
                  }
                  await Navigator.push(context,
                      MaterialPageRoute(builder: (_) => editScreen));
                  _loadProfile();
                })
              else ...[
                _appBarIcon(Icons.share_rounded, () {
                  Share.share(
                    'Check out ${_userData?.name ?? 'this profile'} on SkillShare!\n'
                    'Category: ${_profile!.category}\n'
                    'Rating: ${_profile!.rating.toStringAsFixed(1)} ⭐',
                    subject: 'SkillShare Profile',
                  );
                }),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                        value: 'report',
                        child: Row(children: [
                          Icon(Icons.report, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Report')
                        ])),
                    PopupMenuItem(
                        value: 'block',
                        child: Row(children: [
                          Icon(Icons.block, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Block')
                        ])),
                  ],
                  onSelected: (v) {
                    if (v == 'report') _showReportDialog();
                    if (v == 'block') _showBlockDialog();
                  },
                ),
              ],
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _buildCoverBanner(coverColors, coverHeight),
            ),
          ),

          // ── Avatar + name card ──
          SliverToBoxAdapter(
            child: _buildProfileIdentitySection(avatarRadius, coverColors),
          ),

          // ── Action buttons ──
          if (!isOwnProfile)
            SliverToBoxAdapter(
              child: _buildActionButtons(),
            ),

          // ── Own-profile controls ──
          if (isOwnProfile)
            SliverToBoxAdapter(
              child: _buildOwnProfileControls(),
            ),

          // ── Bio ──
          SliverToBoxAdapter(child: _buildBioSection()),

          // ── Skills ──
          if (_profile!.skills.isNotEmpty)
            SliverToBoxAdapter(child: _buildSkillsSection()),

          // ── Services ──
          SliverToBoxAdapter(child: _buildServicesSection()),

          // ── Portfolio ──
          SliverToBoxAdapter(child: _buildPortfolioSection()),

          // ── Reviews ──
          SliverToBoxAdapter(child: _buildReviewsSection()),

          const SliverToBoxAdapter(child: SizedBox(height: 48)),
        ],
      ),
    );
  }

  List<Color> _getCoverGradient(String? category) {
    const Map<String, List<Color>> palettes = {
      'Baking': [Color(0xFFFF6B9D), Color(0xFFC44FEB)],
      'Photography': [Color(0xFF667EEA), Color(0xFF764BA2)],
      'Tailoring': [Color(0xFFf093fb), Color(0xFFf5576c)],
      'Carpentry': [Color(0xFF4facfe), Color(0xFF00f2fe)],
      'Electrician': [Color(0xFF43e97b), Color(0xFF38f9d7)],
      'Plumbing': [Color(0xFF0ba360), Color(0xFF3cba92)],
      'Web Dev': [Color(0xFF30cfd0), Color(0xFF667eea)],
      'Painting': [Color(0xFFfa709a), Color(0xFFfee140)],
    };
    for (final entry in palettes.entries) {
      if (category?.toLowerCase().contains(entry.key.toLowerCase()) == true) {
        return entry.value;
      }
    }
    return const [Color(0xFF6A11CB), Color(0xFF2575FC)];
  }

  Widget _appBarIcon(IconData icon, VoidCallback onTap) => IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onTap,
      );

  Widget _buildCoverBanner(List<Color> colors, double height) {
    const overlapFromBanner = 40.0;
    const avatarRadius = 52.0;
    const avatarBorder = 3.0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Gradient fill
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        // Decorative blobs
        Positioned(
          top: -40,
          right: -40,
          child: _blob(200, Colors.white.withValues(alpha: 0.08)),
        ),
        Positioned(
          top: 20,
          left: -50,
          child: _blob(160, Colors.white.withValues(alpha: 0.06)),
        ),
        Positioned(
          bottom: 30,
          right: 60,
          child: _blob(80, Colors.white.withValues(alpha: 0.05)),
        ),
        // Category pill — upper centre of banner
        Positioned(
          top: 70,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.45), width: 1.2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded,
                      color: Colors.white, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    _profile!.category ?? 'Skilled Professional',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Avatar straddling the banner bottom
        Positioned(
          bottom: -overlapFromBanner,
          left: 20,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                  colors: colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              boxShadow: [
                BoxShadow(
                  color: colors.last.withValues(alpha: 0.45),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.all(avatarBorder),
            child: CircleAvatar(
              radius: avatarRadius,
              backgroundColor: Colors.white,
              child: WebImageLoader.loadAvatar(
                imageUrl: _profile!.profilePicture,
                radius: avatarRadius - 1,
                fallbackText: _userData?.name,
                backgroundColor: Colors.grey[100],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _blob(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  Widget _buildProfileIdentitySection(
      double avatarRadius, List<Color> coverColors) {
    return Transform.translate(
      offset: const Offset(0, -40),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Avatar with border
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                        colors: coverColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    boxShadow: [
                      BoxShadow(
                        color: coverColors.last.withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(3),
                  child: CircleAvatar(
                    radius: avatarRadius,
                    backgroundColor: Colors.white,
                    child: WebImageLoader.loadAvatar(
                      imageUrl: _profile!.profilePicture,
                      radius: avatarRadius - 3,
                      fallbackText: _userData?.name,
                      backgroundColor: Colors.grey[100],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Stats row beside avatar
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _miniStat(_profile!.rating.toStringAsFixed(1),
                            'Rating', Icons.star_rounded, Colors.amber),
                        _miniStat(_profile!.reviewCount.toString(), 'Reviews',
                            Icons.reviews_rounded, const Color(0xFF2196F3)),
                        _miniStat(_profile!.projectCount.toString(), 'Projects',
                            Icons.work_rounded, const Color(0xFF4CAF50)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Name
            Text(
              _userData?.name ?? 'User',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            // Location + Verified badge row
            Row(
              children: [
                if (_profile!.city != null || _profile!.address != null) ...[
                  const Icon(Icons.location_on_rounded,
                      size: 14, color: Color(0xFF9E9E9E)),
                  const SizedBox(width: 3),
                  Text(
                    _profile!.city ?? _profile!.address ?? '',
                    style:
                        const TextStyle(color: Color(0xFF9E9E9E), fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                ],
                if (_profile!.isVerified) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_rounded,
                            size: 12, color: Colors.white),
                        SizedBox(width: 4),
                        Text('Verified Expert',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            // Star rating bar
            Row(
              children: [
                RatingBarIndicator(
                  rating: _profile!.rating,
                  itemBuilder: (_, __) =>
                      const Icon(Icons.star_rounded, color: Colors.amber),
                  itemCount: 5,
                  itemSize: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  '${_profile!.rating.toStringAsFixed(1)}  •  ${_profile!.reviewCount} reviews',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(
      String value, String label, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800])),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E))),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          // Message button
          Expanded(
            child: _gradientButton(
              label: 'Message',
              icon: Icons.chat_bubble_rounded,
              colors: const [Color(0xFF2979FF), Color(0xFF00B0FF)],
              onTap: () async {
                final nav = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                final ctx = context;
                try {
                  final currentUser = FirebaseAuth.instance.currentUser;
                  if (currentUser == null) return;
                  final currentUserData =
                      await _firestoreService.getUserById(currentUser.uid);
                  if (currentUserData == null || _userData == null) return;
                  if (!mounted) return;
                  showDialog(
                    context: ctx,
                    barrierDismissible: false,
                    builder: (_) =>
                        const Center(child: CircularProgressIndicator()),
                  );
                  final chatId = await _chatService.getOrCreateChat(
                    currentUser.uid,
                    widget.userId,
                    {
                      'name': currentUserData.name,
                      'profilePhoto': currentUserData.profilePhoto
                    },
                    {'name': _userData!.name, 'profilePhoto': _userData!.profilePhoto},
                  );
                  if (!mounted) return;
                  nav.pop();
                  nav.push(MaterialPageRoute(
                    builder: (_) => ChatDetailScreen(
                      chatId: chatId,
                      otherUserId: widget.userId,
                      otherUserName: _userData!.name,
                      otherUserPhoto: _userData!.profilePhoto,
                    ),
                  ));
                } catch (e) {
                  if (!mounted) return;
                  nav.pop();
                  messenger.showSnackBar(
                      SnackBar(content: Text('Failed to start chat: $e')));
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          // Hire / Review button
          if (_isCurrentUserCustomer && _canCurrentUserReview)
            Expanded(
              child: _gradientButton(
                label: 'Review',
                icon: Icons.star_rate_rounded,
                colors: const [Color(0xFF43E97B), Color(0xFF38F9D7)],
                onTap: _showAddReviewDialog,
              ),
            ),
          if (_isCurrentUserCompany)
            Expanded(
              child: _gradientButton(
                label: 'Hire',
                icon: Icons.handshake_rounded,
                colors: const [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                onTap: _showHireRequestDialog,
              ),
            ),
        ],
      ),
    );
  }

  Widget _gradientButton({
    required String label,
    required IconData icon,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: colors.last.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 7),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildOwnProfileControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AddProductScreen()));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFE91E63), Color(0xFFFF6B9D)]),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFFE91E63).withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_shopping_cart_rounded,
                      color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('Add Product to Shop',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Visibility + Verification badges
          Row(
            children: [
              _infoBadge(
                icon: _profile!.visibility == AppConstants.visibilityPublic
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                label: _profile!.visibility == AppConstants.visibilityPublic
                    ? 'Public'
                    : 'Private',
                color: _profile!.visibility == AppConstants.visibilityPublic
                    ? const Color(0xFF4CAF50)
                    : Colors.orange,
              ),
              const SizedBox(width: 8),
              _infoBadge(
                icon: _profile!.isVerified
                    ? Icons.verified_rounded
                    : Icons.pending_rounded,
                label: _profile!.isVerified ? 'Verified' : 'Pending',
                color: _profile!.isVerified
                    ? const Color(0xFF2196F3)
                    : Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoBadge(
      {required IconData icon,
      required String label,
      required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.4)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter),
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 10),
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E))),
        ],
      ),
    );
  }

  Widget _buildBioSection() {
    if (_profile!.bio.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Bio', Icons.info_outline_rounded, const Color(0xFF6A11CB)),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 3)),
              ],
            ),
            child: Text(
              _profile!.bio,
              style: const TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: Color(0xFF444466)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsSection() {
    final skillColors = [
      const Color(0xFF6A11CB),
      const Color(0xFF2575FC),
      const Color(0xFFE91E63),
      const Color(0xFF4CAF50),
      const Color(0xFFFF9800),
      const Color(0xFF00BCD4),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
              'Skills', Icons.auto_awesome_rounded, const Color(0xFFE91E63)),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 3)),
              ],
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_profile!.skills.length, (i) {
                final color = skillColors[i % skillColors.length];
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _profile!.skills[i],
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
              'Services', Icons.design_services_rounded, const Color(0xFF2575FC)),
          FutureBuilder<List<ServiceModel>>(
            future: _firestoreService.getUserServices(widget.userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator()));
              }
              final services = snapshot.data ?? [];
              if (services.isEmpty) {
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Icon(Icons.design_services,
                          size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 8),
                      Text('No services listed yet',
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 14)),
                    ],
                  ),
                );
              }
              return Column(
                children: services
                    .map((s) => _buildServiceCard(s))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(ServiceModel service) {
    const serviceIcons = [
      Icons.star_rounded,
      Icons.bolt_rounded,
      Icons.brush_rounded,
      Icons.construction_rounded,
      Icons.camera_alt_rounded,
    ];
    final icon = serviceIcons[service.title.length % serviceIcons.length];
    const iconColors = [
      Color(0xFFE91E63),
      Color(0xFFFF9800),
      Color(0xFF9C27B0),
      Color(0xFF2196F3),
      Color(0xFF4CAF50),
    ];
    final iconColor = iconColors[service.title.length % iconColors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service.title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E))),
                const SizedBox(height: 2),
                Text(
                  service.description,
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey[500]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [iconColor, iconColor.withValues(alpha: 0.7)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '₹${service.priceMin.toStringAsFixed(0)}/${service.priceUnit.replaceAll('per ', '')}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolioSection() {
    if (_profile!.portfolioImages.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('Portfolio', Icons.photo_library_rounded,
                const Color(0xFF4CAF50)),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  Icon(Icons.photo_library, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 8),
                  Text('No portfolio yet',
                      style:
                          TextStyle(color: Colors.grey[500], fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
              'Portfolio', Icons.photo_library_rounded, const Color(0xFF4CAF50)),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossCount =
                  constraints.maxWidth > 600 ? 4 : 3;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossCount,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  childAspectRatio: 1,
                ),
                itemCount: _profile!.portfolioImages.length,
                itemBuilder: (ctx, i) => GestureDetector(
                  onTap: () => _showFullScreenImage(context, i),
                  child: Hero(
                    tag: 'portfolio_$i',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: WebImageLoader.loadImage(
                        imageUrl: _profile!.portfolioImages[i],
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _sectionHeader(
                    'Reviews', Icons.reviews_rounded, Colors.amber),
              ),
              if (!isOwnProfile && _canCurrentUserReview)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: GestureDetector(
                    onTap: _showAddReviewDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Colors.amber, Color(0xFFFF9800)]),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text('Add Review',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (_reviews.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  Icon(Icons.rate_review, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 8),
                  Text('No reviews yet',
                      style:
                          TextStyle(color: Colors.grey[500], fontSize: 14)),
                ],
              ),
            )
          else
            Column(
              children: _reviews
                  .take(5)
                  .map((r) => _buildReviewCard(r))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(ReviewModel review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WebImageLoader.loadAvatar(
            imageUrl: review.reviewerPhoto,
            radius: 22,
            fallbackText: review.reviewerName,
            backgroundColor: Colors.grey[200],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        review.reviewerName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF1A1A2E)),
                      ),
                    ),
                    RatingBarIndicator(
                      rating: review.rating,
                      itemBuilder: (_, __) => const Icon(Icons.star_rounded,
                          color: Colors.amber),
                      itemCount: 5,
                      itemSize: 14,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(review.comment,
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        height: 1.4)),
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
    const coverColors = [Color(0xFF9C27B0), Color(0xFFE91E63)];
    const coverHeight = 200.0;
    const avatarRadius = 52.0;
    const avatarBorder = 3.0;
    const avatarTotal = avatarRadius + avatarBorder; // 55
    const overlapFromBanner = 40.0;

    // Build location string cleanly – filter out blanks / single chars
    String locationText = '';
    if (profile.city != null && profile.city!.trim().length > 1) {
      locationText = profile.city!.trim();
    }
    if (profile.state != null && profile.state!.trim().length > 1) {
      locationText = locationText.isEmpty
          ? profile.state!.trim()
          : '$locationText, ${profile.state!.trim()}';
    }
    if (locationText.isEmpty &&
        profile.location != null &&
        profile.location!.trim().length > 2) {
      locationText = profile.location!.trim();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: coverHeight,
            backgroundColor: coverColors.first,
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              if (isOwnProfile)
                IconButton(
                  icon: const Icon(Icons.edit_rounded, color: Colors.white),
                  onPressed: () async {
                    await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                CustomerSetupScreen(userId: widget.userId)));
                    _loadProfile();
                  },
                )
              else
                IconButton(
                  icon: const Icon(Icons.chat_bubble_rounded,
                      color: Colors.white),
                  onPressed: () async {
                    final nav = Navigator.of(context);
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      final cu = FirebaseAuth.instance.currentUser;
                      if (cu == null) return;
                      final cuData =
                          await _firestoreService.getUserById(cu.uid);
                      if (cuData == null || _userData == null) return;
                      if (!mounted) return;
                      showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => const Center(
                              child: CircularProgressIndicator()));
                      final chatId = await _chatService.getOrCreateChat(
                        cu.uid,
                        widget.userId,
                        {
                          'name': cuData.name,
                          'profilePhoto': cuData.profilePhoto
                        },
                        {
                          'name': _userData!.name,
                          'profilePhoto': _userData!.profilePhoto
                        },
                      );
                      if (!mounted) return;
                      nav.pop();
                      nav.push(MaterialPageRoute(
                          builder: (_) => ChatDetailScreen(
                              chatId: chatId,
                              otherUserId: widget.userId,
                              otherUserName: _userData!.name,
                              otherUserPhoto: _userData!.profilePhoto)));
                    } catch (e) {
                      if (!mounted) return;
                      nav.pop();
                      messenger.showSnackBar(
                          SnackBar(content: Text('Error: $e')));
                    }
                  },
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Gradient fill
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                            colors: coverColors,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                      ),
                    ),
                  ),
                  // Decorative blobs
                  Positioned(
                      top: -40,
                      right: -40,
                      child: _blob(200, Colors.white.withValues(alpha: 0.08))),
                  Positioned(
                      top: 20,
                      left: -50,
                      child: _blob(160, Colors.white.withValues(alpha: 0.06))),
                  Positioned(
                      bottom: 30,
                      right: 60,
                      child: _blob(80, Colors.white.withValues(alpha: 0.05))),
                  // Role pill — centred, in the upper portion of the banner
                  Positioned(
                    top: 70,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.45),
                              width: 1.2),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_rounded,
                                color: Colors.white, size: 14),
                            SizedBox(width: 6),
                            Text('Customer',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    letterSpacing: 0.5)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Avatar — placed so it straddles the banner bottom
                  Positioned(
                    bottom: -overlapFromBanner,
                    left: 20,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                            colors: coverColors,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                        boxShadow: [
                          BoxShadow(
                              color: coverColors.last.withValues(alpha: 0.45),
                              blurRadius: 20,
                              spreadRadius: 2,
                              offset: const Offset(0, 6))
                        ],
                      ),
                      padding: const EdgeInsets.all(avatarBorder),
                      child: CircleAvatar(
                        radius: avatarRadius,
                        backgroundColor: Colors.white,
                        child: WebImageLoader.loadAvatar(
                          imageUrl: imageUrl,
                          radius: avatarRadius - 1,
                          fallbackText: _userData?.name,
                          backgroundColor: const Color(0xFFF3E5F5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Identity row (name + action button) ──
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                  20, overlapFromBanner + 12, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Name + location
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userData?.name ?? 'Customer',
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A2E),
                              letterSpacing: -0.3),
                        ),
                        if (locationText.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded,
                                  size: 14, color: Color(0xFFAA44BB)),
                              const SizedBox(width: 3),
                              Text(locationText,
                                  style: const TextStyle(
                                      color: Color(0xFF777788),
                                      fontSize: 13)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Action button
                  if (isOwnProfile)
                    GestureDetector(
                      onTap: () async {
                        await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => CustomerSetupScreen(
                                    userId: widget.userId)));
                        _loadProfile();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: coverColors),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                                color: coverColors.last
                                    .withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 3))
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_rounded,
                                color: Colors.white, size: 14),
                            SizedBox(width: 6),
                            Text('Edit Profile',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: () async {
                        final nav = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          final cu = FirebaseAuth.instance.currentUser;
                          if (cu == null) return;
                          final cuData =
                              await _firestoreService.getUserById(cu.uid);
                          if (cuData == null || _userData == null) return;
                          if (!mounted) return;
                          showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => const Center(
                                  child: CircularProgressIndicator()));
                          final chatId =
                              await _chatService.getOrCreateChat(
                            cu.uid,
                            widget.userId,
                            {
                              'name': cuData.name,
                              'profilePhoto': cuData.profilePhoto
                            },
                            {
                              'name': _userData!.name,
                              'profilePhoto': _userData!.profilePhoto
                            },
                          );
                          if (!mounted) return;
                          nav.pop();
                          nav.push(MaterialPageRoute(
                              builder: (_) => ChatDetailScreen(
                                  chatId: chatId,
                                  otherUserId: widget.userId,
                                  otherUserName: _userData!.name,
                                  otherUserPhoto:
                                      _userData!.profilePhoto)));
                        } catch (e) {
                          if (!mounted) return;
                          nav.pop();
                          messenger.showSnackBar(
                              SnackBar(content: Text('Error: $e')));
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [
                                Color(0xFF2979FF),
                                Color(0xFF00B0FF)
                              ]),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                                color: const Color(0xFF2979FF)
                                    .withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 3))
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_rounded,
                                color: Colors.white, size: 14),
                            SizedBox(width: 6),
                            Text('Message',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // Bio
          if (profile.bio.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader('About', Icons.info_outline_rounded,
                        const Color(0xFF9C27B0)),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 12,
                              offset: const Offset(0, 3))
                        ],
                      ),
                      child: Text(profile.bio,
                          style: const TextStyle(
                              fontSize: 14,
                              height: 1.65,
                              color: Color(0xFF444466))),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

          // Interests
          if (profile.interests.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader('Interests',
                        Icons.favorite_rounded, const Color(0xFFE91E63)),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 12,
                              offset: const Offset(0, 3))
                        ],
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: profile.interests.map((i) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE91E63)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: const Color(0xFFE91E63)
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Text(i,
                                style: const TextStyle(
                                    color: Color(0xFFE91E63),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

          // Looking For
          if (profile.lookingFor.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader('Looking For',
                        Icons.search_rounded, const Color(0xFF9C27B0)),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 12,
                              offset: const Offset(0, 3))
                        ],
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: profile.lookingFor.map((c) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF9C27B0)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: const Color(0xFF9C27B0)
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Text(c,
                                style: const TextStyle(
                                    color: Color(0xFF9C27B0),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

          // Assigned Projects
          if (profile.assignedProjects.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader('Projects',
                        Icons.folder_rounded, const Color(0xFF4CAF50)),
                    ...profile.assignedProjects
                        .map((p) => _buildProjectCard(p)),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 48)),
        ],
      ),
    );
  }

  Widget _buildCompanyProfileView() {
    final profile = _companyProfile!;
    final imageUrl = profile.logoUrl?.isNotEmpty == true
        ? profile.logoUrl
        : _userData?.profilePhoto;
    const coverColors = [Color(0xFF1565C0), Color(0xFF42A5F5)];
    const coverHeight = 200.0;
    const avatarRadius = 52.0;
    const avatarBorder = 3.0;
    const overlapFromBanner = 40.0;

    // Clean location
    String locationText = '';
    if (profile.city != null && profile.city!.trim().length > 1) {
      locationText = profile.city!.trim();
    }
    if (profile.state != null && profile.state!.trim().length > 1) {
      locationText = locationText.isEmpty
          ? profile.state!.trim()
          : '$locationText, ${profile.state!.trim()}';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: coverHeight,
            backgroundColor: coverColors.first,
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              if (isOwnProfile)
                IconButton(
                  icon: const Icon(Icons.edit_rounded, color: Colors.white),
                  onPressed: () async {
                    await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                CompanySetupScreen(userId: widget.userId)));
                    _loadProfile();
                  },
                )
              else ...
                [
                  IconButton(
                    icon: const Icon(Icons.share_rounded,
                        color: Colors.white),
                    onPressed: () => Share.share(
                        'Check out ${profile.companyName} on SkillShare!\nIndustry: ${profile.industry}',
                        subject: 'SkillShare Company'),
                  ),
                  PopupMenuButton<String>(
                    icon:
                        const Icon(Icons.more_vert, color: Colors.white),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: 'report',
                          child: Row(children: [
                            Icon(Icons.report, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Report')
                          ])),
                    ],
                    onSelected: (v) {
                      if (v == 'report') _showReportDialog();
                    },
                  ),
                ],
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                            colors: coverColors,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                      ),
                    ),
                  ),
                  Positioned(
                      top: -40,
                      right: -40,
                      child: _blob(200, Colors.white.withValues(alpha: 0.08))),
                  Positioned(
                      top: 20,
                      left: -50,
                      child: _blob(160, Colors.white.withValues(alpha: 0.06))),
                  Positioned(
                      bottom: 30,
                      right: 60,
                      child: _blob(80, Colors.white.withValues(alpha: 0.05))),
                  // Industry pill — upper-centre of banner
                  if (profile.industry.isNotEmpty)
                    Positioned(
                      top: 70,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                                color:
                                    Colors.white.withValues(alpha: 0.45),
                                width: 1.2),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.business_rounded,
                                  color: Colors.white, size: 14),
                              const SizedBox(width: 6),
                              Text(profile.industry,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      letterSpacing: 0.5)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // Logo avatar — straddles banner bottom
                  Positioned(
                    bottom: -overlapFromBanner,
                    left: 20,
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                            colors: coverColors,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                        boxShadow: [
                          BoxShadow(
                              color: Color(0x6642A5F5),
                              blurRadius: 20,
                              spreadRadius: 2,
                              offset: Offset(0, 6))
                        ],
                      ),
                      padding: const EdgeInsets.all(avatarBorder),
                      child: CircleAvatar(
                        radius: avatarRadius,
                        backgroundColor: Colors.white,
                        child: WebImageLoader.loadAvatar(
                          imageUrl: imageUrl,
                          radius: avatarRadius - 1,
                          fallbackText: profile.companyName,
                          backgroundColor: const Color(0xFFE3F2FD),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Identity row ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  20, overlapFromBanner + 12, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + industry details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.companyName.isNotEmpty
                              ? profile.companyName
                              : 'Company',
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A2E),
                              letterSpacing: -0.3),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            if (locationText.isNotEmpty) ...[
                              const Icon(Icons.location_on_rounded,
                                  size: 14, color: Color(0xFF1E88E5)),
                              const SizedBox(width: 3),
                              Text(locationText,
                                  style: const TextStyle(
                                      color: Color(0xFF777788),
                                      fontSize: 13)),
                              const SizedBox(width: 8),
                            ],
                            if (profile.isVerified)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                      colors: coverColors),
                                  borderRadius:
                                      BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.verified_rounded,
                                        size: 11, color: Colors.white),
                                    SizedBox(width: 4),
                                    Text('Verified',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight:
                                                FontWeight.bold)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Stats row
                        Row(
                          children: [
                            _miniStat(
                                profile.rating.toStringAsFixed(1),
                                'Rating',
                                Icons.star_rounded,
                                Colors.amber),
                            const SizedBox(width: 16),
                            _miniStat(
                                profile.reviewCount.toString(),
                                'Reviews',
                                Icons.reviews_rounded,
                                const Color(0xFF2196F3)),
                            const SizedBox(width: 16),
                            _miniStat(
                                profile.assignedProjects.length
                                    .toString(),
                                'Projects',
                                Icons.work_rounded,
                                const Color(0xFF4CAF50)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Action button
                  if (isOwnProfile)
                    GestureDetector(
                      onTap: () async {
                        await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => CompanySetupScreen(
                                    userId: widget.userId)));
                        _loadProfile();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: coverColors),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0x5542A5F5),
                                blurRadius: 10,
                                offset: Offset(0, 3))
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_rounded,
                                color: Colors.white, size: 14),
                            SizedBox(width: 6),
                            Text('Edit',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: () async {
                        final nav = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          final cu = FirebaseAuth.instance.currentUser;
                          if (cu == null) return;
                          final cuData =
                              await _firestoreService.getUserById(cu.uid);
                          if (cuData == null || _userData == null) return;
                          if (!mounted) return;
                          showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => const Center(
                                  child: CircularProgressIndicator()));
                          final chatId =
                              await _chatService.getOrCreateChat(
                            cu.uid,
                            widget.userId,
                            {
                              'name': cuData.name,
                              'profilePhoto': cuData.profilePhoto
                            },
                            {
                              'name': _userData!.name,
                              'profilePhoto': _userData!.profilePhoto
                            },
                          );
                          if (!mounted) return;
                          nav.pop();
                          nav.push(MaterialPageRoute(
                              builder: (_) => ChatDetailScreen(
                                  chatId: chatId,
                                  otherUserId: widget.userId,
                                  otherUserName: _userData!.name,
                                  otherUserPhoto:
                                      _userData!.profilePhoto)));
                        } catch (e) {
                          if (!mounted) return;
                          nav.pop();
                          messenger.showSnackBar(
                              SnackBar(content: Text('Error: $e')));
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [
                                Color(0xFF2979FF),
                                Color(0xFF00B0FF)
                              ]),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                                color: const Color(0xFF2979FF)
                                    .withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 3))
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_rounded,
                                color: Colors.white, size: 14),
                            SizedBox(width: 6),
                            Text('Message',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // About
          if (profile.description.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader('About', Icons.info_outline_rounded,
                        const Color(0xFF1565C0)),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 12,
                              offset: const Offset(0, 3))
                        ],
                      ),
                      child: Text(profile.description,
                          style: const TextStyle(
                              fontSize: 14,
                              height: 1.65,
                              color: Color(0xFF444466))),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

          // Company details info cards
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader('Company Details',
                      Icons.business_rounded, const Color(0xFF42A5F5)),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 3))
                      ],
                    ),
                    child: Column(
                      children: [
                        if (profile.website != null &&
                            profile.website!.isNotEmpty)
                          _companyDetailRow(Icons.language_rounded,
                              'Website', profile.website!, const Color(0xFF2196F3)),
                        if (profile.headOfficeLocation != null &&
                            profile.headOfficeLocation!.isNotEmpty)
                          _companyDetailRow(
                              Icons.location_city_rounded,
                              'Head Office',
                              profile.headOfficeLocation!,
                              const Color(0xFF9C27B0)),
                        if (profile.employeeCount != null &&
                            profile.employeeCount!.isNotEmpty)
                          _companyDetailRow(
                              Icons.people_rounded,
                              'Team Size',
                              '${profile.employeeCount} employees',
                              const Color(0xFF4CAF50)),
                        if (profile.gstNumber != null &&
                            profile.gstNumber!.isNotEmpty)
                          _companyDetailRow(
                              Icons.badge_rounded,
                              'GST Number',
                              profile.gstNumber!,
                              Colors.orange),
                        if (profile.website == null &&
                            profile.headOfficeLocation == null &&
                            profile.employeeCount == null &&
                            profile.gstNumber == null)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('No details added yet',
                                style: TextStyle(color: Colors.grey)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Assigned Projects
          if (profile.assignedProjects.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader('Projects',
                        Icons.folder_rounded, const Color(0xFF1565C0)),
                    ...profile.assignedProjects
                        .map((p) => _buildProjectCard(p)),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 48)),
        ],
      ),
    );
  }

  Widget _companyDetailRow(
      IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9E9E9E),
                        fontWeight: FontWeight.w500)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF1A1A2E),
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectCard(Map<String, dynamic> project) {
    final title = (project['title'] as String?) ?? 'Unnamed Project';
    final description = (project['description'] as String?) ?? '';
    final status = (project['status'] as String?) ?? 'accepted';
    final assignedAt = (project['assignedAt'] as String?) ?? '';

    List<Color> statusGradient;
    IconData statusIcon;
    switch (status) {
      case 'completed':
        statusGradient = [const Color(0xFF1565C0), const Color(0xFF42A5F5)];
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'accepted':
        statusGradient = [const Color(0xFF2E7D32), const Color(0xFF66BB6A)];
        statusIcon = Icons.assignment_turned_in_rounded;
        break;
      default:
        statusGradient = [const Color(0xFFE65100), const Color(0xFFFFB74D)];
        statusIcon = Icons.pending_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: statusGradient),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(statusIcon, size: 18, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF1A1A2E)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: statusGradient),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status[0].toUpperCase() + status.substring(1),
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                description,
                style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF777799),
                    height: 1.5),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (assignedAt.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 11, color: Color(0xFFBBBBCC)),
                  const SizedBox(width: 4),
                  Text(
                    'Assigned: $assignedAt',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFFBBBBCC)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
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
              // Share the image URL (opens system share sheet which includes save option)
              Share.share(
                widget.images[_currentIndex],
                subject: 'Portfolio Image',
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
