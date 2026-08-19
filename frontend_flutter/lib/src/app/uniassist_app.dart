import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../core/session/session_manager.dart';

import '../features/auth/presentation/login_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/dashboard/presentation/kiosk_dashboard.dart';
import '../features/grievance/presentation/grievance_screen.dart';
import '../features/scholarship/presentation/scholarship_screen.dart';
import '../features/withdrawal/presentation/withdrawal_flow_screen.dart';
import '../features/withdrawal/presentation/withdrawal_home_screen.dart';
import '../features/dashboard/presentation/request_status_screen.dart';
import '../features/dashboard/presentation/document_center_screen.dart';
import '../features/dashboard/presentation/academics_screen.dart';

import '../features/staff/presentation/staff_dashboard_screen.dart';
import '../features/staff/presentation/staff_desktop_layout.dart';
import '../features/staff/presentation/clearance_queue_screen.dart';
import '../features/staff/presentation/document_approvals_screen.dart';
import '../features/staff/presentation/grievance_response_screen.dart';

class UniAssistApp extends StatelessWidget {
  const UniAssistApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/kiosk',
          builder: (context, state) => const KioskDashboard(),
        ),
        GoRoute(
          path: '/request-status',
          builder: (context, state) => const RequestStatusScreen(),
        ),
        GoRoute(
          path: '/documents',
          builder: (context, state) => const DocumentCenterScreen(),
        ),
        GoRoute(
          path: '/academics',
          builder: (context, state) => const AcademicsScreen(),
        ),
        GoRoute(
          path: '/scholarship',
          builder: (context, state) => const ScholarshipScreen(),
        ),
        GoRoute(
          path: '/grievance',
          builder: (context, state) => const GrievanceScreen(),
        ),
        GoRoute(
          path: '/withdrawal',
          builder: (context, state) => const WithdrawalHomeScreen(),
        ),
        GoRoute(
          path: '/withdrawal/flow',
          builder: (context, state) => const WithdrawalFlowScreen(),
        ),
        
        // Staff Portal Routes wrapped in Desktop Layout
        ShellRoute(
          builder: (context, state, child) {
            return StaffDesktopLayout(child: child);
          },
          routes: [
            GoRoute(
              path: '/staff',
              builder: (context, state) => const StaffDashboardScreen(),
            ),
            GoRoute(
              path: '/staff/clearance',
              builder: (context, state) => const ClearanceQueueScreen(),
            ),
            GoRoute(
              path: '/staff/documents',
              builder: (context, state) => const DocumentApprovalsScreen(),
            ),
            GoRoute(
              path: '/staff/grievances',
              builder: (context, state) => const GrievanceResponseScreen(),
            ),
          ],
        ),
      ],
    );

    return SessionManager(
      timeout: const Duration(minutes: 2),
      onTimeout: () => router.go('/'),
      child: MaterialApp.router(
        title: 'UNIASSIST',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
