import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../models/skilled_user_profile.dart';
import '../../models/customer_profile.dart';
import '../../models/company_profile.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../services/firestore_service.dart';
import '../../utils/web_image_loader.dart';
import '../../utils/user_roles.dart';
import 'profile_screen.dart';
import 'edit_skilled_profile_screen.dart';
import 'skilled_user_setup_screen.dart';
import 'customer_setup_screen.dart';
import 'company_setup_screen.dart';
import '../auth/login_screen.dart';
import 'settings_screen.dart';

class ProfileTabScreen extends StatefulWidget {
  const ProfileTabScreen({super.key});

  @override
  State<ProfileTabScreen> createState() => _ProfileTabScreenState();
}

class _ProfileTabScreenState extends State<ProfileTabScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  StreamSubscription<UserModel?>? _userSub;
  StreamSubscription<SkilledUserProfile?>? _skilledSub;
  StreamSubscription<CustomerProfile?>? _customerSub;
  StreamSubscription<CompanyProfile?>? _companySub;
  UserModel? _currentUser;
  SkilledUserProfile? _skilledProfile;
  bool _isLoading = true;
  String? _profilePhotoUrl;
  String? _roleSpecificPhotoUrl; // set once from role profile, not overridden by user stream
  String? _lastSubscribedRole; // tracks role so we only re-subscribe when it changes

  @override
  void initState() {
    super.initState();
    _subscribeToUserData();
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _skilledSub?.cancel();
    _customerSub?.cancel();
    _companySub?.cancel();
    super.dispose();
  }

  void _subscribeToUserData() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    _userSub = _firestoreService.streamUserModel(userId).listen(
      (user) {
        if (!mounted) return;
        setState(() {
          _currentUser = user;
          // Prefer the role-specific photo; fall back to user.profilePhoto
          _profilePhotoUrl = _roleSpecificPhotoUrl?.isNotEmpty == true
              ? _roleSpecificPhotoUrl
              : (user?.profilePhoto?.isNotEmpty == true
                  ? user!.profilePhoto
                  : _profilePhotoUrl);
          if (_isLoading) _isLoading = false;
        });
        // Only re-subscribe when role actually changes (avoids constant churn)
        if (user?.role != _lastSubscribedRole) {
          _lastSubscribedRole = user?.role;
          _subscribeToRoleProfile(userId, user?.role);
        }
      },
      onError: (e) {
        debugPrint('Error streaming user: $e');
        if (mounted && _isLoading) setState(() => _isLoading = false);
      },
    );
  }

  void _subscribeToRoleProfile(String userId, String? role) {
    // Cancel previous role subscriptions
    _skilledSub?.cancel();
    _customerSub?.cancel();
    _companySub?.cancel();

    if (role == UserRoles.skilledPerson) {
      _skilledSub =
          _firestoreService.skilledUserProfileStream(userId).listen((profile) {
        if (!mounted) return;
        setState(() {
          _skilledProfile = profile;
          if (profile?.profilePicture != null &&
              profile!.profilePicture!.isNotEmpty) {
            _roleSpecificPhotoUrl = profile.profilePicture;
            _profilePhotoUrl = profile.profilePicture;
          }
        });
      });
    } else if (role == UserRoles.customer) {
      _customerSub =
          _firestoreService.customerProfileStream(userId).listen((profile) {
        if (!mounted) return;
        setState(() {
          if (profile?.profilePicture != null &&
              profile!.profilePicture!.isNotEmpty) {
            _roleSpecificPhotoUrl = profile.profilePicture;
            _profilePhotoUrl = profile.profilePicture;
          }
        });
      });
    } else if (role == UserRoles.company) {
      _companySub =
          _firestoreService.companyProfileStream(userId).listen((profile) {
        if (!mounted) return;
        setState(() {
          if (profile?.logoUrl != null && profile!.logoUrl!.isNotEmpty) {
            _roleSpecificPhotoUrl = profile.logoUrl;
            _profilePhotoUrl = profile.logoUrl;
          }
        });
      });
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;
    try {
      final authProvider =
          Provider.of<app_auth.AuthProvider>(context, listen: false);
      await authProvider.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF6F7FB),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: RefreshIndicator(
        onRefresh: () async {}, // Stream auto-updates
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // ── Attractive Profile Header ──
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF6A0DAD),
                      Color(0xFF9C27B0),
                      Color(0xFFE91E63)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(36),
                    bottomRight: Radius.circular(36),
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Decorative blobs
                    Positioned(
                      top: -30,
                      right: -30,
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.07),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 20,
                      left: -40,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 40,
                      left: 80,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                    ),
                    // Content
                    Padding(
                      padding: EdgeInsets.fromLTRB(0, MediaQuery.of(context).padding.top + 20, 0, 32),
                      child: Column(
                        children: [
                          // Avatar with gradient ring
                          GestureDetector(
                            onTap: () {
                              if (_currentUser != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ProfileScreen(
                                        userId: _currentUser!.uid),
                                  ),
                                );
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [Colors.white, Color(0xFFFFD700)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 24,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(3.5),
                              child: CircleAvatar(
                                radius: 52,
                                backgroundColor: Colors.white,
                                child: WebImageLoader.loadAvatar(
                                  imageUrl: _profilePhotoUrl,
                                  radius: 50,
                                  fallbackText: _currentUser?.name,
                                  backgroundColor: const Color(0xFFF3E5F5),
                                  alignment: Alignment.center,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          // Name
                          Text(
                            _currentUser?.name ?? 'User',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Email
                          Text(
                            _currentUser?.email ?? '',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Role Badge — company only
                          if (_currentUser?.role == UserRoles.company)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    width: 1.2),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.business_rounded,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    UserRoles.getDisplayName(
                                        _currentUser?.role ?? UserRoles.company),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 20),
                          // Verified badge for skilled users
                          if (_currentUser?.role == UserRoles.skilledPerson) ...[
                            const SizedBox(height: 8),
                            if (_skilledProfile?.isVerified == true)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: Colors.greenAccent.withValues(
                                          alpha: 0.7),
                                      width: 1.2),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.verified_user,
                                        color: Colors.greenAccent, size: 14),
                                    SizedBox(width: 5),
                                    Text(
                                      'Aadhaar Verified',
                                      style: TextStyle(
                                        color: Colors.greenAccent,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              GestureDetector(
                                onTap: () async {
                                  if (_currentUser == null) return;
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => SkilledUserSetupScreen(
                                          userId: _currentUser!.uid),
                                    ),
                                  );
                                  // Stream auto-updates
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: Colors.orange.withValues(
                                            alpha: 0.7),
                                        width: 1.2),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.fingerprint,
                                          color: Colors.orange, size: 14),
                                      SizedBox(width: 5),
                                      Text(
                                        'Tap to Verify Identity',
                                        style: TextStyle(
                                          color: Colors.orange,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                          const SizedBox(height: 20),
                          // Quick action buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _headerAction(
                                icon: Icons.visibility_rounded,
                                label: 'View Profile',
                                onTap: () {
                                  if (_currentUser != null) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ProfileScreen(
                                            userId: _currentUser!.uid),
                                      ),
                                    );
                                  }
                                },
                              ),
                              const SizedBox(width: 16),
                              _headerAction(
                                icon: Icons.edit_rounded,
                                label: 'Edit Profile',
                                onTap: () async {
                                  if (_currentUser == null) return;
                                  Widget editScreen;
                                  if (_currentUser!.role ==
                                      UserRoles.skilledPerson) {
                                    editScreen =
                                        const EditSkilledProfileScreen();
                                  } else if (_currentUser!.role ==
                                      UserRoles.customer) {
                                    editScreen = CustomerSetupScreen(
                                        userId: _currentUser!.uid);
                                  } else if (_currentUser!.role ==
                                      UserRoles.company) {
                                    editScreen = CompanySetupScreen(
                                        userId: _currentUser!.uid);
                                  } else {
                                    editScreen =
                                        const EditSkilledProfileScreen();
                                  }
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => editScreen),
                                  );
                                  // Stream auto-updates
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Menu Section ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildMenuTile(
                        icon: Icons.settings_rounded,
                        iconColor: const Color(0xFF607D8B),
                        title: 'Settings',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SettingsScreen()),
                          );
                        },
                      ),
                      const Divider(height: 1, indent: 60),
                      _buildMenuTile(
                        icon: Icons.help_outline_rounded,
                        iconColor: const Color(0xFF009688),
                        title: 'Help & Support',
                        onTap: () => _showHelpDialog(),
                      ),
                      const Divider(height: 1, indent: 60),
                      _buildMenuTile(
                        icon: Icons.info_outline_rounded,
                        iconColor: const Color(0xFF3F51B5),
                        title: 'About SkillShare',
                        onTap: () {
                          showAboutDialog(
                            context: context,
                            applicationName: 'SkillShare',
                            applicationVersion: '1.0.0',
                            applicationIcon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF9C27B0),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.handshake,
                                  color: Colors.white, size: 32),
                            ),
                            children: [
                              const Text(
                                  'Connect skilled professionals with customers'),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Logout Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: _handleLogout,
                    borderRadius: BorderRadius.circular(16),
                    child: Ink(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE53935), Color(0xFFFF7043)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFFE53935).withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout_rounded,
                              color: Colors.white, size: 20),
                          SizedBox(width: 10),
                          Text(
                            'Logout',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _showHelpDialog() {
    final subjectController = TextEditingController();
    final messageController = TextEditingController();
    bool isSending = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.help_outline, color: Color(0xFF9C27B0)),
              SizedBox(width: 8),
              Text('Help & Support'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Having a problem? Send us a message and we\'ll get back to you shortly.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: subjectController,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.subject),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: messageController,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 4,
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
              onPressed: isSending
                  ? null
                  : () async {
                      final subject = subjectController.text.trim();
                      final message = messageController.text.trim();
                      if (subject.isEmpty || message.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Please fill in both fields')),
                        );
                        return;
                      }
                      setDialogState(() => isSending = true);
                      try {
                        final uid = FirebaseAuth.instance.currentUser?.uid;
                        if (uid != null) {
                          await FirestoreService().submitSupportTicket(
                            userId: uid,
                            subject: subject,
                            message: message,
                          );
                        }
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        // ignore: use_build_context_synchronously
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Support ticket submitted! We\'ll respond soon.'),
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
                  backgroundColor: const Color(0xFF9C27B0)),
              child: isSending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Submit', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.4), width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 7),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color iconColor = const Color(0xFF9C27B0),
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 15,
          color: Color(0xFF1A1A2E),
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded,
          color: Color(0xFFBBBBCC), size: 22),
      onTap: onTap,
    );
  }
}
