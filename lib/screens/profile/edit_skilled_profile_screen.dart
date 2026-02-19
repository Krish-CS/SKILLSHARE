import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/skilled_user_profile.dart';
import '../../models/service_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/web_image_loader.dart';
import 'skilled_user_setup_screen.dart';

class EditSkilledProfileScreen extends StatefulWidget {
  const EditSkilledProfileScreen({super.key});

  @override
  State<EditSkilledProfileScreen> createState() =>
      _EditSkilledProfileScreenState();
}

class _EditSkilledProfileScreenState extends State<EditSkilledProfileScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  SkilledUserProfile? _profile;
  List<ServiceModel> _services = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (authProvider.currentUser != null) {
      await userProvider.loadProfile(authProvider.currentUser!.uid);
      try {
        _services = await _firestoreService.getUserServices(authProvider.currentUser!.uid);
      } catch (e) {
        debugPrint('Error loading services: $e');
      }
    }
    setState(() {
      _profile = userProvider.currentProfile;
      _isLoading = false;
    });
  }

  void _showVerificationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.security, color: Colors.orange),
            SizedBox(width: 8),
            Text('Verification Required'),
          ],
        ),
        content: const Text(
          'Complete Aadhaar verification from Edit Full Profile to '
          'upload portfolio images and add services.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _toggleVisibility() async {
    if (_profile == null) return;
    final newVisibility = _profile!.visibility == 'public' ? 'private' : 'public';
    final updatedProfile = SkilledUserProfile(
      userId: _profile!.userId,
      name: _profile!.name,
      bio: _profile!.bio,
      skills: _profile!.skills,
      category: _profile!.category,
      profilePicture: _profile!.profilePicture,
      verificationStatus: _profile!.verificationStatus,
      visibility: newVisibility,
      portfolioImages: _profile!.portfolioImages,
      portfolioVideos: _profile!.portfolioVideos,
      verificationData: _profile!.verificationData,
      address: _profile!.address,
      city: _profile!.city,
      state: _profile!.state,
      rating: _profile!.rating,
      reviewCount: _profile!.reviewCount,
      projectCount: _profile!.projectCount,
      isVerified: _profile!.isVerified,
      verifiedAt: _profile!.verifiedAt,
      createdAt: _profile!.createdAt,
      updatedAt: DateTime.now(),
    );
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final success = await userProvider.updateProfile(updatedProfile);
    if (success && mounted) {
      setState(() => _profile = updatedProfile);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            Icon(newVisibility == 'public' ? Icons.visibility : Icons.visibility_off, color: Colors.white),
            const SizedBox(width: 8),
            Text('Profile is now ${newVisibility.toUpperCase()}'),
          ]),
          backgroundColor: newVisibility == 'public' ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  void _navigateToFullEdit() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SkilledUserSetupScreen(userId: authProvider.currentUser!.uid)),
    );
    _loadProfile();
  }

  void _showAddServiceDialog({ServiceModel? existing}) {
    if (_profile?.isVerified != true) {
      _showVerificationDialog();
      return;
    }
    final titleController = TextEditingController(text: existing?.title ?? '');
    final descController = TextEditingController(text: existing?.description ?? '');
    final minPriceController = TextEditingController(text: existing != null ? existing.priceMin.toStringAsFixed(0) : '');
    final maxPriceController = TextEditingController(text: existing != null ? existing.priceMax.toStringAsFixed(0) : '');
    String selectedUnit = existing?.priceUnit ?? 'per session';
    final formKey = GlobalKey<FormState>();
    final priceUnits = ['per session', 'per hour', 'per day', 'per project', 'per order', 'fixed price'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(existing != null ? 'Edit Service' : 'Add Service'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Service Title', hintText: 'e.g., Wedding Photography', prefixIcon: Icon(Icons.work)),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Description', hintText: 'Describe what you offer...', alignLabelWithHint: true),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextFormField(
                      controller: minPriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Min Price', prefixText: ' '),
                      validator: (v) { if (v == null || v.isEmpty) return 'Required'; if (double.tryParse(v) == null) return 'Invalid'; return null; },
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(
                      controller: maxPriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Max Price', prefixText: ' '),
                      validator: (v) { if (v == null || v.isEmpty) return 'Required'; if (double.tryParse(v) == null) return 'Invalid'; return null; },
                    )),
                  ]),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedUnit,
                    decoration: const InputDecoration(labelText: 'Pricing Unit', prefixIcon: Icon(Icons.schedule)),
                    items: priceUnits.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                    onChanged: (v) => setDialogState(() => selectedUnit = v ?? selectedUnit),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(ctx);
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                final now = DateTime.now();
                final service = ServiceModel(
                  id: existing?.id ?? '',
                  userId: authProvider.currentUser!.uid,
                  title: titleController.text.trim(),
                  description: descController.text.trim(),
                  priceMin: double.parse(minPriceController.text),
                  priceMax: double.parse(maxPriceController.text),
                  priceUnit: selectedUnit,
                  images: existing?.images ?? [],
                  category: _profile?.category ?? '',
                  isActive: true,
                  createdAt: existing?.createdAt ?? now,
                  updatedAt: now,
                );
                try {
                  if (existing != null) {
                    await _firestoreService.updateService(service);
                  } else {
                    await _firestoreService.createService(service);
                  }
                  _loadProfile();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(existing != null ? 'Service updated!' : 'Service added!'),
                      backgroundColor: Colors.green,
                    ));
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2196F3), foregroundColor: Colors.white),
              child: Text(existing != null ? 'Update' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteService(ServiceModel service) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Service'),
        content: Text('Delete "${service.title}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      await _firestoreService.deleteService(service.id);
      _loadProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUser = authProvider.currentUser;
    final isVerified = _profile?.isVerified ?? false;
    final isPublic = _profile?.visibility == 'public';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text('Edit Profile', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton.icon(
            onPressed: _navigateToFullEdit,
            icon: const Icon(Icons.edit, color: Colors.white, size: 18),
            label: const Text('Full Edit', style: TextStyle(color: Colors.white)),
          ),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF6A11CB), Color(0xFF2575FC)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFF6A11CB), Color(0xFF2575FC)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                ),
                child: Column(children: [
                  Container(
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
                    child: WebImageLoader.loadAvatar(
                      imageUrl: _profile?.profilePicture ?? currentUser?.profilePhoto,
                      radius: 50,
                      fallbackText: currentUser?.name,
                      backgroundColor: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(currentUser?.name ?? 'User', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(_profile?.category ?? 'No Category', style: const TextStyle(fontSize: 15, color: Colors.white70)),
                  if (_profile?.address != null && _profile!.address!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.location_on, color: Colors.white70, size: 14),
                      const SizedBox(width: 4),
                      Text(_profile!.address!, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ]),
                  ],
                ]),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Visibility Toggle
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(children: [
                        Icon(isPublic ? Icons.visibility : Icons.visibility_off, color: isPublic ? Colors.green : Colors.orange),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Profile Visibility', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                          Text(isPublic ? 'Visible to everyone' : 'Hidden from search', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        ])),
                        Switch(value: isPublic, onChanged: (_) => _toggleVisibility(), activeColor: Colors.green),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Verification Status
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(children: [
                        Icon(isVerified ? Icons.verified : Icons.pending, color: isVerified ? Colors.green : Colors.orange),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Verification', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                          Text(isVerified ? 'Aadhaar verified' : 'Complete verification to unlock features', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        ])),
                        if (!isVerified) TextButton(onPressed: _navigateToFullEdit, child: const Text('Verify Now')),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Portfolio
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Portfolio', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('${_profile?.portfolioImages.length ?? 0} images', style: TextStyle(color: Colors.grey[600])),
                  ]),
                  const SizedBox(height: 12),
                  if (_profile?.portfolioImages.isNotEmpty == true)
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _profile!.portfolioImages.length,
                        itemBuilder: (context, index) => Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: WebImageLoader.loadImage(imageUrl: _profile!.portfolioImages[index], fit: BoxFit.cover),
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[300]!)),
                      child: Column(children: [
                        Icon(Icons.photo_library, size: 40, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text('No portfolio images yet', style: TextStyle(color: Colors.grey[600])),
                      ]),
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _navigateToFullEdit,
                      icon: const Icon(Icons.add_photo_alternate),
                      label: const Text('Manage Portfolio'),
                      style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF6A11CB), side: const BorderSide(color: Color(0xFF6A11CB)), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Services
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Services & Pricing', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('${_services.length} services', style: TextStyle(color: Colors.grey[600])),
                  ]),
                  const SizedBox(height: 12),
                  if (_services.isNotEmpty)
                    ..._services.map((service) => Card(
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: Text(service.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const SizedBox(height: 4),
                          Text(service.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text(
                            '${service.priceMin.toStringAsFixed(0)} - ${service.priceMax.toStringAsFixed(0)} ${service.priceUnit}',
                            style: const TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold),
                          ),
                        ]),
                        trailing: PopupMenuButton(
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'edit', child: Text('Edit')),
                            const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                          ],
                          onSelected: (v) {
                            if (v == 'edit') { _showAddServiceDialog(existing: service); }
                            else if (v == 'delete') { _deleteService(service); }
                          },
                        ),
                      ),
                    ))
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[300]!)),
                      child: Column(children: [
                        Icon(Icons.miscellaneous_services, size: 40, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text('No services added yet', style: TextStyle(color: Colors.grey[600])),
                        const SizedBox(height: 4),
                        Text(isVerified ? 'Add your services and pricing' : 'Verify Aadhaar to add services', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      ]),
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showAddServiceDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Service & Pricing'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2196F3), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Skills
                  const Text('Skills', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_profile?.skills.isNotEmpty == true)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _profile!.skills.map((skill) => Chip(
                        label: Text(skill),
                        backgroundColor: const Color(0xFF2196F3).withValues(alpha: 0.1),
                        labelStyle: const TextStyle(color: Color(0xFF2196F3)),
                      )).toList(),
                    )
                  else
                    Text('No skills added', style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  TextButton.icon(onPressed: _navigateToFullEdit, icon: const Icon(Icons.edit, size: 16), label: const Text('Edit Skills')),
                  const SizedBox(height: 24),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
