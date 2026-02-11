import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import '../../providers/user_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/company_profile.dart';
import '../../services/cloudinary_service.dart';
import '../../services/firestore_service.dart';
import '../main_navigation.dart';

class CompanySetupScreen extends StatefulWidget {
  final String userId;

  const CompanySetupScreen({super.key, required this.userId});

  @override
  State<CompanySetupScreen> createState() => _CompanySetupScreenState();
}

class _CompanySetupScreenState extends State<CompanySetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _websiteController = TextEditingController();
  final _headOfficeController = TextEditingController();
  final _gstController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  
  String _selectedIndustry = 'Technology';
  String _selectedEmployeeCount = '1-10';
  bool _isLoading = true;
  bool _isUploading = false;
  
  // Image variables
  File? _logoImage;
  Uint8List? _logoImageBytes;
  String? _logoUrl;

  final List<String> _industries = [
    'Technology',
    'Manufacturing',
    'Retail',
    'Healthcare',
    'Education',
    'Construction',
    'Food & Beverage',
    'Finance',
    'Real Estate',
    'Transportation',
    'Entertainment',
    'Agriculture',
    'Other',
  ];

  final List<String> _employeeCounts = [
    '1-10',
    '11-50',
    '51-200',
    '201-500',
    '500+',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.loadCompanyProfile(widget.userId);

    if (userProvider.companyProfile != null) {
      final profile = userProvider.companyProfile!;
      _companyNameController.text = profile.companyName;
      _descriptionController.text = profile.description;
      _websiteController.text = profile.website ?? '';
      _headOfficeController.text = profile.headOfficeLocation ?? '';
      _gstController.text = profile.gstNumber ?? '';
      _selectedIndustry = profile.industry.isNotEmpty ? profile.industry : 'Technology';
      _selectedEmployeeCount = profile.employeeCount ?? '1-10';
      _logoUrl = profile.logoUrl;
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _descriptionController.dispose();
    _websiteController.dispose();
    _headOfficeController.dispose();
    _gstController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          setState(() {
            _logoImageBytes = bytes;
          });
        } else {
          setState(() {
            _logoImage = File(image.path);
          });
        }
      }
    } catch (e) {
      // Handle web-specific errors gracefully
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: ${e.toString()}'),
            backgroundColor: Colors.orange,
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
      final currentProfile = userProvider.companyProfile;

      // Upload logo if selected
      String? finalLogoUrl = _logoUrl;
      if (_logoImage != null || _logoImageBytes != null) {
        if (kIsWeb && _logoImageBytes != null) {
          finalLogoUrl = await _cloudinaryService.uploadImageBytes(
            _logoImageBytes!,
            folder: 'company_logos',
          );
        } else if (_logoImage != null) {
          finalLogoUrl = await _cloudinaryService.uploadImage(
            _logoImage!,
            folder: 'company_logos',
          );
        }
      }

      final profile = CompanyProfile(
        userId: widget.userId,
        companyName: _companyNameController.text.trim(),
        description: _descriptionController.text.trim(),
        industry: _selectedIndustry,
        website: _websiteController.text.trim().isNotEmpty 
            ? _websiteController.text.trim() 
            : null,
        logoUrl: finalLogoUrl,
        employeeCount: _selectedEmployeeCount,
        headOfficeLocation: _headOfficeController.text.trim().isNotEmpty
            ? _headOfficeController.text.trim()
            : null,
        gstNumber: _gstController.text.trim().isNotEmpty
            ? _gstController.text.trim()
            : null,
        isVerified: false, // Requires admin verification
        verificationStatus: 'pending',
        createdAt: currentProfile?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await userProvider.updateCompanyProfile(profile);

      if (finalLogoUrl != null && finalLogoUrl.isNotEmpty) {
        try {
          await FirestoreService().updateUserProfilePhoto(widget.userId, finalLogoUrl);

          if (authProvider.currentUser != null) {
            final updatedUser = authProvider.currentUser!.copyWith(
              profilePhoto: finalLogoUrl,
            );
            await authProvider.updateProfile(updatedUser);
          }
        } catch (e) {
          debugPrint('Failed to sync company logo: $e');
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Company profile saved successfully!'),
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
        title: const Text('Company Profile Setup'),
        backgroundColor: Colors.indigo,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tell us about your company',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Build your company profile to attract talented candidates',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),

              // Company Logo
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        image: (kIsWeb && _logoImageBytes != null)
                            ? DecorationImage(
                                image: MemoryImage(_logoImageBytes!),
                                fit: BoxFit.cover,
                              )
                            : (_logoImage != null
                                ? DecorationImage(
                                    image: FileImage(_logoImage!),
                                    fit: BoxFit.cover,
                                  )
                                : (_logoUrl != null && _logoUrl!.isNotEmpty
                                    ? DecorationImage(
                                        image: NetworkImage(_logoUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null)),
                      ),
                      child: _logoImage == null && _logoImageBytes == null && (_logoUrl == null || _logoUrl!.isEmpty)
                          ? const Icon(Icons.business, size: 60, color: Colors.grey)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        backgroundColor: Colors.indigo,
                        radius: 20,
                        child: IconButton(
                          icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                          onPressed: _pickLogo,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Company Name
              TextFormField(
                controller: _companyNameController,
                decoration: const InputDecoration(
                  labelText: 'Company Name *',
                  hintText: 'Your Company Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter company name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Industry
              DropdownButtonFormField<String>(
                value: _selectedIndustry,
                decoration: const InputDecoration(
                  labelText: 'Industry *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: _industries.map((industry) {
                  return DropdownMenuItem(
                    value: industry,
                    child: Text(industry),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedIndustry = value!;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Employee Count
              DropdownButtonFormField<String>(
                value: _selectedEmployeeCount,
                decoration: const InputDecoration(
                  labelText: 'Company Size',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.people),
                ),
                items: _employeeCounts.map((count) {
                  return DropdownMenuItem(
                    value: count,
                    child: Text('$count employees'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedEmployeeCount = value!;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Company Description *',
                  hintText: 'Tell us about your company...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 4,
                maxLength: 1000,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please provide company description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Head Office Location
              TextFormField(
                controller: _headOfficeController,
                decoration: const InputDecoration(
                  labelText: 'Head Office Location',
                  hintText: 'City, State, Country',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
              ),
              const SizedBox(height: 16),

              // Website
              TextFormField(
                controller: _websiteController,
                decoration: const InputDecoration(
                  labelText: 'Website',
                  hintText: 'https://www.company.com',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.language),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 16),

              // GST Number
              TextFormField(
                controller: _gstController,
                decoration: const InputDecoration(
                  labelText: 'GST Number (Optional)',
                  hintText: 'For business verification',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.verified),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Note: Business verification is recommended to attract quality candidates',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
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
