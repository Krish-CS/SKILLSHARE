import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_lock_provider.dart';
import '../services/app_lock_service.dart';

class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate>
    with WidgetsBindingObserver {
  final TextEditingController _secretCtrl = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppLockProvider>().initialize();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _secretCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    final provider = context.read<AppLockProvider>();
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      provider.lockNow();
      _secretCtrl.clear();
      _error = null;
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppLockProvider>(
      builder: (context, lock, _) {
        if (!lock.initialized || !lock.requiresUnlock) {
          return widget.child;
        }

        return Stack(
          children: [
            widget.child,
            Positioned.fill(
              child: Material(
                color: const Color(0xCC0F172A),
                child: SafeArea(
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 420),
                      margin: const EdgeInsets.symmetric(horizontal: 18),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 24,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: _buildUnlockPanel(context, lock),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUnlockPanel(BuildContext context, AppLockProvider lock) {
    final isPin = lock.type == AppLockService.typePin;
    final isPattern = lock.type == AppLockService.typePattern;
    final isBiometric = lock.type == AppLockService.typeBiometric;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Color(0xFFE0ECFF),
              child: Icon(Icons.lock_rounded, color: Color(0xFF1D4ED8)),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'App Locked',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          isPin
              ? 'Enter your PIN to continue.'
              : isPattern
                  ? 'Enter your pattern sequence (1-9) to continue.'
                  : 'Use your fingerprint/biometric to continue.',
          style: const TextStyle(color: Color(0xFF475569)),
        ),
        const SizedBox(height: 16),
        if (isPin || isPattern)
          TextField(
            controller: _secretCtrl,
            keyboardType: TextInputType.number,
            obscureText: true,
            decoration: InputDecoration(
              labelText: isPin ? 'PIN' : 'Pattern sequence',
              hintText: isPin ? '4-8 digits' : 'Example: 14789',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
          ),
        if (isBiometric)
          const Text(
            'Tap below to authenticate.',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () async {
              if (isPin || isPattern) {
                final ok = lock.tryUnlockWithSecret(_secretCtrl.text);
                if (!ok) {
                  setState(() {
                    _error = 'Invalid ${isPin ? 'PIN' : 'pattern'}';
                  });
                } else {
                  _secretCtrl.clear();
                  setState(() => _error = null);
                }
                return;
              }

              final ok = await lock.tryUnlockWithBiometric();
              if (!mounted) return;
              if (!ok) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                      content: Text('Biometric authentication failed')),
                );
              }
            },
            icon: Icon(
              isBiometric ? Icons.fingerprint_rounded : Icons.lock_open_rounded,
            ),
            label: Text(isBiometric ? 'Unlock with Biometrics' : 'Unlock'),
          ),
        ),
      ],
    );
  }
}
