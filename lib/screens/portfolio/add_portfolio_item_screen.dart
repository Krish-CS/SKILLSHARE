import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../models/portfolio_model.dart';
import '../../services/portfolio_service.dart';
import '../../services/cloudinary_service.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../utils/app_constants.dart';

class AddPortfolioItemScreen extends StatefulWidget {
  final PortfolioItem? portfolioItem; // For editing existing item

  const AddPortfolioItemScreen({super.key, this.portfolioItem});

  @override
  State<AddPortfolioItemScreen> createState() => _AddPortfolioItemScreenState();
}

class _AddPortfolioItemScreenState extends State<AddPortfolioItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final PortfolioService _portfolioService = PortfolioService();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final ImagePicker _picker = ImagePicker();

  String? _selectedCategory;
  List<String> _skills = [];
  List<String> _imageUrls = [];
  List<String> _videoUrls = [];
  final List<File> _selectedImages = [];
  final List<File> _selectedVideos = [];
  bool _isLoading = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    if (widget.portfolioItem != null) {
      _loadExistingItem();
    }
  }

  void _loadExistingItem() {
    final item = widget.portfolioItem!;
    _titleController.text = item.title;
    _descriptionController.text = item.description;
    _selectedCategory = item.category;
    _skills = List.from(item.tags);
    _imageUrls = List.from(item.images);
    _videoUrls = List.from(item.videos);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      if (_selectedImages.length + _imageUrls.length >= 10) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 10 images allowed')),
        );
        return;
      }

      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 90,
      );

      if (images.isEmpty) return;

      setState(() {
        final remaining = 10 - (_selectedImages.length + _imageUrls.length);
        _selectedImages.addAll(
          images.take(remaining).map((img) => File(img.path)),
        );
      });
    } catch (e) {
      if (mounted && !e.toString().contains('cancel')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking images: $e')),
        );
      }
    }
  }

  Future<void> _pickVideo() async {
    try {
      if (_selectedVideos.length + _videoUrls.length >= 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 3 videos allowed')),
        );
        return;
      }

      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 3),
      );

      if (video == null) return;

      setState(() {
        _selectedVideos.add(File(video.path));
      });
    } catch (e) {
      if (mounted && !e.toString().contains('cancel')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking video: $e')),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _removeUploadedImage(int index) {
    setState(() {
      _imageUrls.removeAt(index);
    });
  }

  void _removeVideo(int index) {
    setState(() {
      _selectedVideos.removeAt(index);
    });
  }

  void _removeUploadedVideo(int index) {
    setState(() {
      _videoUrls.removeAt(index);
    });
  }

  void _addSkill() {
    showDialog(
      context: context,
      builder: (context) {
        String skillName = '';
        return AlertDialog(
          title: const Text('Add Skill Tag'),
          content: TextField(
            onChanged: (value) => skillName = value,
            decoration: const InputDecoration(hintText: 'Enter skill name'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (skillName.trim().isNotEmpty && !_skills.contains(skillName.trim())) {
                  setState(() {
                    _skills.add(skillName.trim());
                  });
                }
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _removeSkill(String skill) {
    setState(() {
      _skills.remove(skill);
    });
  }

  Future<void> _savePortfolioItem() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    if (_selectedImages.isEmpty && _imageUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one image'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _isUploading = true;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final now = DateTime.now();
      List<String> finalImageUrls = List.from(_imageUrls);
      List<String> finalVideoUrls = List.from(_videoUrls);

      // Upload selected images
      if (_selectedImages.isNotEmpty) {
        for (var image in _selectedImages) {
          final url = await _cloudinaryService.uploadImage(
            image,
            folder: 'portfolio',
          );
          if (url != null) {
            finalImageUrls.add(url);
          }
        }
      }

      // Upload selected videos
      if (_selectedVideos.isNotEmpty) {
        for (var video in _selectedVideos) {
          final url = await _cloudinaryService.uploadVideo(
            video,
            folder: 'portfolio',
          );
          if (url != null) {
            finalVideoUrls.add(url);
          }
        }
      }

      final portfolioItem = PortfolioItem(
        id: widget.portfolioItem?.id ?? '',
        userId: userId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        images: finalImageUrls,
        videos: finalVideoUrls,
        category: _selectedCategory!,
        tags: _skills,
        likes: widget.portfolioItem?.likes ?? 0,
        views: widget.portfolioItem?.views ?? 0,
        createdAt: widget.portfolioItem?.createdAt ?? now,
        updatedAt: now,
      );

      if (widget.portfolioItem == null) {
        await _portfolioService.createPortfolioItem(portfolioItem);
      } else {
        await _portfolioService.updatePortfolioItem(portfolioItem);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.portfolioItem == null
                ? 'Portfolio item added successfully!'
                : 'Portfolio item updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving portfolio item: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<app_auth.AuthProvider>(context);

    if (!authProvider.isSkilledPerson) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Add Portfolio Item'),
          backgroundColor: Colors.red,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.block, size: 80, color: Colors.red),
                const SizedBox(height: 20),
                const Text(
                  'Access Denied',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Only skilled persons can manage their portfolio.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.portfolioItem == null ? 'Add Portfolio Item' : 'Edit Portfolio Item',
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.teal,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Title
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Title',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        hintText: 'e.g., Custom Wedding Cake',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.title),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Category
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Category',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        hintText: 'Select category',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.category),
                      ),
                      items: AppConstants.categories.map((category) {
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
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Description
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        hintText: 'Describe your work and the skills used',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.description),
                      ),
                      maxLines: 5,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a description';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Skill Tags
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Skill Tags',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _addSkill,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Skill'),
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
                          deleteIcon: const Icon(Icons.close, size: 18),
                          backgroundColor: Colors.teal.shade50,
                        );
                      }).toList(),
                    ),
                    if (_skills.isEmpty)
                      const Text(
                        'Add relevant skills to help customers find your work',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Images Upload
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Portfolio Images',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                        Text(
                          '${_selectedImages.length + _imageUrls.length}/10',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Image Preview Grid
                    if (_selectedImages.isNotEmpty || _imageUrls.isNotEmpty)
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _imageUrls.length + _selectedImages.length,
                          itemBuilder: (context, index) {
                            if (index < _imageUrls.length) {
                              return Stack(
                                children: [
                                  Container(
                                    width: 120,
                                    height: 120,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey[300]!),
                                      image: DecorationImage(
                                        image: NetworkImage(_imageUrls[index]),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 16,
                                    child: GestureDetector(
                                      onTap: () => _removeUploadedImage(index),
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
                              final fileIndex = index - _imageUrls.length;
                              return Stack(
                                children: [
                                  Container(
                                    width: 120,
                                    height: 120,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey[300]!),
                                      image: DecorationImage(
                                        image: FileImage(_selectedImages[fileIndex]),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 16,
                                    child: GestureDetector(
                                      onTap: () => _removeImage(fileIndex),
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

                    if (_selectedImages.isNotEmpty || _imageUrls.isNotEmpty)
                      const SizedBox(height: 12),

                    // Add Images Button
                    InkWell(
                      onTap: (_selectedImages.length + _imageUrls.length < 10)
                          ? _pickImages
                          : null,
                      child: Container(
                        height: 100,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: (_selectedImages.length + _imageUrls.length < 10)
                                ? Colors.teal
                                : Colors.grey[400]!,
                            width: 2,
                            style: BorderStyle.solid,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey[50],
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate,
                                size: 40,
                                color: (_selectedImages.length + _imageUrls.length < 10)
                                    ? Colors.teal
                                    : Colors.grey,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                (_selectedImages.length + _imageUrls.length < 10)
                                    ? 'Tap to add images'
                                    : 'Maximum 10 images',
                                style: TextStyle(
                                  color: (_selectedImages.length + _imageUrls.length < 10)
                                      ? Colors.teal
                                      : Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Videos Upload
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Portfolio Videos (Optional)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                        Text(
                          '${_selectedVideos.length + _videoUrls.length}/3',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Video List
                    if (_selectedVideos.isNotEmpty || _videoUrls.isNotEmpty)
                      Column(
                        children: [
                          ..._videoUrls.asMap().entries.map((entry) {
                            return ListTile(
                              leading: const Icon(Icons.video_library, color: Colors.teal),
                              title: Text('Video ${entry.key + 1}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _removeUploadedVideo(entry.key),
                              ),
                            );
                          }),
                          ..._selectedVideos.asMap().entries.map((entry) {
                            return ListTile(
                              leading: const Icon(Icons.video_file, color: Colors.teal),
                              title: Text('New Video ${entry.key + 1}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _removeVideo(entry.key),
                              ),
                            );
                          }),
                        ],
                      ),

                    // Add Video Button
                    ElevatedButton.icon(
                      onPressed: (_selectedVideos.length + _videoUrls.length < 3)
                          ? _pickVideo
                          : null,
                      icon: const Icon(Icons.video_call),
                      label: Text(
                        (_selectedVideos.length + _videoUrls.length < 3)
                            ? 'Add Video'
                            : 'Maximum 3 videos',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Save Button
            ElevatedButton(
              onPressed: _isLoading ? null : _savePortfolioItem,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      widget.portfolioItem == null
                          ? 'Add to Portfolio'
                          : 'Update Portfolio Item',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
      bottomSheet: _isUploading
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              color: Colors.black87,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(width: 16),
                  Text(
                    'Uploading media...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}
