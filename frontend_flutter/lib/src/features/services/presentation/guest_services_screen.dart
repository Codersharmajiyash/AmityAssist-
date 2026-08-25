import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/kiosk_theme.dart';
import '../../../core/widgets/uniassist_logo.dart';
import '../../kiosk/presentation/assistant_fab.dart';

class GuestServicesScreen extends StatelessWidget {
  const GuestServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 800;

    return Scaffold(
      floatingActionButton: const AssistantFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: AppColors.panel,
                border: Border(bottom: BorderSide(color: AppColors.line)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, size: 28),
                    onPressed: () => context.go('/'),
                  ),
                  const SizedBox(width: 16),
                  const UniAssistLogo(size: 34, showWordmark: true),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.tealSoft,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'PUBLIC SERVICES',
                      style: TextStyle(
                        color: AppColors.teal,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Grid Content
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Public Services',
                          style: TextStyle(
                            fontSize: isCompact ? 28 : 36,
                            fontWeight: FontWeight.w900,
                            color: AppColors.ink,
                          ),
                        ).animate().fadeIn().slideX(begin: -0.1),
                        const SizedBox(height: 8),
                        const Text(
                          'Select a category to find information, download forms, or learn about procedures.',
                          style: TextStyle(fontSize: 16, color: AppColors.muted, fontWeight: FontWeight.w500),
                        ).animate(delay: 100.ms).fadeIn(),
                        const SizedBox(height: 40),

                        GridView.count(
                          crossAxisCount: isCompact ? 2 : 4,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 24,
                          crossAxisSpacing: 24,
                          childAspectRatio: 1.1,
                          children: [
                            _CategoryCard(
                              title: 'Procedures',
                              icon: Icons.account_tree_outlined,
                              color: AppColors.primary,
                              delay: 200,
                              route: '/withdrawal',
                            ),
                            _CategoryCard(
                              title: 'Forms',
                              icon: Icons.description_outlined,
                              color: AppColors.teal,
                              delay: 250,
                              route: '/forms',
                            ),
                            _CategoryCard(
                              title: 'Documents',
                              icon: Icons.folder_open_rounded,
                              color: AppColors.gold,
                              delay: 300,
                              route: '/login', // Requires login
                            ),
                            _CategoryCard(
                              title: 'Notices',
                              icon: Icons.campaign_outlined,
                              color: AppColors.danger,
                              delay: 350,
                              route: '/notices',
                            ),
                            _CategoryCard(
                              title: 'FAQs',
                              icon: Icons.help_outline_rounded,
                              color: AppColors.primary,
                              delay: 400,
                              route: '/chat',
                            ),
                            _CategoryCard(
                              title: 'Scholarships',
                              icon: Icons.school_outlined,
                              color: AppColors.teal,
                              delay: 450,
                              route: '/scholarship',
                            ),
                            _CategoryCard(
                              title: 'Certificates',
                              icon: Icons.verified_outlined,
                              color: AppColors.gold,
                              delay: 500,
                              route: '/forms',
                            ),
                            _CategoryCard(
                              title: 'Hostel Services',
                              icon: Icons.apartment_rounded,
                              color: AppColors.danger,
                              delay: 550,
                              route: '/login',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.delay,
    required this.route,
  });

  final String title;
  final IconData icon;
  final Color color;
  final int delay;
  final String route;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (route == '/login') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Please login to access $title.')),
          );
        }
        context.go(route);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      ).animate(delay: delay.ms).fadeIn().scale(begin: const Offset(0.9, 0.9)),
    );
  }
}
