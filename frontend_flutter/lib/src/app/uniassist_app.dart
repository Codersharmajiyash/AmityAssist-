import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/withdrawal/presentation/withdrawal_home_screen.dart';

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
          path: '/withdrawal',
          builder: (context, state) => const WithdrawalHomeScreen(),
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
