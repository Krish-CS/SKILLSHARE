import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../providers/user_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/skilled_user_profile.dart';
import '../../utils/app_constants.dart';
import '../../services/cloudinary_service.dart';
import '../../services/firestore_service.dart';
import '../main_navigation.dart';

class SkilledUserSetupScreen extends StatefulWidget {
  final String userId;

  const SkilledUserSetupScreen({super.key, required this.userId});

  @override
  State<SkilledUserSetupScreen> createState() => _SkilledUserSetupScreenState();
}

class _SkilledUserSetupScreenState extends State<SkilledUserSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bioController = TextEditingController();
  final _skillController = TextEditingController();
  final _aadhaarController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  
  String? _selectedCategory;
  List<String> _skills = [];
  bool _isLoading = true;
  bool _isUploading = false;
  bool _isVerified = false;
  String _verificationStatus = 'pending';
  
  // Image variables
  File? _profileImage;
  String? _profileImageUrl;
  List<File> _portfolioImages = [];
  List<String> _portfolioImageUrls = [];

  final List<String> _categories = [
    'Home Baking',
    'Handicrafts',
    'Content Creation',
    'Beauty & Wellness',
    'Carpentry',
    'Tailoring',
    'Photography',
    'Videography',
    'Editing',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.loadProfile(widget.userId);

    if (userProvider.currentProfile != null) {
      final profile = userProvider.currentProfile!;
      _bioController.text = profile.bio;
      _selectedCategory = profile.category;
      _skills = List.from(profile.skills);
      _profileImageUrl = profile.profilePicture;
      _portfolioImageUrls = List.from(profile.portfolioImages);
      _isVerified = profile.isVerified;
      _verificationStatus = profile.verificationStatus;
      
      // Load Aadhaar if exists
      if (profile.verificationData != null && profile.verificationData!['aadhaarNumber'] != null) {
        _aadhaarController.text = profile.verificationData!['aadhaarNumber'];
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _bioController.dispose();
    _skillController.dispose();
    _aadhaarController.dispose();
    super.dispose();
  }

  void _addSkill() {
    if (_skillController.text.isNotEmpty) {
      setState(() {
        _skills.add(_skillController.text.trim());
        _skillController.clear();
      });
    }
  }

  void _removeSkill(String skill) {
    setState(() {
      _skills.remove(skill);
    });
  }

  // Image picking methods
  Future<void> _pickProfileImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      // User cancelled - do nothing
      if (image == null) return;

      setState(() {
        _profileImage = File(image.path);
      });
    } on Exception catch (e) {
      // Only show error for actual errors, not cancellations
      if (mounted && e.toString().isNotEmpty && !e.toString().contains('cancel')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _pickPortfolioImages() async {
    try {
      if (_portfolioImages.length + _portfolioImageUrls.length >= 10) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 10 portfolio images allowed')),
        );
        return;
      }

      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      // User cancelled - do nothing
      if (images.isEmpty) return;

      setState(() {
        final remaining = 10 - (_portfolioImages.length + _portfolioImageUrls.length);
        _portfolioImages.addAll(
          images.take(remaining).map((img) => File(img.path)),
        );
      });
    } on Exception catch (e) {
      // Only show error for actual errors, not cancellations
      if (mounted && e.toString().isNotEmpty && !e.toString().contains('cancel')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking images: $e')),
        );
      }
    }
  }

  void _removePortfolioImage(int index) {
    setState(() {
      _portfolioImages.removeAt(index);
    });
  }

  void _removePortfolioUrl(int index) {
    setState(() {
      _portfolioImageUrls.removeAt(index);
    });
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Image Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickProfileImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickProfileImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _maskAadhaar(String aadhaar) {
    if (aadhaar.length < 4) return aadhaar;
    return 'XXXX XXXX ${aadhaar.substring(aadhaar.length - 4)}';
  }

  bool _validateAadhaar(String aadhaar) {
    // Remove spaces and check if it's 12 digits
    final cleanAadhaar = aadhaar.replaceAll(' ', '');
    return cleanAadhaar.length == 12 && int.tryParse(cleanAadhaar) != null;
  }

  Future<void> _verifyAadhaar() async {
    final aadhaar = _aadhaarController.text.trim().replaceAll(' ', '');
    
    if (aadhaar.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter Aadhaar number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_validateAadhaar(aadhaar)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid Aadhaar number. Must be 12 digits'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      // Simulate API call for verification
      await Future.delayed(const Duration(seconds: 2));
      
      // In production, you would call actual Aadhaar verification API
      // For now, we'll mark as verified
      setState(() {
        _isVerified = true;
        _verificationStatus = 'verified';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aadhaar verified successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    if (_skills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one skill')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentProfile = userProvider.currentProfile;
      
      String? finalProfileUrl = _profileImageUrl;
      List<String> finalPortfolioUrls = List.from(_portfolioImageUrls);

      // Upload profile image if selected
      if (_profileImage != null) {
        finalProfileUrl = await _cloudinaryService.uploadImage(
          _profileImage!,
          folder: 'profiles',
        );
      }

      // Upload portfolio images if selected
      if (_portfolioImages.isNotEmpty) {
        for (var image in _portfolioImages) {
          final url = await _cloudinaryService.uploadImage(
            image,
            folder: 'portfolios',
          );
          if (url != null) {
            finalPortfolioUrls.add(url);
          }
        }
      }

      // Prepare verification data
      Map<String, dynamic>? verificationData;
      if (_aadhaarController.text.isNotEmpty) {
        verificationData = {
          'aadhaarNumber': _aadhaarController.text.trim().replaceAll(' ', ''),
          'maskedAadhaar': _maskAadhaar(_aadhaarController.text.trim()),
          'verifiedAt': _isVerified ? DateTime.now().toIso8601String() : null,
        };
      }

      final profile = SkilledUserProfile(
        userId: widget.userId,
        bio: _bioController.text.trim(),
        skills: _skills,
        category: _selectedCategory,
        profilePicture: finalProfileUrl ?? '',
        verificationStatus: _verificationStatus,
        visibility: _isVerified ? AppConstants.visibilityPublic : AppConstants.visibilityPrivate,
        portfolioImages: finalPortfolioUrls,
        portfolioVideos: currentProfile?.portfolioVideos ?? [],
        verificationData: verificationData,
        rating: currentProfile?.rating ?? 0.0,
        reviewCount: currentProfile?.reviewCount ?? 0,
        projectCount: currentProfile?.projectCount ?? 0,
        isVerified: _isVerified,
        verifiedAt: _isVerified ? DateTime.now() : null,
        createdAt: currentProfile?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final success = await userProvider.updateProfile(profile);

      if (!mounted) return;

      if (success) {
        // Also update user basic profile with profile photo in Firestore directly
        try {
          if (finalProfileUrl != null && finalProfileUrl.isNotEmpty) {
            // Update via Firestore service directly for reliability
            await FirestoreService().updateUserProfilePhoto(widget.userId, finalProfileUrl);
            
            // Also update via auth provider to keep local state in sync
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            if (authProvider.currentUser != null) {
              final updatedUser = authProvider.currentUser!.copyWith(
                profilePhoto: finalProfileUrl,
              );
              await authProvider.updateProfile(updatedUser);
            }
            debugPrint('Profile photo saved to both collections: $finalProfileUrl');
          }
        } catch (e) {
          debugPrint('Error updating user profile photo: $e');
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate to main navigation after successful save
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MainNavigation()),
            (route) => false,
          );
        }
      } else {
        throw Exception(userProvider.error ?? 'Failed to save profile');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Profile'),
        actions: [
          TextButton(
            onPressed: _saveProfile,
            child: const Text(
              'Save',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF9C27B0), Color(0xFFE91E63)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Profile Photo Section
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _showImageSourceDialog,
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 60,
                                backgroundColor: Colors.grey[300],
                                backgroundImage: _profileImage != null
                                    ? FileImage(_profileImage!)
                                    : (_profileImageUrl != null && _profileImageUrl!.isNotEmpty
                                        ? NetworkImage(_profileImageUrl!)
                                        : null) as ImageProvider?,
                                child: (_profileImage == null && (_profileImageUrl == null || _profileImageUrl!.isEmpty))
                                    ? const Icon(Icons.person, size: 60, color: Colors.grey)
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF9C27B0),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap to ${_profileImage != null || (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) ? 'change' : 'add'} photo',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Category Selection
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: _categories.map((category) {
                      return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                  });
                },
                validator: (value) {
                  if (value == null) return 'Please select a category';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Bio
              TextFormField(
                controller: _bioController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Bio',
                  hintText: 'Tell people about yourself and your skills...',
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your bio';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Skills
              const Text(
                'Skills',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _skillController,
                      decoration: const InputDecoration(
                        hintText: 'Add a skill',
                      ),
                      onSubmitted: (_) => _addSkill(),
                    ),
                  ),
                  IconButton(
                    onPressed: _addSkill,
                    icon: const Icon(Icons.add),
                    color: const Color(0xFF2196F3),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _skills.map((skill) {
                  return Chip(
                    label: Text(skill),
                    onDeleted: () => _removeSkill(skill),
                    backgroundColor: const Color(0xFF2196F3).withValues(alpha: 0.1),
                    labelStyle: const TextStyle(color: Color(0xFF2196F3)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              
              // Portfolio Images Section
              const Text(
                'Portfolio Images',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Showcase your work (Max 10 images)',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(height: 12),
              
              // Display existing portfolio images
              if (_portfolioImageUrls.isNotEmpty || _portfolioImages.isNotEmpty)
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _portfolioImageUrls.length + _portfolioImages.length,
                    itemBuilder: (context, index) {
                      if (index < _portfolioImageUrls.length) {
                        // Display existing URL images
                        return Stack(
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                image: DecorationImage(
                                  image: NetworkImage(_portfolioImageUrls[index]),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 16,
                              child: GestureDetector(
                                onTap: () => _removePortfolioUrl(index),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      } else {
                        // Display newly selected images
                        final fileIndex = index - _portfolioImageUrls.length;
                        return Stack(
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                image: DecorationImage(
                                  image: FileImage(_portfolioImages[fileIndex]),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 16,
                              child: GestureDetector(
                                onTap: () => _removePortfolioImage(fileIndex),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ),
              
              const SizedBox(height: 12),
              
              // Add Portfolio Images Button
              OutlinedButton.icon(
                onPressed: (_portfolioImages.length + _portfolioImageUrls.length < 10)
                    ? _pickPortfolioImages
                    : null,
                icon: const Icon(Icons.add_photo_alternate),
                label: Text(
                  'Add Portfolio Images (${_portfolioImages.length + _portfolioImageUrls.length}/10)',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2196F3),
                  side: const BorderSide(color: Color(0xFF2196F3)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 24),
              
              // Verification Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Identity Verification',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Complete identity verification to make your profile visible to customers',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 16),
                      
                      // Verification Status
                      if (_isVerified)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.verified, color: Colors.green),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Identity Verified ✓',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else ...[  
                        TextFormField(
                          controller: _aadhaarController,
                          decoration: InputDecoration(
                            labelText: 'Aadhaar Number',
                            hintText: '1234 5678 9012',
                            prefixIcon: const Icon(Icons.credit_card),
                            helperText: 'Enter 12-digit Aadhaar number',
                            suffixIcon: _isVerified
                                ? const Icon(Icons.check_circle, color: Colors.green)
                                : null,
                          ),
                          keyboardType: TextInputType.number,
                          maxLength: 14, // 12 digits + 2 spaces
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return null; // Optional field
                            }
                            if (!_validateAadhaar(value)) {
                              return 'Invalid Aadhaar number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _verifyAadhaar,
                            icon: const Icon(Icons.verified_user),
                            label: const Text('Verify Identity'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4CAF50),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '⚠️ Note: Verification is optional but recommended for better visibility',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      
      // Loading overlay
      if (_isUploading)
        Container(
          color: Colors.black.withValues(alpha: 0.5),
          child: const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Uploading images...'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
    );
  }
}
