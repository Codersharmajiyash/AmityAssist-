import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../chat/presentation/digital_counselor_modal.dart';
import '../../chat/state/standby_counselor_state.dart';
import '../../../core/theme/kiosk_theme.dart';
import '../../../core/services/page_context_service.dart';

class AssistantFab extends ConsumerWidget {
  const AssistantFab({super.key, this.currentRoute});

  final String? currentRoute;

  void _showModeSelection(BuildContext context, WidgetRef ref) {
    if (currentRoute != null) {
      ref.read(pageContextProvider.notifier).setRoute(currentRoute!);
    }
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.support_agent_rounded, size: 56, color: AppColors.primary),
                const SizedBox(height: 16),
                const Text(
                  'How would you like to communicate?',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: _ModeButton(
                        icon: Icons.mic_rounded,
                        label: 'Voice Conversation',
                        color: AppColors.teal,
                        onTap: () {
                          Navigator.pop(context);
                          if (currentRoute != null) {
                            ref.read(pageContextProvider.notifier).setRoute(currentRoute!);
                          }
                          showDigitalCounselor(
                            context,
                            initialTab: 1,
                            autoStartVoice: true,
                            currentRoute: currentRoute,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _ModeButton(
                        icon: Icons.chat_bubble_rounded,
                        label: 'Chat',
                        color: AppColors.primary,
                        onTap: () {
                          Navigator.pop(context);
                          if (currentRoute != null) {
                            ref.read(pageContextProvider.notifier).setRoute(currentRoute!);
                          }
                          showDigitalCounselor(
                            context,
                            initialTab: 0,
                            currentRoute: currentRoute,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final standby = ref.watch(standbyCounselorProvider);

    // If AI is in Standby Mode on a form:
    if (standby.isStandbyActive) {
      return _StandbyCompanionPill(
        topic: standby.activeTopic,
        currentRoute: currentRoute,
        onTapExpand: () {
          if (currentRoute != null) {
            ref.read(pageContextProvider.notifier).setRoute(currentRoute!);
          }
          // Re-open counselor modal with restored history
          showDigitalCounselor(
            context,
            initialTab: 1,
            autoStartVoice: false,
            currentRoute: currentRoute,
          );
        },
        onMicTap: () {
          if (currentRoute != null) {
            ref.read(pageContextProvider.notifier).setRoute(currentRoute!);
          }
          // Trigger push-to-talk voice conversation
          showDigitalCounselor(
            context,
            initialTab: 1,
            autoStartVoice: true,
            currentRoute: currentRoute,
          );
        },
      );
    }

    // Normal default state when not on standby:
    return FloatingActionButton.extended(
      onPressed: () => _showModeSelection(context, ref),
      backgroundColor: AppColors.primary,
      icon: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 28),
      label: const Text(
        'Ask UniAssist',
        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _StandbyCompanionPill extends ConsumerWidget {
  const _StandbyCompanionPill({
    required this.topic,
    this.currentRoute,
    required this.onTapExpand,
    required this.onMicTap,
  });

  final String topic;
  final String? currentRoute;
  final VoidCallback onTapExpand;
  final VoidCallback onMicTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayTopic = topic.trim().isNotEmpty ? topic.trim() : 'Guidance';

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0A192F),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFF10B981), width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Glowing Green status dot
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF10B981),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Standby Topic label
            InkWell(
              onTap: onTapExpand,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  'Standby: $displayTopic',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(width: 1, height: 20, color: Colors.white24),
            const SizedBox(width: 4),
            // Push-to-Talk Mic
            IconButton(
              icon: const Icon(Icons.mic_rounded, color: Color(0xFF10B981), size: 22),
              tooltip: 'Tap to Speak',
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
              onPressed: onMicTap,
            ),
            const SizedBox(width: 4),
            // Expand Chat
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white70, size: 20),
              tooltip: 'Expand Chat History',
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
              onPressed: onTapExpand,
            ),
            const SizedBox(width: 2),
            // Exit Standby
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 18),
              tooltip: 'Exit Standby',
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
              onPressed: () {
                ref.read(standbyCounselorProvider.notifier).exitStandby();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
