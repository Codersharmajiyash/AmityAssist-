// ==============================================================================
// UniAssist — 45-Second Ambient Kiosk Inactivity Privacy Guard
// Lead Architect: Abhishek Shrivastava
// Phase 5: Multi-Platform Deployment & Zero-Touch Kiosk Updates
// ==============================================================================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/application/auth_provider.dart';

class KioskInactivityWrapper extends ConsumerStatefulWidget {
  final Widget child;
  const KioskInactivityWrapper({super.key, required this.child});

  @override
  ConsumerState<KioskInactivityWrapper> createState() => _KioskInactivityWrapperState();
}

class _KioskInactivityWrapperState extends ConsumerState<KioskInactivityWrapper> {
  static const int _idleTimeoutSeconds = 45;
  static const int _warningCountdownSeconds = 10;
  Timer? _idleTimer;
  Timer? _countdownTimer;
  int _remainingSeconds = _warningCountdownSeconds;
  bool _isWarningVisible = false;

  @override
  void initState() {
    super.initState();
    _resetIdleTimer();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    if (_isWarningVisible) {
      _dismissWarning();
    }
    // Only arm timer if a student is actively logged in
    final isAuthenticated = ref.read(authProvider).isAuthenticated;
    if (isAuthenticated) {
      _idleTimer = Timer(const Duration(seconds: _idleTimeoutSeconds), _showWarningModal);
    }
  }

  void _showWarningModal() {
    setState(() {
      _isWarningVisible = true;
      _remainingSeconds = _warningCountdownSeconds;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 1) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
        _purgeSessionAndLogout();
      }
    });
  }

  void _dismissWarning() {
    _countdownTimer?.cancel();
    setState(() => _isWarningVisible = false);
    _resetIdleTimer();
  }

  void _purgeSessionAndLogout() {
    _countdownTimer?.cancel();
    setState(() => _isWarningVisible = false);
    // 1. Wipe JWT tokens and student profile from memory
    ref.read(authProvider.notifier).logout();
    // 2. Return to Kiosk Welcome Screen
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session reset due to inactivity for privacy protection.'),
          backgroundColor: Colors.blueGrey,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetIdleTimer(),
      child: Stack(
        children: [
          widget.child,
          if (_isWarningVisible)
            Container(
              color: Colors.black.withOpacity(0.75),
              child: Center(
                child: Container(
                  width: 420,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20)],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_outlined, color: Colors.orange, size: 54),
                      const SizedBox(height: 16),
                      const Text(
                        'Are you still there?',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'For your security on public kiosks, this session will reset automatically.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '$_remainingSeconds',
                        style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.orange),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _purgeSessionAndLogout,
                              child: const Text('Log Out Now'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: _dismissWarning,
                              child: const Text('Continue'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

