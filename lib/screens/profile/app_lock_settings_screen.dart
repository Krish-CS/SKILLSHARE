import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_lock_provider.dart';
import '../../services/app_lock_service.dart';

class AppLockSettingsScreen extends StatefulWidget {
  const AppLockSettingsScreen({super.key});

  @override
  State<AppLockSettingsScreen> createState() => _AppLockSettingsScreenState();
}

class _AppLockSettingsScreenState extends State<AppLockSettingsScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final lock = context.watch<AppLockProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('App Lock')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Text(
              'Protect your app with PIN, pattern, or biometrics. The app locks when it goes to background and asks for unlock when you return.',
              style: TextStyle(color: Color(0xFF334155)),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile.adaptive(
            title: const Text('Enable App Lock'),
            subtitle: Text(lock.enabled ? _subtitleForType(lock.type) : 'Off'),
            value: lock.enabled,
            onChanged: _busy
                ? null
                : (enabled) async {
                    if (!enabled) {
                      setState(() => _busy = true);
                      await lock.disable();
                      if (mounted) setState(() => _busy = false);
                      return;
                    }
                    await _chooseAndEnable(context, lock);
                  },
          ),
          const Divider(height: 24),
          ListTile(
            enabled: lock.enabled && !_busy,
            leading: const Icon(Icons.pin_rounded),
            title: const Text('Use PIN Lock'),
            subtitle: const Text('4-8 numeric digits'),
            onTap: lock.enabled && !_busy ? () => _enablePin(lock) : null,
          ),
          ListTile(
            enabled: lock.enabled && !_busy,
            leading: const Icon(Icons.gesture_rounded),
            title: const Text('Use Pattern Lock'),
            subtitle: const Text('Sequence using digits 1-9'),
            onTap: lock.enabled && !_busy ? () => _enablePattern(lock) : null,
          ),
          ListTile(
            enabled: lock.enabled && !_busy,
            leading: const Icon(Icons.fingerprint_rounded),
            title: const Text('Use Fingerprint/Biometrics'),
            subtitle: const Text('Device biometrics required'),
            onTap:
                lock.enabled && !_busy ? () => _enableBiometric(lock) : null,
          ),
          if (lock.enabled)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Current mode: ${_subtitleForType(lock.type)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _subtitleForType(String type) {
    if (type == AppLockService.typePin) return 'PIN lock enabled';
    if (type == AppLockService.typePattern) return 'Pattern lock enabled';
    if (type == AppLockService.typeBiometric) return 'Biometric lock enabled';
    return 'Off';
  }

  Future<void> _chooseAndEnable(BuildContext context, AppLockProvider lock) async {
    final mode = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.pin_rounded),
                title: const Text('PIN Lock'),
                onTap: () => Navigator.pop(ctx, AppLockService.typePin),
              ),
              ListTile(
                leading: const Icon(Icons.gesture_rounded),
                title: const Text('Pattern Lock'),
                onTap: () => Navigator.pop(ctx, AppLockService.typePattern),
              ),
              ListTile(
                leading: const Icon(Icons.fingerprint_rounded),
                title: const Text('Biometric Lock'),
                onTap: () => Navigator.pop(ctx, AppLockService.typeBiometric),
              ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );

    if (!mounted || mode == null) return;
    if (mode == AppLockService.typePin) {
      await _enablePin(lock);
      return;
    }
    if (mode == AppLockService.typePattern) {
      await _enablePattern(lock);
      return;
    }
    await _enableBiometric(lock);
  }

  Future<void> _enablePin(AppLockProvider lock) async {
    final pin = await _askSecret(
      title: 'Set PIN',
      hint: 'Enter 4-8 digits',
      validator: (value) {
        final valid = RegExp(r'^\d{4,8}$').hasMatch(value);
        return valid ? null : 'PIN must be 4-8 digits';
      },
    );
    if (pin == null || !mounted) return;

    setState(() => _busy = true);
    await lock.enablePin(pin);
    if (mounted) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN lock enabled')),
      );
    }
  }

  Future<void> _enablePattern(AppLockProvider lock) async {
    final pattern = await _askSecret(
      title: 'Set Pattern Sequence',
      hint: 'Example: 14789',
      validator: (value) {
        final valid = RegExp(r'^[1-9]{4,9}$').hasMatch(value);
        return valid ? null : 'Pattern must be 4-9 digits using numbers 1-9';
      },
    );
    if (pattern == null || !mounted) return;

    setState(() => _busy = true);
    await lock.enablePattern(pattern);
    if (mounted) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pattern lock enabled')),
      );
    }
  }

  Future<void> _enableBiometric(AppLockProvider lock) async {
    setState(() => _busy = true);
    final ok = await lock.enableBiometric();
    if (!mounted) return;
    setState(() => _busy = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Biometric lock enabled'
              : 'Biometric lock unavailable or verification failed',
        ),
      ),
    );
  }

  Future<String?> _askSecret({
    required String title,
    required String hint,
    required String? Function(String value) validator,
  }) async {
    final ctrl = TextEditingController();
    String? error;

    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(title),
            content: TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              obscureText: true,
              decoration: InputDecoration(hintText: hint, errorText: error),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final first = ctrl.text.trim();
                  final firstError = validator(first);
                  if (firstError != null) {
                    setDialogState(() => error = firstError);
                    return;
                  }
                  Navigator.pop(ctx, first);
                },
                child: const Text('Continue'),
              ),
            ],
          );
        },
      ),
    );

    if (value == null || !mounted) return null;

    final confirm = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final confirmCtrl = TextEditingController();
        String? confirmError;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Confirm'),
              content: TextField(
                controller: confirmCtrl,
                keyboardType: TextInputType.number,
                obscureText: true,
                decoration:
                    InputDecoration(hintText: hint, errorText: confirmError),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final second = confirmCtrl.text.trim();
                    if (second != value) {
                      setDialogState(() => confirmError = 'Values do not match');
                      return;
                    }
                    Navigator.pop(ctx, second);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    return confirm;
  }
}
