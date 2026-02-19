import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import '../../providers/user_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/customer_profile.dart';
import '../../services/cloudinary_service.dart';
import '../../services/firestore_service.dart';
import '../main_navigation.dart';

class CustomerSetupScreen extends StatefulWidget {
  final String userId;

  const CustomerSetupScreen({super.key, required this.userId});

  @override
  State<CustomerSetupScreen> createState() => _CustomerSetupScreenState();
}

class _CustomerSetupScreenState extends State<CustomerSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bioController = TextEditingController();
  final _interestController = TextEditingController();
  final _locationController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  
  List<String> _interests = [];
  List<String> _lookingFor = [];
  bool _isLoading = true;
  bool _isUploading = false;
  
  // Image variables
  File? _profileImage;
  Uint8List? _profileImageBytes; // For web
  String? _profileImageUrl;

  final List<String> _serviceCategories = [
    'Home Baking',
    'Handicrafts',
    'Carpentry',
    'Plumbing',
    'Electrical',
    'Painting',
    'Tailoring',
    'Beauty & Wellness',
    'Photography',
    'Videography',
    'Content Creation',
    'Home Cleaning',
    'Gardening',
    'Tutoring',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.loadCustomerProfile(widget.userId);

    if (userProvider.customerProfile != null) {
      final profile = userProvider.customerProfile!;
      _bioController.text = profile.bio;
      _interests = List.from(profile.interests);
      _lookingFor = List.from(profile.lookingFor);
      _profileImageUrl = profile.profilePicture;
      _locationController.text = profile.location ?? '';
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _bioController.dispose();
    _interestController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _addInterest() {
    if (_interestController.text.isNotEmpty) {
      setState(() {
        _interests.add(_interestController.text.trim());
        _interestController.clear();
      });
    }
  }

  void _removeInterest(String interest) {
    setState(() {
      _interests.remove(interest);
    });
  }

  void _toggleLookingFor(String category) {
    setState(() {
      if (_lookingFor.contains(category)) {
        _lookingFor.remove(category);
      } else {
        _lookingFor.add(category);
      }
    });
  }

  Future<void> _pickProfileImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        if (kIsWeb) {
          // For web, read as bytes
          final bytes = await image.readAsBytes();
          setState(() {
            _profileImageBytes = bytes;
          });
        } else {
          // For mobile, use File
          setState(() {
            _profileImage = File(image.path);
          });
        }
      }
    } catch (e) {
      // Handle web-specific errors gracefully
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image selected! Click Save to upload.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentProfile = userProvider.customerProfile;

      // Upload profile picture if selected
      String? finalProfileUrl = _profileImageUrl;
      if (_profileImage != null || _profileImageBytes != null) {
        // Create temp file for web bytes
        if (kIsWeb && _profileImageBytes != null) {
          finalProfileUrl = await _cloudinaryService.uploadImageBytes(
            _profileImageBytes!,
            folder: 'customer_profiles',
          );
        } else if (_profileImage != null) {
          finalProfileUrl = await _cloudinaryService.uploadImage(
            _profileImage!,
            folder: 'customer_profiles',
          );
        }
      }

      final profile = CustomerProfile(
        userId: widget.userId,
        bio: _bioController.text.trim(),
        interests: _interests,
        lookingFor: _lookingFor,
        profilePicture: finalProfileUrl ?? '',
        location: _locationController.text.trim(),
        preferredCategories: _lookingFor,
        createdAt: currentProfile?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await userProvider.updateCustomerProfile(profile);

      if (finalProfileUrl != null && finalProfileUrl.isNotEmpty) {
        try {
          await FirestoreService().updateUserProfilePhoto(widget.userId, finalProfileUrl);

          if (authProvider.currentUser != null) {
            final updatedUser = authProvider.currentUser!.copyWith(
              profilePhoto: finalProfileUrl,
            );
            await authProvider.updateProfile(updatedUser);
          }
        } catch (e) {
          debugPrint('Failed to sync customer profile photo: $e');
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate to main screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const MainNavigation(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
        title: const Text('Set Up Your Profile'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tell us about yourself',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Help us understand what you\'re looking for',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),

              // Profile Picture
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundImage: (kIsWeb && _profileImageBytes != null)
                          ? MemoryImage(_profileImageBytes!)
                          : (_profileImage != null
                              ? FileImage(_profileImage!)
                              : (_profileImageUrl != null && _profileImageUrl!.isNotEmpty
                                  ? NetworkImage(_profileImageUrl!)
                                  : null)) as ImageProvider?,
                        child: _profileImage == null && _profileImageBytes == null && (_profileImageUrl == null || _profileImageUrl!.isEmpty)
                          ? const Icon(Icons.person, size: 60)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: IconButton(
                          icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                          onPressed: _pickProfileImage,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Bio
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(
                  labelText: 'About You',
                  hintText: 'Tell us a bit about yourself...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.info_outline),
                ),
                maxLines: 3,
                maxLength: 500,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please tell us about yourself';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Location
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  hintText: 'City, State',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
              ),
              const SizedBox(height: 24),

              // Interests Section
              const Text(
                'Your Interests',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'What are you passionate about?',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _interestController,
                      decoration: const InputDecoration(
                        hintText: 'Add an interest',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _addInterest(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.blue),
                    onPressed: _addInterest,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _interests.map((interest) {
                  return Chip(
                    label: Text(interest),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () => _removeInterest(interest),
                    backgroundColor: Colors.blue[100],
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // What are you looking for?
              const Text(
                'What Services Do You Need?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select the categories you\'re interested in',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _serviceCategories.map((category) {
                  final isSelected = _lookingFor.contains(category);
                  return FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (_) => _toggleLookingFor(category),
                    selectedColor: Colors.blue[300],
                    checkmarkColor: Colors.white,
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: _isUploading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Complete Profile',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
