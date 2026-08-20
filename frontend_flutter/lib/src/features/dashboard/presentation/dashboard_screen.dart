import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/kiosk_theme.dart';
import '../../student/application/student_provider.dart';
import '../../auth/application/auth_provider.dart';
import '../../notifications/application/notifications_provider.dart';

/// Theme mode provider for runtime dark/light toggle.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentAsync = ref.watch(studentProfileProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('UNIASSIST'),
        leading: const Padding(
          padding: EdgeInsets.all(10),
          child: Icon(Icons.school_rounded, size: 28),
        ),
        actions: [
          // Notification bell with badge
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, size: 28),
                onPressed: () => context.push('/notifications'),
              ),
              if (unreadCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.urgentRed,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          // Theme toggle
          IconButton(
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              size: 26,
            ),
            onPressed: () {
              final current = ref.read(themeModeProvider);
              ref.read(themeModeProvider.notifier).state =
                  current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 26),
            onPressed: () {
              ref.read(authProvider.notifier).logout();
              context.go('/');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Hero banner ────────────────────────────────
            _HeroBanner(studentAsync: studentAsync),
            const SizedBox(height: 8),

            // ── Quick stats ────────────────────────────────
            studentAsync.when(
              data: (s) => s == null
                  ? const SizedBox.shrink()
                  : _QuickStatsRow(student: s),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            // ── Navigation grid ────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.15,
                children: [
                  _NavCard(
                    title: 'Withdrawal',
                    icon: Icons.exit_to_app_rounded,
                    color: const Color(0xFFE53935),
                    onTap: () => context.push('/withdrawal'),
                  ),
                  _NavCard(
                    title: 'Academics',
                    icon: Icons.school_rounded,
                    color: AppColors.amityBlue,
                    onTap: () => context.push('/academics'),
                  ),
                  _NavCard(
                    title: 'Scholarships',
                    icon: Icons.emoji_events_rounded,
                    color: const Color(0xFFF9A825),
                    onTap: () => context.push('/scholarship'),
                  ),
                  _NavCard(
                    title: 'Grievance Desk',
                    icon: Icons.gavel_rounded,
                    color: const Color(0xFF7B1FA2),
                    onTap: () => context.push('/grievance'),
                  ),
                  _NavCard(
                    title: 'Documents',
                    icon: Icons.folder_rounded,
                    color: const Color(0xFF00897B),
                    onTap: () => context.push('/documents'),
                  ),
                  _NavCard(
                    title: 'Request Status',
                    icon: Icons.track_changes_rounded,
                    color: const Color(0xFF1565C0),
                    onTap: () => context.push('/request-status'),
                  ),
                  _NavCard(
                    title: 'Notices',
                    icon: Icons.campaign_rounded,
                    color: const Color(0xFFEF6C00),
                    onTap: () => context.push('/notices'),
                  ),
                  _NavCard(
                    title: 'AI Assistant',
                    icon: Icons.smart_toy_rounded,
                    color: AppColors.jade,
                    onTap: () => context.push('/chat'),
                  ),
                ]
                    .asMap()
                    .entries
                    .map(
                      (e) => e.value.animate().fadeIn(
                            delay: Duration(milliseconds: 80 * e.key),
                            duration: 400.ms,
                          ).slideY(begin: 0.15),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hero Banner ──────────────────────────────────────────────
class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.studentAsync});
  final AsyncValue<StudentProfile?> studentAsync;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.gradientStart, AppColors.gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      child: studentAsync.when(
        data: (student) => student == null
            ? const Text('Profile not found', style: TextStyle(color: Colors.white))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back,',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    student.name,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${student.course} • ${student.id}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
        error: (err, _) => Text(
          'Error: $err',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    ).animate().fadeIn(duration: 500.ms);
  }
}

// ── Quick Stats Row ──────────────────────────────────────────
class _QuickStatsRow extends StatelessWidget {
  const _QuickStatsRow({required this.student});
  final StudentProfile student;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _StatChip(
              label: 'CGPA',
              value: student.cgpa.toStringAsFixed(1),
              icon: Icons.trending_up_rounded,
              color: AppColors.jade,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatChip(
              label: 'Attendance',
              value: '${student.attendance}%',
              icon: Icons.calendar_today_rounded,
              color: AppColors.amityBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatChip(
              label: 'Fee Status',
              value: student.feeStatus,
              icon: Icons.account_balance_wallet_rounded,
              color: student.feeStatus == 'CLEAR'
                  ? AppColors.successGreen
                  : AppColors.urgentRed,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms, duration: 400.ms);
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Navigation Card ──────────────────────────────────────────
class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.08),
                color.withValues(alpha: 0.02),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 36, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
