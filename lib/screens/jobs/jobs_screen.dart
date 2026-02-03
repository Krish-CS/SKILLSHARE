import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shimmer/shimmer.dart';
import '../../models/job_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../utils/user_roles.dart';
import '../../widgets/job_card.dart';
import 'create_job_screen.dart';
import 'job_detail_screen.dart';
import '../../utils/app_constants.dart';

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  
  List<JobModel> _allJobs = [];
  List<JobModel> _filteredJobs = [];
  UserModel? _currentUser;
  bool _isLoading = true;
  
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
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        _currentUser = await _firestoreService.getUserById(userId);
      }
      
      _allJobs = await _firestoreService.getOpenJobs();
      _applyFilters();
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading jobs: $e')),
        );
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredJobs = _allJobs.where((job) {
        // Search filter
        final matchesSearch = _searchQuery.isEmpty ||
            job.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            job.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
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
    setState(() {
      _searchQuery = query;
    });
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

  bool get _canPostJobs {
    // Only companies and customers can post jobs
    return _currentUser?.role == AppConstants.roleCompany || 
           _currentUser?.role == UserRoles.customer;
  }
  
  bool get _canApplyToJobs {
    // Only skilled persons can apply to jobs
    return _currentUser?.role == UserRoles.skilledPerson;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<app_auth.AuthProvider>(context);
    final userRole = authProvider.userRole ?? UserRoles.customer;
    
    // Role-based title
    String screenTitle = 'Jobs';
    if (userRole == UserRoles.skilledPerson) {
      screenTitle = 'Find Jobs';
    } else if (userRole == UserRoles.company) {
      screenTitle = 'Post Jobs';
    } else {
      screenTitle = 'Hire & Jobs';
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(screenTitle, style: const TextStyle(color: Colors.white)),
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
          if (_canPostJobs)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateJobScreen(),
                  ),
                );
                if (result == true) {
                  _loadData();
                }
              },
            ),
        ],
      ),
      body: Column(
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
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search TextField
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
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Filters Row
                Row(
                  children: [
                    // Job Type Filter
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
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
                                value: type,
                                child: Text(type),
                              );
                            }).toList(),
                            onChanged: _onJobTypeSelected,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    
                    // Sort Filter
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
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
                                value: 'newest',
                                child: Text('Newest'),
                              ),
                              DropdownMenuItem(
                                value: 'deadline',
                                child: Text('Deadline'),
                              ),
                              DropdownMenuItem(
                                value: 'budget',
                                child: Text('Highest Budget'),
                              ),
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

          // Results Count
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
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          // Jobs List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
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
                              onTap: () => _navigateToJobDetail(_filteredJobs[index]),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
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
            _searchQuery.isNotEmpty || _selectedJobType != null && _selectedJobType != 'All'
                ? Icons.search_off
                : Icons.work_off,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty || _selectedJobType != null && _selectedJobType != 'All'
                ? 'No jobs found'
                : 'No jobs available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty || _selectedJobType != null && _selectedJobType != 'All'
                ? 'Try adjusting your filters'
                : 'Check back later for new opportunities!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          if (_canPostJobs && _searchQuery.isEmpty && (_selectedJobType == null || _selectedJobType == 'All'))
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateJobScreen(),
                    ),
                  );
                  if (result == true) {
                    _loadData();
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Post a Job'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _navigateToJobDetail(JobModel job) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JobDetailScreen(job: job),
      ),
    );
    
    // If job was updated/deleted, reload
    if (result == true) {
      _loadData();
    }
  }
}
