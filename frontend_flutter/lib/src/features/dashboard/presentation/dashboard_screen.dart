import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../student/application/student_provider.dart';
import '../../auth/application/auth_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentAsync = ref.watch(studentProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authProvider.notifier).logout();
              context.go('/');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            color: Theme.of(context).colorScheme.primaryContainer,
            width: double.infinity,
            child: studentAsync.when(
              data: (student) => student == null
                  ? const Text('Student profile not found')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Welcome, ${student.name}',
                            style: Theme.of(context).textTheme.headlineMedium),
                        Text('${student.course} • CGPA: ${student.cgpa}',
                            style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Text('Error loading profile: $err'),
            ),
          ),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(16),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _DashboardCard(
                  title: 'Withdrawal Services',
                  icon: Icons.exit_to_app,
                  onTap: () => context.go('/withdrawal'),
                ),
                _DashboardCard(
                  title: 'Academics',
                  icon: Icons.school,
                  onTap: () => context.go('/academics'),
                ),
                _DashboardCard(
                  title: 'Scholarships',
                  icon: Icons.monetization_on,
                  onTap: () => context.go('/scholarship'),
                ),
                _DashboardCard(
                  title: 'Grievance Desk',
                  icon: Icons.gavel,
                  onTap: () => context.go('/grievance'),
                ),
                _DashboardCard(
                  title: 'Request Status',
                  icon: Icons.track_changes,
                  onTap: () => context.go('/request-status'),
                ),
                _DashboardCard(
                  title: 'Document Center',
                  icon: Icons.folder,
                  onTap: () => context.go('/documents'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
