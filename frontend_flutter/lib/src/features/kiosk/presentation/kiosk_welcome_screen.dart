import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/kiosk_theme.dart';
import '../../../core/widgets/uniassist_logo.dart';
import '../../chat/presentation/digital_counselor_modal.dart';

class KioskWelcomeScreen extends ConsumerStatefulWidget {
  const KioskWelcomeScreen({super.key});

  @override
  ConsumerState<KioskWelcomeScreen> createState() => _KioskWelcomeScreenState();
}

class _KioskWelcomeScreenState extends ConsumerState<KioskWelcomeScreen> {
  late Timer _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 960;
            return Column(
              children: [
                // Top Kiosk Header Bar
                _KioskTopBar(
                  timeStr: _formatTime(_now),
                  dateStr: _formatDate(_now),
                  onTalkToAssistant: () => showDigitalCounselor(context),
                ),

                // Main Content Body
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1160),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Hero Brand Banner
                            _HeroHeader(wide: wide)
                                .animate()
                                .fadeIn(duration: 400.ms)
                                .slideY(begin: -0.04),

                            const SizedBox(height: 32),

                            // Dual Pathway Cards (Guest Services vs Login)
                            if (wide)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _PathwayCard(
                                      title: 'University Services',
                                      tag: 'GUEST MODE • NO LOGIN REQUIRED',
                                      tagColor: AppColors.teal,
                                      tagBg: AppColors.tealSoft,
                                      icon: Icons.account_balance_rounded,
                                      iconColor: AppColors.teal,
                                      description:
                                          'For visitors, parents, prospective students, and students needing instant procedure info or forms.',
                                      bulletPoints: const [
                                        'Withdrawal Process (Checklist, timeline, departments)',
                                        'Scholarships & Financial Aid criteria',
                                        'Certificates & Migration Transcripts',
                                        'Hostel & Campus Facilities policies',
                                        'Academic procedures, Notices & FAQs',
                                        '30+ Official University Form Downloads',
                                      ],
                                      actionLabel: 'Explore Services as Guest',
                                      actionIcon: Icons.arrow_forward_rounded,
                                      isPrimary: true,
                                      onTap: () => context.go('/services'),
                                    ).animate().fadeIn(delay: 100.ms, duration: 400.ms).slideX(begin: -0.02),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    child: _PathwayCard(
                                      title: 'Student / Staff Login',
                                      tag: 'SECURE AUTHENTICATED PORTAL',
                                      tagColor: AppColors.primary,
                                      tagBg: AppColors.primarySoft,
                                      icon: Icons.badge_outlined,
                                      iconColor: AppColors.primary,
                                      description:
                                          'Access your personalized university dashboard, track active requests, file grievances, and view records.',
                                      bulletPoints: const [
                                        'My Requests & Live Workflow Tracking',
                                        'Personalized Academic Progress & Backpapers',
                                        'Document Center (OCR Verification)',
                                        'Grievance Redressal Desk & Timeline',
                                        'Staff Approvals & Department Triage',
                                      ],
                                      actionLabel: 'Sign In (Student or Staff)',
                                      actionIcon: Icons.login_rounded,
                                      isPrimary: false,
                                      onTap: () => context.go('/login'),
                                    ).animate().fadeIn(delay: 180.ms, duration: 400.ms).slideX(begin: 0.02),
                                  ),
                                ],
                              )
                            else ...[
                              _PathwayCard(
                                title: 'University Services',
                                tag: 'GUEST MODE • NO LOGIN REQUIRED',
                                tagColor: AppColors.teal,
                                tagBg: AppColors.tealSoft,
                                icon: Icons.account_balance_rounded,
                                iconColor: AppColors.teal,
                                description:
                                    'For visitors, parents, prospective students, and students needing instant procedure info or forms.',
                                bulletPoints: const [
                                  'Withdrawal Process (Checklist & timeline)',
                                  'Scholarships, Certificates & Hostel Rules',
                                  'University Notices, FAQs & Document Downloads',
                                ],
                                actionLabel: 'Explore Services as Guest',
                                actionIcon: Icons.arrow_forward_rounded,
                                isPrimary: true,
                                onTap: () => context.go('/services'),
                              ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
                              const SizedBox(height: 20),
                              _PathwayCard(
                                title: 'Student / Staff Login',
                                tag: 'SECURE AUTHENTICATED PORTAL',
                                tagColor: AppColors.primary,
                                tagBg: AppColors.primarySoft,
                                icon: Icons.badge_outlined,
                                iconColor: AppColors.primary,
                                description:
                                    'Access your personalized dashboard, track active requests, and file grievances.',
                                bulletPoints: const [
                                  'Track My Requests & Clearances',
                                  'Academics, Documents & Grievance Desk',
                                  'Staff Portal & Approvals',
                                ],
                                actionLabel: 'Sign In (Student or Staff)',
                                actionIcon: Icons.login_rounded,
                                isPrimary: false,
                                onTap: () => context.go('/login'),
                              ).animate().fadeIn(delay: 180.ms, duration: 400.ms),
                            ],

                            const SizedBox(height: 28),

                            // Digital Counselor AI Banner Card
                            _AssistantBanner(
                              onTalk: () => showDigitalCounselor(context),
                              onAskWithdrawal: () => showDigitalCounselor(context, initialQuery: 'I want withdrawal'),
                            ).animate().fadeIn(delay: 250.ms, duration: 400.ms).slideY(begin: 0.03),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Kiosk Footer Info Bar
                const _KioskBottomFooter(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _KioskTopBar extends StatelessWidget {
  const _KioskTopBar({
    required this.timeStr,
    required this.dateStr,
    required this.onTalkToAssistant,
  });

  final String timeStr;
  final String dateStr;
  final VoidCallback onTalkToAssistant;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 700;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.panel,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          const UniAssistLogo(size: 34, showWordmark: true),
          const Spacer(),
          if (!isCompact) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on_outlined, size: 15, color: AppColors.primary),
                  const SizedBox(width: 4),
                  const Text('Main Campus', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink)),
                  const SizedBox(width: 8),
                  const Text('•', style: TextStyle(color: AppColors.muted)),
                  const SizedBox(width: 8),
                  Text('$timeStr', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted)),
                ],
              ),
            ),
            const SizedBox(width: 10),
          ],
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.ink,
              minimumSize: const Size(100, 38),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            icon: const Icon(Icons.mic_rounded, size: 16),
            label: const Text('Assistant', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
            onPressed: onTalkToAssistant,
          ),
        ],
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(wide ? 32 : 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF0F2B48)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'UNIVERSITY SERVICE PLATFORM',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Welcome to UniAssist',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: Colors.white,
                        fontSize: wide ? 36 : 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your digital counselor and front desk service kiosk. Get official procedural guidance, downloadable forms, scholarship criteria, or sign in to track requests.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: wide ? 16 : 14,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (wide) ...[
            const SizedBox(width: 24),
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 2),
              ),
              child: const Icon(Icons.touch_app_rounded, color: AppColors.gold, size: 48),
            ),
          ],
        ],
      ),
    );
  }
}

class _PathwayCard extends StatelessWidget {
  const _PathwayCard({
    required this.title,
    required this.tag,
    required this.tagColor,
    required this.tagBg,
    required this.icon,
    required this.iconColor,
    required this.description,
    required this.bulletPoints,
    required this.actionLabel,
    required this.actionIcon,
    required this.isPrimary,
    required this.onTap,
  });

  final String title;
  final String tag;
  final Color tagColor;
  final Color tagBg;
  final IconData icon;
  final Color iconColor;
  final String description;
  final List<String> bulletPoints;
  final String actionLabel;
  final IconData actionIcon;
  final bool isPrimary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPrimary ? AppColors.teal.withValues(alpha: 0.6) : AppColors.line,
            width: isPrimary ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: tagBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: tagBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            color: tagColor,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              description,
              style: const TextStyle(fontSize: 14, color: AppColors.muted, height: 1.4, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 12),
            ...bulletPoints.map(
              (pt) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pt,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.ink),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: isPrimary ? AppColors.teal : AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: Icon(actionIcon, size: 20),
                label: Text(actionLabel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                onPressed: onTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssistantBanner extends StatelessWidget {
  const _AssistantBanner({
    required this.onTalk,
    required this.onAskWithdrawal,
  });

  final VoidCallback onTalk;
  final VoidCallback onAskWithdrawal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '🎤 Need instant guidance? Talk to our AI Digital Counselor',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.ink),
                ),
                SizedBox(height: 3),
                Text(
                  'Ask in English, Hindi, or Hinglish: "I want withdrawal", "Check CGPA", "Where is the library?", "Bonafide form"',
                  style: TextStyle(fontSize: 13, color: AppColors.muted, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(100, 44),
                  backgroundColor: Colors.white,
                ),
                onPressed: onAskWithdrawal,
                child: const Text('Withdrawal Help', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(110, 44),
                ),
                icon: const Icon(Icons.mic_rounded, size: 18),
                label: const Text('Speak / Chat', style: TextStyle(fontWeight: FontWeight.w800)),
                onPressed: onTalk,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KioskBottomFooter extends StatelessWidget {
  const _KioskBottomFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.panel,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: const [
          Icon(Icons.lock_clock_outlined, size: 15, color: AppColors.muted),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Kiosk sessions clear automatically after 5 minutes of inactivity for student privacy.',
              style: TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: 12),
          Text(
            'UniAssist Kiosk v2.0',
            style: TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
