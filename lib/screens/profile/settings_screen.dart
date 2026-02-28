import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../utils/app_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = true;
  bool _isSaving = false;

  // Notification settings
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _chatNotifications = true;
  bool _jobNotifications = true;

  // Privacy settings
  bool _profileVisible = true;
  bool _showEmail = false;
  bool _showPhone = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final settings = await _firestoreService.getUserSettings(uid);
      setState(() {
        _pushNotifications = settings['pushNotifications'] as bool? ?? true;
        _emailNotifications = settings['emailNotifications'] as bool? ?? true;
        _chatNotifications = settings['chatNotifications'] as bool? ?? true;
        _jobNotifications = settings['jobNotifications'] as bool? ?? true;
        _profileVisible = settings['profileVisible'] as bool? ?? true;
        _showEmail = settings['showEmail'] as bool? ?? false;
        _showPhone = settings['showPhone'] as bool? ?? false;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _isSaving = true);
    try {
      await _firestoreService.updateUserSettings(uid, {
        'pushNotifications': _pushNotifications,
        'emailNotifications': _emailNotifications,
        'chatNotifications': _chatNotifications,
        'jobNotifications': _jobNotifications,
        'profileVisible': _profileVisible,
        'showEmail': _showEmail,
        'showPhone': _showPhone,
      });
      if (mounted) {
        AppDialog.success(context, 'Settings saved!');
      }
    } catch (e) {
      if (mounted) {
        AppDialog.error(context, 'Error saving settings', detail: e.toString());
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF9C27B0), Color(0xFFE91E63)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _saveSettings,
              child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const _SectionHeader(title: 'Notifications'),
                _buildSwitch(
                  icon: Icons.notifications,
                  title: 'Push Notifications',
                  subtitle: 'Receive push notifications on this device',
                  value: _pushNotifications,
                  onChanged: (v) => setState(() => _pushNotifications = v),
                ),
                _buildSwitch(
                  icon: Icons.email,
                  title: 'Email Notifications',
                  subtitle: 'Receive updates via email',
                  value: _emailNotifications,
                  onChanged: (v) => setState(() => _emailNotifications = v),
                ),
                _buildSwitch(
                  icon: Icons.chat,
                  title: 'Chat Notifications',
                  subtitle: 'Notify when you receive new messages',
                  value: _chatNotifications,
                  onChanged: (v) => setState(() => _chatNotifications = v),
                ),
                _buildSwitch(
                  icon: Icons.work,
                  title: 'Job Notifications',
                  subtitle: 'Notify about new job postings & applications',
                  value: _jobNotifications,
                  onChanged: (v) => setState(() => _jobNotifications = v),
                ),
                const _SectionHeader(title: 'Privacy'),
                _buildSwitch(
                  icon: Icons.visibility,
                  title: 'Profile Visible',
                  subtitle:
                      'Make your profile discoverable to other users',
                  value: _profileVisible,
                  onChanged: (v) => setState(() => _profileVisible = v),
                ),
                _buildSwitch(
                  icon: Icons.alternate_email,
                  title: 'Show Email',
                  subtitle: 'Display email address on your public profile',
                  value: _showEmail,
                  onChanged: (v) => setState(() => _showEmail = v),
                ),
                _buildSwitch(
                  icon: Icons.phone,
                  title: 'Show Phone Number',
                  subtitle: 'Display phone number on your public profile',
                  value: _showPhone,
                  onChanged: (v) => setState(() => _showPhone = v),
                ),
                const _SectionHeader(title: 'Account'),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.lock_reset, color: Colors.red),
                  ),
                  title: const Text('Change Password'),
                  subtitle: const Text('Update your account password'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showChangePasswordDialog(),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4285F4).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.g_mobiledata, color: Color(0xFF4285F4), size: 28),
                  ),
                  title: const Text('Link Google Account'),
                  subtitle: const Text('Sign in with Google on this account'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _linkGoogleAccount(),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _buildSwitch({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF9C27B0).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color(0xFF9C27B0)),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12, color: Colors.grey)),
      value: value,
      activeColor: const Color(0xFF9C27B0),
      onChanged: onChanged,
    );
  }

  Future<void> _linkGoogleAccount() async {
    try {
      final authService = AuthService();
      await authService.linkGoogleToCurrentAccount();
      if (mounted) {
        AppDialog.success(context, 'Google account linked successfully!');
      }
    } catch (e) {
      if (mounted) {
        AppDialog.error(context, 'Could not link Google account', detail: e.toString());
      }
    }
  }

  void _showChangePasswordDialog() {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Enter your email address to receive a password reset link.'),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty) return;
              try {
                await FirebaseAuth.instance
                    .sendPasswordResetEmail(email: email);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                // ignore: use_build_context_synchronously
                AppDialog.success(context, 'Password reset email sent! Check your inbox.');
              } catch (e) {
                if (!ctx.mounted) return;
                // ignore: use_build_context_synchronously
                AppDialog.error(context, 'Error sending reset email', detail: e.toString());
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9C27B0)),
            child: const Text('Send Reset Email',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Color(0xFF9C27B0),
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
