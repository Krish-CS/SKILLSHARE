import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';
import '../../models/job_model.dart';
import '../../models/user_model.dart';
import '../../models/skilled_user_profile.dart';
import '../../services/firestore_service.dart';
import '../../services/chat_service.dart';
import '../../utils/app_helpers.dart';
import '../../utils/app_dialog.dart';
import '../../utils/app_constants.dart';
import '../../widgets/universal_avatar.dart';
import '../profile/profile_screen.dart';
import '../chat/chat_detail_screen.dart';
import 'create_job_screen.dart';

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
  late JobModel _job;
  StreamSubscription<JobModel?>? _jobSub;
  StreamSubscription<UserModel?>? _employerSub;
  StreamSubscription<UserModel?>? _currentUserSub;
  bool _isLoading = false;
  bool _hasApplied = false;
  String? _processingApplicantId;
  List<SkilledUserProfile> _applicantProfiles = [];
  Map<String, UserModel> _applicantUsers =
      {}; // Store UserModel for each applicant
  final GlobalKey _applicantsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _job = widget.job;
    _subscribeToJob();
    _subscribeToUsers();
    _loadApplicantProfilesIfNeeded();
  }

  @override
  void dispose() {
    _jobSub?.cancel();
    _employerSub?.cancel();
    _currentUserSub?.cancel();
    super.dispose();
  }

  void _subscribeToJob() {
    _jobSub?.cancel();
    _jobSub = _firestoreService.streamJob(widget.job.id).listen((job) {
      if (!mounted || job == null) return;
      setState(() {
        _job = job;
        _hasApplied =
            _currentUser != null && _job.applicants.contains(_currentUser!.uid);
      });
      if (_isEmployer) {
        _loadApplicantProfiles();
      }
    });
  }

  void _subscribeToUsers() {
    // Stream the employer's data live
    _employerSub = _firestoreService
        .streamUserModel(_job.companyId)
        .listen((user) {
      if (mounted) setState(() => _employer = user);
    });

    // Stream the current user's data live
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      _currentUserSub = _firestoreService
          .streamUserModel(userId)
          .listen((user) {
        if (!mounted) return;
        setState(() {
          _currentUser = user;
          _hasApplied = _job.applicants.contains(userId);
        });
      });
    }
  }

  Future<void> _loadApplicantProfilesIfNeeded() async {
    if (_isEmployer) {
      await _loadApplicantProfiles();
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadApplicantProfiles() async {
    if (!_isEmployer) return;
    if (_job.applicants.isEmpty) {
      if (mounted) {
        setState(() {
          _applicantProfiles = [];
          _applicantUsers = {};
        });
      }
      return;
    }

    final profiles = <SkilledUserProfile>[];
    final users = <String, UserModel>{};

    for (var applicantId in _job.applicants) {
      final profile =
          await _firestoreService.getSkilledUserProfile(applicantId);
      final user = await _firestoreService.getUserById(applicantId);
      if (profile != null) {
        profiles.add(profile);
        if (user != null) {
          users[applicantId] = user;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _applicantProfiles = profiles;
      _applicantUsers = users;
    });
  }

  Future<void> _applyForJob() async {
    if (_currentUser == null) return;

    if (_currentUser!.role != AppConstants.roleSkilledUser) {
      AppDialog.info(context, 'Only skilled users can apply for jobs');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _firestoreService.applyForJob(_job.id, _currentUser!.uid);

      setState(() {
        _hasApplied = true;
      });

      if (mounted) {
        AppDialog.success(context, 'Application submitted successfully!');
      }
    } catch (e) {
      if (mounted) {
        AppDialog.error(context, 'Error applying for job',
            detail: e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _shareJob() async {
    await Share.share(
      '${_job.title}\n\n'
      '${_job.description}\n\n'
      'Location: ${_job.location}\n'
      'Job Type: ${_job.jobType}\n'
      'Deadline: ${AppHelpers.formatDate(_job.deadline)}\n\n'
      'Apply now on SkillShare!',
      subject: _job.title,
    );
  }

  Future<void> _deleteJob() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Job'),
        content: const Text(
            'Are you sure you want to delete this job posting? This action cannot be undone.'),
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
        await _firestoreService.deleteJob(_job.id);
        if (mounted) {
          AppDialog.success(context, 'Job deleted successfully',
              onDismiss: () => Navigator.of(context).pop(true));
        }
      } catch (e) {
        if (mounted) {
          AppDialog.error(context, 'Error deleting job', detail: e.toString());
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  bool get _isEmployer {
    return _currentUser?.uid == _job.companyId;
  }

  bool get _canApply {
    return !_isEmployer &&
        !_hasApplied &&
        _job.status == 'open' &&
        _currentUser?.role == AppConstants.roleSkilledUser;
  }

  Color get _statusColor {
    switch (_job.status) {
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

  String _applicationState(String applicantId) {
    return _job.applicationStatus[applicantId] ?? 'pending';
  }

  Future<void> _acceptApplicant(String applicantId) async {
    if (!_isEmployer || _currentUser == null) return;
    setState(() => _processingApplicantId = applicantId);
    try {
      await _firestoreService.acceptJobApplicant(
        jobId: _job.id,
        applicantId: applicantId,
        companyId: _currentUser!.uid,
      );
      if (!mounted) return;
      AppDialog.success(context, 'Applicant accepted.');
    } catch (e) {
      if (!mounted) return;
      AppDialog.error(context, 'Failed to accept applicant',
          detail: e.toString());
    } finally {
      if (mounted) {
        setState(() => _processingApplicantId = null);
      }
    }
  }

  Future<void> _rejectApplicant(String applicantId) async {
    if (!_isEmployer || _currentUser == null) return;
    setState(() => _processingApplicantId = applicantId);
    try {
      await _firestoreService.rejectJobApplicant(
        jobId: _job.id,
        applicantId: applicantId,
        companyId: _currentUser!.uid,
      );
      if (!mounted) return;
      AppDialog.success(context, 'Applicant rejected.');
    } catch (e) {
      if (!mounted) return;
      AppDialog.error(context, 'Failed to reject applicant',
          detail: e.toString());
    } finally {
      if (mounted) {
        setState(() => _processingApplicantId = null);
      }
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
                    color: Colors.black.withValues(alpha: 0.1),
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
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _job.jobType.toUpperCase(),
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
                    _job.title,
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
                      const Icon(Icons.location_on,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _job.location,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_job.budgetMin != null && _job.budgetMax != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '${AppHelpers.formatCurrency(_job.budgetMin!)} - ${AppHelpers.formatCurrency(_job.budgetMax!)}',
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
                          color: _statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                                _statusColor == Colors.green
                                    ? Icons.circle
                                    : Icons.work,
                                color: _statusColor,
                                size: 12),
                            const SizedBox(width: 6),
                            Text(
                              _job.status.toUpperCase(),
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
                      Icon(Icons.access_time,
                          color: Colors.grey[600], size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Deadline: ${AppHelpers.formatDate(_job.deadline)}',
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
                    _job.description,
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
                    children: _job.requiredSkills.map((skill) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2196F3).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color:
                                const Color(0xFF2196F3).withValues(alpha: 0.3),
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
                            UniversalAvatar(
                              avatarConfig: _employer!.avatarConfig,
                              photoUrl: _employer!.profilePhoto,
                              fallbackName: _employer!.name,
                              radius: 30,
                              animate: false,
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
                                  final nav = Navigator.of(context);
                                  try {
                                    final currentUser =
                                        FirebaseAuth.instance.currentUser;
                                    if (currentUser == null ||
                                        _employer == null) {
                                      return;
                                    }

                                    // Show loading
                                    if (!mounted) return;
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (_) => const Center(
                                          child: CircularProgressIndicator()),
                                    );

                                    // Get or create chat
                                    final chatId =
                                        await _chatService.getOrCreateChat(
                                      currentUser.uid,
                                      _job.companyId,
                                      {
                                        'name': _currentUser!.name,
                                        'profilePhoto':
                                            _currentUser!.profilePhoto,
                                      },
                                      {
                                        'name': _employer!.name,
                                        'profilePhoto': _employer!.profilePhoto,
                                      },
                                    );

                                    // Close loading
                                    if (!mounted) return;
                                    nav.pop();
                                    nav.push(
                                      MaterialPageRoute(
                                        builder: (_) => ChatDetailScreen(
                                          chatId: chatId,
                                          otherUserId: _job.companyId,
                                          otherUserName: _employer!.name,
                                          otherUserPhoto:
                                              _employer!.profilePhoto,
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    // Close loading if still showing
                                    if (!context.mounted) return;
                                    nav.pop();
                                    AppDialog.error(
                                        context, 'Failed to start chat',
                                        detail: e.toString());
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
                  if (_isEmployer) ...[
                    Row(
                      key: _applicantsKey,
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
                            color:
                                const Color(0xFF2196F3).withValues(alpha: 0.1),
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
                    if (_applicantProfiles.isEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            vertical: 24, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_outline,
                                size: 40, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text(
                              'No applications yet',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Skilled users who apply will appear here',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ),
                    ..._applicantProfiles.map((profile) {
                      final applicantUser = _applicantUsers[profile.userId];
                      final status = _applicationState(profile.userId);
                      final isAccepted = status == 'accepted' ||
                          _job.selectedApplicant == profile.userId;
                      final isRejected = status == 'rejected';
                      final isPending = !isAccepted && !isRejected;
                      final anotherApplicantSelected =
                          _job.selectedApplicant != null &&
                              _job.selectedApplicant!.isNotEmpty &&
                              _job.selectedApplicant != profile.userId;
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
                                      builder: (context) =>
                                          ProfileScreen(userId: profile.userId),
                                    ),
                                  );
                                },
                                child: UniversalAvatar(
                                  avatarConfig: applicantUser?.avatarConfig,
                                  photoUrl: profile.profilePicture,
                                  fallbackName:
                                      applicantUser?.name ?? profile.name,
                                  radius: 25,
                                  animate: false,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ProfileScreen(
                                            userId: profile.userId),
                                      ),
                                    );
                                  },
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isAccepted
                                              ? Colors.green
                                                  .withValues(alpha: 0.12)
                                              : isRejected
                                                  ? Colors.red
                                                      .withValues(alpha: 0.12)
                                                  : Colors.orange
                                                      .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          isAccepted
                                              ? 'Accepted'
                                              : isRejected
                                                  ? 'Rejected'
                                                  : 'Pending',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: isAccepted
                                                ? Colors.green[700]
                                                : isRejected
                                                    ? Colors.red[700]
                                                    : Colors.orange[800],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  IconButton(
                                    onPressed: () async {
                                      if (applicantUser == null ||
                                          _currentUser == null) {
                                        return;
                                      }
                                      final nav = Navigator.of(context);

                                      try {
                                        final currentUser =
                                            FirebaseAuth.instance.currentUser;
                                        if (currentUser == null) return;

                                        if (!mounted) return;
                                        showDialog(
                                          context: context,
                                          barrierDismissible: false,
                                          builder: (_) => const Center(
                                              child:
                                                  CircularProgressIndicator()),
                                        );

                                        final chatId =
                                            await _chatService.getOrCreateChat(
                                          currentUser.uid,
                                          profile.userId,
                                          {
                                            'name': _currentUser!.name,
                                            'profilePhoto':
                                                _currentUser!.profilePhoto,
                                          },
                                          {
                                            'name': applicantUser.name,
                                            'profilePhoto':
                                                applicantUser.profilePhoto,
                                          },
                                        );

                                        if (!mounted) return;
                                        nav.pop();
                                        nav.push(
                                          MaterialPageRoute(
                                            builder: (_) => ChatDetailScreen(
                                              chatId: chatId,
                                              otherUserId: profile.userId,
                                              otherUserName: applicantUser.name,
                                              otherUserPhoto:
                                                  applicantUser.profilePhoto,
                                            ),
                                          ),
                                        );
                                      } catch (e) {
                                        if (!context.mounted) return;
                                        nav.pop();
                                        AppDialog.error(
                                            context, 'Failed to start chat',
                                            detail: e.toString());
                                      }
                                    },
                                    icon: const Icon(Icons.chat_bubble_outline),
                                    color: const Color(0xFF2196F3),
                                    tooltip: 'Contact',
                                  ),
                                  if (isPending && !anotherApplicantSelected)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextButton(
                                          onPressed: _processingApplicantId ==
                                                  profile.userId
                                              ? null
                                              : () => _rejectApplicant(
                                                  profile.userId),
                                          child: const Text(
                                            'Reject',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        ElevatedButton(
                                          onPressed: _processingApplicantId ==
                                                  profile.userId
                                              ? null
                                              : () => _acceptApplicant(
                                                  profile.userId),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF4CAF50),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 6),
                                            minimumSize: Size.zero,
                                          ),
                                          child: _processingApplicantId ==
                                                  profile.userId
                                              ? const SizedBox(
                                                  width: 12,
                                                  height: 12,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : const Text(
                                                  'Accept',
                                                  style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12),
                                                ),
                                        ),
                                      ],
                                    ),
                                ],
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
              color: Colors.black.withValues(alpha: 0.05),
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
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  CreateJobScreen(existingJob: _job),
                            ),
                          );
                          if (result == true && mounted) {
                            // Job data is streamed live — updates will
                            // arrive automatically via _jobSub.
                            setState(() {});
                          }
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
                          if (_applicantsKey.currentContext != null) {
                            Scrollable.ensureVisible(
                              _applicantsKey.currentContext!,
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeInOut,
                            );
                          }
                        },
                        icon: const Icon(Icons.people),
                        label: Text('${_job.applicants.length} Applicant${_job.applicants.length == 1 ? '' : 's'}'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2196F3),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                )
              : _hasApplied
                  ? ElevatedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.check_circle_outline,
                          color: Colors.white),
                      label: const Text(
                        'Application Submitted',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        disabledBackgroundColor: const Color(0xFF4CAF50),
                        disabledForegroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    )
                  : ElevatedButton(
                      onPressed:
                          _canApply ? (_isLoading ? null : _applyForJob) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        foregroundColor: Colors.white,
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
                              _job.status != 'open'
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
