import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/api_client.dart';
import '../../../core/theme/kiosk_theme.dart';
import '../../auth/application/auth_provider.dart';

/// A single chat message.
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<String>? quickReplies;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.quickReplies,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// State notifier managing conversation history.
class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  final Dio _dio;
  final String? _studentId;

  ChatNotifier(this._dio, this._studentId) : super([]) {
    // Welcome message
    state = [
      ChatMessage(
        text: 'Hi! I\'m your UniAssist AI advisor. I can help with academics, scholarships, exams, grievances, withdrawals, and more. How can I help you today?',
        isUser: false,
        quickReplies: [
          'Check my CGPA',
          'Scholarship options',
          'Register backpaper',
          'File a grievance',
          'Withdrawal process',
          'Fee details',
        ],
      ),
    ];
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // Add user message
    state = [...state, ChatMessage(text: text, isUser: true)];

    try {
      final response = await _dio.post('/chat', data: {
        'student_id': _studentId ?? 'STU001',
        'message': text,
      });

      final data = response.data;
      final reply = data['reply'] ?? data['response'] ?? 'I\'m not sure how to help with that.';
      final List<String>? quickReplies =
          (data['quick_replies'] as List?)?.map((e) => e.toString()).toList();

      state = [
        ...state,
        ChatMessage(text: reply, isUser: false, quickReplies: quickReplies),
      ];
    } on DioException catch (e) {
      state = [
        ...state,
        ChatMessage(
          text: 'Sorry, I couldn\'t connect to the server. Please try again. (${e.message})',
          isUser: false,
        ),
      ];
    } catch (e) {
      state = [
        ...state,
        ChatMessage(text: 'An error occurred. Please try again.', isUser: false),
      ];
    }
  }
}

final chatProvider =
    StateNotifierProvider.autoDispose<ChatNotifier, List<ChatMessage>>((ref) {
  final dio = ref.watch(apiClientProvider);
  final studentId = ref.watch(authProvider).studentId;
  return ChatNotifier(dio, studentId);
});

// ─────────────────────────────────────────────────────────────
// Chat Screen
// ─────────────────────────────────────────────────────────────

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send([String? overrideText]) async {
    final text = overrideText ?? _controller.text;
    if (text.trim().isEmpty) return;

    _controller.clear();
    setState(() => _isSending = true);

    await ref.read(chatProvider.notifier).sendMessage(text);

    setState(() => _isSending = false);

    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.smart_toy_rounded, size: 24),
            SizedBox(width: 10),
            Text('AI Assistant'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Messages ────────────────────────────────────
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                return _ChatBubble(
                  message: msg,
                  onQuickReply: (text) => _send(text),
                ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.05);
              },
            ),
          ),

          // ── Typing indicator ────────────────────────────
          if (_isSending)
            Padding(
              padding: const EdgeInsets.only(left: 24, bottom: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        3,
                        (i) => Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: AppColors.jade.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                        )
                            .animate(
                              onPlay: (c) => c.repeat(),
                            )
                            .scaleXY(
                              begin: 0.6,
                              end: 1.0,
                              duration: 600.ms,
                              delay: Duration(milliseconds: 200 * i),
                              curve: Curves.easeInOut,
                            ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── Input bar ───────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Type your question...',
                        filled: true,
                        fillColor: Theme.of(context).scaffoldBackgroundColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      enabled: !_isSending,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton.small(
                    onPressed: _isSending ? null : () => _send(),
                    child: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chat Bubble ──────────────────────────────────────────────
class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, this.onQuickReply});
  final ChatMessage message;
  final ValueChanged<String>? onQuickReply;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) ...[
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.jade.withValues(alpha: 0.15),
                  child: const Icon(Icons.smart_toy_rounded, size: 18, color: AppColors.jade),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser
                        ? AppColors.amityBlue
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      fontSize: 15,
                      color: isUser ? Colors.white : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Quick replies
          if (!isUser && message.quickReplies != null && message.quickReplies!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10, left: 40),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: message.quickReplies!
                    .map(
                      (reply) => ActionChip(
                        label: Text(reply, style: const TextStyle(fontSize: 13)),
                        onPressed: () => onQuickReply?.call(reply),
                        side: BorderSide(color: AppColors.jade.withValues(alpha: 0.4)),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}
