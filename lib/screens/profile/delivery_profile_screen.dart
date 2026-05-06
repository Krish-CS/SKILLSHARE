import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../screens/avatar/avatar_builder_screen.dart';
import '../../services/cloudinary_service.dart';
import '../../services/firestore_service.dart';
import '../../utils/app_dialog.dart';
import '../../utils/app_helpers.dart';
import '../../utils/user_roles.dart';
import '../../widgets/universal_avatar.dart';
import '../delivery/delivery_screen.dart';

class DeliveryProfileScreen extends StatefulWidget {
  final String userId;

  const DeliveryProfileScreen({super.key, required this.userId});

  @override
  State<DeliveryProfileScreen> createState() => _DeliveryProfileScreenState();
}

class _DeliveryProfileScreenState extends State<DeliveryProfileScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final ImagePicker _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  StreamSubscription<UserModel?>? _userSub;
  UserModel? _user;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasSeededForm = false;
  File? _profileImage;
  Uint8List? _profileImageBytes;
  String? _profilePhotoUrl;
  Map<String, dynamic>? _avatarConfig;

  bool get _isCurrentUser =>
      FirebaseAuth.instance.currentUser?.uid == widget.userId;

  @override
  void initState() {
    super.initState();
    _userSub = _firestoreService.streamUserModel(widget.userId).listen(
      (user) {
        if (!mounted) return;
        setState(() {
          _user = user;
          if (user != null && !_hasSeededForm) {
            _seedForm(user);
          }
          _isLoading = false;
        });
      },
      onError: (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
      },
    );
  }

  void _seedForm(UserModel user) {
    _nameController.text = user.name;
    _phoneController.text = user.phone ?? '';
    _profilePhotoUrl = user.profilePhoto;
    _avatarConfig = user.avatarConfig;
    _hasSeededForm = true;
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null || !mounted) return;

      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        if (!mounted) return;
        setState(() {
          _profileImageBytes = bytes;
          _profileImage = null;
        });
      } else {
        setState(() {
          _profileImage = File(image.path);
          _profileImageBytes = null;
        });
      }
    } catch (e) {
      if (mounted) {
        AppDialog.error(context, 'Image selection failed', detail: e.toString());
      }
    }
  }

  Future<void> _openAvatarBuilder() async {
    if (_user == null) return;

    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (_) => AvatarBuilderScreen(initialConfig: _avatarConfig),
      ),
    );

    if (!mounted || result == null) return;
    setState(() {
      _avatarConfig = Map<String, dynamic>.from(result as Map);
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_user == null) return;

    setState(() => _isSaving = true);

    try {
      final authProvider = context.read<app_auth.AuthProvider>();
      String? finalProfileUrl = _profilePhotoUrl;

      if (_profileImageBytes != null || _profileImage != null) {
        if (kIsWeb && _profileImageBytes != null) {
          finalProfileUrl = await _cloudinaryService.uploadImageBytes(
            _profileImageBytes!,
            folder: 'delivery_profiles',
          );
        } else if (_profileImage != null) {
          finalProfileUrl = await _cloudinaryService.uploadImage(
            _profileImage!,
            folder: 'delivery_profiles',
          );
        }
      }

      final currentUser = authProvider.currentUser ?? _user!;

      final updatedUser = currentUser.copyWith(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        profilePhoto: finalProfileUrl,
        avatarConfig: _avatarConfig,
      );

      await authProvider.updateProfile(updatedUser);

      if (_avatarConfig != null) {
        await _firestoreService.saveAvatarConfig(widget.userId, _avatarConfig!);
      }

      if (!mounted) return;

      setState(() {
        _profilePhotoUrl = finalProfileUrl;
        _profileImage = null;
        _profileImageBytes = null;
      });

      AppDialog.success(
        context,
        'Delivery profile saved',
        onDismiss: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      AppDialog.error(context, 'Could not save delivery profile',
          detail: e.toString());
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildHeader() {
    final user = _user;
    final displayName = AppHelpers.capitalize(user?.name ?? 'Delivery Partner');
    final roleLabel = UserRoles.getDisplayName(user?.role ?? UserRoles.deliveryPartner);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1D4ED8), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (Navigator.of(context).canPop())
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white),
                ),
              const Spacer(),
              if (_isCurrentUser)
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const DeliveryScreen(),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.14),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                  icon: const Icon(Icons.local_shipping_rounded, size: 18),
                  label: const Text('Delivery Console'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _user?.email ?? '',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.86),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.24),
                        ),
                      ),
                      child: Text(
                        roleLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    const radius = 48.0;
    final imageWidget = _profileImageBytes != null
        ? Image.memory(
            _profileImageBytes!,
            fit: BoxFit.cover,
            width: radius * 2,
            height: radius * 2,
          )
        : _profileImage != null
            ? Image.file(
                _profileImage!,
                fit: BoxFit.cover,
                width: radius * 2,
                height: radius * 2,
              )
            : UniversalAvatar(
                avatarConfig: _avatarConfig,
                photoUrl: _profilePhotoUrl,
                fallbackName: _user?.name,
                radius: radius,
              );

    return GestureDetector(
      onTap: _isSaving ? null : _pickProfileImage,
      child: Container(
        padding: const EdgeInsets.all(3.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            ClipOval(child: imageWidget),
            Positioned(
              right: 1,
              bottom: 1,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF2563EB),
                ),
                child: const Icon(Icons.photo_camera_rounded,
                    color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    return StreamBuilder<List<OrderModel>>(
      stream: _firestoreService.streamDeliveryPartnerOrders(widget.userId),
      builder: (context, snapshot) {
        final orders = snapshot.data ?? const <OrderModel>[];
        final total = orders.length;
        final active = orders.where((order) => order.status == 'out_for_delivery').length;
        final delivered = orders.where((order) => order.status == 'delivered').length;

        return Row(
          children: [
            Expanded(child: _buildStatTile('Assigned', '$total')),
            const SizedBox(width: 12),
            Expanded(child: _buildStatTile('In Transit', '$active')),
            const SizedBox(width: 12),
            Expanded(child: _buildStatTile('Delivered', '$delivered')),
          ],
        );
      },
    );
  }

  Widget _buildStatTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Form(
      key: _formKey,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Profile Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              enabled: !_isSaving,
              decoration: _fieldDecoration(
                label: 'Full Name',
                icon: Icons.badge_rounded,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter your name';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phoneController,
              enabled: !_isSaving,
              keyboardType: TextInputType.phone,
              decoration: _fieldDecoration(
                label: 'Phone Number',
                icon: Icons.phone_rounded,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: _isSaving ? null : _pickProfileImage,
                  icon: const Icon(Icons.image_rounded),
                  label: const Text('Change Photo'),
                ),
                OutlinedButton.icon(
                  onPressed: _isSaving ? null : _openAvatarBuilder,
                  icon: const Icon(Icons.face_retouching_natural_rounded),
                  label: const Text('Avatar Builder'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Delivery profile updates the shared user document only. Transit actions remain in the Delivery Console.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF2563EB)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.4),
      ),
    );
  }

  Widget _buildActionBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _saveProfile,
          icon: _isSaving
              ? Container(
                  width: 18,
                  height: 18,
                  padding: const EdgeInsets.all(2),
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_rounded),
          label: Text(_isSaving ? 'Saving...' : 'Save Delivery Profile'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _isSaving
              ? null
              : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const DeliveryScreen(),
                    ),
                  ),
          icon: const Icon(Icons.local_shipping_rounded),
          label: const Text('Open Delivery Console'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            foregroundColor: const Color(0xFF2563EB),
            side: const BorderSide(color: Color(0xFFBFDBFE)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 18),
              _buildStatsCard(),
              const SizedBox(height: 18),
              _buildFormCard(),
              const SizedBox(height: 18),
              _buildActionBar(),
            ],
          ),
        ),
      ),
    );
  }
}