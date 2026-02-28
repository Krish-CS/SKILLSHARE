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
import '../../utils/app_dialog.dart';
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

  // Purple palette constants
  static const _primary = Color(0xFF4527A0);
  static const _light = Color(0xFF7E57C2);
  static const _chipBg = Color(0xFFEDE7F6);

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
      _selectedIndustry =
          profile.industry.isNotEmpty ? profile.industry : 'Technology';
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
      if (mounted) {
        AppDialog.error(context, 'Error picking image', detail: e.toString());
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isUploading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentProfile = userProvider.companyProfile;

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
        isVerified: false,
        verificationStatus: 'pending',
        createdAt: currentProfile?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await userProvider.updateCompanyProfile(profile);

      if (finalLogoUrl != null && finalLogoUrl.isNotEmpty) {
        try {
          await FirestoreService()
              .updateUserProfilePhoto(widget.userId, finalLogoUrl);
          if (authProvider.currentUser != null) {
            final updatedUser =
                authProvider.currentUser!.copyWith(profilePhoto: finalLogoUrl);
            await authProvider.updateProfile(updatedUser);
          }
        } catch (e) {
          debugPrint('Failed to sync company logo: $e');
        }
      }

      if (!mounted) return;

      AppDialog.success(context, 'Company profile saved successfully!',
          onDismiss: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainNavigation()),
          ));
    } catch (e) {
      if (!mounted) return;
      AppDialog.error(context, 'Error saving profile', detail: e.toString());
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: Form(
        key: _formKey,
        child: CustomScrollView(
          slivers: [
            // ── Gradient header with logo ──────────────────────────────────
            SliverAppBar(
              expandedHeight: 210,
              pinned: true,
              stretch: true,
              backgroundColor: _primary,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 16, bottom: 14),
                title: const Text(
                  'Company Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_primary, _light],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 28),
                      child: GestureDetector(
                        onTap: _pickLogo,
                        child: Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border:
                                    Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                                image: (kIsWeb && _logoImageBytes != null)
                                    ? DecorationImage(
                                        image: MemoryImage(_logoImageBytes!),
                                        fit: BoxFit.cover)
                                    : (_logoImage != null
                                        ? DecorationImage(
                                            image: FileImage(_logoImage!),
                                            fit: BoxFit.cover)
                                        : (_logoUrl != null &&
                                                _logoUrl!.isNotEmpty
                                            ? DecorationImage(
                                                image:
                                                    NetworkImage(_logoUrl!),
                                                fit: BoxFit.cover)
                                            : null)),
                              ),
                              child: (_logoImage == null &&
                                      _logoImageBytes == null &&
                                      (_logoUrl == null || _logoUrl!.isEmpty))
                                  ? const Icon(Icons.business,
                                      size: 48, color: _primary)
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: _primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 2),
                                ),
                                child: const Icon(Icons.camera_alt,
                                    color: Colors.white, size: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 20, 16, bottomPad + 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Company Identity ─────────────────────────────────
                    _sectionCard(
                      title: 'Company Identity',
                      icon: Icons.business_center_rounded,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _companyNameController,
                            decoration: _inputDeco(
                              label: 'Company Name *',
                              hint: 'Your Company Name',
                              icon: Icons.business_outlined,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter company name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            value: _selectedIndustry,
                            decoration: _inputDeco(
                              label: 'Industry *',
                              hint: '',
                              icon: Icons.category_outlined,
                            ),
                            items: _industries
                                .map((i) => DropdownMenuItem(
                                    value: i, child: Text(i)))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedIndustry = v!),
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            value: _selectedEmployeeCount,
                            decoration: _inputDeco(
                              label: 'Company Size',
                              hint: '',
                              icon: Icons.people_outline_rounded,
                            ),
                            items: _employeeCounts
                                .map((c) => DropdownMenuItem(
                                    value: c,
                                    child: Text('$c employees')))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedEmployeeCount = v!),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── About ────────────────────────────────────────────
                    _sectionCard(
                      title: 'About the Company',
                      icon: Icons.info_outline_rounded,
                      subtitle: 'Help talent understand your mission',
                      child: TextFormField(
                        controller: _descriptionController,
                        decoration: _inputDeco(
                          label: 'Company Description *',
                          hint:
                              'Describe your vision, culture, work style...',
                          icon: Icons.description_outlined,
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
                    ),

                    const SizedBox(height: 16),

                    // ── Location & Web ───────────────────────────────────
                    _sectionCard(
                      title: 'Location & Web',
                      icon: Icons.public_rounded,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _headOfficeController,
                            decoration: _inputDeco(
                              label: 'Head Office Location',
                              hint: 'City, State, Country',
                              icon: Icons.location_on_outlined,
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _websiteController,
                            decoration: _inputDeco(
                              label: 'Website',
                              hint: 'https://www.company.com',
                              icon: Icons.language_outlined,
                            ),
                            keyboardType: TextInputType.url,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Legal Details ────────────────────────────────────
                    _sectionCard(
                      title: 'Legal Details',
                      icon: Icons.verified_outlined,
                      subtitle: 'Optional — builds trust with candidates',
                      child: TextFormField(
                        controller: _gstController,
                        decoration: _inputDeco(
                          label: 'GST Number (Optional)',
                          hint: 'For business verification',
                          icon: Icons.numbers_outlined,
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Save button ──────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_primary, _light],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: _primary.withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isUploading ? null : _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isUploading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2.5),
                                )
                              : const Text(
                                  'Save Company Profile',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
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

  Widget _sectionCard({
    required String title,
    required IconData icon,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _chipBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: _primary, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  InputDecoration _inputDeco({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: _primary),
      filled: true,
      fillColor: const Color(0xFFF5F7FA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCFD8DC)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCFD8DC)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primary, width: 2),
      ),
      labelStyle: const TextStyle(color: Color(0xFF607D8B)),
    );
  }
}
