import 'package:flutter/material.dart';
import '../../models/job_model.dart';
import '../../models/user_model.dart';
import '../../models/skilled_user_profile.dart';
import '../../services/firestore_service.dart';
import '../../utils/app_dialog.dart';
import '../../widgets/universal_avatar.dart';
import '../profile/profile_screen.dart';
import 'job_detail_screen.dart';

class CompanyApplicantsTab extends StatefulWidget {
  final String companyId;
  final List<JobModel> jobs;

  const CompanyApplicantsTab({
    super.key,
    required this.companyId,
    required this.jobs,
  });

  @override
  State<CompanyApplicantsTab> createState() => _CompanyApplicantsTabState();
}

class _CompanyApplicantsTabState extends State<CompanyApplicantsTab> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = true;
  final Map<String, List<_ApplicantEntry>> _jobApplicants = {};
  String? _processingId;

  @override
  void initState() {
    super.initState();
    _loadApplicants();
  }

  @override
  void didUpdateWidget(CompanyApplicantsTab old) {
    super.didUpdateWidget(old);
    // Reload when job list changes (new job posted or applicant count changes)
    if (old.jobs != widget.jobs) {
      _loadApplicants();
    }
  }

  Future<void> _loadApplicants() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final map = <String, List<_ApplicantEntry>>{};

    for (final job in widget.jobs) {
      final entries = <_ApplicantEntry>[];
      for (final applicantId in job.applicants) {
        final results = await Future.wait([
          _firestoreService.getUserById(applicantId),
          _firestoreService.getSkilledUserProfile(applicantId),
        ]);
        final user = results[0] as UserModel?;
        var profile = results[1] as SkilledUserProfile?;

        // Fallback: create minimal profile from UserModel so we always show them
        if (profile == null && user != null) {
          profile = SkilledUserProfile(
            userId: applicantId,
            name: user.name,
            bio: '',
            skills: const [],
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        }

        entries.add(_ApplicantEntry(job: job, profile: profile, user: user));
      }
      map[job.id] = entries;
    }

    if (!mounted) return;
    setState(() {
      _jobApplicants.clear();
      _jobApplicants.addAll(map);
      _isLoading = false;
    });
  }

  Future<void> _accept(JobModel job, String applicantId) async {
    setState(() => _processingId = applicantId);
    try {
      await _firestoreService.acceptJobApplicant(
        jobId: job.id,
        applicantId: applicantId,
        companyId: widget.companyId,
      );
      if (mounted) AppDialog.success(context, 'Applicant accepted!');
    } catch (e) {
      if (mounted) AppDialog.error(context, 'Failed', detail: e.toString());
    } finally {
      if (mounted) setState(() => _processingId = null);
      await _loadApplicants();
    }
  }

  Future<void> _reject(JobModel job, String applicantId) async {
    setState(() => _processingId = applicantId);
    try {
      await _firestoreService.rejectJobApplicant(
        jobId: job.id,
        applicantId: applicantId,
        companyId: widget.companyId,
      );
      if (mounted) AppDialog.success(context, 'Applicant rejected.');
    } catch (e) {
      if (mounted) AppDialog.error(context, 'Failed', detail: e.toString());
    } finally {
      if (mounted) setState(() => _processingId = null);
      await _loadApplicants();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final jobsWithApplicants =
        widget.jobs.where((j) => j.applicants.isNotEmpty).toList();

    if (jobsWithApplicants.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 72, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No applications yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'When skilled users apply for your jobs, they appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadApplicants,
      color: const Color(0xFF2196F3),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: jobsWithApplicants.length,
        itemBuilder: (context, index) {
          final job = jobsWithApplicants[index];
          final entries = _jobApplicants[job.id] ?? [];
          return _buildJobSection(job, entries);
        },
      ),
    );
  }

  Widget _buildJobSection(JobModel job, List<_ApplicantEntry> entries) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Job header — tap to open job detail
        InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => JobDetailScreen(job: job)),
          ),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2196F3), Color(0xFF00BCD4)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.work_outline,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        '${job.applicants.length} applicant${job.applicants.length == 1 ? '' : 's'}  •  ${job.status.toUpperCase()}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white70),
              ],
            ),
          ),
        ),

        // Applicant cards
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 4),
            child: Text(
              'Loading applicant details…',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          )
        else
          ...entries.map((e) => _buildApplicantCard(job, e)),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildApplicantCard(JobModel job, _ApplicantEntry entry) {
    final status = job.applicationStatus[entry.userId] ?? 'pending';
    final isAccepted = status == 'accepted';
    final isRejected = status == 'rejected';
    final isPending = !isAccepted && !isRejected;
    final isProcessing = _processingId == entry.userId;

    // Disable accept/reject if another applicant is already selected
    final anotherSelected = job.selectedApplicant != null &&
        job.selectedApplicant!.isNotEmpty &&
        job.selectedApplicant != entry.userId;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        ProfileScreen(userId: entry.userId)),
              ),
              child: UniversalAvatar(
                avatarConfig: entry.user?.avatarConfig,
                photoUrl: entry.profile?.profilePicture,
                fallbackName: entry.displayName,
                radius: 24,
                animate: false,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          ProfileScreen(userId: entry.userId)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            entry.displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (entry.profile?.isVerified == true) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified,
                              color: Colors.blue, size: 16),
                        ],
                      ],
                    ),
                    if (entry.profile?.category != null)
                      Text(
                        entry.profile!.category!,
                        style: TextStyle(
                            color: Colors.grey[600], fontSize: 13),
                      ),
                    if ((entry.profile?.rating ?? 0) > 0) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.star,
                              color: Colors.amber, size: 13),
                          const SizedBox(width: 3),
                          Text(
                            '${entry.profile!.rating.toStringAsFixed(1)} (${entry.profile!.reviewCount})',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isAccepted
                            ? Colors.green.withValues(alpha: 0.12)
                            : isRejected
                                ? Colors.red.withValues(alpha: 0.12)
                                : Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
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
            if (isPending && !anotherSelected)
              isProcessing
                  ? const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 30,
                          child: TextButton(
                            onPressed: () => _reject(job, entry.userId),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8),
                              minimumSize: Size.zero,
                            ),
                            child: const Text(
                              'Reject',
                              style: TextStyle(
                                  color: Colors.red, fontSize: 12),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 30,
                          child: ElevatedButton(
                            onPressed: () => _accept(job, entry.userId),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4CAF50),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10),
                              minimumSize: Size.zero,
                              textStyle:
                                  const TextStyle(fontSize: 12),
                            ),
                            child: const Text('Accept'),
                          ),
                        ),
                      ],
                    ),
          ],
        ),
      ),
    );
  }
}

class _ApplicantEntry {
  final JobModel job;
  final SkilledUserProfile? profile;
  final UserModel? user;

  _ApplicantEntry({required this.job, this.profile, this.user});

  String get userId =>
      user?.uid ?? profile?.userId ?? '';

  String get displayName =>
      user?.name.trim().isNotEmpty == true
          ? user!.name.trim()
          : profile?.name?.trim().isNotEmpty == true
              ? profile!.name!.trim()
              : 'Unknown';
}
