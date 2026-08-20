import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/application/auth_provider.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/grievance/presentation/grievance_screen.dart';
import '../features/scholarship/presentation/scholarship_screen.dart';
import '../features/withdrawal/presentation/withdrawal_flow_screen.dart';
import '../features/withdrawal/presentation/withdrawal_home_screen.dart';
import '../features/dashboard/presentation/request_status_screen.dart';
import '../features/dashboard/presentation/document_center_screen.dart';
import '../features/dashboard/presentation/academics_screen.dart';
import '../features/staff/presentation/staff_dashboard_screen.dart';
import '../features/staff/presentation/staff_document_screen.dart';
import '../features/staff/presentation/staff_grievance_screen.dart';
import '../features/staff/presentation/staff_withdrawal_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/notices/presentation/notices_screen.dart';
import '../features/chat/presentation/chat_screen.dart';

class UniAssistApp extends ConsumerWidget {
  const UniAssistApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const _InactivityWrapper(
            child: DashboardScreen(),
          ),
        ),
        GoRoute(
          path: '/request-status',
          builder: (context, state) => const _InactivityWrapper(
            child: RequestStatusScreen(),
          ),
        ),
        GoRoute(
          path: '/documents',
          builder: (context, state) => const _InactivityWrapper(
            child: DocumentCenterScreen(),
          ),
        ),
        GoRoute(
          path: '/academics',
          builder: (context, state) => const _InactivityWrapper(
            child: AcademicsScreen(),
          ),
        ),
        GoRoute(
          path: '/scholarship',
          builder: (context, state) => const _InactivityWrapper(
            child: ScholarshipScreen(),
          ),
        ),
        GoRoute(
          path: '/grievance',
          builder: (context, state) => const _InactivityWrapper(
            child: GrievanceScreen(),
          ),
        ),
        GoRoute(
          path: '/withdrawal',
          builder: (context, state) => const _InactivityWrapper(
            child: WithdrawalHomeScreen(),
          ),
        ),
        GoRoute(
          path: '/withdrawal/flow',
          builder: (context, state) => const _InactivityWrapper(
            child: WithdrawalFlowScreen(),
          ),
        ),
        GoRoute(
          path: '/notifications',
          builder: (context, state) => const _InactivityWrapper(
            child: NotificationsScreen(),
          ),
        ),
        GoRoute(
          path: '/notices',
          builder: (context, state) => const _InactivityWrapper(
            child: NoticesScreen(),
          ),
        ),
        GoRoute(
          path: '/chat',
          builder: (context, state) => const _InactivityWrapper(
            child: ChatScreen(),
          ),
        ),
        GoRoute(
          path: '/staff',
          builder: (context, state) => const StaffDashboardScreen(),
        ),
        GoRoute(
          path: '/staff/withdrawals',
          builder: (context, state) => const StaffWithdrawalScreen(),
        ),
        GoRoute(
          path: '/staff/grievances',
          builder: (context, state) => const StaffGrievanceScreen(),
        ),
        GoRoute(
          path: '/staff/documents',
          builder: (context, state) => const StaffDocumentScreen(),
        ),
      ],
    );

    return MaterialApp.router(
      title: 'UNIASSIST',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Kiosk Inactivity Wrapper
// ─────────────────────────────────────────────────────────────
// Monitors user interaction and auto-logs out after 5 minutes
// of inactivity (kiosk safety).
// ─────────────────────────────────────────────────────────────

class _InactivityWrapper extends ConsumerStatefulWidget {
  const _InactivityWrapper({required this.child});
  final Widget child;

  @override
  ConsumerState<_InactivityWrapper> createState() => _InactivityWrapperState();
}

class _InactivityWrapperState extends ConsumerState<_InactivityWrapper> {
  Timer? _timer;
  static const _timeout = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    _resetTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _resetTimer() {
    _timer?.cancel();
    _timer = Timer(_timeout, _onInactivityTimeout);
  }

  void _onInactivityTimeout() {
    if (!mounted) return;
    ref.read(authProvider.notifier).logout();
    context.go('/');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Session expired due to inactivity.'),
        duration: Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _resetTimer(),
      onPointerMove: (_) => _resetTimer(),
      behavior: HitTestBehavior.translucent,
      child: widget.child,
    );
  }
}
