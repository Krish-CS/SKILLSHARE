import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/job_model.dart';
import '../../models/user_model.dart';
import '../../models/skilled_user_profile.dart';
import '../../services/firestore_service.dart';
import '../../services/chat_service.dart';
import '../../utils/app_helpers.dart';
import '../../utils/app_constants.dart';
import '../profile/profile_screen.dart';
import '../chat/chat_detail_screen.dart';

class JobDetailScreen extends StatefulWidget {
  final JobModel job;

  const JobDetailScreen({
    super.key,
    required this.job,
  });

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final ChatService _chatService = ChatService();
  
  UserModel? _currentUser;
  UserModel? _employer;
  bool _isLoading = false;
  bool _hasApplied = false;
  List<SkilledUserProfile> _applicantProfiles = [];
  Map<String, UserModel> _applicantUsers = {}; // Store UserModel for each applicant

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        _currentUser = await _firestoreService.getUserById(userId);
        _hasApplied = widget.job.applicants.contains(userId);
      }
      
      _employer = await _firestoreService.getUserById(widget.job.companyId);
      
      // Load applicant profiles if user is the employer
      if (_currentUser?.uid == widget.job.companyId && widget.job.applicants.isNotEmpty) {
        _applicantProfiles = [];
        _applicantUsers = {};
        for (var applicantId in widget.job.applicants) {
          final profile = await _firestoreService.getSkilledUserProfile(applicantId);
          final user = await _firestoreService.getUserById(applicantId);
          if (profile != null) {
            _applicantProfiles.add(profile);
            if (user != null) {
              _applicantUsers[applicantId] = user;
            }
          }
        }
      }
      
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
  }

  Future<void> _applyForJob() async {
    if (_currentUser == null) return;

    if (_currentUser!.role != AppConstants.roleSkilledUser) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only skilled users can apply for jobs'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _firestoreService.applyForJob(widget.job.id, _currentUser!.uid);
      
      setState(() {
        _hasApplied = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error applying: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _shareJob() async {
    await Share.share(
      '${widget.job.title}\n\n'
      '${widget.job.description}\n\n'
      'Location: ${widget.job.location}\n'
      'Job Type: ${widget.job.jobType}\n'
      'Deadline: ${AppHelpers.formatDate(widget.job.deadline)}\n\n'
      'Apply now on SkillShare!',
      subject: widget.job.title,
    );
  }

  Future<void> _deleteJob() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Job'),
        content: const Text('Are you sure you want to delete this job posting? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _firestoreService.deleteJob(widget.job.id);
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Job deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting job: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  bool get _isEmployer {
    return _currentUser?.uid == widget.job.companyId;
  }

  bool get _canApply {
    return !_isEmployer && 
           !_hasApplied && 
           widget.job.status == 'open' &&
           _currentUser?.role == AppConstants.roleSkilledUser;
  }

  Color get _statusColor {
    switch (widget.job.status) {
      case 'open':
        return Colors.green;
      case 'in_progress':
        return Colors.orange;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Details', style: TextStyle(color: Colors.white)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2196F3), Color(0xFF00BCD4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareJob,
          ),
          if (_isEmployer)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') {
                  _deleteJob();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete Job', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Job Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2196F3), Color(0xFF00BCD4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Job Type Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.job.jobType.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Job Title
                  Text(
                    widget.job.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Location and Budget
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.white, size: 18),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.job.location,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (widget.job.budgetMin != null && widget.job.budgetMax != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.attach_money, color: Colors.white, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          '${AppHelpers.formatCurrency(widget.job.budgetMin!)} - ${AppHelpers.formatCurrency(widget.job.budgetMax!)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status and Deadline
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_statusColor == Colors.green ? Icons.circle : Icons.work, 
                              color: _statusColor, size: 12),
                            const SizedBox(width: 6),
                            Text(
                              widget.job.status.toUpperCase(),
                              style: TextStyle(
                                color: _statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.access_time, color: Colors.grey[600], size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Deadline: ${AppHelpers.formatDate(widget.job.deadline)}',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Description
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.job.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Required Skills
                  const Text(
                    'Required Skills',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.job.requiredSkills.map((skill) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2196F3).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF2196F3).withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          skill,
                          style: const TextStyle(
                            color: Color(0xFF2196F3),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Employer Info
                  if (_employer != null) ...[
                    const Text(
                      'Posted By',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundImage: _employer!.profilePhoto != null
                                  ? CachedNetworkImageProvider(_employer!.profilePhoto!)
                                  : null,
                              child: _employer!.profilePhoto == null
                                  ? Text(
                                      _employer!.name[0].toUpperCase(),
                                      style: const TextStyle(fontSize: 24),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _employer!.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    _employer!.email,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Contact employer button (for non-employers)
                            if (!_isEmployer && _currentUser != null)
                              IconButton(
                                onPressed: () async {
                                  // Start chat with employer
                                  try {
                                    final currentUser = FirebaseAuth.instance.currentUser;
                                    if (currentUser == null || _employer == null) return;
                                    
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
                                      widget.job.companyId,
                                      {
                                        'name': _currentUser!.name,
                                        'profilePhoto': _currentUser!.profilePhoto,
                                      },
                                      {
                                        'name': _employer!.name,
                                        'profilePhoto': _employer!.profilePhoto,
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
                                          otherUserId: widget.job.companyId,
                                          otherUserName: _employer!.name,
                                          otherUserPhoto: _employer!.profilePhoto,
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
                                icon: const Icon(Icons.chat_bubble_outline),
                                color: const Color(0xFF2196F3),
                                tooltip: 'Contact Employer',
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Applicants (visible to employer only)
                  if (_isEmployer && _applicantProfiles.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Applicants',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2196F3).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_applicantProfiles.length} ${_applicantProfiles.length == 1 ? 'applicant' : 'applicants'}',
                            style: const TextStyle(
                              color: Color(0xFF2196F3),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._applicantProfiles.map((profile) {
                      final applicantUser = _applicantUsers[profile.userId];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ProfileScreen(userId: profile.userId),
                                    ),
                                  );
                                },
                                child: CircleAvatar(
                                  radius: 25,
                                  backgroundImage: profile.profilePicture != null
                                      ? CachedNetworkImageProvider(profile.profilePicture!)
                                      : null,
                                  child: profile.profilePicture == null
                                      ? Text(
                                          applicantUser?.name[0].toUpperCase() ?? 'U',
                                          style: const TextStyle(fontSize: 20),
                                        )
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ProfileScreen(userId: profile.userId),
                                      ),
                                    );
                                  },
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            applicantUser?.name ?? 'Unknown',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (profile.isVerified) ...[
                                            const SizedBox(width: 4),
                                            const Icon(
                                              Icons.verified,
                                              color: Colors.blue,
                                              size: 18,
                                            ),
                                          ],
                                        ],
                                      ),
                                      Text(
                                        profile.category ?? 'No category',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.star,
                                            color: Colors.amber,
                                            size: 14,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${profile.rating.toStringAsFixed(1)} (${profile.reviewCount})',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Contact button
                              IconButton(
                                onPressed: () async {
                                  // Start chat with applicant
                                  if (applicantUser == null || _currentUser == null) return;
                                  
                                  try {
                                    final currentUser = FirebaseAuth.instance.currentUser;
                                    if (currentUser == null) return;
                                    
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
                                      profile.userId,
                                      {
                                        'name': _currentUser!.name,
                                        'profilePhoto': _currentUser!.profilePhoto,
                                      },
                                      {
                                        'name': applicantUser.name,
                                        'profilePhoto': applicantUser.profilePhoto,
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
                                          otherUserId: profile.userId,
                                          otherUserName: applicantUser.name,
                                          otherUserPhoto: applicantUser.profilePhoto,
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
                                icon: const Icon(Icons.chat_bubble_outline),
                                color: const Color(0xFF2196F3),
                                tooltip: 'Contact',
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                  ],

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ],
        ),
      ),

      // Bottom Action Bar
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: _isEmployer
              ? Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Edit feature coming soon!'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit Job'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Color(0xFF2196F3)),
                          foregroundColor: const Color(0xFF2196F3),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Show applicants or manage job
                        },
                        icon: const Icon(Icons.people),
                        label: Text('${widget.job.applicants.length} Applicants'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2196F3),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                )
              : ElevatedButton(
                  onPressed: _canApply
                      ? (_isLoading ? null : _applyForJob)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    disabledBackgroundColor: Colors.grey[300],
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
                          _hasApplied
                              ? 'Already Applied'
                              : widget.job.status != 'open'
                              ? 'Job Closed'
                              : 'Apply Now',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
        ),
      ),
    );
  }
}
