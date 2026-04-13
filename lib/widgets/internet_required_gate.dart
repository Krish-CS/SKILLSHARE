import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../services/internet_required_service.dart';

class InternetRequiredGate extends StatefulWidget {
  const InternetRequiredGate({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<InternetRequiredGate> createState() => _InternetRequiredGateState();
}

class _InternetRequiredGateState extends State<InternetRequiredGate>
    with WidgetsBindingObserver {
  final Connectivity _connectivity = Connectivity();
  final InternetRequiredService _internetRequiredService =
      InternetRequiredService();

  StreamSubscription<dynamic>? _connectivitySubscription;
  bool _hasInternet = true;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscribeToConnectivity();
    unawaited(_refreshConnectionState());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshConnectionState());
    }
  }

  void _subscribeToConnectivity() {
    final dynamic connectivityStream = _connectivity.onConnectivityChanged;
    _connectivitySubscription = connectivityStream.listen((dynamic event) {
      unawaited(_refreshConnectionState(event: event));
    });
  }

  List<ConnectivityResult> _normalizeConnectivityResults(dynamic event) {
    if (event is ConnectivityResult) {
      return <ConnectivityResult>[event];
    }
    if (event is List<ConnectivityResult>) {
      return event;
    }
    if (event is List) {
      return event.whereType<ConnectivityResult>().toList();
    }
    return const <ConnectivityResult>[];
  }

  Future<void> _refreshConnectionState({dynamic event}) async {
    if (!mounted) return;
    setState(() => _isChecking = true);

    final results = event == null
        ? _normalizeConnectivityResults(await _connectivity.checkConnectivity())
        : _normalizeConnectivityResults(event);

    final hasTransport =
        results.any((result) => result != ConnectivityResult.none);
    final hasInternet = hasTransport
        ? await _internetRequiredService.hasInternetAccess()
        : false;

    if (!mounted) return;
    setState(() {
      _hasInternet = hasInternet;
      _isChecking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (!_hasInternet)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.45),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE3F2FD),
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: const Icon(
                                Icons.wifi_off_rounded,
                                size: 36,
                                color: Color(0xFF1565C0),
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'Internet Connection Required',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'This app needs an active internet connection. We will keep checking automatically and continue as soon as you are back online.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: Color(0xFF616161),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF8E1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFFFB300)
                                      .withValues(alpha: 0.45),
                                ),
                              ),
                              child: Row(
                                children: [
                                  if (_isChecking)
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  else
                                    const Icon(
                                      Icons.portable_wifi_off_rounded,
                                      color: Color(0xFFE65100),
                                    ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _isChecking
                                          ? 'Checking connection...'
                                          : 'No working internet detected yet.',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF5D4037),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isChecking
                                    ? null
                                    : () =>
                                        unawaited(_refreshConnectionState()),
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Retry Now'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1565C0),
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
