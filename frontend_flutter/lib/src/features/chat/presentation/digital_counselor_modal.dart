import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/kiosk_theme.dart';
import 'chat_screen.dart';

/// Shows the AI Digital Counselor in a touch-first modal/dialog on kiosk or mobile.
Future<void> showDigitalCounselor(BuildContext context, {String? initialQuery}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DigitalCounselorModal(initialQuery: initialQuery),
  );
}

class DigitalCounselorModal extends ConsumerStatefulWidget {
  const DigitalCounselorModal({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  ConsumerState<DigitalCounselorModal> createState() => _DigitalCounselorModalState();
}

class _DigitalCounselorModalState extends ConsumerState<DigitalCounselorModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSpeaking = false;
  String _voiceStatus = 'Tap microphone to speak your question...';

  final List<String> _quickPrompts = const [
    'I want withdrawal',
    'Scholarship eligibility',
    'How to get Bonafide certificate',
    'Hostel room & mess rules',
    'Check backpaper registration',
    'Contact Registrar office',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleSend(widget.initialQuery!);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleSend(String query) {
    final text = query.trim();
    if (text.isEmpty) return;
    _textController.clear();
    ref.read(chatProvider.notifier).sendMessage(text);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 200,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _simulateVoiceInput(String spokenText) {
    setState(() {
      _isSpeaking = true;
      _voiceStatus = 'Listening... ("$spokenText")';
    });

    Future.delayed(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      setState(() {
        _isSpeaking = false;
        _voiceStatus = 'Processing speech: "$spokenText"';
      });
      _handleSend(spokenText);
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final isDesktop = mediaQuery.size.width >= 800;

    return Container(
      height: screenHeight * (isDesktop ? 0.88 : 0.94),
      margin: EdgeInsets.symmetric(
        horizontal: isDesktop ? (mediaQuery.size.width - 760) / 2 : 8,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: AppColors.line),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: AppColors.primary,
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Row(
                          children: [
                            Text(
                              'AI Digital Counselor',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                            ),
                            SizedBox(width: 8),
                            _OnlinePill(),
                          ],
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Hi 👋 How can I help you today?',
                          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Tab Selector: [ Type ] vs [ Speak ]
            Container(
              color: AppColors.primarySoft,
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.muted,
                labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                tabs: const [
                  Tab(icon: Icon(Icons.keyboard_rounded, size: 20), text: 'Type Question'),
                  Tab(icon: Icon(Icons.mic_rounded, size: 20), text: 'Speak to Assistant'),
                ],
              ),
            ),

            // Quick Prompts Carousel
            Container(
              height: 46,
              padding: const EdgeInsets.symmetric(vertical: 6),
              color: AppColors.surface,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                scrollDirection: Axis.horizontal,
                itemCount: _quickPrompts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final prompt = _quickPrompts[index];
                  return ActionChip(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.line),
                    avatar: const Icon(Icons.bolt_rounded, size: 14, color: AppColors.gold),
                    label: Text(
                      prompt,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.ink),
                    ),
                    onPressed: () => _handleSend(prompt),
                  );
                },
              ),
            ),

            // Chat Messages Stream
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: chatState.messages.length + (chatState.isSending ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= chatState.messages.length) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                            ),
                            SizedBox(width: 10),
                            Text('Counselor is formulating guidance...', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          ],
                        ),
                      ),
                    );
                  }

                  final message = chatState.messages[index];
                  final isUser = message.isUser;

                  // Check if response discusses withdrawal
                  final isWithdrawal = !isUser && (message.text.toLowerCase().contains('withdrawal') || (message.intent ?? '').contains('withdraw'));

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Container(
                          constraints: BoxConstraints(maxWidth: mediaQuery.size.width * 0.72),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                          decoration: BoxDecoration(
                            color: isUser ? AppColors.primary : AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isUser ? AppColors.primary : AppColors.line),
                          ),
                          child: Text(
                            message.text,
                            style: TextStyle(
                              color: isUser ? Colors.white : AppColors.ink,
                              fontSize: 14.5,
                              height: 1.4,
                              fontWeight: isUser ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                        ),

                        // If response is withdrawal guidance, show quick launch cards
                        if (isWithdrawal) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.goldSoft,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.assignment_turned_in_rounded, color: AppColors.ink, size: 18),
                                    SizedBox(width: 6),
                                    Text(
                                      'Official Withdrawal Workflow Steps Available',
                                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.ink),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    FilledButton.icon(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        minimumSize: const Size(120, 36),
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                      ),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        context.go('/services');
                                      },
                                      icon: const Icon(Icons.menu_book_rounded, size: 16),
                                      label: const Text('Open Withdrawal Guide', style: TextStyle(fontSize: 12.5)),
                                    ),
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size(120, 36),
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                      ),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        context.go('/login');
                                      },
                                      icon: const Icon(Icons.login_rounded, size: 16),
                                      label: const Text('Login to Submit Request', style: TextStyle(fontSize: 12.5)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ).animate().fadeIn(duration: 200.ms),
                        ],

                        // Quick reply chips
                        if (!isUser && message.quickReplies.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: message.quickReplies.map((qr) {
                              return ActionChip(
                                label: Text(qr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                onPressed: () => _handleSend(qr),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),

            // Tab Content: Type vs Speak inputs
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              child: SizedBox(
                height: 72,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Keyboard Input
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            textInputAction: TextInputAction.send,
                            onSubmitted: _handleSend,
                            decoration: InputDecoration(
                              hintText: 'Ask anything (e.g. "I want withdrawal", "Fee dues")...',
                              prefixIcon: const Icon(Icons.chat_bubble_outline_rounded),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                                onPressed: () => _handleSend(_textController.text),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Tab 2: Speak / Microphone Input
                    Row(
                      children: [
                        IconButton.filled(
                          style: IconButton.styleFrom(
                            backgroundColor: _isSpeaking ? AppColors.danger : AppColors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(16),
                          ),
                          icon: Icon(_isSpeaking ? Icons.mic_rounded : Icons.mic_none_rounded, size: 26),
                          onPressed: () => _simulateVoiceInput('I want withdrawal guidance and required documents'),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _voiceStatus,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _isSpeaking ? AppColors.teal : AppColors.muted,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                children: [
                                  _VoiceQuickChip(
                                    label: '🎤 "I want withdrawal"',
                                    onTap: () => _simulateVoiceInput('I want withdrawal'),
                                  ),
                                  _VoiceQuickChip(
                                    label: '🎤 "Scholarship details"',
                                    onTap: () => _simulateVoiceInput('What scholarships are available?'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceQuickChip extends StatelessWidget {
  const _VoiceQuickChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.tealSoft,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.teal),
        ),
      ),
    );
  }
}

class _OnlinePill extends StatelessWidget {
  const _OnlinePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.success,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 3, backgroundColor: Colors.white),
          SizedBox(width: 4),
          Text(
            'ACTIVE',
            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}
