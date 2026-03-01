import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shimmer/shimmer.dart';
import '../../models/job_model.dart';
import '../../models/user_model.dart';
import '../../models/company_profile.dart';
import '../../services/firestore_service.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../utils/user_roles.dart';
import '../../widgets/job_card.dart';
import 'create_job_screen.dart';
import 'job_detail_screen.dart';
import '../chat/chat_detail_screen.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_dialog.dart';
import '../profile/company_setup_screen.dart';
import 'company_applicants_tab.dart';

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();

  StreamSubscription<List<JobModel>>? _jobsSub;
  StreamSubscription<UserModel?>? _userSub;
  StreamSubscription<CompanyProfile?>? _companySub;
  StreamSubscription<List<JobModel>>? _appliedJobsSub;

  List<JobModel> _allJobs = [];
  List<JobModel> _filteredJobs = [];
  List<JobModel> _appliedJobs = [];
  UserModel? _currentUser;
  CompanyProfile? _companyProfile;
  bool _isLoading = true;
  String? _jobsScopeKey;
  String? _openingJobChatForJobId;

  String _searchQuery = '';
  String? _selectedJobType;
  String _sortBy = 'newest'; // newest, deadline, budget

  final List<String> _jobTypes = [
    'All',
    'Full-time',
    'Part-time',
    'Contract',
    'Freelance',
  ];

  @override
  void initState() {
    super.initState();
    _subscribeToData();
  }

  @override
  void dispose() {
    _jobsSub?.cancel();
    _userSub?.cancel();
    _companySub?.cancel();
    _appliedJobsSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _subscribeToData() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      _attachJobsStream();
      return;
    }

    _userSub = _firestoreService.streamUserModel(userId).listen((user) {
      if (!mounted) return;
      setState(() => _currentUser = user);

      // Subscribe to company profile only for company role.
      if (user?.role == AppConstants.roleCompany) {
        _companySub ??=
            _firestoreService.companyProfileStream(userId).listen((profile) {
          if (mounted) setState(() => _companyProfile = profile);
        });
      } else {
        _companySub?.cancel();
        _companySub = null;
        if (_companyProfile != null) {
          setState(() => _companyProfile = null);
        }
      }

      _attachJobsStream();
    });
  }

  void _attachJobsStream() {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isCompany = _currentUser?.role == AppConstants.roleCompany;
    final scopeKey = isCompany ? 'company:${currentUid ?? ''}' : 'open';
    if (_jobsScopeKey == scopeKey) return;
    _jobsScopeKey = scopeKey;

    _jobsSub?.cancel();

    final stream = isCompany && currentUid != null
        ? _firestoreService.streamCompanyJobs(currentUid)
        : _firestoreService.streamOpenJobs();

    _jobsSub = stream.listen(
      (jobs) {
        if (!mounted) return;
        _allJobs = jobs;
        _applyFilters();
        if (_isLoading) setState(() => _isLoading = false);
      },
      onError: (e) {
        debugPrint('Error streaming jobs: $e');
        if (mounted && _isLoading) setState(() => _isLoading = false);
      },
    );

    // For skilled persons: also stream the jobs they have applied to
    if (!isCompany && currentUid != null) {
      _appliedJobsSub?.cancel();
      _appliedJobsSub = _firestoreService
          .streamAppliedJobs(currentUid)
          .listen((jobs) {
        if (mounted) setState(() => _appliedJobs = jobs);
      });
    } else {
      _appliedJobsSub?.cancel();
      _appliedJobsSub = null;
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredJobs = _allJobs.where((job) {
        // Search filter
        final matchesSearch = _searchQuery.isEmpty ||
            job.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            job.description
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            job.requiredSkills.any((skill) =>
                skill.toLowerCase().contains(_searchQuery.toLowerCase()));

        // Job type filter
        final matchesJobType = _selectedJobType == null ||
            _selectedJobType == 'All' ||
            job.jobType.toLowerCase() == _selectedJobType!.toLowerCase();

        return matchesSearch && matchesJobType;
      }).toList();

      // Sort
      switch (_sortBy) {
        case 'deadline':
          _filteredJobs.sort((a, b) => a.deadline.compareTo(b.deadline));
          break;
        case 'budget':
          _filteredJobs.sort((a, b) {
            final aBudget = a.budgetMax ?? 0;
            final bBudget = b.budgetMax ?? 0;
            return bBudget.compareTo(aBudget);
          });
          break;
        case 'newest':
        default:
          _filteredJobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
    });
  }

  void _onSearchChanged(String query) {
    _searchQuery = query;
    _applyFilters();
  }

  void _onJobTypeSelected(String? jobType) {
    setState(() {
      _selectedJobType = jobType;
    });
    _applyFilters();
  }

  void _onSortChanged(String? sortBy) {
    if (sortBy != null) {
      setState(() {
        _sortBy = sortBy;
      });
      _applyFilters();
    }
  }

  Future<void> _openAcceptedJobChat(JobModel job) async {
    final skilledUserId = FirebaseAuth.instance.currentUser?.uid;
    if (skilledUserId == null) return;
    if (job.applicationStatus[skilledUserId] != 'accepted') {
      AppDialog.info(context, 'Job chat is enabled only after acceptance.');
      return;
    }
    if (_openingJobChatForJobId == job.id) return;

    setState(() => _openingJobChatForJobId = job.id);
    try {
      final companyUser = await _firestoreService.getUserById(job.companyId);
      final chatId = await _firestoreService.ensureJobApplicationChat(
        jobId: job.id,
        companyId: job.companyId,
        skilledUserId: skilledUserId,
        jobTitle: job.title,
        // Skilled person cannot write applicationChatIds on the job doc
        skipStatusCheck: false,
        updateJobRecord: false,
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(
            chatId: chatId,
            otherUserId: job.companyId,
            otherUserName:
                (companyUser?.name.trim().isNotEmpty == true)
                    ? companyUser!.name.trim()
                    : 'Company',
            otherUserPhoto: companyUser?.profilePhoto,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        AppDialog.error(context, 'Unable to open job chat', detail: e.toString());
      }
    } finally {
      if (mounted && _openingJobChatForJobId == job.id) {
        setState(() => _openingJobChatForJobId = null);
      }
    }
  }

  bool get _canPostJobs {
    // Only companies can post jobs
    return _currentUser?.role == AppConstants.roleCompany;
  }

  /// Returns true if the company is verified (or about to be — submitted).
  bool get _isCompanyVerified {
    if (_companyProfile == null) return false;
    return _companyProfile!.isVerified ||
        _companyProfile!.verificationStatus == 'submitted';
  }

  /// Shows a gate dialog if company is not verified; navigates to
  /// CreateJobScreen otherwise.
  Future<void> _navigateToPostJob() async {
    if (!_isCompanyVerified) {
      final goVerify = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.verified_user_outlined, color: Color(0xFF4527A0)),
              SizedBox(width: 8),
              Text('Verify Your Business'),
            ],
          ),
          content: const Text(
            'You need to verify your business details before you can post jobs or hire skilled persons.\n\nTap \'Verify Now\' to complete the quick verification process.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4527A0)),
              child: const Text('Verify Now',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (goVerify == true && mounted) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CompanySetupScreen(userId: uid)),
          );
        }
      }
      return;
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateJobScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_canPostJobs) return _buildCompanyView();
    return _buildDefaultScaffold();
  }

  // ─── Company view: two tabs ────────────────────────────────────────────────

  Widget _buildCompanyView() {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('Jobs', style: TextStyle(color: Colors.white)),
          ),
          titleSpacing: 18,
          toolbarHeight: 68,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2196F3), Color(0xFF00BCD4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              tooltip: 'Post Job',
              onPressed: _navigateToPostJob,
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: [
              Tab(icon: Icon(Icons.work_outline), text: 'Posted Jobs'),
              Tab(icon: Icon(Icons.people_outline), text: 'Applicants'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildJobsBody(),
            CompanyApplicantsTab(
              jobs: _allJobs,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultScaffold() {
    final authProvider = Provider.of<app_auth.AuthProvider>(context);
    final userRole = authProvider.userRole ?? UserRoles.customer;
    final isSkilledPerson = userRole == UserRoles.skilledPerson;

    if (!isSkilledPerson) {
      // Non-company, non-skilled (customer): plain view
      return Scaffold(
        appBar: AppBar(
          title: const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('Hire & Jobs', style: TextStyle(color: Colors.white)),
          ),
          titleSpacing: 18,
          toolbarHeight: 68,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2196F3), Color(0xFF00BCD4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          elevation: 0,
        ),
        body: _buildJobsBody(),
      );
    }

    // ── Skilled Person: tabbed view ──────────────────────────────────────────
    final acceptedCount =
        _appliedJobs.where((j) => j.applicationStatus[FirebaseAuth.instance.currentUser?.uid ?? ''] == 'accepted').length;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('Jobs', style: TextStyle(color: Colors.white)),
          ),
          titleSpacing: 18,
          toolbarHeight: 68,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2196F3), Color(0xFF00BCD4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          elevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(46),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.14)),
                ),
              ),
              child: TabBar(
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  const Tab(
                      icon: Icon(Icons.search, size: 18),
                      text: 'Browse Jobs'),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.work_history_outlined, size: 18),
                        const SizedBox(width: 6),
                        const Text('My Jobs'),
                        if (acceptedCount > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$acceptedCount',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2196F3),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _buildJobsBody(),
            _buildMyJobsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildMyJobsTab() {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (_appliedJobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.work_off_outlined, size: 72, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No applications yet',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Jobs you apply to will appear here.',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    // Group by status
    final accepted =
        _appliedJobs.where((j) => j.applicationStatus[userId] == 'accepted').toList();
    final pending = _appliedJobs
        .where((j) =>
            j.applicationStatus[userId] == 'pending' ||
            j.applicationStatus[userId] == null)
        .toList();
    final rejected =
        _appliedJobs.where((j) => j.applicationStatus[userId] == 'rejected').toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (accepted.isNotEmpty) ...[
          _sectionHeader(Icons.check_circle, 'Accepted / Offer Received',
              Colors.green, accepted.length),
          const SizedBox(height: 8),
          ...accepted.map((j) => _appliedJobCard(j, userId, 'accepted')),
          const SizedBox(height: 16),
        ],
        if (pending.isNotEmpty) ...[
          _sectionHeader(
              Icons.hourglass_top, 'Pending Review', Colors.orange, pending.length),
          const SizedBox(height: 8),
          ...pending.map((j) => _appliedJobCard(j, userId, 'pending')),
          const SizedBox(height: 16),
        ],
        if (rejected.isNotEmpty) ...[
          _sectionHeader(
              Icons.cancel_outlined, 'Not Selected', Colors.red, rejected.length),
          const SizedBox(height: 8),
          ...rejected.map((j) => _appliedJobCard(j, userId, 'rejected')),
        ],
      ],
    );
  }

  Widget _sectionHeader(
      IconData icon, String title, Color color, int count) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(title,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ),
      ],
    );
  }

  Widget _appliedJobCard(JobModel job, String userId, String status) {
    final Color statusColor = status == 'accepted'
        ? Colors.green
        : status == 'rejected'
            ? Colors.red
            : Colors.orange;
    final String statusText = status == 'accepted'
        ? 'Accepted'
        : status == 'rejected'
            ? 'Not Selected'
            : 'Pending';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => JobDetailScreen(job: job)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Slim accent bar
            Container(
              height: 4,
              color: statusColor,
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          job.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: statusColor.withValues(alpha: 0.4)),
                        ),
                        child: Text(statusText,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: statusColor)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _infoChip(Icons.category_outlined,
                          job.jobType.replaceAll('-', ' ')),
                      _infoChip(Icons.location_on_outlined, job.location),
                      if (job.shiftType != null)
                        _infoChip(Icons.schedule, job.shiftLabel),
                    ],
                  ),
                  if (status == 'accepted') ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.mark_email_unread_outlined,
                              size: 16, color: Colors.green),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Application accepted. Use Manage Chat to discuss this job and view offer letters.',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.green),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _openingJobChatForJobId == job.id
                            ? null
                            : () => _openAcceptedJobChat(job),
                        icon: _openingJobChatForJobId == job.id
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.chat_bubble_outline_rounded,
                                size: 16),
                        label: Text(
                          _openingJobChatForJobId == job.id
                              ? 'Opening...'
                              : 'Manage Chat',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1565C0),
                          side: BorderSide(
                            color: const Color(0xFF1565C0).withValues(alpha: 0.35),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey[700])),
          ],
        ),
      );


  // ─── Shared jobs list body ────────────────────────────────────────────────

  Widget _buildJobsBody() {
    return Column(
      children: [
        // Search and Filter Bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2196F3), Color(0xFF00BCD4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search jobs, skills...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedJobType ?? 'All',
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down),
                          items: _jobTypes.map((type) {
                            return DropdownMenuItem(
                                value: type, child: Text(type));
                          }).toList(),
                          onChanged: _onJobTypeSelected,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _sortBy,
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down),
                          items: const [
                            DropdownMenuItem(
                                value: 'newest', child: Text('Newest')),
                            DropdownMenuItem(
                                value: 'deadline',
                                child: Text('Deadline')),
                            DropdownMenuItem(
                                value: 'budget',
                                child: Text('Highest Budget')),
                          ],
                          onChanged: _onSortChanged,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        if (!_isLoading)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  '${_filteredJobs.length} ${_filteredJobs.length == 1 ? 'job' : 'jobs'} found',
                  style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {},
            color: const Color(0xFF2196F3),
            child: _isLoading
                ? _buildShimmerLoading()
                : _filteredJobs.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredJobs.length,
                        itemBuilder: (context, index) {
                          return JobCard(
                            job: _filteredJobs[index],
                            onTap: () =>
                                _navigateToJobDetail(_filteredJobs[index]),
                          );
                        },
                      ),
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Container(
              height: 180,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 20,
                    width: double.infinity,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 14,
                    width: 200,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        height: 24,
                        width: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        height: 24,
                        width: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    height: 12,
                    width: 150,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isNotEmpty ||
                    _selectedJobType != null && _selectedJobType != 'All'
                ? Icons.search_off
                : Icons.work_off,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ||
                    _selectedJobType != null && _selectedJobType != 'All'
                ? 'No jobs found'
                : _canPostJobs
                    ? 'No jobs posted yet'
                    : 'No jobs available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty ||
                    _selectedJobType != null && _selectedJobType != 'All'
                ? 'Try adjusting your filters'
                : _canPostJobs
                    ? 'Post your first job to start receiving applications.'
                    : 'Check back later for new opportunities!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          if (_canPostJobs &&
              _searchQuery.isEmpty &&
              (_selectedJobType == null || _selectedJobType == 'All'))
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2196F3), Color(0xFF00BCD4)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2196F3).withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _navigateToPostJob,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    'Post a Job',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _navigateToJobDetail(JobModel job) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JobDetailScreen(job: job),
      ),
    );

    // Stream auto-updates
  }
}
