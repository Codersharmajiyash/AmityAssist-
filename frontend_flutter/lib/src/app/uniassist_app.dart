import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
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
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
