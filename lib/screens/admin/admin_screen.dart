import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/user_roles.dart';
import '../../widgets/universal_avatar.dart';
import '../../widgets/app_popup.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A237E), Color(0xFF7B1FA2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amberAccent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
            Tab(icon: Icon(Icons.people), text: 'Users'),
            Tab(icon: Icon(Icons.report), text: 'Reports'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _DashboardTab(firestoreService: _firestoreService),
          _UsersTab(firestoreService: _firestoreService),
          _ReportsTab(firestoreService: _firestoreService),
        ],
      ),
    );
  }
}

// ─────────────────────────── DASHBOARD TAB ───────────────────────────

class _DashboardTab extends StatelessWidget {
  final FirestoreService firestoreService;
  const _DashboardTab({required this.firestoreService});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        firestoreService.getAllUsers(limit: 500),
        firestoreService.getAllReports(limit: 500),
        firestoreService.getPendingVerifications(),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = (snapshot.data?[0] as List<UserModel>? ?? []);
        final reports =
            (snapshot.data?[1] as List<Map<String, dynamic>>? ?? []);
        final pendingVerifs = (snapshot.data?[2] as List? ?? []);

        final customers = users.where((u) => u.role == UserRoles.customer).length;
        final skilledPersons =
            users.where((u) => u.role == UserRoles.skilledPerson).length;
        final companies = users.where((u) => u.role == UserRoles.company).length;
        final suspended =
            users.where((u) => u.isSuspended == true).length;
        final pendingReports =
            reports.where((r) => r['status'] == 'pending').length;

        return RefreshIndicator(
          onRefresh: () async {
            (context as Element).markNeedsBuild();
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Platform Overview',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.4,
                children: [
                  _StatCard(
                      'Total Users', '${users.length}', Icons.people,
                      const Color(0xFF1565C0)),
                  _StatCard(
                      'Customers', '$customers', Icons.person,
                      const Color(0xFF2E7D32)),
                  _StatCard(
                      'Skilled Persons', '$skilledPersons', Icons.build,
                      const Color(0xFFE65100)),
                  _StatCard(
                      'Companies', '$companies', Icons.business,
                      const Color(0xFF4A148C)),
                  _StatCard(
                      'Suspended', '$suspended', Icons.block, Colors.red),
                  _StatCard(
                      'Pending Reports', '$pendingReports', Icons.flag,
                      Colors.orange),
                  _StatCard(
                      'Pending Verifications', '${pendingVerifs.length}',
                      Icons.verified_user, const Color(0xFF00695C)),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Quick Actions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _QuickActionTile(
                icon: Icons.pending_actions,
                title: 'Pending Verifications',
                subtitle: '${pendingVerifs.length} skilled user(s) pending',
                color: const Color(0xFF00695C),
                onTap: () {
                  // Navigate to users tab and filter pending
                },
              ),
              _QuickActionTile(
                icon: Icons.report_problem,
                title: 'Open Reports',
                subtitle: '$pendingReports report(s) need attention',
                color: Colors.orange,
                onTap: () {
                  // Navigate to reports tab
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard(this.title, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

// ─────────────────────────── USERS TAB ───────────────────────────

class _UsersTab extends StatefulWidget {
  final FirestoreService firestoreService;
  const _UsersTab({required this.firestoreService});

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  List<UserModel> _allUsers = [];
  List<UserModel> _filteredUsers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _roleFilter;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    _allUsers = await widget.firestoreService.getAllUsers(limit: 300);
    _applyFilter();
    if (mounted) setState(() => _isLoading = false);
  }

  void _applyFilter() {
    setState(() {
      _filteredUsers = _allUsers.where((u) {
        final matchesSearch = _searchQuery.isEmpty ||
            u.name.toLowerCase().contains(_searchQuery) ||
            u.email.toLowerCase().contains(_searchQuery);
        final matchesRole =
            _roleFilter == null || u.role == _roleFilter;
        return matchesSearch && matchesRole;
      }).toList();
    });
  }

  Future<void> _toggleSuspend(UserModel user) async {
    final currentAdminId = FirebaseAuth.instance.currentUser?.uid;
    if (currentAdminId == user.uid) {
      AppPopup.show(context,
          message: 'You cannot suspend your own account',
          type: PopupType.error);
      return;
    }

    final newSuspend = !(user.isSuspended ?? false);
    final action = newSuspend ? 'suspend' : 'reactivate';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${newSuspend ? 'Suspend' : 'Reactivate'} Account'),
        content: Text(
            'Are you sure you want to $action ${user.name}\'s account?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: newSuspend ? Colors.red : Colors.green),
            child: Text(newSuspend ? 'Suspend' : 'Reactivate',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await widget.firestoreService
          .suspendUser(user.uid, suspend: newSuspend);
      await _loadUsers();
      if (mounted) {
        AppPopup.show(
          context,
          message:
              'Account ${newSuspend ? 'suspended' : 'reactivated'} successfully',
          type: PopupType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AppPopup.show(context,
            message: 'Error: $e', type: PopupType.error);
      }
    }
  }

  Future<void> _deleteAccount(UserModel user) async {
    final currentAdminId = FirebaseAuth.instance.currentUser?.uid;
    if (currentAdminId == user.uid) {
      AppPopup.show(context,
          message: 'You cannot delete your own account',
          type: PopupType.error);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Account'),
        content: Text(
            'This will permanently delete ${user.name}\'s account and all associated data. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await widget.firestoreService.adminDeleteUserAccount(user.uid);
      await _loadUsers();
      if (mounted) {
        AppPopup.show(context,
            message: 'Account deleted successfully',
            type: PopupType.success);
      }
    } catch (e) {
      if (mounted) {
        AppPopup.show(context,
            message: 'Error: $e', type: PopupType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                onChanged: (v) {
                  _searchQuery = v.toLowerCase();
                  _applyFilter();
                },
                decoration: InputDecoration(
                  hintText: 'Search users...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip('All', null, _roleFilter,
                        (v) => setState(() { _roleFilter = v; _applyFilter(); })),
                    _filterChip('Customers', UserRoles.customer, _roleFilter,
                        (v) => setState(() { _roleFilter = v; _applyFilter(); })),
                    _filterChip('Skilled', UserRoles.skilledPerson, _roleFilter,
                        (v) => setState(() { _roleFilter = v; _applyFilter(); })),
                    _filterChip('Companies', UserRoles.company, _roleFilter,
                        (v) => setState(() { _roleFilter = v; _applyFilter(); })),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '${_filteredUsers.length} user(s) found',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadUsers,
            child: _filteredUsers.isEmpty
                ? const Center(child: Text('No users found'))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = _filteredUsers[index];
                      return _UserCard(
                        user: user,
                        onSuspend: () => _toggleSuspend(user),
                        onDelete: () => _deleteAccount(user),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

Widget _filterChip(String label, String? value, String? current,
    ValueChanged<String?> onSelected) {
  final selected = current == value;
  return GestureDetector(
    onTap: () => onSelected(value),
    child: Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF512DA8) : Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : Colors.grey[700],
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        ),
      ),
    ),
  );
}

class _UserCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback onSuspend;
  final VoidCallback onDelete;

  const _UserCard({
    required this.user,
    required this.onSuspend,
    required this.onDelete,
  });

  Color get _roleColor {
    switch (user.role) {
      case UserRoles.customer:
        return const Color(0xFF2E7D32);
      case UserRoles.skilledPerson:
        return const Color(0xFFE65100);
      case UserRoles.company:
        return const Color(0xFF4A148C);
      default:
        return Colors.grey;
    }
  }

  String get _roleLabel {
    return UserRoles.getDisplayName(user.role);
  }

  @override
  Widget build(BuildContext context) {
    final isSuspended = user.isSuspended ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            UniversalAvatar(
              avatarConfig: user.avatarConfig,
              photoUrl: user.profilePhoto,
              fallbackName: user.name,
              radius: 24,
              animate: false,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          user.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSuspended)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('SUSPENDED',
                              style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  Text(user.email,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _roleColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _roleLabel,
                      style: TextStyle(
                          color: _roleColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'suspend') onSuspend();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'suspend',
                  child: Row(
                    children: [
                      Icon(
                        isSuspended
                            ? Icons.check_circle_outline
                            : Icons.block,
                        color: isSuspended ? Colors.green : Colors.orange,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(isSuspended ? 'Reactivate' : 'Suspend'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red, size: 18),
                      SizedBox(width: 8),
                      Text('Delete Account',
                          style: TextStyle(color: Colors.red)),
                    ],
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

// ─────────────────────────── REPORTS TAB ───────────────────────────

class _ReportsTab extends StatefulWidget {
  final FirestoreService firestoreService;
  const _ReportsTab({required this.firestoreService});

  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> {
  List<Map<String, dynamic>> _reports = [];
  bool _isLoading = true;
  String _statusFilter = 'pending';

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    _reports = await widget.firestoreService.getAllReports(limit: 200);
    if (mounted) setState(() => _isLoading = false);
  }

  List<Map<String, dynamic>> get _filteredReports {
    if (_statusFilter == 'all') return _reports;
    return _reports
        .where((r) => r['status'] == _statusFilter)
        .toList();
  }

  Future<void> _resolveReport(
      Map<String, dynamic> report, String action) async {
    final adminId = FirebaseAuth.instance.currentUser?.uid;

    // If action is to suspend user, do both
    if (action == 'suspend_user') {
      final reportedUserId = report['reportedUserId'] as String?;
      if (reportedUserId != null) {
        try {
          await widget.firestoreService
              .suspendUser(reportedUserId, suspend: true);
        } catch (_) {}
      }
    }

    await widget.firestoreService.updateReportStatus(
      report['id'] as String,
      action == 'dismiss' ? 'dismissed' : 'resolved',
      adminId: adminId,
      adminNotes:
          action == 'suspend_user' ? 'User suspended based on report' : null,
    );
    await _loadReports();
    if (mounted) {
      AppPopup.show(context,
          message: 'Report updated successfully', type: PopupType.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('Pending', 'pending', _statusFilter,
                    (v) => setState(() => _statusFilter = v ?? 'pending')),
                _filterChip('Resolved', 'resolved', _statusFilter,
                    (v) => setState(() => _statusFilter = v ?? 'resolved')),
                _filterChip('Dismissed', 'dismissed', _statusFilter,
                    (v) => setState(() => _statusFilter = v ?? 'dismissed')),
                _filterChip('All', 'all', _statusFilter,
                    (v) => setState(() => _statusFilter = v ?? 'all')),
              ],
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadReports,
            child: _filteredReports.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 64, color: Colors.green[300]),
                        const SizedBox(height: 12),
                        const Text('No reports in this category',
                            style: TextStyle(fontSize: 16)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _filteredReports.length,
                    itemBuilder: (context, index) {
                      final report = _filteredReports[index];
                      return _ReportCard(
                        report: report,
                        onResolve: (action) => _resolveReport(report, action),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  final Map<String, dynamic> report;
  final ValueChanged<String> onResolve;

  const _ReportCard({required this.report, required this.onResolve});

  Color get _statusColor {
    switch (report['status']) {
      case 'pending':
        return Colors.orange;
      case 'resolved':
        return Colors.green;
      case 'dismissed':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPending = report['status'] == 'pending';
    final type = report['type'] ?? 'profile';
    final reason = report['reason'] ?? 'No reason provided';
    final details = report['details'] ?? '';
    final status = (report['status'] ?? 'pending').toString().toUpperCase();
    final createdAt = report['createdAt'];
    String timeStr = '';
    if (createdAt is Timestamp) {
      final dt = createdAt.toDate();
      timeStr =
          '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  type == 'chat' ? Icons.chat_bubble : Icons.person,
                  color: const Color(0xFF512DA8),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  type == 'chat' ? 'Chat Report' : 'Profile Report',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(status,
                      style: TextStyle(
                          color: _statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Reason: $reason',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(details,
                  style: TextStyle(color: Colors.grey[700], fontSize: 13)),
            ],
            if (timeStr.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Reported: $timeStr',
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey[500])),
            ],
            if (isPending) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => onResolve('dismiss'),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Dismiss'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[700]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => onResolve('suspend_user'),
                      icon:
                          const Icon(Icons.block, size: 16, color: Colors.white),
                      label: const Text('Suspend User',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => onResolve('resolve'),
                      icon: const Icon(Icons.check, size: 16, color: Colors.white),
                      label: const Text('Resolve',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
