import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../services/delivery_partner_admin_service.dart';
import '../../services/firestore_service.dart';
import '../splash_screen.dart';
import '../../utils/app_dialog.dart';
import '../../utils/user_roles.dart';
import '../../widgets/universal_avatar.dart';
import '../../widgets/app_popup.dart';
import 'admin_products_tab.dart';

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
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: 12,
        title: const Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Color(0x26FFFFFF),
              child: Icon(Icons.admin_panel_settings,
                  color: Colors.white, size: 20),
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Admin Control Center',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                Text(
                  'Manage users, products and reports',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F1B5B), Color(0xFF5E2CA5), Color(0xFF8E24AA)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 2,
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.label,
          indicator: const UnderlineTabIndicator(
            borderSide: BorderSide(color: Color(0xFFFFD54F), width: 3),
          ),
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFFCEBFE8),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
            Tab(icon: Icon(Icons.people), text: 'Users'),
            Tab(icon: Icon(Icons.inventory_2), text: 'Products'),
            Tab(icon: Icon(Icons.report), text: 'Reports'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _DashboardTab(firestoreService: _firestoreService),
          _TabGradientShell(
            colors: const [Color(0xFFEFF7FF), Color(0xFFF6F1FF)],
            child: _UsersTab(firestoreService: _firestoreService),
          ),
          _TabGradientShell(
            colors: const [Color(0xFFFFF4EE), Color(0xFFF8F2FF)],
            child: AdminProductsTab(firestoreService: _firestoreService),
          ),
          _TabGradientShell(
            colors: const [Color(0xFFFFF6EF), Color(0xFFFFF1F7)],
            child: _ReportsTab(firestoreService: _firestoreService),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Logout Admin',
      message: 'Do you want to logout from admin account?',
      confirmText: 'Logout',
      gradientColors: const [Color(0xFFD32F2F), Color(0xFFF57C00)],
      icon: Icons.logout,
    );
    if (confirmed != true) return;

    await FirebaseAuth.instance.signOut();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (route) => false,
    );
  }
}

class _TabGradientShell extends StatelessWidget {
  final Widget child;
  final List<Color> colors;

  const _TabGradientShell({required this.child, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: child,
    );
  }
}

// ─────────────────────────── DASHBOARD TAB ───────────────────────────

class _DashboardTab extends StatelessWidget {
  final FirestoreService firestoreService;
  const _DashboardTab({required this.firestoreService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AdminDashboardData>(
      stream: firestoreService.streamAdminDashboardData(limit: 500),
      builder: (context, dashboardSnapshot) {
        if (!dashboardSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final dashboard = dashboardSnapshot.data!;
        final users = dashboard.users;
        final reports = dashboard.reports;
        final pendingVerifs = dashboard.pendingVerifications;

        final customers = users.where((u) => u.role == UserRoles.customer).length;
        final skilledPersons =
            users.where((u) => u.role == UserRoles.skilledPerson).length;
        final companies = users.where((u) => u.role == UserRoles.company).length;
        final deliveryPartners =
            users.where((u) => u.role == UserRoles.deliveryPartner).length;
        final suspended = users.where((u) => u.isSuspended == true).length;
        final pendingReports =
            reports.where((r) => r['status'] == 'pending').length;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1B2A73), Color(0xFF512DA8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.insights_rounded,
                      color: Colors.white, size: 26),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Platform Overview',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _TopCounter(
                    label: 'Users',
                    value: '${users.length}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 1.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  _MetricListRow('Total Users', '${users.length}', Icons.people,
                      const Color(0xFF1565C0)),
                  _MetricListRow('Customers', '$customers', Icons.person,
                      const Color(0xFF2E7D32)),
                  _MetricListRow('Skilled Persons', '$skilledPersons', Icons.build,
                      const Color(0xFFE65100)),
                  _MetricListRow('Companies', '$companies', Icons.business,
                      const Color(0xFF4A148C)),
                  _MetricListRow('Delivery Partners', '$deliveryPartners',
                      Icons.local_shipping, const Color(0xFF00838F)),
                  _MetricListRow(
                      'Suspended', '$suspended', Icons.block, Colors.red),
                  _MetricListRow('Pending Reports', '$pendingReports', Icons.flag,
                      Colors.orange),
                  _MetricListRow('Pending Verifications',
                      '${pendingVerifs.length}', Icons.verified_user,
                      const Color(0xFF00695C)),
                ],
              ),
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
              icon: Icons.flag_outlined,
              title: 'Open Reports',
              subtitle: '$pendingReports report(s) need attention',
              color: Colors.orange,
              onTap: () {
                // Navigate to reports tab
              },
            ),
          ],
        );
      },
    );
  }
}

class _TopCounter extends StatelessWidget {
  final String label;
  final String value;

  const _TopCounter({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _MetricListRow extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricListRow(this.title, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
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
  final DeliveryPartnerAdminService _deliveryPartnerAdminService =
      DeliveryPartnerAdminService();
  List<UserModel> _allUsers = [];
  List<UserModel> _filteredUsers = [];
  bool _isLoading = true;
  bool _isBulkCreatingUsers = false;
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
        final matchesRole = _roleFilter == null || u.role == _roleFilter;
        return matchesSearch && matchesRole;
      }).toList();
    });
  }

  Future<void> _createDeliveryPartner() async {
    final formData = await showDialog<_DeliveryPartnerFormData>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => const _DeliveryPartnerDialog(),
    );

    if (formData == null) return;

    try {
      final created = await _deliveryPartnerAdminService.createDeliveryPartner(
        name: formData.name,
        email: formData.email,
        password: formData.password,
        phone: formData.phone,
      );
      await _loadUsers();
      if (!mounted) return;
      await AppDialog.success(
        context,
        'Delivery partner account created.\n\n'
        'Name: ${created.name}\n'
        'Email: ${created.email}\n'
        'Password: ${created.password}',
        title: 'Login Details Ready',
        buttonText: 'Close',
      );
    } catch (e) {
      if (!mounted) return;
      await AppDialog.error(
        context,
        'Could not create the delivery partner account.',
        detail: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> _createUserWithRole() async {
    final formData = await showDialog<_AdminUserFormData>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => const _AdminUserDialog(),
    );

    if (formData == null) return;

    try {
      final created = await _deliveryPartnerAdminService.createManagedUser(
        name: formData.name,
        email: formData.email,
        password: formData.password,
        role: formData.role,
        phone: formData.phone,
      );

      await _loadUsers();
      if (!mounted) return;

      await AppDialog.success(
        context,
        'User account created successfully.\n\n'
        'Name: ${created.name}\n'
        'Email: ${created.email}\n'
        'Role: ${UserRoles.getDisplayName(created.role)}\n'
        'Password: ${created.password}',
        title: 'User Created',
        buttonText: 'Close',
      );
    } catch (e) {
      if (!mounted) return;
      await AppDialog.error(
        context,
        'Could not create the user account.',
        detail: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> _bulkCreateUsersFromCsv() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      withData: true,
    );

    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.single;
    final bytes = file.bytes;

    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      AppPopup.show(
        context,
        message: 'Could not read CSV file bytes.',
        type: PopupType.error,
      );
      return;
    }

    setState(() => _isBulkCreatingUsers = true);

    int successCount = 0;
    final failures = <String>[];

    try {
      final raw = utf8.decode(bytes, allowMalformed: true);
      final rows = const CsvToListConverter(
        shouldParseNumbers: false,
        eol: '\n',
      ).convert(raw);

      if (rows.length < 2) {
        throw Exception('CSV needs a header and at least one data row.');
      }

      final headers = rows.first.map((e) => e.toString().trim().toLowerCase()).toList();
      int idx(String key) => headers.indexOf(key);

      final nameIdx = idx('name');
      final emailIdx = idx('email');
      final passwordIdx = idx('password');
      final roleIdx = idx('role');
      final phoneIdx = idx('phone');

      if (nameIdx == -1 || emailIdx == -1 || passwordIdx == -1 || roleIdx == -1) {
        throw Exception('CSV columns required: name,email,password,role (phone optional).');
      }

      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];
        final rowNumber = i + 1;

        String cell(int index) {
          if (index < 0 || index >= row.length) return '';
          return row[index].toString().trim();
        }

        final name = cell(nameIdx);
        final email = cell(emailIdx);
        final password = cell(passwordIdx);
        final role = cell(roleIdx);
        final phone = phoneIdx == -1 ? '' : cell(phoneIdx);

        if (name.isEmpty && email.isEmpty && password.isEmpty && role.isEmpty) {
          continue;
        }

        try {
          await _deliveryPartnerAdminService.createManagedUser(
            name: name,
            email: email,
            password: password,
            role: role,
            phone: phone,
          );
          successCount++;
        } catch (e) {
          failures.add('Row $rowNumber: ${e.toString().replaceFirst('Exception: ', '')}');
        }
      }

      await _loadUsers();
      if (!mounted) return;

      final summary = StringBuffer()
        ..writeln('Bulk user creation finished.')
        ..writeln()
        ..writeln('Success: $successCount')
        ..writeln('Failed: ${failures.length}');

      if (failures.isNotEmpty) {
        summary.writeln();
        summary.writeln('Errors (first 8):');
        for (final failure in failures.take(8)) {
          summary.writeln('- $failure');
        }
      }

      await AppDialog.info(
        context,
        summary.toString(),
        title: 'Bulk Users Result',
      );
    } catch (e) {
      if (!mounted) return;
      await AppDialog.error(
        context,
        'Bulk user import failed.',
        detail: e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() => _isBulkCreatingUsers = false);
      }
    }
  }

  Future<void> _editUser(UserModel user) async {
    final nameController = TextEditingController(text: user.name);
    final phoneController = TextEditingController(text: user.phone ?? '');
    var selectedRole = UserRoles.normalizeRole(user.role) ?? UserRoles.customer;
    var isActive = user.isActive;

    final updated = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) {
          return AlertDialog(
            title: const Text('Edit User'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'Phone'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: UserRoles.allRoles
                        .map(
                          (role) => DropdownMenuItem(
                            value: role,
                            child: Text(UserRoles.getDisplayName(role)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setLocalState(() => selectedRole = value);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: isActive,
                    title: const Text('Active account'),
                    onChanged: (value) => setLocalState(() => isActive = value),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    if (updated != true) {
      nameController.dispose();
      phoneController.dispose();
      return;
    }

    final updatedName = nameController.text.trim();
    final updatedPhone = phoneController.text.trim();

    nameController.dispose();
    phoneController.dispose();

    final currentAdminId = FirebaseAuth.instance.currentUser?.uid;
    if (currentAdminId == user.uid && selectedRole != UserRoles.admin) {
      if (!mounted) return;
      AppPopup.show(
        context,
        message: 'You cannot remove your own admin role.',
        type: PopupType.error,
      );
      return;
    }

    try {
      await widget.firestoreService.updateUserByAdmin(
        userId: user.uid,
        name: updatedName,
        phone: updatedPhone,
        role: selectedRole,
        isActive: isActive,
      );

      await _loadUsers();
      if (!mounted) return;
      AppPopup.show(
        context,
        message: 'User updated successfully',
        type: PopupType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppPopup.show(
        context,
        message: 'Update failed: $e',
        type: PopupType.error,
      );
    }
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
    final confirmed = await AppDialog.confirm(
      context,
      title: newSuspend ? 'Suspend Account' : 'Reactivate Account',
      message: 'Are you sure you want to $action ${user.name}\'s account?',
      confirmText: newSuspend ? 'Suspend' : 'Reactivate',
      gradientColors: newSuspend
          ? const [Color(0xFFD32F2F), Color(0xFFF57C00)]
          : const [Color(0xFF2E7D32), Color(0xFF00ACC1)],
      icon: newSuspend ? Icons.block : Icons.verified_user,
    );

    if (confirmed != true) return;

    try {
      await widget.firestoreService.suspendUser(user.uid, suspend: newSuspend);
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
        AppPopup.show(context, message: 'Error: $e', type: PopupType.error);
      }
    }
  }

  Future<void> _deleteAccount(UserModel user) async {
    final currentAdminId = FirebaseAuth.instance.currentUser?.uid;
    if (currentAdminId == user.uid) {
      AppPopup.show(context,
          message: 'You cannot delete your own account', type: PopupType.error);
      return;
    }

    final confirmed = await AppDialog.confirm(
      context,
      title: 'Delete Account',
      message:
          'This will permanently delete ${user.name}\'s account and all associated data. This cannot be undone.',
      confirmText: 'Delete',
      gradientColors: const [Color(0xFFD32F2F), Color(0xFFFF7043)],
      icon: Icons.delete_forever_rounded,
    );

    if (confirmed != true) return;

    try {
      await widget.firestoreService.adminDeleteUserAccount(user.uid);
      await _loadUsers();
      if (mounted) {
        AppPopup.show(context,
            message: 'Account deleted successfully', type: PopupType.success);
      }
    } catch (e) {
      if (mounted) {
        AppPopup.show(context, message: 'Error: $e', type: PopupType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1565C0), Color(0xFF5E35B1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            children: [
              Icon(Icons.groups_rounded, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Users Management',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                'Live',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Manage user profiles, roles, status and bulk user creation.',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _createUserWithRole,
                        icon: const Icon(Icons.person_add, size: 18),
                        label: const Text('Add User'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            _isBulkCreatingUsers ? null : _bulkCreateUsersFromCsv,
                        icon: _isBulkCreatingUsers
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.upload_file, size: 18),
                        label: const Text('Bulk CSV'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _createDeliveryPartner,
                        icon: const Icon(Icons.local_shipping, size: 18),
                        label: const Text('Add Delivery'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (v) {
                  _searchQuery = v.toLowerCase();
                  _applyFilter();
                },
                decoration: InputDecoration(
                  hintText: 'Search users...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip(
                        'All',
                        null,
                        _roleFilter,
                        const [Color(0xFF1565C0), Color(0xFF5E35B1)],
                        (v) => setState(() {
                              _roleFilter = v;
                              _applyFilter();
                            })),
                    _filterChip(
                        'Customers',
                        UserRoles.customer,
                        _roleFilter,
                        const [Color(0xFF1565C0), Color(0xFF5E35B1)],
                        (v) => setState(() {
                              _roleFilter = v;
                              _applyFilter();
                            })),
                    _filterChip(
                        'Skilled',
                        UserRoles.skilledPerson,
                        _roleFilter,
                        const [Color(0xFF1565C0), Color(0xFF5E35B1)],
                        (v) => setState(() {
                              _roleFilter = v;
                              _applyFilter();
                            })),
                    _filterChip(
                        'Companies',
                        UserRoles.company,
                        _roleFilter,
                        const [Color(0xFF1565C0), Color(0xFF5E35B1)],
                        (v) => setState(() {
                              _roleFilter = v;
                              _applyFilter();
                            })),
                    _filterChip(
                        'Delivery',
                        UserRoles.deliveryPartner,
                        _roleFilter,
                        const [Color(0xFF1565C0), Color(0xFF5E35B1)],
                        (v) => setState(() {
                              _roleFilter = v;
                              _applyFilter();
                            })),
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
                        onEdit: () => _editUser(user),
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

Widget _filterChip(
  String label,
  String? value,
  String? current,
  List<Color> gradient,
  ValueChanged<String?> onSelected,
) {
  final selected = current == value;
  return GestureDetector(
    onTap: () => onSelected(value),
    child: Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        gradient: selected
            ? LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: selected ? null : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? Colors.transparent : const Color(0xFFDADDE8),
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: gradient.first.withValues(alpha: 0.28),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
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
  final VoidCallback onEdit;
  final VoidCallback onSuspend;
  final VoidCallback onDelete;

  const _UserCard({
    required this.user,
    required this.onEdit,
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
      case UserRoles.deliveryPartner:
        return const Color(0xFF00838F);
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
    final isActive = user.isActive;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.green.withValues(alpha: 0.14)
                              : Colors.grey.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          isActive ? 'ACTIVE' : 'INACTIVE',
                          style: TextStyle(
                            color: isActive ? Colors.green[700] : Colors.grey[700],
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              color: Colors.white,
              elevation: 8,
              onSelected: (v) {
                if (v == 'edit') onEdit();
                if (v == 'suspend') onSuspend();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: Color(0xFF1565C0), size: 18),
                      SizedBox(width: 8),
                      Text('Edit User'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'suspend',
                  child: Row(
                    children: [
                      Icon(
                        isSuspended ? Icons.check_circle_outline : Icons.block,
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

class _AdminUserFormData {
  final String name;
  final String email;
  final String password;
  final String role;
  final String? phone;

  const _AdminUserFormData({
    required this.name,
    required this.email,
    required this.password,
    required this.role,
    this.phone,
  });
}

class _AdminUserDialog extends StatefulWidget {
  const _AdminUserDialog();

  @override
  State<_AdminUserDialog> createState() => _AdminUserDialogState();
}

class _AdminUserDialogState extends State<_AdminUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  String _role = UserRoles.customer;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create User Account'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Name required' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'Email required';
                  if (!text.contains('@')) return 'Enter valid email';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                  ),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.length < 6) return 'Min 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: UserRoles.allRoles
                    .map(
                      (role) => DropdownMenuItem(
                        value: role,
                        child: Text(UserRoles.getDisplayName(role)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _role = value);
                  }
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone (optional)'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(
              _AdminUserFormData(
                name: _nameController.text.trim(),
                email: _emailController.text.trim(),
                password: _passwordController.text.trim(),
                role: _role,
                phone: _phoneController.text.trim().isEmpty
                    ? null
                    : _phoneController.text.trim(),
              ),
            );
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _DeliveryPartnerFormData {
  final String name;
  final String email;
  final String password;
  final String? phone;

  const _DeliveryPartnerFormData({
    required this.name,
    required this.email,
    required this.password,
    this.phone,
  });
}

class _DeliveryPartnerDialog extends StatefulWidget {
  const _DeliveryPartnerDialog();

  @override
  State<_DeliveryPartnerDialog> createState() => _DeliveryPartnerDialogState();
}

class _DeliveryPartnerDialogState extends State<_DeliveryPartnerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFFF6F8FF)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x331565C0),
                blurRadius: 28,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0D47A1), Color(0xFF26A69A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Column(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Color(0x33FFFFFF),
                        child: Icon(Icons.local_shipping,
                            color: Colors.white, size: 28),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Add Delivery Partner',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Create login details for a new delivery account.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Partner Name',
                            prefixIcon: Icon(Icons.person_outline),
                            border: OutlineInputBorder(),
                          ),
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter the delivery partner name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Login Email',
                            prefixIcon: Icon(Icons.email_outlined),
                            border: OutlineInputBorder(),
                            helperText:
                                'Use a real inbox-backed email if you want password reset emails to work.',
                          ),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            if (email.isEmpty) {
                              return 'Enter the login email';
                            }
                            if (!email.contains('@') || !email.contains('.')) {
                              return 'Enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Temporary Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                            ),
                          ),
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            final password = value?.trim() ?? '';
                            if (password.length < 6) {
                              return 'Use at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number (Optional)',
                            prefixIcon: Icon(Icons.phone_outlined),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.done,
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF1565C0),
                                  side: const BorderSide(
                                      color: Color(0xFF1565C0)),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 13),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF0D47A1),
                                      Color(0xFF26A69A)
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: ElevatedButton(
                                  onPressed: () {
                                    if (!_formKey.currentState!.validate()) {
                                      return;
                                    }
                                    Navigator.of(context).pop(
                                      _DeliveryPartnerFormData(
                                        name: _nameController.text.trim(),
                                        email: _emailController.text.trim(),
                                        password:
                                            _passwordController.text.trim(),
                                        phone: _phoneController.text.trim(),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 13),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: const Text(
                                    'Create Account',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
    return _reports.where((r) => r['status'] == _statusFilter).toList();
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
        Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF8F00), Color(0xFFD81B60)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.report_gmailerrorred,
                  color: Colors.white, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Reports Center',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                '${_filteredReports.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('Pending', 'pending', _statusFilter,
                  const [Color(0xFFFF8F00), Color(0xFFD81B60)],
                    (v) => setState(() => _statusFilter = v ?? 'pending')),
                _filterChip('Resolved', 'resolved', _statusFilter,
                  const [Color(0xFFFF8F00), Color(0xFFD81B60)],
                    (v) => setState(() => _statusFilter = v ?? 'resolved')),
                _filterChip('Dismissed', 'dismissed', _statusFilter,
                  const [Color(0xFFFF8F00), Color(0xFFD81B60)],
                    (v) => setState(() => _statusFilter = v ?? 'dismissed')),
                _filterChip('All', 'all', _statusFilter,
                  const [Color(0xFFFF8F00), Color(0xFFD81B60)],
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1.5,
      color: Colors.white,
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
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
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
                      icon: const Icon(Icons.block,
                          size: 16, color: Colors.white),
                      label: const Text('Suspend User',
                          style: TextStyle(color: Colors.white)),
                      style:
                          ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => onResolve('resolve'),
                      icon: const Icon(Icons.check,
                          size: 16, color: Colors.white),
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
